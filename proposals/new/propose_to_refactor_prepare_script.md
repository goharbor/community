# Proposal: Refactor Prepare Script

Author: Qian Deng

## Abstract

Refactor the prepare script code, make it eazy to configure and change the template rendering engine to jinja2 and containerize this prepare file.

## Overview

Currently, the prepare file is too giant and messy to understand the logic inside it. So need refactor this file make it more stylish and modular to decrease the learning curve for developer.

In addition, the template we just using a simple string substitution, in this paper we propose to change it to _jinja2_ which is powerful and widely used in template rendering situation.

Futhermore, there was a historical issues that cannot change `/data` directory through config file. Therefore we need solve this issue in this refactor.

Moreover, the configparse format is old-fashine and cannot present complex structure, also in this refactor the `harbor.cfg` file will replaced by `harbor.yml` .

Finally, all the codes and it dependencies will packaged in one container to realease.

## Proposal

1. Refactor code implementation make it more pythonic and structure, the code skeleton looks like this:
   ```
    ├── Dockerfile   # dockerfile to build container
    ├── Pipfile      # denpendencies
    ├── Pipfile.lock # locked version of denpencies
    ├── __init__.py
    ├── g.py         # global variables
    ├── main.py
    ├── templates    # all template files are placed in this directory
    │   ├── adminserver
    │   │   └── ...
    │   ├── chartserver
    │   │   └── ...
    │   ├── clair
    │   │   └── ...
    │   ├── core
    │   │   └── ...
    │   ├── db
    │   │   └── ...
    │   ├── docker_compose
    │   │   └── ...
    │   ├── jobservice
    │   │   └── ...
    │   ├── log
    │   │   └── ...
    │   ├── nginx
    │   │   └── ...
    │   ├── notary
    │   │   └── ...
    │   ├── registry
    │   │   ├── ...
    │   └── registryctl
    │       └── ...
    └── utils       # uitls are some helpers to solve related problems
        ├── __init__.py
        ├── admin_server.py
        ├── cert.py
        ├── chart.py
        ├── clair.py
        ├── configs.py
        ├── core.py
        ├── db.py
        ├── docker_compose.py
        ├── jinja.py
        ├── jobservice.py
        ├── log.py
        ├── misc.py
        ├── nginx.py
        ├── notary.py
        ├── proxy.py
        ├── registry.py
        ├── registry_ctl.py
        ├── uaa.py
      ```

2. The docker-compose config files are rendered by sed in `Makefile`, as a result, we can only rendering multiple docker-compose files
   when need additional component and also cannot replace template data properly because it's hard to get some info in config file. So it's
   better to move these logic to prepare files too.

3. The template engine is essential to render config files, a high level rendering engine can provide more complex syntax. In this proposal we recommend jinja2 as the template engine. The templates may looks like this:

   ```jinja2
   PORT=8080
   LOG_LEVEL=info
   EXT_ENDPOINT={{public_url}}
   AUTH_MODE={{auth_mode}}
   SELF_REGISTRATION={{self_registration}}
   LDAP_URL={{ldap_url}}
   LDAP_SEARCH_DN={{ldap_searchdn}}
   LDAP_SEARCH_PWD={{ldap_search_pwd}}
   LDAP_BASE_DN={{ldap_basedn}}
   LDAP_FILTER={{ldap_filter}}
   LDAP_UID={{ldap_uid}}
   LDAP_SCOPE={{ldap_scope}}
   LDAP_TIMEOUT={{ldap_timeout}}
   LDAP_VERIFY_CERT={{ldap_verify_cert}}
   DATABASE_TYPE=postgresql
   POSTGRESQL_HOST={{db_host}}
   POSTGRESQL_PORT={{db_port}}
   POSTGRESQL_USERNAME={{db_user}}
   ```

   and this:

   ```jinja2
   version: '2'
   services:
     log:
       image: goharbor/harbor-log:{{version}}
       container_name: harbor-log
       restart: always
       dns_search: .
       volumes:
         - /var/log/harbor/:/var/log/docker/:z
         - ./common/config/log/:/etc/logrotate.d/:z
       ports:
         - 127.0.0.1:1514:10514
       networks:
         - harbor
     registry:
         ...
     registryctl:
         ...
     postgresql:
       ...
     adminserver:
       ...
     core:
       ...
     portal:
       ...

     jobservice:
       ...
     redis:
       ...
     proxy:
       ...

   {% if with_notary %}
       notary-server:
         ...
       notary-signer:
         ...
   {% endif %}
   networks:
     harbor:
       external: false
   {% if with_notary %}
     harbor-notary:
       external: false
     notary-sig:
       external: false
   {% endif %}

   ```

