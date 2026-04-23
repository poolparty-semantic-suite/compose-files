# Elasticsearch Upgrade Orchestrator

Automates sequential Elasticsearch version upgrades in a Docker Compose environment. Supports single-node and multi-node cluster deployments, basic auth, pre-upgrade snapshots, and idempotent re-runs.

## Directory structure

```
files/elasticsearch/
  upgrade-elasticsearch.sh      # orchestrator — entry point
  lib.sh                        # shared curl/auth/health helpers
  migrations/
    8.19.13/
      is-migrated.sh            # exits 0 if this version is already applied
      pre-upgrade.sh            # runs against the old node before restart
      post-upgrade.sh           # runs against the new node after restart
    9.2.4/
      is-migrated.sh
      pre-upgrade.sh
      post-upgrade.sh
```

Each migration directory also stores a `.done` sentinel file once its post-upgrade script completes successfully.

## One-time setup

The orchestrator controls which image Docker Compose pulls by reading `ELASTICSEARCH_VERSION` from `.env`. For this to work the elasticsearch service in `docker-compose.yaml` must reference that variable rather than a hardcoded tag:

```yaml
# docker-compose.yaml
services:
  elasticsearch:
    image: ontotext/poolparty-elasticsearch:${ELASTICSEARCH_VERSION}
```

If the image line currently has a hardcoded version (e.g. `…:8.17.6`), replace it with `${ELASTICSEARCH_VERSION}` before running the script for the first time. Then add the matching variable to `.env`:

```sh
ELASTICSEARCH_VERSION=8.17.6   # must reflect what is actually running right now
```

## Prerequisites

