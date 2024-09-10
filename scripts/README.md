# JBT Scripts

These scripts implement the Joomla Branches Tester (JBT), delivering the complete functionality along with necessary configuration files. They are stored in this directory `scripts`.

:point_right: For a quick overview of all mandatory and optional arguments, you can run each script with the 'help' argument. For example:
```
scripts/database.sh help
```
```
*** 240909 16:00:10 *** Script 'database.sh' started.

    database.sh – Change the database and database driver for all, one or multiple Joomla containers.
                  The mandatory database variant must be one of: mysqli mysql mariadbi mariadb pgsql.
                  Optional Joomla version can be one or more of the following: 44 51 52 53 60 (default is all).

                  "惚れた病に薬なし。", 不明

*** 240909 16:00:11 *** Script 'database.sh' finished in 1 second.
```

## Your Scripts

The following scripts are available and the use is described in [../README.md](../README.md).

| Script | Description | Additional Info |
| --- | --- | --- |
| [scripts/clean.sh](clean.sh) | Delete all `jbt_*`-Docker containers and the `joomla-branches-tester_default` Docker network and `branch_*` folders. | Used by `create.sh` or for you to get rid of all the stuff. |
| [scripts/create.sh](create.sh) | (Re-)Build all docker containers. | Optional arguments are version number(s), database variant, PHP version, `IPv6` and `no-cache`. |
| [scripts/cypress.sh](cypress.sh) | Running interactive Cypress GUI. | Mandatory argument is the Joomla version number. Optional argument is `local` to use a locally installed Cypress. |
| [scripts/database.sh](database.sh) | Changes database and database driver. | :warning: The overall database content is lost.<br />Mandatory argument is the database variant. Optional argument(s): Joomla version number(s). |
| [scripts/graft.sh](graft.sh) | Grafting a Joomla package onto a branch. | :warning: The overall database content is lost.<br />Mandatory argument is the Joomla package. Optional argument is the database variant.|
| [scripts/info.sh](info.sh) | Retrieves Joomla Branches Tester status information. |  |
| [scripts/patchtester.sh](patchtester.sh) | Installs and configures Joomla patch tester component in one or all Joomla instances. | The GitHub token comes from environment variable `JBT_GITHUB_TOKEN` or as mandatory argument. Optional argument(s): Joomla version number(s). |
| [scripts/php.sh](php.sh) | Change used PHP version. | Mandatory is the PHP version, e.g. `php8.3`. Optional argument(s): Joomla version number(s). |
| [scripts/pull.sh](pull.sh) | Running `git pull` and more. | Optional argument(s): Joomla version number(s). |
| [scripts/test.sh](test.sh) | Running Cypress headless System Tests on one or all branches. | Optional argument(s): Joomla version number(s), browser and test spec pattern. |
| [scripts/ubuntu_setup.sh](ubuntu_setup.sh) | Helper script in an installation on Ubuntu Linux (native or in Windows WSL 2). | |
| [scripts/xdebug.sh](xdebug.sh) | Switching PHP in web container to installation with or without Xdebug. | Mandatory argument is `on` or `off`. Optional arguments are the version number(s). |

:point_right: The scripts use [ANSI escape codes](https://en.wikipedia.org/wiki/ANSI_escape_code#Colors)
to color their own log and error messages. 
Log messages are highlighted in green and directed to the standard output (stdout) stream.
Error messages are displayed in red and directed to the standard error output (stderr) stream.
Colouring can be avoided by setting the environment variable [NOCOLOR=1](https://no-color.org/).
All messages start with three asterisks, the date and the time. See the following example:

![scripts/test.sh running screen shot](../images/screen-shot.png)

## Engine Room Scripts and Configurations

| File | Description | Additional Info |
| --- | --- | --- |
| [docker-compose.base.yml](docker-compose.base.yml) | The basic part of the `docker-compose.yml` file. | Used by `create.sh`. |
| [docker-compose.joomla.yml](docker-compose.joomla.yml) | Part of the `docker-compose.yml` file to be parameterised for one Joomla web server. | Used by `create.sh`. |
| [dockerfile-relay.yml](dockerfile-relay.yml) | Docker container definition for the SMTP relay doubler. | Used to create `jbt_relay`. |
| [scripts/helper.sh](helper.sh) | Some commonly used bash script functions and definitions. | Sourced and used by other Bash scripts within the project. |
| [scripts/patchtester.cy.js](patchtester.cy.js) | Cypress script to install and confgure Joomla Patch Tester component. | Used by `patchtester.sh`. |
| [scripts/pgpass](pgpass) | Auto-logon password file. | Used by `pgAdmin`. |
| [scripts/servers.json](servers.json) | PostgreSQL server configuration. | Used by `pgAdmin`. |
| [scripts/smtp_double_relay.py](smtp_double_relay.py) | SMTP relay triplicator source code. | Used by `jbt_relay`. |
