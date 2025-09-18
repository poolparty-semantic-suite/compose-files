# Docker compose file for PoolParty

This repository contains docker compose files for running PoolParty and related services.
Docker compose simplifies the deployment of several services in one go, their configuration, and the relation between
the service.

Docker compose allows chaining multiple service definition files, allowing the creation of multiple flavors, e.g.
development, stage, and production.

There are several files in this repository:
* `docker-compose.yaml` this file should be used only for evaluation and testing purposes - it's not sutable for production
* `production.yaml` this build on the default configuration, by adding additional services and configuration
* `spark.yaml` if desired, a separate spark instance can be deployed
* `ssl.yaml` add support for ssl to the proxy service

The basic docker compose commands are:

`docker compose up`: this is used to start all services defined in the compose files. It will start the services in the
foreground. To start the container and detach, add the `-d`/`--detach` flag.

`docker compose down`: this is used to stop all services defined in the compose files. To remove all volumes add the
`--volumes` flag, but be careful, as this will delete all data used by the services.

To control individual containers you can use `docker compose [COMMAND]`, where `[COMMAND]` can be `start`, `stop`,
`restart`, etc. Check the output of `docker compose help` for more information.

Multiple files could be used to manage different flavors of the deployment. The default `docker-compose.yaml` can be
used for development and testing/evaluations. All other flavors build on top of this, for example to deploy a separate
Apache Spark service use the following command:

```shell
docker compose -f docker-compose.yaml -f spark.yaml up
```

# Running

## Prerequisites

