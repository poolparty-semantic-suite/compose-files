# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Older major version changelogs are archived in [`archive/CHANGELOG_v1.md`](archive/CHANGELOG_v1.md).

## [2.0.0] - 2026-09-18

### Added
- Dedicated OAuth2 confidential client configuration in Keycloak 2.7.0 for addon services: `adf`, `semantic-workbench`, and `graphviews`.
- Client scopes (`aud-adf`, `aud-semantic-workbench`, `aud-graphviews`) and client role (`user`) authorization for addons.
- S2S (Service-to-Service) OAuth2 authentication for GraphViews communicating with PoolParty APIs.

### Changed
- **Breaking**: Replaced shared `ppt` Keycloak client usage across addon services with isolated, dedicated Keycloak clients and credentials.
- **Breaking**: Migrated GraphViews from static Basic Authentication (`PP_USERNAME` / `PP_PASSWORD`) to Keycloak OAuth2 client credentials grant via `SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_GRAPHVIEWS_PPT_CLIENT_SECRET`.
- Updated Semantic Workbench and ADF service-to-service credential propagation to use individual client secrets (`WORKBENCH_OAUTH2_CLIENT_SECRET`, `ADF_OAUTH2_CLIENT_SECRET`).

### Configuration Changes
*Group all .properties / yaml changes here so Ops/DevOps can find them instantly.*
- `ADF_KEYCLOAK_LOGIN_CLIENTSECRET` - **Added**. Client secret for the `adf` Keycloak client, passed to Keycloak and mapped to `ADF_OAUTH2_CLIENT_SECRET` in `addons.yaml`.
- `SEMANTIC_WORKBENCH_KEYCLOAK_LOGIN_CLIENTSECRET` - **Added**. Client secret for the `semantic-workbench` Keycloak client, passed to Keycloak and mapped to `WORKBENCH_OAUTH2_CLIENT_SECRET` in `addons.yaml`.
- `GRAPHVIEWS_KEYCLOAK_LOGIN_CLIENTSECRET` - **Added**. Client secret for the `graphviews` Keycloak client, passed to Keycloak and mapped to `SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_GRAPHVIEWS_PPT_CLIENT_SECRET` in `addons.yaml`.
- `ADF_MIGRATION_USER_GROUP_PATH` - **Added** (optional). Keycloak group path (e.g. `/ADFUsers`) to automatically receive the `adf/user` client role during 2.7.0 migration.
- `SEMANTIC_WORKBENCH_MIGRATION_USER_GROUP_PATH` - **Added** (optional). Keycloak group path (e.g. `/SemanticWorkbenchUsers`) to automatically receive the `semantic-workbench/user` client role during 2.7.0 migration.
- `GRAPHVIEWS_MIGRATION_USER_GROUP_PATH` - **Added** (optional). Keycloak group path (e.g. `/GraphViewsUsers`) to automatically receive the `graphviews/user` client role during 2.7.0 migration.
- `SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_PPT_CLIENTSECRET` - **Removed** from `adf` and `semantic-workbench` services in `addons.yaml`.
- `PP_USERNAME` / `PP_PASSWORD` - **Removed** from `graphviews` service in `addons.yaml`.
- `KEYCLOAK_URL` / `KEYCLOAK_REALM` - **Added** to `graphviews` service in `addons.yaml`.
- Deprecated Spring Boot 2 Keycloak provider URI workarounds removed from `semantic-workbench` in `addons.yaml`.

### Infrastructure & Security Upgrades
- **PoolParty Keycloak**: Upgraded `2.6.0` -> `2.7.0`. Adds automated migration 2.7.0 for addon clients, roles, scopes, and default service-account group assignments.
- **ADF**: Upgraded `1.9.0` -> `1.10.0`. Introduces dedicated `adf` client authentication, client-role authorization, audience enforcement (`aud=adf`), and isolated S2S token minting.
- **Semantic Workbench**: Upgraded `2.5.0` -> `2.6.0`. Introduces dedicated `semantic-workbench` client, Spring 6 `RestClient` S2S outbound communication, audience validation, and `TAGGING_PLUS` licensing.
- **GraphViews**: Upgraded `1.0.1` -> `1.2.0`. Migrated to Spring Security OAuth2 resource server and S2S client credentials; default service port changed to `8088`.