- Docker Compose v2 (`docker compose` plugin syntax)
- bash 3.2+, curl, awk, sort (all standard on macOS and Linux)
- Elasticsearch reachable before the script is run (the current node must be up)
- `ELASTICSEARCH_VERSION` variable present in the project `.env` file (see [One-time setup](#one-time-setup) above)

## Quick start

```sh
# Upgrade to 9.2.4 from the version currently in .env (auto-detected)
./files/elasticsearch/upgrade-elasticsearch.sh --to 9.2.4

# Explicit from/to — useful when resuming a partial upgrade
./files/elasticsearch/upgrade-elasticsearch.sh --from 8.17.6 --to 9.2.4

# Single hop only
./files/elasticsearch/upgrade-elasticsearch.sh --from 8.17.6 --to 8.19.13

# Take a snapshot before each version step
./files/elasticsearch/upgrade-elasticsearch.sh --to 9.2.4 --snapshot
```

## Environment variables

All variables are optional unless marked required.

| Variable | Default | Description |
|---|---|---|
| `POOLPARTY_INDEX_URL` | `http://localhost:9200` | Elasticsearch base URL |
| `POOLPARTY_INDEX_USERNAME` | _(empty)_ | Basic auth username |
| `POOLPARTY_INDEX_PASSWORD` | _(empty)_ | Basic auth password |
| `ES_SERVICE_PATTERN` | `elasticsearch` | Prefix used to discover ES services in the compose file |
| `SNAPSHOT_REPO` | `backup` | Name of an existing ES snapshot repository (required with `--snapshot`) |

Credentials are read from the project `.env` file if not already set in the shell environment. A value set in the shell always takes precedence.

## Single-node vs cluster

The script detects topology automatically by querying `GET /_cat/nodes` at startup.

**Single-node** — the named service is restarted once; cluster health of `yellow` is accepted as the final healthy state (replicas cannot be assigned with only one node).

**Cluster** — the script performs a rolling restart:

1. For each ES node in discovery order:
   - Excludes the node from shard allocation (`cluster.routing.allocation.exclude._name`)
   - Waits for all primary shards to migrate off the node (up to 10 minutes)
   - Restarts the corresponding compose service
   - Waits for the node to rejoin the cluster
   - Removes the allocation exclusion
   - Waits for `yellow` health before moving to the next node
2. After all nodes are restarted, waits for `green` health

### Service name → ES node name mapping

ES uses the container hostname as the node name by default, and Docker Compose sets the container hostname to the service name. So a service named `elasticsearch1` maps to ES node `elasticsearch1`.

If your compose file overrides `hostname:` or your ES config sets `node.name` explicitly, this mapping breaks. In that case set `ES_SERVICE_PATTERN` to a prefix that matches your actual ES node names, or ensure the service names and node names align.

The script validates the mapping before starting any rolling restarts and exits with a clear error listing the discovered node names if there is a mismatch.

## Basic auth

If `xpack.security.enabled=true` is set in the ES configuration, all API calls require credentials. Set them in `.env` or export them before running:

```sh
# Via environment
POOLPARTY_INDEX_USERNAME=elastic POOLPARTY_INDEX_PASSWORD=secret \
  ./files/elasticsearch/upgrade-elasticsearch.sh --to 9.2.4

# Or in .env (already supported — the orchestrator reads both vars from there)
POOLPARTY_INDEX_USERNAME=elastic
POOLPARTY_INDEX_PASSWORD=secret
```

All curl calls — in the orchestrator and in every migration script — pick up credentials automatically through `lib.sh`.

## Snapshots

Pass `--snapshot` to take a snapshot before each version step. The repository must already exist in Elasticsearch before the script runs — the script will not create it.

```sh
# Verify your repo exists
curl http://localhost:9200/_snapshot/backup

# Run with snapshots
SNAPSHOT_REPO=backup ./files/elasticsearch/upgrade-elasticsearch.sh --to 9.2.4 --snapshot
```

Snapshots are named `pre-upgrade-to-<version>-<timestamp>` and polled until `SUCCESS` (30-minute timeout). A `FAILED` or `PARTIAL` result aborts the upgrade before any files are changed.

## How idempotency works

Each migration step is guarded by `is-migrated.sh`, which:

1. Checks for a `.done` sentinel file in the migration directory
2. If the file is absent, queries the live ES version — if it is already at or past the target version, writes the sentinel and exits 0

This means re-running the script after a partial failure skips any version steps that completed successfully and resumes from where it stopped.

## Adding a new upgrade path

1. Create `migrations/<target-version>/` with three executable scripts:

   **`is-migrated.sh`** — exits 0 if the migration is already applied:
   ```sh
   cp -r migrations/9.2.4 migrations/<new-version>
   # Update MARKER path, TARGET version, and .done text
   ```

   **`pre-upgrade.sh`** — runs against the current (old) node. Typical tasks: check deprecation warnings, disable shard allocation, flush indices.

   **`post-upgrade.sh`** — runs against the new node after it is healthy. Typical tasks: re-enable allocation, verify index health, write `.done`.

2. Add the new version to `KNOWN_VERSIONS` in `upgrade-elasticsearch.sh` in ascending order:
   ```sh
   KNOWN_VERSIONS=("8.19.13" "9.2.4" "<new-version>")
   ```

3. Update `ELASTICSEARCH_VERSION` in `.env` if you need to start from a different base.

## Troubleshooting

**`Connection refused` at startup**
Elasticsearch is not running. Start it first:
```sh
docker compose up -d elasticsearch
```

**`Hostname could not be resolved`**
The host in `POOLPARTY_INDEX_URL` is wrong or not in DNS. For local Docker deployments use `http://localhost:9200`.

**`Elasticsearch returned an HTTP error` (curl exit 22)**
Usually a 401 Unauthorized when security is enabled without credentials configured. Set `POOLPARTY_INDEX_USERNAME` and `POOLPARTY_INDEX_PASSWORD`.

**`No ES node named '<svc>' found`**
The compose service name does not match the ES node name. Check the actual node names:
```sh
curl http://localhost:9200/_cat/nodes?h=name
```
Then either align service names with node names or set `ES_SERVICE_PATTERN` accordingly.

**`Primary shards did not drain from '<node>'`**
Shard drain timed out (10 minutes). The cluster may be undersized to absorb the primary shards of the excluded node. Check cluster state:
```sh
curl http://localhost:9200/_cluster/health
curl "http://localhost:9200/_cat/shards?h=index,shard,prirep,state,node&v"
```

**`critical deprecation(s) found` during 9.2.4 pre-upgrade**
The running 8.x instance has breaking-change deprecations that must be resolved before the 8→9 jump. Review the output and address each item before re-running:
```sh
curl http://localhost:9200/_migration/deprecations
```

**Re-running after partial failure**
The script is safe to re-run. Completed steps are skipped via `.done` files. To force a step to re-run, delete the corresponding sentinel:
```sh
rm files/elasticsearch/migrations/<version>/.done
```
