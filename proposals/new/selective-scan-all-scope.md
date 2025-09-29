Proposal: Selective scope for scheduled “Scan All”

Author: Soumya Raikwar (@SoumyaRaikwar)

Discussion: https://github.com/goharbor/harbor/issues/22266

Abstract
Allow administrators to limit scheduled “Scan All” executions to a subset of artifacts by specifying scope via an optional X-Scan-All-Scope header on schedule create/update. Scope can be defined by project_ids or repositories. When absent, behavior remains unchanged (scan all artifacts).

Background
Today, the scheduled “Scan All” job scans every artifact in Harbor. In large installations this is resource-intensive and often unnecessary—teams typically need recurring scans only for selected projects or images. There is no built-in way to constrain the scheduled scan set without removing other projects from Harbor or disabling the schedule entirely.

Proposal
•  Introduce an optional request header for schedule create/update: X-Scan-All-Scope
•  Supported JSON payloads for the header:
◦  {"project_ids":[number,...]}
◦  {"repositories":[string,...]} where strings are repo references like project/repo or project/repo:tag
•  Execution behavior:
◦  If scope header is present, enumerate artifacts only from the specified scope.
◦  If scope header is omitted, retain existing behavior and scan all artifacts.
•  Portal (UI):
◦  In Interrogation Services > Vulnerability page, add inputs to pick one or more projects and optionally multi-select repositories. When saving a schedule, the UI sends the scope via X-Scan-All-Scope.
•  Backward compatibility:
◦  No changes to existing API schemas; only an optional header. Existing clients keep working unchanged.

Non-Goals
•  Changing the behavior of manual “Scan All now” (remains global in this iteration).
•  Adding advanced matching patterns (e.g., wildcards/regex) beyond explicit project/repository selection.
•  Persisting complex scope objects beyond what is necessary to execute the schedule and record execution metadata.

Rationale
•  Header vs request body:
◦  Using a header avoids changing the schedule schema and keeps the request body stable/backward compatible.
◦  It lets existing clients ignore the feature safely.
•  Scope shapes:
◦  project_ids aligns with Harbor’s internal references and is efficient to resolve.
◦  repositories matches how users think about targets and supports per-tag precision if needed.
•  Compatibility:
◦  Optional feature flag style—no impact when not used.

Compatibility
•  API: Backward compatible. Existing endpoints and payloads remain valid. The optional X-Scan-All-Scope header is additive.
•  RBAC: Unchanged—only system admins can configure the “Scan All” schedule.
•  Mixed versions: Older clients not sending the header continue scanning all artifacts.

Implementation
•  Backend
◦  Parse X-Scan-All-Scope header JSON on schedule create/update and store it in schedule execution context or scheduler metadata (implementation detail depending on existing scheduler storage).
◦  Extend scan-all controller to accept an optional scope and apply it to the artifact iterator (project-based and repo-based filters).
◦  Record scope summary in execution metadata/logs for observability.
•  Frontend
◦  Add project selection and repository multi-select to the Vulnerability configuration screen.
◦  Send X-Scan-All-Scope on schedule create/update when user selects a scope.
◦  Minor type fix: use the local Project model where needed for compatibility with existing services.
•  Testing
◦  Unit tests for scope parsing and filtering logic.
◦  Integration tests for scheduled runs covering: no scope (global), project-scoped, repo-scoped.
◦  UI tests to verify schedule save with/without scope and correct header transmission.
•  Documentation
◦  Update API docs to describe X-Scan-All-Scope and provide examples.
◦  Update admin docs to show UI flow for configuring scoped schedules.

Open issues (if applicable)
•  Header size limits: Very large lists of repositories may exceed practical header limits. Guidance may be required (e.g., prefer project_ids for broad scoping; keep repo lists manageable).
•  Persistence details: Confirm where scope is stored for scheduled jobs (job metadata vs scheduler DB) to ensure it survives restarts and is visible in execution history.
•  Error handling/partial scope: Define whether invalid/unauthorized IDs or repositories are ignored with warnings or cause schedule update rejection. Initial suggestion: skip invalid entries, log warnings, and continue with valid targets.
•  Future enhancements: Support patterns (e.g., by label or wildcard), and scoping for “Scan All now” as a separate follow-up if community agrees.