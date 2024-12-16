# Proposal: API to support updating the encrypted data with a new secret key

Author: `reasonerjt`

## Abstract

This proposal aims to provide an API to support updating the encrypted data with a new secret key. It will decrypt the persisted data 
with the old key and use the new key to encrypt the data again. This API will be used to support rotating the secret key in Harbor.

## Background

Harbor needs to persist sensitive data in datastore like database, including the credentials for connecting to external services, like LDAP
and other registries. These sensitive data are encrypted using symmetric methods before persisted to the database.  When Harbor needs to read
the data, it will decrypt the data using the same secret key, which is mounted to the "harbor-core" container or pod.  
Because which key was used to encrypt certain data is not tracked, there's problem when the secret key has to be changed.  When a new key is
configured in Harbor, the data encrypted with the old key will not be able to be decrypted.

## Proposal

I propose to provide a simple API to help Harbor's system admin update the encrypted data with a new secret key.  The Admin will provide the
old and new secret keys as parameters when calling the API, and Harbor will decrypt the data with the old key and encrypt the data with the new key, 
then persist the data back to the database.  This API will be used to support rotating the secret key in Harbor.

A typical workflow to rotate the secret key will be like this:
    Generate the new secret key  -->  Call the API to update the encrypted data with the new key  -->  Update the secret key and restart `harbor-core`

## Non Goal

- This proposal does not cover the end-to-end flow for rotating the secret key in Harbor.  User may use this API in conjunction with 
other tools.
- This proposal will not cover the user case to recover or reset the secret key in case of losing the key. 
- Although it is debatable whether encrypting the data is necessary, we will not refine the encryption flow in this proposal.
- When the encrypted data is updated some on-going functionality maybe broken.  It is the responsibility of the system admin to manage the impact, for example,
call this API during the maintenance window.

## Design

### The encrypted data in Harbor

As for v2.12.0 of Harbor, the encrypted data in Harbor includes:

| Table Name | Column Name   | Description                                         | Comment                                                                                                                                                                                                                                                                 |
|------------|---------------|-----------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| properties | v             | Some sensitive properties like LDAP search password | We can distinguish the encrypted data by checking the pattern of the string from the DB, or check the "itemType", of the metadata: [link](https://github.com/goharbor/harbor/blob/28896b1bd6916d59e2445226753c73365d9ba062/src/lib/config/metadata/metadatalist.go#L93) |
| oidc_user  | secret        | The CLI secret for user authenticated via OIDC      |                                                                                                                                                                                                                                                                         |
| oidc_user  | token         | The token data of a user                            | It's a serialized JSON containing the ID token and refresh Token                                                                                                                                                                                                        |
| registry   | access_secret | The access secret of a registry endpoint            |                                                                                                                                                                                                                                                                         |

This API MUST handle all the encrypted data in Harbor.  Therefore, whenever there's a change in the scope of encrypted data, this API should be updated accordingly.

### The API

The API to rotate the secret key will look like
```
POST /api/v2.0/system/rotatesecretkey
```
Request body will be JSON Object containing the current and new secret key, and an optional attribute `skip_oidc_secret`:
```json
{
  "current_secret_key": "current_secret",
  "new_secret_key": "new_secret",
  "skip_oidc_secret": false
}
```
This API will be available to system admin only, if the user is not a system admin, the API will return `403`.

When it's called Harbor will decrypt the encrypted data with the current secret key and encrypt the data with the new secret 
key, then persist the data back to the database.  Because the secret key is set via environment variable, so after the data are 
updated and persisted the secret key is not updated, if we continue use this key to encrypt data it will cause inconsistency and
will be hard to fix.  Therefore, Harbor will enter "read-only" mode after the data are updated, and the system admin should update
the secret key and unset the "read-only" mode.  In addition, to avoid inconsistency all these actions will be wrapped into one 
transaction, if any step fails the API return will return status code `500` and the transaction will be rolled back.

When the attribute `skip_oidc_secret` is set to `true`, the API will skip updating the OIDC secret.  This is added to avoid 
the corner case where there are too many records in the `oidc_user` table and the update will take too long.  The system admin
should call the API with `skip_oidc_secret` set to `false` first, and set it to `true` only when the API failed due to the reason 
mentioned.  If the API is called with `skip_oidc_secret` set to `true`, the OIDC secrets will not be usable after the secret key is 
updated, and the user will need to manually update the OIDC secret via Harbor's UI.

### Implementation

The implementation of this API is relatively straight forward, the controller to handle the actual logic will call db layer directly 
to update the data.  We should make sure there're detailed log messages to track the progress of update of each type of data.

