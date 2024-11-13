# JBT Configuration Files

The configuration files are part of the [Joomla Branches Tester](../README.md) (JBT):

| File | Description | Additional Info |
| --- | --- | --- |
| [cypress.config.js](cypress.config.js) | Template for Cypress configuration used in `installation/joomla-*` directories. | Used by `scripts/database.sh`. |
| [docker-compose.base.yml](docker-compose.base.yml) | The basic part of the `docker-compose.yml` file. | Used by `scripts/helper.sh`. |
| [docker-compose.end.yml](docker-compose.end.yml) | The last lines of the `docker-compose.yml` file. | Used by `scripts/helper.sh`. |
| [docker-compose.joomla.yml](docker-compose.joomla.yml) | Part of the `docker-compose.yml` file to be parameterised for one Joomla web server. | Used by `scripts/helper.sh`. |
| [error-logging.ini](error-logging.ini) | Config file to catch all PHP errors, notices and warnings. | Used by `scripts/setup.sh`. |
| [pgpass](pgpass) | Auto-logon password file. | Used by `pgAdmin`. |
| [servers.json](servers.json) | PostgreSQL server configuration. | Used by `pgAdmin`. |
