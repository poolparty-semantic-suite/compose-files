# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Older major version changelogs are archived in [`archive/CHANGELOG_v1.md`](archive/CHANGELOG_v1.md).

## [2.0.0] - 2026-09-18

### Added
- Dedicated OAuth2 confidential client configuration in Keycloak 2.7.0 for addon services: `adf`, `semantic-workbench`, and `graphviews`.
- Client scopes (`aud-adf`, `aud-semantic-workbench`, `aud-graphviews`) and client role (`user`) authorization for addons.
- Default internal fallback groups (`/ADF_Users`, `/SemanticWorkbench_Users`, `/GraphViews_Users`) and automatic assignment of `superadmin` during Keycloak 2.7.0 migration.

### Changed
- **Breaking**: Replaced shared `ppt` Keycloak client usage across addon services with isolated, dedicated Keycloak clients and credentials.
- **Breaking**: Migrated GraphViews from static Basic Authentication (`PP_USERNAME` / `PP_PASSWORD`) to Keycloak OAuth2 client credentials grant via `GRAPHVIEWS_OAUTH2_CLIENT_SECRET`.
- Updated Semantic Workbench and ADF service-to-service credential propagation to use individual client secrets (`WORKBENCH_OAUTH2_CLIENT_SECRET`, `ADF_OAUTH2_CLIENT_SECRET`).
- Proxy configuration: Updated `files/nginx/addons/graphviews.conf` to disable `X-Forwarded-Port`, preventing post-login port redirection issues (aligning with `adf.conf` and `semantic-workbench.conf`).

### Configuration Changes
*Group all .properties / yaml changes here so Ops/DevOps can find them instantly.*
- `ADF_KEYCLOAK_LOGIN_CLIENTSECRET` - **Added**. Client secret for the `adf` Keycloak client, passed to Keycloak and mapped to `ADF_OAUTH2_CLIENT_SECRET` in `addons.yaml`.
- `SEMANTIC_WORKBENCH_KEYCLOAK_LOGIN_CLIENTSECRET` - **Added**. Client secret for the `semantic-workbench` Keycloak client, passed to Keycloak and mapped to `WORKBENCH_OAUTH2_CLIENT_SECRET` in `addons.yaml`.
- `GRAPHVIEWS_KEYCLOAK_LOGIN_CLIENTSECRET` - **Added**. Client secret for the `graphviews` Keycloak client, passed to Keycloak and mapped to `GRAPHVIEWS_OAUTH2_CLIENT_SECRET` in `addons.yaml`.
- `ADF_MIGRATION_USER_GROUP_PATH` - **Added** (optional). Keycloak group path (fallback: `/ADF_Users`) to automatically receive the `adf/user` client role during 2.7.0 migration.
- `SEMANTIC_WORKBENCH_MIGRATION_USER_GROUP_PATH` - **Added** (optional). Keycloak group path (fallback: `/SemanticWorkbench_Users`) to automatically receive the `semantic-workbench/user` client role during 2.7.0 migration.
- `GRAPHVIEWS_MIGRATION_USER_GROUP_PATH` - **Added** (optional). Keycloak group path (fallback: `/GraphViews_Users`) to automatically receive the `graphviews/user` client role during 2.7.0 migration.
- `ADF_MIGRATION_USERS` - **Added** (optional). Comma-separated usernames assigned to the ADF migration user group during 2.7.0 migration.
- `SEMANTIC_WORKBENCH_MIGRATION_USERS` - **Added** (optional). Comma-separated usernames assigned to the Semantic Workbench migration user group during 2.7.0 migration.
- `GRAPHVIEWS_MIGRATION_USERS` - **Added** (optional). Comma-separated usernames assigned to the GraphViews migration user group during 2.7.0 migration.
- `KEYCLOAK_PUBLIC_URL` / `KEYCLOAK_INTERNAL_URL` / `KEYCLOAK_REALM` - **Added** to `graphviews` service in `addons.yaml`.
- `KEYCLOAK_URL` - **Added** to `graphviews` service and retained as a deprecated fallback across all addon services in `addons.yaml` (mapping to internal Keycloak URL for backward compatibility).
- `GRAPHVIEWS_SECURITY_FILTER_DISABLED` - **Added** to `graphviews` service in `addons.yaml` (set to `"false"` to enable inbound security).
- `ADF_SECURITY_BASIC_AUTH_ENABLED` / `WORKBENCH_SECURITY_BASIC_AUTH_ENABLED` / `GRAPHVIEWS_BASIC_AUTH_ENABLED` - **Added** (optional, default `false`). Configures inbound HTTP Basic Authentication via Keycloak Direct Access Grants for `adf`, `semantic-workbench`, and `graphviews` respectively for legacy M2M integrations (omitted from `addons.yaml` by default).
- `SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_PPT_CLIENTSECRET` - **Removed** from `adf` and `semantic-workbench` services in `addons.yaml`.
- `PP_USERNAME` / `PP_PASSWORD` - **Removed** from `graphviews` service in `addons.yaml`.
- Deprecated Spring Boot 2 Keycloak provider URI workarounds removed from `semantic-workbench` in `addons.yaml`.

### Infrastructure & Security Upgrades
- **PoolParty Keycloak**: Upgraded to `2.7.0`. Adds automated migration 2.7.0 for addon clients, roles, scopes, and default service-account group assignments.
- **ADF**: Upgraded `1.9.0` -> `1.10.0`.
- **Semantic Workbench**: Upgraded `2.5.0` -> `2.6.0`.
- **GraphViews**: Upgraded `1.0.1` -> `1.2.0`.
