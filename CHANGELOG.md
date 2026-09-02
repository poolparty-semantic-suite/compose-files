# [1.4.0] - 2026-08-25

## Configuration Changes
- Added support for Keycloak 2.6.0 automated migration parameters in `.env_template`:
    - `SUPERADMIN_REQUIRES_ACTIONS`: Controls mandatory password reset on initial import of `superadmin` (default: `true`).
    - `AUTO_MIGRATION_ENABLED`: Toggles startup migration orchestrator (default: `true`).
    - `POOLPARTY_KEYCLOAK_REALM`: Target realm identifier for orchestrator runs (default: `poolparty`).
    - `TARGET_MIGRATION_VERSION`, `MIGRATION_BASELINE_VERSION`, `CURRENT_VERSION`: Version boundaries for automated schema/realm upgrades.
    - `MIGRATION_TIMEOUT`, `MIGRATION_READINESS_TIMEOUT`, `MIGRATION_REALM_TIMEOUT`, `MIGRATION_SCRIPT_TIMEOUT`, `MIGRATION_LOCK_TIMEOUT`: Fine-grained timeout controls for migration readiness, script run caps, and concurrency locks.
    - `MIGRATION_HEALTH_SIGNAL_FILE`, `MIGRATION_LOG_FILE`, `MIGRATION_LOG_DEBUG`, `MIGRATION_LOG_MAX_BYTES`: Orchestrator health signal marker and logging controls.

## Infrastructure & Security Upgrades
- **PoolParty**: Upgraded `10.3.0` -> `10.3.1` (patch).
- **GraphDB**: Upgraded `11.4.2` -> `11.4.3`. (patch)
- **Elasticsearch**: Upgraded `9.3.3` -> `9.3.8` (patch).
- **PoolParty Keycloak**: Upgraded to `2.5.0` -> `2.6.0` (minor). Includes automated migration orchestrator on startup and clears redundant `Public` group role mappings from `PoolPartySuperAdmin`.

# 1.2.0

## Changes related for Graph Modeling integration with GraphDB with OAuth2

   - Added GraphDB Keycloak integration via additional oauth.yaml file
   - Added properties for GraphDB Keycloak integration in .env_template
   - New image of poolparty-keycloak required (2.4.0)
