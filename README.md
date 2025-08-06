# Docker compose file for PoolParty

This repository contains docker compose files for running PoolParty and dependent services.
There are several files for different environments, e.g. development and production.

# Configuration

The services are configured mostly using environment variables. The repository contains a [.env_template](.env_template)
file containing most common configurations. Before running any `docker compose` commands, copy the `.env_template` as
`.env` in the same directory and change the configurations as desired.

The only properties that must be changed are:
* `POOLPARTY_LICENSE` this is the full path on the host machine to a valid PoolParty license
* `GRAPHDB_LICENSE` this is the full path on the host machine to a valid GraphDB license



## Development

To start a local development environment, run the following command:
```shell
docker compose up
```

This command will use the default [docker-compose.yaml](./docker-compose.yaml) file.

This will start PoolParty and dependent service in the foreground. Append the `-d` flag to run in the background.
The services are configured with less security and no high-availability.

After all services are running, PoolParty should be accessible at http://localhost. The default password for the 
`superadmin` user (if not changed in the `.env` file) is `poolparty`. After the first login, you should be prompted to
change it.

The default Keycloak admin is `poolparty_auth_admin` with password `admin`. These could be changed using the `.env`
file, respectively with the variables `POOLPARTY_KEYCLOAK_ADMIN_USERNAME` and `POOLPARTY_KEYCLOAK_ADMIN_PASSWORD`.

## Production

The production deployment build on top of the default compose file. To deploy the production configuration, run:

```shell
docker compose -f docker-compose.yaml -f production.yaml up
```

The additional [production.yaml](./production.yaml) file configures additional service, e.g. PostgreSQL service, used
by Keycloak, configures persistent volumes, and other optimization options.

## Spark

Starting PoolParty 10, support for external Spark service was added. If needed any of the above deployments can be
extended with an external Spark. To do that run a command similar to the following:

```shell
docker compose up -f docker-compose.yaml -f spark.yaml up
```

# Stopping services

If the services were started in the foreground, you can simply interrupt the process and the services will stop. If 
started with `-d` flag - the command is the same as the one for starting, but instead of `up`, specify the `down`
command.

The delete all data stored by the services, append the `--volumes` flag.