4. The `/data` dir is hardcoded in template file, this can also be solved easily in replacing render engine. Files including hardcoded `/data` are `docker-compose.yml`, `harbor.cfg`, `.travis.yml`, `prepare`, `core/systeminfo/systeminfo.go`, `jobservice/generateCerts.sh`,
   `tests/docker-compose.test.yml`, `tests/resources/Harbor-Util.robot`, `tests/robot-cases/Group2-Longevity/Longevity.robot`,
   `tests/testprepare.sh`, `tests/travis/api_common_install.sh`, `tests/travis/ut_install.sh`.

6. Current config file is `harbor.cfg` which is configparser-style format. In order to describe more complex content, We need replace it using YAML format file `harbor.yml` . current config file may look like this.

```yaml
## Configuration file of Harbor

#This attribute is for migrator to detect the version of the .cfg file, DO NOT MODIFY!
_version: 1.7.0
#The IP address or hostname to access admin UI and registry service.
#DO NOT use localhost or 127.0.0.1, because Harbor needs to be accessed by external clients.
#DO NOT comment out this line, modify the value of "hostname" directly, or the installation will fail.
hostname: reg.mydomain.com

#The protocol for accessing the UI and token/notification service, by default it is http.
#It can be set to https if ssl is enabled on nginx.
ui_url_protocol: http

#The attribute used to name a LDAP/AD group, it could be cn, name
ldap_group_gid: cn

#The scope to search for ldap groups. 0-LDAP_SCOPE_BASE, 1-LDAP_SCOPE_ONELEVEL, 2-LDAP_SCOPE_SUBTREE
ldap_group_scope: 2

...

clair_db_port: 5432
#Clair DB username
clair_db_username: postgres
#Clair default database
clair_db: postgres

#The interval of clair updaters, the unit is hour, set to 0 to disable the updaters.
clair_updaters_interval: 12

### Harbor Storage settings ###
#Please be aware that the following storage settings will be applied to both docker registry and helm chart repository.
#registry_storage_provider can be: filesystem, s3, gcs, azure, etc.
registry_storage_provider_name: filesystem
#registry_storage_provider_config is a comma separated "key: value" pairs, e.g. "key1: value, key2: value2".
#To avoid duplicated configurations, both docker registry and chart repository follow the same storage configuration specifications of docker registry.
#Refer to https://docs.docker.com/registry/configuration/#storage for all available configuration.
registry_storage_provider_config:
#registry_custom_ca_bundle is the path to the custom root ca certificate, which will be injected into the truststore
#of registry's and chart repository's containers.  This is usually needed when the user hosts a internal storage with self signed certificate.
registry_custom_ca_bundle:
#If reload_config=true, all settings which present in harbor.cfg take effect after prepare and restart harbor, it overwrites exsiting settings.
#reload_config=true
#Regular expression to match skipped environment variables
#skip_reload_env_pattern=(^EMAIL.*)|(^LDAP.*)
```

we need be cautious that all configparser value are string, but in yaml format values have types. below is values that not string.

| item                    | type    |
| ----------------------- | ------- |
| \_version               | number  |
| max_job_workers         | number  |
| log_rotate_count        | number  |
| email_server_port       | number  |
| ldap_scope              | number  |
| ldap_timeout            | number  |
| ldap_group_scope        | number  |
| token_expiration        | number  |
| db_port                 | number  |
| redis_port              | number  |
| clair_db_port           | number  |
| clair_updaters_interval | number  |
| customize_crt           | boolean |
| email_insecure          | boolean |
| ldap_verify_cert        | boolean |
| self_registration       | boolean |
| uaa_verify_cert         | boolean |