1. A recent version of [Docker](https://docs.docker.com/engine/install/) and the docker-compose plugin.
   1. Installation instructions for Docker on Linux include the `docker-compose-plugin`

## Configuration

The services are configured using environment variables. The repository contains a [.env_template](.env_template)
file containing most common configurations.

Before running any `docker compose` commands, copy the `.env_template` as `.env` in the same directory and change the 
configurations as desired.

There are two variables that must be changed:
* `POOLPARTY_LICENSE` this is the full path on the host machine to a valid PoolParty license
* `GRAPHDB_LICENSE` this is the full path on the host machine to a valid GraphDB license

Other notable variable are:
* `POOLPARTY_KEYCLOAK_ADMIN_USERNAME`: this is the admin username for Keycloak, default `poolparty_auth_admin`.
* `POOLPARTY_KEYCLOAK_ADMIN_PASSWORD`: this is the password for the admin user in Keycloak, default `admin` and it's 
recommended to be changed in production environments.
* `POOLPARTY_SUPER_ADMIN_PASSWORD`: this is the password for the `superadmin` in PoolParty, default `poolparty`. After the
first login you'll be asked to change this password.

Review the comments in the [.env_template](./.env_template) for all available variable and their purpose.

## Development

This should be used only for development, testing, and evaluation purposes. The services are configured with less 
security and no high-availability.

To start a local development environment, run the following command:

```shell
docker compose up -d
```

This command will use the default [docker-compose.yaml](./docker-compose.yaml) file. It will start PoolParty and the services that it
depends on.

After all services are running, PoolParty should be accessible at http://poolparty.127.0.0.1.nip.io/PoolParty. 
The default password for the `superadmin` is `poolparty`. After the first login, you will be prompted to change your 
password.

You can use a different instance for the Keycloak service. There are a few thing to configure before running without 
Keycloak by default:
1. Remember to change the PoolParty configurations for Keycloak.
2. Update the proxy configuration file
   1. Create a copy of either [poolparty.conf](files/nginx/poolparty.conf) or [poolparty_ssl.conf](files/nginx/poolparty_ssl.conf) and remove the `/auth` location directive.
   2. In `.env` change the `PROXY_CONFIG_PATH` variable to point to your new config.
3. Use the following command to start without deploying Keycloak.
```shell
docker compose up -d --scale keycloak=0
```

## Production

The production deployment builds on the default compose file. To deploy the production configuration, run:

```shell
docker compose -f docker-compose.yaml -f production.yaml up -d
```

Here we use multiple compose files, where every file is merged with the previous one. By doing that we add additional
services or change configurations on existing ones.

The additional [production.yaml](./production.yaml) file configures additional service, e.g. PostgreSQL service, used
by Keycloak, and other optimization options.

## Spark

Starting PoolParty 10, support for external Spark service was added. If needed any of the above deployments can be
extended with an external Spark. To do that run a command similar to the following:

```shell
docker compose up -f docker-compose.yaml -f spark.yaml up -d
```

## Running with SSL

In order to run the `proxy` service with SSL enabled, you will need to:
1. Obtain an SSL certificate and key. Preferably, this should be generated by a trusted authority.
   1. To generate a self-signed certificate, you can use the following command:
   ```shell
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout /etc/ssl/private/poolparty.key \
      -out /etc/ssl/certs/poolparty.crt
   ```
2. In `.env` update the values of `PROXY_CERT_PATH` and `PROXY_CERT_KEY_PATH` to point to the respective files.
3. In `.env` update the value of `PROXY_CONFIG_PATH` to `./files/nginx/poolparty_ssl.conf`
4. Finally, start the services with:
```shell
docker compose -f docker-compose.yaml -f ssl.yaml up -d
```

# Stopping services

If the services were started in the foreground, you can simply interrupt the process and the services will stop. If 
started with `-d` flag - the command is the same as the one for starting, but instead of `up`, specify the `down`
command.

The delete all data stored by the services, append the `--volumes` flag.

If you have specified multiple compose files in the `up` command, also specify them for the `down` command, otherwise
some services might be left running.

# Viewing log messages

To view the combined log messages of all services use the `docker compose logs` command. If you have specified multiple
compose files when starting the services, specify them here as well.

Instead of viewing the logs from all services, you can request the logs from a single service. Using
`docker compose logs [SERVICE]`, where [SERVICE] is the name of the desired service as defined in the compose file.
You can use `docker compose logs -f [SERVICE]`, to follow the log as it's updated.

# Migrating from PoolParty 9.7

## Prerequisites

1. Download the [migration tool](https://maven.ontotext.com/repository/poolparty-releases/biz/poolparty/poolparty-10-migration/1.0.0/poolparty-10-migration-1.0.0.jar)
2. If you have projects stored on a remote GraphDB instance, download them locally, if you want to migrate them
3. Stop the 9.7 PoolParty instance, and copy the installation directory to the directory specified by `POOLPARTY_9_DIR`

## Migration Steps

All migration steps will be executed within the PoolParty container. The [default](./docker-compose.yaml) compose file
will be used, but additionally, we will override the PoolParty start up command, and also Keycloak and ElasticSearch
will not be started.

This is done using the [migration](./migration.yaml) compose file. It disables the Keycloak and ElasticSearch containers,
but their volumes will be created. Additionally, it leaves GraphDB running, so that project data can be migrated.

The migration compose file will also:
1. Mount the current working directory to the `/migration` directory inside the PoolParty container
2. Mount the directory specified in by the `POOLPARTY_9_DIR` variable in `.env` to `/var/lib/poolparty-9` inside the PoolParty container

To migrate data from a PoolParty 9.7 to PoolParty 10, follow these steps:

1. Start the migration containers
   ```shell
   docker compose -f docker-compose.yaml -f migration.yaml up -d
   ```
2. Enter the `poolparty` container
   ```shell
   docker compose -f docker-compose.yaml -f migration.yaml exec --user root -it poolparty bash
   ```
3. To migrate all local projects and PoolParty configurations, run the following commands
   ```shell
   java -jar /migration/poolparty-10-migration-1.0.0.jar "/var/lib/poolparty-9" "/var/lib/poolparty" \
     --gdb-url http://graphdb:7200 \
     --skip-remote \
     --env-file /migration/env_migrated
   chown -R poolparty:poolparty /var/lib/poolparty
   ```
   This step will migrate all repositories from the PoolParty 9.7 to a new external GraphDB instance.
   If you are not using the GraphDB instance from the compose file, change the `--gdb-url` flag. You can also provide
   `--gdb-username`, `--gdb-password` for basic authentication, or `--gdb-auth-header` for other authentication methods.
4. To migrate ElasticSearch data, run the following commands
   ```shell
   cp -r /var/lib/poolparty-9/data/elasticsearch/. /usr/share/elasticsearch/data/
   chown -R 1000:root /usr/share/elasticsearch/data
   ```
5. To migrate Keycloak, choose one of the following options, based on your setup
   1. If in PoolParty 9.7 you used Keycloak with the embedded database, and you want to use the Keycloak instance from
      the compose files, again with the embedded database, run the following command:
      ```shell
      cp -r /var/lib/poolparty-9/auth_service/keycloak/data/. /opt/keycloak/data/
      chown -R 1000:root /opt/keycloak/data
      ```
   2. If in PoolParty 9.7 you used Keycloak with an external database, and you want to use the Keycloak instance from
      the compose files with the same external database, add the appropriate Keycloak configurations in `.env`.
   3. If you plan to use an external Keycloak instance, configure the PoolParty container to use that Keycloak instance.
6. Exit the container using the `exit` command, and stop the containers. Be careful not to delete the volumes.
   ```shell
   docker compose -f docker-compose.yaml -f migration.yaml down
   ```

In step `3`, the `--env-file /migration/env_migrated` flag was used. This should have created the `env_migrated` file
in the current directory.

1. Copy the contents of this file and paste it at the end of your `.env` file
2. Review the migrated configurations
   1. Make sure that any addresses match the new installation
   2. Delete `POOLPARTY_INDEX_URL` property, as it is already present in the configuration with the correct value
3. Follow the [section](#running) on running the compose files
4. Import any downloaded remote projects back to PoolParty
