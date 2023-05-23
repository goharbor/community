# Proposal: More Versatile Replication Filters

This is a feature proposal for [issue 8614](https://github.com/goharbor/harbor/issues/8614)

Author: Wilfred Almeida [@WilfredAlmeida](https://github.com/WilfredAlmeida/)

## Abstract

Proposal to add more fine-grained replication filters using Regular Expressions. This proposal proposes support for artifacts with [semantically versioned](https://semver.org/) tags.

## Background

As discussed in [issue 8614](https://github.com/goharbor/harbor/issues/8614), the support for more versatile replication filters is been desired by the Harbor user community for a long time now. Users have to frequently change their filter rules every time their images are updated.

## Goals

* Add regex-based filtering for the artifact tags.
    
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


---

# Proposal Updates as per discussions

Proposal updates as per discussion with [Vadim Bauer](https://twitter.com/vad1mo)

Approach 2 specified in the proposal on taking regular expression from users is favored more.

Various approaches to get this done that we discussed are as follows:


  
1. **Add a new input field for regex:**
    
    An additional input field to take user input can be added as follows along with the existing ones. Users can input an expression that will be matched against the artifacts' name, label, and tag.
    
    ![](https://cdn.hashnode.com/res/hashnode/image/upload/v1682791477555/dcc6ea2d-be9f-4343-acc0-a633638e9a0b.png)
    

**Pros:**

* No migration is needed. Existing rules will continue working.
    
* Users can switch to regex-based filtering at their convenience.
    

**Cons:**

* Logical and development complexity as novice users might need/try to combine regex and glob-based filtering which is complex to understand and develop.
    
* The development effort needed is significant. UI portal, databases, API handlers, and filtering logic are some of the components that need to be modified which is time-consuming, complex, and has the potential of breaking and causing bugs.  


  
2. **Accept regular expressions in existing input fields and distinguish between glob pattern and regex using some specifier like** `/<regex>/` **as follows**
    
    ![](https://cdn.hashnode.com/res/hashnode/image/upload/v1682791786810/47f44272-f632-49a3-93ca-9a4b5df02d6a.png)
    

**Pros:**

* Reuse of existing UI
    
* Existing filters continue working
    

**Cons:**

* Users might try to combine glob and regex rules which is complex to handle on the backend
    
* Distinguishing between the glob rule and regex rule might fail at the backend due to unidentified edge cases
    
* Database schema change needed to store glob rule and regex separately or a status field to indicate if a rule is a glob or regex  


  
3. **Provide an option for choosing between glob and regex like following**
    
    ![](https://cdn.hashnode.com/res/hashnode/image/upload/v1682792140270/b081d468-d45f-427f-a2f1-98254df55f77.png)
    

**Pros:**

* Easy to understand and use
    
* Seamless, convenient migration
    

**Cons:**

* UI, API, and Database schema changes are needed to accept, process, and store regex rules which is a lot of work
    
* Higher development and maintenance complexity  



  
4. **Depreciate glob pattern and migrate completely to regex**
    
    Pros:
    
    * Instant migration to regex rules
        
    * No need to maintain both regex and glob
        
    
    Cons:
    
    * Will break all existing installations and cause heavy migrations  



  
5. **Accept both regex and glob on UI, implement regex filtering and convert glob rules to regex in the backend**
    
    ![](https://cdn.hashnode.com/res/hashnode/image/upload/v1682792611965/2eba4664-3760-46e9-aacd-e91cf0d528bf.png)
    

Existing glob rules stored in the database in can be converted to regex on runtime.

New rules will be stored as regex

A migration script can be provided to migrate existing glob rules to regex

**Pros:**

* Existing rules continue working
    
* Regex filtering gets implemented without any change to the UI
    

**Cons:**

* Needs migration script
    
* Might break if upgrade versions
    
* Conversion of glob pattern to regex must have 100% coverage, any unidentified edge cases might break the working.


---


Approach 3 finalized after community & maintainer reviews


---


Checkout the following links to understand code decisions:

1. [Slack Converation: Whether or not to modify database schema](https://cloud-native.slack.com/archives/CC1E0J0MC/p1684043550667889)
