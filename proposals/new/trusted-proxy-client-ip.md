# Proposal: `Trusted Proxies for Client IP Resolution`

Author: [`Hanna Czifrus`](https://github.com/czifrushanna)

Discussion: [`x-forwarded-for support for logging true user IP #20367`](https://github.com/goharbor/harbor/issues/20367), [`Real IP is not shown behind a reverse proxy in the logs #16449`](https://github.com/goharbor/harbor/issues/16449)

## Abstract

Add a `trusted_proxies` setting that tells Harbor which load balancers and reverse proxies sit in front of it. Harbor only believes the `X-Forwarded-For` header when a request reaches it through one of those proxies, and resolves the client IP by walking the header from right to left, skipping trusted hops. The same setting drives both Harbor's bundled nginx (through `ngx_http_realip_module`) and harbor-core (through one shared resolver), so the nginx access log, the audit log (`audit_log_ext.source_ip`) and core's own log lines all record the same, non-spoofable client IP.

## Background

Most production Harbor deployments run behind a load balancer or an ingress controller. In those deployments Harbor sees the proxy's address, not the client's:

- **nginx access log**: `log_format timed_combined` logs `$remote_addr`, and the nginx templates have no `set_real_ip_from` / `real_ip_header` directives, so every request is logged with the load balancer's IP ([#16449](https://github.com/goharbor/harbor/issues/16449), [#20367](https://github.com/goharbor/harbor/issues/20367)).
- **Audit log**: the [Enhance Audit Log](enhance_audit_log.md) proposal added `source_ip` to `audit_log_ext` as a reserved column, and explicitly listed client IP tracking as a non-goal:

  > Tracking the client IP address: usually `x-forwarded-for` contains the IP address of the client, in cloud native applications, the ingress, or loadbalancer will set this field to the IP of its pod, and result in the information inaccurate. maybe in future we could have a better solution to solve this problem, just keep the reserved column empty.

  The column is still never populated.
- **Failed login log**: `GetClientIP` in `src/server/middleware/security/basic_auth.go` logs the raw value of the `X-Forwarded-For` header (or of the header named by the undocumented `TRUE_CLIENT_IP_HEADER` environment variable). It returns the whole list (e.g. `"203.0.113.7, 10.0.0.5"`) and trusts it from any client.

There is also demand to fill the audit log's `source_ip`: [goharbor/harbor#19725](https://github.com/goharbor/harbor/pull/19725) adds IP address and user agent tracking to audit logs, taking the **first** `X-Forwarded-For` entry. That is exactly the inaccuracy the Enhance Audit Log proposal warned about, and it is also spoofable:

```
client sends:            X-Forwarded-For: 6.6.6.6
load balancer appends:   X-Forwarded-For: 6.6.6.6, 203.0.113.7
Harbor nginx appends:    X-Forwarded-For: 6.6.6.6, 203.0.113.7, 10.0.0.5
first entry:             6.6.6.6        <- chosen by the client
```

The only workaround today is to place a custom `*.server.conf` with `set_real_ip_from` into `common/config/nginx/conf.d/` by hand. It only fixes the nginx access log, and `prepare` deletes the generated config directory on every run, so it is lost on every `./prepare`, `install.sh` or upgrade.

The missing piece in all of the above is the same: Harbor has no notion of which proxies it can trust. This proposal adds it.

## Proposal

### Configuration

A new optional block in `harbor.yml`:

```yaml
# Uncomment trusted_proxies if Harbor runs behind load balancers or reverse proxies
# that set the X-Forwarded-For header, to record the real client IP in logs.
# trusted_proxies:
#   # Networks (CIDR) or single IPs of the proxies in front of Harbor.
#   # Only list addresses you control: any client in these networks can choose
#   # the IP that Harbor records.
#   networks:
#     - 10.0.0.0/24
#     - 2001:db8::/64
#   # The header the proxies put the client address in, read by Harbor's nginx.
#   # Defaults to X-Forwarded-For.
#   header: X-Forwarded-For
```

`prepare` validates the block and fails with an error for:

- entries that are not valid IPs or CIDRs,
- `0.0.0.0/0` and `::/0` (trusting every address is the same as trusting the header from anyone),

and prints a warning for very broad networks (prefix shorter than `/8` for IPv4, `/32` for IPv6).

This is a `harbor.yml` (install-time) setting, not a system setting in the UI or the `properties` table: nginx needs it when `prepare` renders its config, and it describes the infrastructure around Harbor rather than application behavior.

### nginx

When `trusted_proxies` is set, `prepare` renders into both `nginx.http.conf.jinja` and `nginx.https.conf.jinja` (http context):

```nginx
set_real_ip_from 10.0.0.0/24;
set_real_ip_from 2001:db8::/64;
real_ip_header   X-Forwarded-For;
real_ip_recursive on;
```

`real_ip_recursive on` makes nginx walk the header from right to left and stop at the first address that is not trusted, which is the same algorithm core uses (below). After that, `$remote_addr` is the client IP, so:

- the access log records the client IP with no change to `log_format`,
- `proxy_set_header X-Real-IP $remote_addr` forwards the client IP,
- `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for` appends the client IP as the rightmost entry of the header sent to core.

The bundled `nginx-photon` image is built from the Photon OS 5 `nginx` package, which is compiled with `--with-http_realip_module`, so no image change is needed. When the block is not set, the nginx config is unchanged.

### harbor-core

One shared resolver in core, used everywhere a client IP is needed:

```go
// ClientIP returns the address of the client that sent the request.
// X-Forwarded-For is only believed when the direct peer is a trusted proxy.
func ClientIP(r *http.Request) string {
	peer := addrOf(r.RemoteAddr)
	if !trusted(peer) {
		return peer.String()
	}
	client := peer
	hops := parseXFF(r.Header.Values("X-Forwarded-For")) // all values, in order
	for i := len(hops) - 1; i >= 0; i-- {
		if !hops[i].IsValid() { // garbage entry: stop, do not skip past it
			break
		}
		client = hops[i]
		if !trusted(client) {
			break
		}
	}
	return client.String()
}
```

- The result is the first untrusted address from the right. If every address is trusted (for example a client inside a trusted network), it is the leftmost one, matching nginx's `real_ip_recursive`.
- Addresses are parsed with `net/netip`; ports, IPv6 brackets and IPv4-mapped IPv6 addresses are normalized. An entry that does not parse ends the walk and the last valid address is used, so a malformed header can never produce an arbitrary string.
- The trusted set is built from two environment variables rendered by `prepare` into `templates/core/env.jinja`:
  - `TRUSTED_PROXY_NETWORKS`: the `trusted_proxies.networks` list, comma separated.
  - `TRUSTED_PROXY_HOSTNAMES`: hostnames whose resolved IPs are trusted. For docker-compose, `prepare` always sets this to `proxy`, the bundled nginx service, so core trusts Harbor's own nginx without users knowing the docker network's subnet. The names are resolved at startup and refreshed periodically (every 30 seconds); if a lookup fails, the previous result is kept, and if there is none, nothing is trusted for that name.
- Core only reads `X-Forwarded-For`, never single-value headers such as `X-Real-IP` or `CF-Connecting-IP`, even when `trusted_proxies.header` names one (see Rationale).

The resolver is used by:

1. **Audit log**: the request context carries the resolved client IP, and the audit log event handler stores it in `audit_log_ext.source_ip` (and the forwarded syslog entry) when IP tracking is enabled. The on/off switch for recording IPs at all (IP addresses are personal data) belongs to the audit log IP and user agent feature from [#19725](https://github.com/goharbor/harbor/pull/19725), which will be re-submitted on top of this proposal. This proposal only decides *which* IP is recorded.
2. **Failed login log line**: `GetClientIP` in `basic_auth.go` is replaced by the resolver, so the log shows one resolved IP instead of the raw header.

### Resulting behavior

| Deployment | `trusted_proxies` | Recorded client IP |
|---|---|---|
| docker-compose, no load balancer | not set | the real client (core trusts nginx, nginx's peer is the client) |
| docker-compose behind a load balancer | not set | the load balancer (same as today's nginx access log; safe default) |
| docker-compose behind a load balancer | load balancer networks | the real client, in nginx, audit log and core logs |
| client forges `X-Forwarded-For` | any | ignored: walking from the right stops at the first untrusted hop, which the trusted proxies appended themselves |

## Non-Goals

- **PROXY protocol.** Supporting TCP load balancers that send the PROXY protocol header (`listen ... proxy_protocol`) is left for a follow-up. A `proxy_protocol` listener rejects plain connections, including Harbor's own container `HEALTHCHECK` (`curl http://localhost:8080`) and load balancer health checks that do not speak it, so it needs a separate listener design.
- **The RFC 7239 `Forwarded` header** in core. Only `X-Forwarded-For` is parsed, which every common proxy and ingress controller can produce.
- **Recording the user agent**, and the audit log UI/API for `source_ip`. These belong to the audit log feature from [#19725](https://github.com/goharbor/harbor/pull/19725).
- **Other components' logs** (registry, jobservice, trivy adapter). They only receive requests from other Harbor components.
- **Proving client identity.** The resolved IP is the first address outside the trusted proxies, that is, the address the outermost trusted proxy saw. Behind NAT or carrier-grade NAT it identifies a network, not a machine.
- **Changing the setting at runtime.** Changes require running `prepare` and restarting, like other `harbor.yml` settings.

## Rationale

### Why a trust list, and why right to left

Any approach that reads `X-Forwarded-For` without knowing which hops are trusted lets the client choose its own IP. Reading the **first** entry (as in [#19725](https://github.com/goharbor/harbor/pull/19725)) or the raw header (as `GetClientIP` does today) are both spoofable, as shown in the Background section. Walking from the right and skipping trusted hops is the approach used by nginx (`real_ip_recursive`) and most reverse proxies and web frameworks: every entry to the right of the result was appended by a proxy the operator vouched for.

### Alternatives considered

| Alternative | Why not |
|---|---|
| **Only configure nginx `real_ip`** | Fixes the nginx access log, but not core: Helm `ingress` deployments do not use Harbor's nginx at all, and core would still have to decide which header to believe. |
| **Only document `TRUE_CLIENT_IP_HEADER`** | Choosing a header name does not establish trust; the IP stays spoofable. |
| **Trust the docker network's subnet in core** | Docker assigns the `harbor` network's subnet per host (the compose template does not pin one), so it would have to be detected from core's own interface. That trusts every container on the network (trivy adapter, exporter, user-added sidecars), not just nginx. Resolving the `proxy` hostname trusts only nginx. |
| **Pin a subnet for the `harbor` network** | Can collide with users' existing networks or Docker address pools, and changes the network on upgrade. |
| **Make it a system setting in the UI** | nginx needs it when `prepare` renders its config; it is infrastructure, not application configuration. |

### Why core only reads `X-Forwarded-For`

nginx forwards incoming headers unchanged, but *appends* to `X-Forwarded-For` the address it actually saw. If core accepted a single-value header such as `X-Real-IP` or `CF-Connecting-IP` because it arrived from trusted nginx, a client that can reach nginx directly (bypassing the load balancer) could set that header to anything: nginx would not trust the client, but would still forward the forged header. With `X-Forwarded-For`, the address nginx appends is always the rightmost entry, so the walk in core stops there. Custom headers are therefore resolved by nginx (`real_ip_header`), which normalizes the result into `X-Forwarded-For`.

### One setting for nginx and core

Both layers apply the same algorithm to the same list, so the nginx access log, the audit log and core's log lines agree, and users configure trust in one place.

## Compatibility

- **Default behavior.** Without `trusted_proxies`, the nginx config is unchanged. Core trusts only the bundled nginx, so it resolves the same address nginx logs today.
- **Failed login log line.** Today it logs the raw `X-Forwarded-For` header, which behind a load balancer happens to contain the real client IP, unverified. After this change, without `trusted_proxies`, it logs the load balancer's IP. Users who rely on the current output need to configure `trusted_proxies`. This must be called out in the release notes.
- **`TRUE_CLIENT_IP_HEADER`.** It is undocumented, but it has existed since [#16423](https://github.com/goharbor/harbor/issues/16423). It is deprecated: if it is set, core logs a warning at startup pointing to `trusted_proxies` and ignores it. It is removed in the following release.
- **`harbor.yml` upgrades.** A `harbor.yml` migration template for the target version is added under `make/photon/prepare/migrations/` that carries the `trusted_proxies` block over, otherwise `prepare migrate` would drop it.
- **Database.** No schema change: `audit_log_ext.source_ip` already exists. Its type is `VARCHAR(50)` (the Enhance Audit Log proposal specified `inet`); the longest normalized IPv6 address is 45 characters, so it fits.
- **Helm.** Without chart changes, users of `expose.type: ingress` can set `TRUSTED_PROXY_NETWORKS` through `core.extraEnvVars`. See Open issues for the deployments that use Harbor's nginx in Kubernetes.

## Implementation

The implementation is planned as separate pull requests, merged in this order so that no release records a spoofable client IP:

1. **Core resolver.** `ClientIP` with `TRUSTED_PROXY_NETWORKS` / `TRUSTED_PROXY_HOSTNAMES`, the hostname refresh loop, and a middleware that stores the resolved IP in the request context. `GetClientIP` in `basic_auth.go` switches to it, and `TRUE_CLIENT_IP_HEADER` gets its deprecation warning. Table-driven unit tests: trusted/untrusted peer, forged and malformed headers, multiple header values, IPv4/IPv6/mapped addresses and ports.
2. **`harbor.yml` and prepare.** The `trusted_proxies` block and its validation, rendering into both nginx templates and `templates/core/env.jinja` (`TRUSTED_PROXY_HOSTNAMES=proxy` for docker-compose), the `harbor.yml.tmpl` documentation, and the `harbor.yml` migration template.
3. **Audit log IP and user agent.** The feature from [#19725](https://github.com/goharbor/harbor/pull/19725), rebased onto `audit_log_ext` and reading the IP from the resolver.
4. **Documentation.** A "Running Harbor behind a load balancer" section in the Harbor docs, including the Kubernetes caveat below.

## Open issues

- **Helm with Harbor's nginx** (`expose.type` `clusterIP`, `nodePort`, `loadBalancer`). The chart's nginx configmap has no hook for custom config, so `real_ip` support needs a harbor-helm change. Core's peer there is the nginx *pod*, whose IP changes and is not what the nginx Service name resolves to; the chart would need a headless Service for `TRUSTED_PROXY_HOSTNAMES`, or users would trust the pod network. Input from the harbor-helm maintainers is needed.
- **Helm with `ingress`.** Core has to trust the ingress controller's pods. Without a stable address, users often end up trusting the whole pod network, which lets any pod in the cluster choose the recorded IP. This should be documented, and a better option may be worth exploring.
- **Kubernetes `LoadBalancer` Services with `externalTrafficPolicy: Cluster`** rewrite the source address before it reaches the pod. With an L4 load balancer that does not add `X-Forwarded-For`, the client IP is lost before Harbor sees it, which needs `externalTrafficPolicy: Local` or PROXY protocol. This is a documentation item, not something Harbor can fix.
- **Overlap with the [Identity Aware Proxy authentication proposal (#233)](https://github.com/goharbor/community/pull/233)**, which has an optional "Allowed sources: List of hosts or IPs the auth proxy requests can be forwarded from." If both are accepted, they should share one trusted proxy list rather than adding two settings with the same meaning.
- **Should `trusted_proxies` also be passed to core**, or is trusting the bundled nginx enough for docker-compose? Passing it costs nothing and makes core correct in deployments where it is not behind Harbor's nginx, so this proposal passes it; the question is whether a single variable is clearer for operators.
