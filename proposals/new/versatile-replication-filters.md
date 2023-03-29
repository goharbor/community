# Proposal: More Versatile Replication Filters

This is a feature proposal for [issue 8614](https://github.com/goharbor/harbor/issues/8614)

Author: Wilfred Almeida [@WilfredAlmeida](https://github.com/WilfredAlmeida/)

## Abstract

Proposal to add more fine-grained replication filters using Regular Expressions. This proposal proposes support for artifacts with [semantically versioned](https://semver.org/) tags.

## Background

As discussed in [issue 8614](https://github.com/goharbor/harbor/issues/8614), the support for more versatile replication filters is been desired by the Harbor user community for a long time now. Users have to frequently change their filter rules every time their images are updated.

## Goals

* Add regex-based filtering for the semantic version tags.
    
* Changes made should not break existing installations upon upgrade.
    
* Provide seamless migration without needing changes to existing configurations.
    

## Implementation

### Psuedo-code Snippets

Following are some pseudo-code implementations of possible solutions

1. The following snippet performs filtration based on pattern matching by double star and version semantic version matching using regex.
    

```go
// semanticVersionRegex is a regular expression to match semantic version numbers
var semanticVersionRegex = regexp.MustCompile(`/^((\d\d?).(\d\d?).(\d\d?(-stable)?))$/gm`)

// FilterArtifactsByPatternAndVersion filters artifacts by doublestar pattern and semantic version
func FilterArtifactsByPatternAndVersion(pattern string, version string, artifacts[] * models.Artifact)[] * models.Artifact {
    matchedArtifacts: = make([] * models.Artifact, 0)
    for _,
    artifact: = range artifacts {
        if matchesDoublestarPattern(artifact.Path, pattern) && matchesSemanticVersion(artifact.Version, version) {
            matchedArtifacts = append(matchedArtifacts, artifact)
        }
    }
    return matchedArtifacts
}

// matchesDoublestarPattern checks if a given path matches a doublestar pattern
func matchesDoublestarPattern(path string, pattern string) bool {
    matched, _: = doublestar.Match(pattern, path)
        //Additional matching using existing rules to be performed here
    return matched
}

// matchesSemanticVersion checks if a given string is a semantic version number
func matchesSemanticVersion(version string, targetVersion string) bool {
    if version == targetVersion {
        return true
    }
    return semanticVersionRegex.MatchString(version) && regexp.MustCompile(targetVersion).MatchString(version)
}
```


2. The following snippet filters artifacts by version and accepts the filtration regex as a function parameter. This can be paired with existing filtration logic.
    

```go
// FilterArtifactsByVersion filters artifacts by semantic version number and a regular expression pattern
func FilterArtifactsByVersion(tags[] string, artifacts[] * models.Artifact, pattern string)([] * models.Artifact, error) {
  re, err: = regexp.Compile(pattern)
  if err != nil {
    return nil, err
  }

  matchedArtifacts: = make([] * models.Artifact, 0)
  for _, artifact: = range artifacts {
    if matchesSemanticVersion(artifact.Version, version) && re.MatchString(artifact.Path) {
      matchedArtifacts = append(matchedArtifacts, artifact)
    }
  }
  return matchedArtifacts, nil
}

// matchesSemanticVersion checks if a given string is a semantic version number
func matchesSemanticVersion(version string, targetVersion string) bool {
  if version == targetVersion {
    return true
  }

  semanticVersionRegex: = regexp.MustCompile(`/^((\d\d?).(\d\d?).(\d\d?(-stable)?))$/gm`)
  return semanticVersionRegex.MatchString(version) && semanticVersionRegex.MatchString(targetVersion)
}
```

The above snippet can also be modified to perform existing filtration logic coupled with the regex pattern passed in as the function parameter.

### Semantic Versions filtering regex

Following is the breakdown of the regex used to filter semantic versions as described & desired in [issue 8614](https://github.com/goharbor/harbor/issues/8614)

```plaintext
/^((\d\d?).(\d\d?).(\d\d?(-stable)?))$/gm
```

The following image shows the regex matches. Highlighted inputs are matches.

![](https://cdn.hashnode.com/res/hashnode/image/upload/v1679849254335/c8f7b760-4612-4860-877d-87d78930198e.png)

### File Location & Directory

To avoid breaking existing operations and for beta test releases, the functions can be put inside a separate file named `regex_replication_filter.go` placed inside the `src/pkg/reg/util/` directory. Following is the resultant directory structure

```plaintext
src/pkg/reg/util
├── pattern.go
├── pattern_test.go
├── regex_replication_filter.go
├── regex_replication_filter_test.go
├── util.go
└── util_test.go
```
