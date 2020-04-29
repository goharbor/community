# Proposal: `Refactor admin server`

Author: `Daojun Zhang/stonezdj`

Discussion: 
[5080](https://github.com/goharbor/harbor/issues/5808)
[5525](https://github.com/goharbor/harbor/issues/5525)

## Abstract

Admin server is component used to manage the configuration for harbor. this proposal is going to provide a simple and mantainable configuration management.

## Background

In previous implementation of harbor admin server, it is a dependent http server to manage configuration, the prepare program parses harbor.cfg and generate env file for harbor and it serves the adminserver, the adminserver load these environment variables to database and also read these configuration from database when ui or job service retrieve/update configurations. some painpoints of mananging configurations.

1. There is a standalone admin server container, actually this server is only used configuration read/write, the api is exposed by core/api actually. there is no need to separate it from core api.

2. There are lots of code change when we need a new configuration item, it is error prone.

3. The system setting/user setting are messed together make the configuration file too large to maintain.

## Proposal

Because refactor adminserver involve lots of code change, in order to We are going to refactor the admin server with following tasks.

1. Remove adminserver container, all configuration related API is handled by core api. also include migrate some other admin server related API to core api.

2. Seperate user settings from harbor.cfg, and keep system settings in harbor.cfg, and system setting is set to env and can not change. user setting are read/write by core api, system settings is read only.

We are going to seperate the configuration in this way.

Items will kept in harbor.cfg | Configure item | System Setting | User Setting 
------------|------------|------------|------------
 | | admin_initial_password    |  | x
admiral_url | admiral_url    | x | 
auth_mode | auth_mode    | x | 
 | | cfg_expiration    | x | 
 | | chart_repository_url    | x | 
clair_db | clair_db    | x | 
clair_db_host | clair_db_host    | x | 
clair_db_password | clair_db_password    | x | 
clair_db_port | clair_db_port    | x | 
clair_db_username | clair_db_sslmode    | x | 
|  | clair_db_username    | x | 
|  | clair_url    | x | 
|  | core_url    | x | 
|  | database_type    | x | 
|  | email_from    |   | x
|  | email_host    |   | x 
|  | email_identity    |   | x 
|  | email_insecure    |   | x
|  | email_password    |   | x
|  | email_port    |   | x
|  | email_ssl    |   | x 
|  | email_username    |  | x
|  | ext_endpoint    | x | 
|  | jobservice_url    | x | 
|  | ldap_base_dn    | x | 
|  | ldap_filter    |   | x 
|  | ldap_group_admin_dn    |  | x 
|  | ldap_group_attribute_name    |   | x 
|  | ldap_group_base_dn    |   | x 
|  | ldap_group_search_filter    |   | x 
|  | ldap_group_search_scope    |   | x
|  | ldap_scope    |   | x
|  | ldap_search_dn    |   | x
|  | ldap_search_password    |  | x
|  | ldap_timeout    |   | x
|  | ldap_uid    |   | x
|  | ldap_url    |   | x
|  | ldap_verify_cert    |   | x
|  | max_job_workers    |   | x
|  | notary_url    | x | 
|  | postgresql_database    | x | 
db_host | postgresql_host    | x | 
db_password | postgresql_password    | x | 
db_port | postgresql_port    | x | 
|  | postgresql_sslmode    | x | 
db_user | postgresql_username    | x | 
 | | project_creation_restriction    | x | 
 | | read_only    |   | x 
registry_storage_provider_name | registry_storage_provider_name    | x | 
 | | registry_url    | x | 
 | | self_registration    |   | x
 | | token_expiration    |   | x 
 | | token_service_url    | x | 
 | | uaa_client_id    |   | x 
 | | uaa_client_secret    |   | x
 | | uaa_endpoint    |  | x
 | | uaa_verify_cert    |   | x
 | | with_chartmuseum    | x | 
 | | with_clair    | x | 
 | | with_notary    | x | 
 | _version |                | x |
 | hostname |                | x  |
 | ui_url_protocol |                | x  |
 | customize_crt|                | x  |
 | ssl_cert|                |  x |
 | ssl_cert_key |                |  x |
 | secretkey_path |                | x  |
 | log_rotate_count |                |  x |
 | log_rotate_size |                |  x |
 | http_proxy |                | x  |
 | https_proxy |                | x  |
 | no_proxy |                | x  |
 | redis_host |                | x  |
 | redis_port |                | x  |
 | redis_password |                | x  |
 | redis_db_index |                | x  |
 | registry_storage_provider_config |                | x  |
 | registry_custom_ca_bundle |                |  x |

3. Remove adminserver related build script, docker file and code.

4. Refactor configuration item management, provide a unified type conversion, validation, default value setting, read, write.

The structure to store metadata of configure items:

```go
// Item - Configure item include default value, type, env name
type Item struct {
	//true for system, false for user settings
	SystemConfig bool
	//email, ldapbasic, ldapgroup, uaa settings, used to retieve configure items by group, for example GetLDAPBasicSetting, GetLDAPGroupSetting settings
	Group string
	//environment key to retrieves this value when initialize, for example: POSTGRESQL_HOST, only used for system settings, for user settings no EnvironmentKey
	EnvironmentKey string
	//The default string value for this key
	DefaultValue string
	//The key for current configure settings in database and rerest api
	Name string
	//It can be integer, string, bool, password, map
	Type string
	//The validation function for this field.
	Validator ValidateFunc
	//Is this settign can be modified after configure
	Editable bool
	//Reloadable - reload config from env after restart
	Reloadable bool
}

```

The internal representation of configure settings will be:

```go
// ConfigureSettings - to manage all configurations
type ConfigureSettings struct {
	// ConfigureMetadata to store all metadata of configure items
	ConfigureMetaData map[string]Item
	// ConfigureValues to store all configure values
	ConfigureValues map[string]config.ConfigureValue
}
```

Each configure values

```go

// ConfigureValue - Configure values
type ConfigureValue struct {
	Key   string
	Value string
}
```

The interface to access ConfigureValue

```go

// Value -- interface to operate configure value
type Value interface {
	GetConfigString(key string) (string, error)
	GetConfigInt(key string) (int, error)
	GetConfigBool(key string) (bool, error)
	GetConfigStringToStringMap(key string) (map[string]string, error)
	GetConfigMap(key string) (map[string]interface{}, error)
}

```


The interface for accessing configurations

```go
// ConfigClient used to retrieve configuration
type ConfigClient interface {
	GetSettingByGroup(groupName string) []config.ConfigureValue
	UpdateConfig(cfg map[string]string) error
	UpdateConfigItem(key string, value string) error
}

```

There are three implementations for this interface.

1. DB configure driver - Used in core container, access configure by Database
2. Rest configure driver - Used outside core container, retrieve configure by Rest API
3. InMemory configure driver - Used in unit test

Steps to onboard a configuration item.

1. Define the configure item in configlist.go, define its scope, group.
	```go
	var (
		//ConfigList - All configure items used in harbor
		// Steps to onboard a new setting
		// 1. Add configure item in configlist.go
		// 2. Get settings by ClientAPI
		ConfigList = []Item{
			{Scope: UserScope, Group: LdapBasicGroup, EnvironmentKey: "", DefaultValue: "", Name: "ldap_search_base_dn", Type: "string", Editable: true},
			{Scope: UserScope, Group: LdapBasicGroup, EnvironmentKey: "", DefaultValue: "", Name: "ldap_search_scope", Type: "int", Editable: true},
			{Scope: UserScope, Group: LdapBasicGroup, EnvironmentKey: "", DefaultValue: "", Name: "ldap_search", Type: "string", Editable: true},
			{Scope: UserScope, Group: LdapBasicGroup, EnvironmentKey: "", DefaultValue: "", Name: "ldap_search_base_dn", Type: "string", Editable: true},
			{Scope: UserScope, Group: LdapBasicGroup, EnvironmentKey: "", DefaultValue: "", Name: "ldap_search_dn", Type: "string", Editable: true},
		}
	)
	```

2. Get the scope by rest API /api/configs/{scope}/{group}/{key} to retrieve this configure items, or get all configurations in the same group by /ap/configs/{scope}/{group}, use PUT method /api/configs/{scope}/{group}/{key} to update the configuration item.


## Non-Goals

 It is only a refactor of adminserver, no new feature.

## Rationale

 [A discussion of alternate approaches and the trade offs, advantages, and disadvantages of the specified approach.]

## Compatibility

  1. The admin server container is only used internal, after remove adminserver container,  some test scripts to ping the status of adminserver container might fail, need to remove it.

  2. Some test automation need to updated to configure user settings.

  3. Harbor tile configuration implementation need to change for some user setting is not include in harbor.cfg.


## Implementation

 Breakdown into following work items, Daojun Zhang will work on this items in harbor 1.7.0. 

1. Remove adminserver container.

2. Seperate user settings from harbor.cfg

3. Remove adminserver related build script, docker file and code.

4. Refactor configuration item management.

5. Change harbor tile configurations

## Open issues (if applicable)

No