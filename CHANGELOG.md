# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Older major version changelogs are archived in [`archive/CHANGELOG_v1.md`](archive/CHANGELOG_v1.md).

## [2.0.0]

### Added
- Dedicated Keycloak client secret passthroughs in `docker-compose.yaml` and `addons.yaml` for `adf`, `semantic-workbench`, and `graphviews`.
- Optional Keycloak 2.7.0 migration variables in `.env_template` (`*_MIGRATION_USER_GROUP_PATH`, `*_MIGRATION_USERS`) to customize group and user role assignments during migration (falling back to `/ADF_Users`, `/SemanticWorkbench_Users`, `/GraphViews_Users` with `superadmin` assigned).

### Changed
- **Breaking**: Replaced shared `ppt` client secret (`SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_PPT_CLIENTSECRET`) in `addons.yaml` with per-service client secrets (`ADF_OAUTH2_CLIENT_SECRET`, `WORKBENCH_OAUTH2_CLIENT_SECRET`).
- **Breaking**: Replaced static PoolParty credentials (`PP_USERNAME`, `PP_PASSWORD`) for `graphviews` in `addons.yaml` with Keycloak configuration (`KEYCLOAK_PUBLIC_URL`, `KEYCLOAK_INTERNAL_URL`, `KEYCLOAK_URL`, `KEYCLOAK_REALM`, `GRAPHVIEWS_OAUTH2_CLIENT_SECRET`).
- Proxy configuration: Updated `files/nginx/addons/graphviews.conf` to comment out `X-Forwarded-Port`, preventing post-login port redirection issues (aligning with `adf.conf` and `semantic-workbench.conf`).

### Configuration Changes
- `ADF_KEYCLOAK_LOGIN_CLIENTSECRET` - **Added** to `.env_template` and `docker-compose.yaml`; mapped to `ADF_OAUTH2_CLIENT_SECRET` for `adf` in `addons.yaml`.
- `SEMANTIC_WORKBENCH_KEYCLOAK_LOGIN_CLIENTSECRET` - **Added** to `.env_template` and `docker-compose.yaml`; mapped to `WORKBENCH_OAUTH2_CLIENT_SECRET` for `semantic-workbench` in `addons.yaml`.
- `GRAPHVIEWS_KEYCLOAK_LOGIN_CLIENTSECRET` - **Added** to `.env_template` and `docker-compose.yaml`; mapped to `GRAPHVIEWS_OAUTH2_CLIENT_SECRET` for `graphviews` in `addons.yaml`.
- `ADF_MIGRATION_USER_GROUP_PATH` / `SEMANTIC_WORKBENCH_MIGRATION_USER_GROUP_PATH` / `GRAPHVIEWS_MIGRATION_USER_GROUP_PATH` - **Added** (optional) to `.env_template`. Group paths receiving the respective addon `user` role during Keycloak 2.7.0 migration (fallbacks: `/ADF_Users`, `/SemanticWorkbench_Users`, `/GraphViews_Users`). Require compose passthrough on `keycloak` when overridden.
- `ADF_MIGRATION_USERS` / `SEMANTIC_WORKBENCH_MIGRATION_USERS` / `GRAPHVIEWS_MIGRATION_USERS` - **Added** (optional) to `.env_template`. Comma-separated usernames assigned to the respective migration group during 2.7.0 migration. Require compose passthrough on `keycloak` when overridden.
- `KEYCLOAK_PUBLIC_URL` / `KEYCLOAK_INTERNAL_URL` / `KEYCLOAK_REALM` - **Added** to `graphviews` service in `addons.yaml`.
- `KEYCLOAK_URL` - **Added** to `graphviews` service and retained as a deprecated fallback across all addon services in `addons.yaml` (mapping to `POOLPARTY_KEYCLOAK_INTERNAL_AUTHURL`).
- `ADF_SECURITY_BASIC_AUTH_ENABLED` / `WORKBENCH_SECURITY_BASIC_AUTH_ENABLED` / `GRAPHVIEWS_BASIC_AUTH_ENABLED` - **Added** (optional, default `false`) to `.env_template`. Enable inbound HTTP Basic Authentication on individual addon services for legacy M2M integrations; omitted from `addons.yaml` by default and require a compose passthrough if enabled.
- `GRAPHVIEWS_SECURITY_FILTER_DISABLED` - **Added** (optional, default `true`) to `.env_template`. Controls inbound security on `graphviews`; omitted from `addons.yaml` by default and requires a compose passthrough if overridden.
- `APPLICATION_VERSION` - **Updated** (`2.5.0` -> `2.6.0`) on `semantic-workbench` in `addons.yaml`.
- `SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_PPT_CLIENTSECRET` - **Removed** from `adf` and `semantic-workbench` services in `addons.yaml`.
- `PP_USERNAME` / `PP_PASSWORD` - **Removed** from `graphviews` service in `addons.yaml`.
- Deprecated Spring Boot 2 Keycloak URI overrides (`spring.security.oauth2.*`) - **Removed** from `semantic-workbench` in `addons.yaml`.

### Infrastructure & Security Upgrades
- **PoolParty**: `10.3.3` -> `10.4.0`.
- **PoolParty Keycloak**: `2.6.2` -> `2.7.0`.
- **ADF**: `1.9.0` -> `1.10.0`.
- **Semantic Workbench**: `2.5.0` -> `2.6.0`.
- **GraphViews**: `1.0.1` -> `1.2.0`.
