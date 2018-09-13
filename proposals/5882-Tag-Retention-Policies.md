# Proposal: Tag Retention Policies

Author: Nathan Lowe

Discussion: [goharbor/harbor#5882](https://github.com/goharbor/harbor/issues/5882)

## Abstract

Provide an automated method of deleting tags from Harbor based on various rules,
which can be defined at the Server, Project, or Repository level. These rules
can be configured by Harbor Admins, or, if enabled, Project Admins.

## Background

Not many people have the luxury of unlimited storage. For images and tags that
are effectively ephemeral (like those built and tagged for use only by an
intermediate process in a CI pipeline) it does not make sense to keep these tags
around for an extended period of time, consuming precious resources. Other tags,
like those correlating to released or deployed software may need to be kept for
an extended period of time or even forever for various legal or compliance
reasons. While this is possible today via Harbor's API, Harbor Administrators
could greatly benefit from having this functionality built-in to harbor itself.

This seems to be a relatively popular issue in the community today:

* [goharbor/harbor#1168](https://github.com/goharbor/harbor/issues/1168) - 强烈建议增加定时删除清理镜像策略 (Google Translate: "It is strongly recommended to add a timed delete cleanup mirroring strategy.")
* [goharbor/harbor#4753](https://github.com/goharbor/harbor/issues/4753) - Can not automation clean old images and can not setup clean policy?
* [goharbor/harbor#5085](https://github.com/goharbor/harbor/issues/5085) - Harbor registry tag cleaner tool

A basic solution exists today as an out-of-tree project contributed by employees
of Hyland Software. For details on this existing solution, please see
[hylandsoftware/Harbor.Tagd](https://github.com/HylandSoftware/Harbor.Tagd).
This solution runs external to Harbor and only supports one type of rule:
"Always keep tags in this list: `[latest, a, b, ...]` and then keep the most
recent `x` tags." These rules cannot be configured from Harbor itself and
requires additional infrastructure to support and run the cleanup process.

## Proposal

I propose the following solution:

[![](https://gist.githubusercontent.com/nlowe/fa9524cef4d9b02dddab29ebb24705db/raw/f773c136facd21269dd61b3662083057dc5cf7f4/process.svg?sanitize=true)](https://www.draw.io/?title=Tag%20Retention%20Process#Uhttps%3A%2F%2Fdrive.google.com%2Fuc%3Fid%3D116m9y_QvSDVOg1TC3g0H2jP9LJHvqMzk%26export%3Ddownload)

### Definitions

* `server`: An instance of [`goharbor/harbor`](https://github.com/goharbor/harbor)
* `project`: A project in a `server`, a collection of `repositories`
* `repo` / `repository`: A repository in a `project`, a collection of `tag`s
* `tag`: A tag on a docker image
* `rule`: A retention rule
* `Filter Chain`: An ordered collection of `rule`s to apply to an ordered set of `tag`s

### Overview

At the heart of Tag Retention is the `Rule`. These can be something as simple as
"Keep Everything" to something as complex as "Delete all tags with any of these
labels: `[foo, bar, ...]` older than `x` days." Rules apply to one or more
Projects, Repositories, and Tags. For each Project and Repository, the rules
that apply to it are composed into a Filter Chain.

### The Filter Chain

Rules can be composed to allow a complex expression of one or more Retention
Policies. Administrators may wish to enforce a default policy but allow the
policy to be tweaked at a per-project or per-repository level. Conversely,
Project Administrators may be fine with the default policy but decide it is
acceptable to keep fewer tags than what the default policy provides for. The
Filter Chain is composed of one or more Filters in order of precedence, and
always concludes with the filters that make up the server-wide policy. If there
is no server-wide policy, all tags are kept.

A rough interface may look like this:

```go
// Project represents a project in Harbor
type Project struct{}

// Repository represents a repo in a Harbor Project
type Repository struct{}

// Tag represents a tag on a project/repository combination
type Tag struct{}

// TagAction records when a filter takes an action upon a tag
type TagAction struct{
    Target Tag
    ActingFilter Filter
}

// Filter is a tag filter in a Retention Policy Filter Chain
type Filter interface {
    // Process takes tags from the input channel and writes them to one of the three output channels.
    // Tags are written to toKeep if the tags should be explicitly kept by the Filter
    // Tags are written to toDelete if the tags should be explicitly deleted by the Filter
    // Tags are written to next if the retention policy does not apply to the provided tag
    //      or if the policy does not care if the tag is kept or deleted
    //
    // Filters do not own any of the provided channels and should **not** close them under any circumstance
    Process(input <-chan Tag, toKeep, toDelete chan<- TagAction, next chan<- Tag) error

    // AppliesToProject determines if the filter is applicable for repositories and tags in the provided project
    AppliesToProject(p *Project) bool

    // AppliesToRepository determines if the filter is applicable for tags in the provided repository
    AppliesToRepository(r *Repository) bool
}
```

Filter chains are constructed on a per-project and per-repository basis. This is
done by chaining together all filters that apply to the specific repository in
order of precedence, then all filters that apply to the specific project, then
server-wide filters. This way, a filter is guaranteed to only receive tags from
the same project and repository for the entire duration of a call to `Process`.

Filter precedence is set by Server and Project administrators.

All operations performed in `Process(...)` should be thread-safe. The
implementation may choose to apply the filter in one or more filter chains
simultaneously (with different input and output channels).

When processing a tag, Filters can make one of three decisions:

1. Explicitly Keep the tag
2. Explicitly Delete the tag
3. Do Nothing with the tag

When a filter keeps or deletes a tag, a `TagAction` record is written to the
`toKeep` or `toDelete` channel associating the acting filter with the tag (and
implicitly the action taken) for logging purposes.

If a filter does nothing with the tag it is expected to pass it to the next
filter in the chain. Keeping or Deleting a tag will terminate the filter chain
for that tag; no further filters will be processed.

An example implementation of the only filter supported by
[hylandsoftware/Harbor.Tagd](https://github.com/HylandSoftware/Harbor.Tagd) may
look something like this:

```go
type KeepLatestXFilter struct{
    Threshold int
}

func (f *KeepLatestXFilter) Process(input <-chan Tag, toKeep, toDelete chan<- TagAction, next chan<- Tag) error {
    count := 0
    for tag := range input {
        if !f.AppliesToTag(tag) {
            next <- tag
            continue
        }

        action := TagAction{Target: tag, ActingFilter: f}
        if ++count > f.Threshold {
            toDelete <- action
        } else {
            toKeep <- action
        }
    }
}

func (f *KeepLatestXFilter) AppliesToProject(p *Project) bool {
    // TODO: Ensure filter applies to Project
    return true
}

func (f *KeepLatestXFilter) AppliesToRepository(r *Repository) bool {
    // TODO: Ensure filter applies to Repository
    return true
}

func (f *KeepLatestXFilter) AppliesToTag(t Tag) bool {
    // TODO: Ensure filter applies to tag
    return true
}
```

While the filter chain is processing tags, all tags in the explicit keep and
explicit delete lists are accumulated. After all rules have finished processing
for all tags, the system checks to ensure that any tags in the delete list do
not have a tag with the same digest in the keep list. If it finds any such tags,
they are removed from the delete list, as harbor will delete all tags with the
same digest when a delete command is issued.

### Built-In Rule Types

These are the rules I propose we implement initially:

* Keep Everything: Simply keep all tags in a project/repository
* Delete Everything: Simply delete all tags in a project/repository

Additionally, I propose the following rules be implemented that support
optionally filtering tags by `Label`s added to them in Harbor:

* Always Keep `x`: Always keep the tag matching the regular expression `x`
* Always Delete `x`: Always delete the tag matching the regular expression `x`
* Keep if the most recent download was at least `x` days ago
* Keep most-recent `x` tags: Keep only the most recent `x` Tags
* Delete all tags older than `x`: Delete any tag that was created on or before `x` and keep everything else

### UI

There's not a lot of prior work for this type of feature. Most "Retention" style
systems seem to just enforce a storage or tag quota instead of allowing for
granular rules. A lot of these quotas don't maintain themselves automatically
for this reason, they rely on developers to interact with the web interface or
API to cleanup after themselves in order to stay under quota. A new proposal
will be submitted for this if this proposal is accepted.

## Non-Goals

This proposal does not seek to cover notifications related to tag retention. The
existing implementation in
[hylandsoftware/Harbor.Tagd](https://github.com/HylandSoftware/Harbor.Tagd)
posts results to a slack-compatible webhook. As far as I'm aware, Harbor has no
other notification capabilities other than what the backing docker registry
supports. A separate proposal should be filed if users seek this functionality.

This proposal does not allow for additional rule types to be added at runtime.
Users who need additional rule types besides what Harbor will support should
contribute to the project or maintain a fork of the project if these rules
cannot be contributed back upstream.

## Rationale

There are a few alternatives to this method. The first being the simplest: Allow
quotas and optionally add automatic enforcement of quotas. Essentially, allow an
Admin to define how much space a project / repository is allowed to consume.
Upon hitting this quota new pushes are rejected until a developer cleans up old
tags manually. Additionally, the system could try to perform automated cleanup
by removing the oldest tags until the project or repository is under quota. I
feel this route does not offer enough flexibility to be feasible.

Alternatively, we could choose to not implement retention policies at all. Users
already have the ability to delete tags programmatically via the API and are
free to develop their own solutions for Tag Retention (a la
[`hylandsoftware/Harbor.Tagd`](https://github.com/hylandsoftware/Harbor.Tagd)).
However, I feel this feature is important enough to warrant inclusion in Harbor.

## Compatibility

No configuration or migration of data should be required ahead of time prior to
installing or upgrading to the first release of Harbor that includes Tag
Retention Policies. Upon installing this release, the default tag policy will be
to keep everything.

Going forwards, changes to filter behavior must be backwards compatible. Any
breaking changes in behavior of existing filters must be reserved for major
version increments of Harbor and be sufficiently documented.

## Implementation

I propose this feature be implemented in 3 phases:

1. Individual rule types and construction of the filter chain are fully implemented with tests
2. API Extended to Add / Update / Remove filters and kick off retention
3. User Interface Implementation

This allows the feature to be worked on and reviewed in smaller chunks. For the
first phase, this could either be one giant PR for the whole phase or smaller
PRs for each newly implemented filter type or feature. More discussion is
required on how to go about doing this.

If this implementation plan is accepted, issues should be created for tracking
each phase of implementation.
