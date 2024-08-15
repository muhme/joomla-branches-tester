# Scripts for a more pleasant and also faster development

The scripts and configuration files of the Joomla Branch Tester are stored in this directory `/scripts`.

## Your Scripts

The following scripts are available and the use is described in [../README.md](../README.md).

| Script | Description | Additional Info |
| --- | --- | --- |
| [scripts/create.sh](create.sh) | (Re-)Build all docker containers. | Optional arguments are version number, database variant and `no-cache`. |
| [scripts/test.sh](test.sh) | Running Cypress headless System Tests on one or all branches. | The version number is an optional argument. |
| [scripts/cypress.sh](cypress.sh) | Running Cypress GUI on your local machine to run System Tests in browser. Cypress must be installed locally. | Mandatory argument is the version number. |
| [scripts/database.sh](database.sh) | Changes database and database driver. | :warning: The overall database content is lost.<br />Optional argument is the version number. Mandatory argument is the database variant. |
| [scripts/patchtester.sh](patchtester.sh) | Installs and configures Joomla patch tester component in one or all Joomla instances. | The version number is an optional argument. The GitHub token argument is mandatory. |
| [scripts/pull.sh](pull.sh) | Running `git pull` and `git status` on one or all branches. | The version number is an optional argument. |
| [scripts/ubuntu_setup.sh](ubuntu_setup.sh) | Helper script in an installation on standard Ubuntu Linux. | |
| [scripts/clean.sh](clean.sh) | Delete all `jbt_*`-Docker containers and the `joomla-branches-tester_default` Docker network and `branch_*` folders.. | Used by `create.sh` or for you to get rid of all the stuff. |

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
| [scripts/patchtester.cy.js](patchtester.cy.js) | Cypress script to install and confgure Joomla Patch Tester component. | Used by `patchtester.sh`. |
| [scripts/helper.sh](helper.sh) | Some commonly used bash script functions and definitions. | Used by all other bash-Scripts. |
| [scripts/Joomla.js](Joomla.js) | [joomla-cypress](https://github.com/joomla-projects/joomla-cypress) *hack* until setting `db_port` is supported | Used by `database.sh`. |
| [scripts/servers.json](servers.json) | PostgreSQL server configuration. | Used by `pgAdmin`. |
| [scripts/pgpass](pgpass) | Auto-logon password file. | Used by `pgAdmin`. |
| [scripts/docker-compose.base.yml](docker-compose.base.yml) | The basic part of the `docker-compose.yml` file. | Used by `create.sh`. |
| [scripts/docker-compose.joomla.yml](docker-compose.joomla.yml) | Part of the `docker-compose.yml` file to be parameterised for one Joomla web server. | Used by `create.sh`. |