Besides above, we need remove some user level config items in config file, mentioned in [this](https://github.com/goharbor/community/pull/12) proposal

| Items will kept in harbor.cfg    | Configure item                 | System Setting | User Setting |
| -------------------------------- | ------------------------------ | -------------- | ------------ |
|                                  | admin_initial_password         |                | x            |
| admiral_url                      | admiral_url                    | x              |
| auth_mode                        | auth_mode                      | x              |
|                                  | cfg_expiration                 | x              |
|                                  | chart_repository_url           | x              |
| clair_db                         | clair_db                       | x              |
| clair_db_host                    | clair_db_host                  | x              |
| clair_db_password                | clair_db_password              | x              |
| clair_db_port                    | clair_db_port                  | x              |
| clair_db_username                | clair_db_sslmode               | x              |
|                                  | clair_db_username              | x              |
|                                  | clair_url                      | x              |
|                                  | core_url                       | x              |
|                                  | database_type                  | x              |
|                                  | email_from                     |                | x            |
|                                  | email_host                     |                | x            |
|                                  | email_identity                 |                | x            |
|                                  | email_insecure                 |                | x            |
|                                  | email_password                 |                | x            |
|                                  | email_port                     |                | x            |
|                                  | email_ssl                      |                | x            |
|                                  | email_username                 |                | x            |
|                                  | ext_endpoint                   | x              |
|                                  | jobservice_url                 | x              |
|                                  | ldap_base_dn                   | x              |
|                                  | ldap_filter                    |                | x            |
|                                  | ldap_group_admin_dn            |                | x            |
|                                  | ldap_group_attribute_name      |                | x            |
|                                  | ldap_group_base_dn             |                | x            |
|                                  | ldap_group_search_filter       |                | x            |
|                                  | ldap_group_search_scope        |                | x            |
|                                  | ldap_scope                     |                | x            |
|                                  | ldap_search_dn                 |                | x            |
|                                  | ldap_search_password           |                | x            |
|                                  | ldap_timeout                   |                | x            |
|                                  | ldap_uid                       |                | x            |
|                                  | ldap_url                       |                | x            |
|                                  | ldap_verify_cert               |                | x            |
|                                  | max_job_workers                |                | x            |
|                                  | notary_url                     | x              |
|                                  | postgresql_database            | x              |
| db_host                          | postgresql_host                | x              |
| db_password                      | postgresql_password            | x              |
| db_port                          | postgresql_port                | x              |
|                                  | postgresql_sslmode             | x              |
| db_user                          | postgresql_username            | x              |
|                                  | project_creation_restriction   | x              |
|                                  | read_only                      |                | x            |
| registry_storage_provider_name   | registry_storage_provider_name | x              |
|                                  | registry_url                   | x              |
|                                  | self_registration              |                | x            |
|                                  | token_expiration               |                | x            |
|                                  | token_service_url              | x              |
|                                  | uaa_client_id                  |                | x            |
|                                  | uaa_client_secret              |                | x            |
|                                  | uaa_endpoint                   |                | x            |
|                                  | uaa_verify_cert                |                | x            |
|                                  | with_chartmuseum               | x              |
|                                  | with_clair                     | x              |
|                                  | with_notary                    | x              |
| \_version                        |                                | x              |
| hostname                         |                                | x              |
| ui_url_protocol                  |                                | x              |
| customize_crt                    |                                | x              |
| ssl_cert                         |                                | x              |
| ssl_cert_key                     |                                | x              |
| secretkey_path                   |                                | x              |
| log_rotate_count                 |                                | x              |
| log_rotate_size                  |                                | x              |
| http_proxy                       |                                | x              |
| https_proxy                      |                                | x              |
| no_proxy                         |                                | x              |
| redis_host                       |                                | x              |
| redis_port                       |                                | x              |
| redis_password                   |                                | x              |
| redis_db_index                   |                                | x              |
| registry_storage_provider_config |                                | x              |
| registry_custom_ca_bundle        |                                | x              |

With some structure optimize, the final result will be like this

```yaml
core:
    proxy:
        ....
registry:
    ......
    storage:
         ......
clair:
     ......
notary:
     .....
```

6. Because the config file changed, a new config migrator will create for these upgrades. The migrator script should parse the old config file and abstract the config items that still in use then render the new config file using pre defined template.

7. Templates dir contains the template using by prepare to render the real world file, move this dir make it under the prepare dir.

8. Packaging all files and its dependencies into a container. All these codes and changes is related to python, so we should using official python images as the base image in Dockerfile. Some actions need super user to operate. like change the owner and group of an file, create files on host system. So we need run this container with privilege.
