# Proposal: Add Official CLI for Harbor

Author: Akshat/[akshatdalton](https://github.com/akshatdalton)

## Abstract

This proposal aims to add the official CLI for Harbor. It will have basic features like user login and other CRUD operations like create project, get project, list projects, etc.

## Background

There are some unofficial CLI projects to interact with Harbor API, and now Harbor wants to provide official support for CLI.

## Goals

- Implement official CLI for Harbor.
- Support basic CRUD operations like create project, get project, list projects, etc.

## Implementation

### Directory structure

```
cli/
├── LICENSE
├── README.md
├── cmd
│   ├── login
│   │   └── login.go
│   ├── project
│   │   └── get_project.go
│   ├── root.go
│   └── utils
│       └── utils.go
├── go.mod
├── go.sum
└── main.go
```

I will be using [cobra](https://github.com/spf13/cobra) to make this CLI tool and it will have the directory structure as shown above. Each of the commands will be treated as an individual sub-package.

```
cmd/
├── project
    ├── create_project.go
    ├── create_project_test.go
    ├── delete_project.go
    ├── delete_project_test.go
    ├── .
    ├── .
    ├── .
```

<br>

User credentials will be stored in `~/.harbor/config` upon sign in and the same will be used to read the credentials to make the API calls.

<br>

[harbor/go-client](https://github.com/goharbor/go-client) will be used to make any API calls for any given server address.

### Example Implementation for `get_project.go`

```go
package project

import (
	"context"

	"github.com/akshatdalton/harbor-cli/cmd/constants"
	"github.com/akshatdalton/harbor-cli/cmd/utils"
	"github.com/goharbor/go-client/pkg/sdk/v2.0/client/project"
	"github.com/spf13/cobra"
)

type getProjectOptions struct {
	projectNameOrID string
}

// NewGetProjectCommand creates a new `harbor get project` command
func NewGetProjectCommand() *cobra.Command {
	var opts getProjectOptions

	cmd := &cobra.Command{
		Use:   "project [NAME|ID]",
		Short: "get project by name or id",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			opts.projectNameOrID = args[0]
			credentialName, err := cmd.Flags().GetString(constants.CredentialNameOption)
			if err != nil {
				return err
			}
			return runGetProject(opts, credentialName)
		},
	}

	return cmd
}

func runGetProject(opts getProjectOptions, credentialName string) error {
	client := utils.GetClientByCredentialName(credentialName)
	ctx := context.Background()
	response, err := client.Project.GetProject(ctx, &project.GetProjectParams{ProjectNameOrID: opts.projectNameOrID})

	if err != nil {
		return err
	}

	utils.PrintPayloadInJSONFormat(response)
	return nil
}
```

We will follow the verb-noun syntax, for example:
```
harbor get project 1
```

### Login to multiple registries

Users can log in to multiple registries and set the credential name for each set of credentials they log in with. And later can specify the credential to use, for any sub-commands, via the CLI option or by setting the environment variable: `HARBORCREDENTIALNAME`. If nothing is set, the current credential name set in `~/.harbor/config` will be used.

#### Structure of config file

```yaml
current-credential-name: localhost-myusername1
credentials:
- name: localhost-myusername1
  username: myusername1
  password: mypassword1
  serveraddress: http://localhost
- name: server1
  username: myusername2
  password: myusername2
  serveraddress: https://my.goharbor.io
- name: server2
  username: myusername3
  password: mypassword3
  serveraddress: https://my.goharbor.io
```

If the credential name is not specified during login then it will be constructed from the credentials passed in the format: `<DOMAINNAME>-<USERNAME>` where `DOMAINNAME` is the domain name of the server address and `USERNAME` is the username.
