⚠️ Under construction ⚠️ 

# Docker based Joomla Branches Tester

All four active Joomla branches run in parallel in a [Docker](https://www.docker.com/) container environment.
Use one or all four branches for:
* Automated [Joomla System Tests](https://github.com/joomla/joomla-cms/tree/4.4-dev/tests/System) with [Cypress](https://www.cypress.io/).
* Automated installation of the [Joomla Patch Tester](https://github.com/joomla-extensions/patchtester).
* Switch between the five combinations of database (MySQL, MariaDB or PostgreSQL) and
  the database driver (MySQL improved or PHP Data Objects).

![Joomla Branches Software Architecture](images/joomla-branches-tester.svg)

The idea is to have all active Joomla development branches (currently 4.4-dev, 5.1-dev, 5.2-dev and 6.0-dev)
available in parallel for testing. The installation takes place in 10 Docker containers and everything is scripted.
You see the four orange Web Server containers with the different Joomla version.
They are based on the `branch_*` folders, which are also available on the Docker host.
On the right you see three blue containers with MySQL, MariaDB and PostgreSQL database.
To be able to check the databases, two further blue containers with phpMyAdmin and pgAdmin are installed.
As green Docker container Cypress runs headless for testing.
If you will check problems you can also run Cypress GUI on your host system.

The `/scripts` folder contains all the bash-Scripts for the Joomla Branches Tester.
It is assumed that your current working directory is `joomla-branches-tester` all the time.
For the list of all Joomla Branches Tester scripts see [scripts/README.md](scripts/README.md).

## Prerequisites

As a prerequisite, it is sufficient to be able to run git, Docker and a bash scripts.
Thanks to Docker, it is not necessary to install one of the databases, the database management tools, PHP, Node or Composer.
Cypress needs only to be installed on your host system if you want to use Cypress GUI.

[Git](https://git-scm.com/), [Docker](https://www.docker.com/) an a bash scripting environment are required and must be installed. The following `/etc/hosts` entry must exist:
```
127.0.0.1 host.docker.internal
```

<details>
  <summary>Ubuntu Setup Script</summary>

:point_right: On Ubuntu with default enabled Uncomplicated Firewall (UFW) you need to allow SMTP port:
```
ufw allow 7025
```

:point_right: For Ubuntu Linux there is the script [ubuntu_setup.sh](scripts/ubuntu_setup.sh) available to install Docker, open the firewall port, set `host.docker.internal` entry etc.:

```
sudo scripts/ubuntu_setup.sh
```
</details>

## Installation

For the four Web server containers, to simplify life, the standard Docker Joomla images (`joomla:4` or `joomla:5`)
are used as a starting point and then overinstalled with the source code from the corresponding Joomla development branch.
The Joomla installation itself is executed by the Cypress spec `Installation.cy.js` from the Joomla System Tests.

Last tested with
* macOS 14 Sonoma,
* Windows 11 Pro WSL 2 and
* Ubuntu 24 Noble Numbat.

You can create the Docker containers and install Joomla with script [create.sh](scripts/create.sh):

```
git clone https://github.com/muhme/joomla-branches-tester
cd joomla-branches-tester
scripts/create.sh
```

The initial script `create.sh` runs some time,
especially the very first time when the Docker images still need to be downloaded.
The `joomla-branches-tester` folder requires 2 GB of disc space.

<details>
  <summary>Windows</summary>

Microsoft Windows needs WSL 2 installed and to run the script with `sudo`:
```
sudo scripts/create.sh
```

</details>

## Containers

The abbreviation `jbt` stands for Joomla Branches Tester:

|Name|Host Port:Local Port|Directory :eight_spoked_asterisk: |Comment|
|----|----|----------------------------------|-------|
|jbt_44|[7044](http://localhost:7044/administrator)| /branch_44 | Joomla branch 4.4-dev<br />PHP 8.1, ci-admin / joomla-17082005 |
|jbt_51|[7051](http://localhost:7051/administrator)| /branch_51 | Joomla branch 5.1-dev<br />PHP 8.2, ci-admin / joomla-17082005 |
|jbt_52|[7052](http://localhost:7052/administrator)| /branch_52 | Joomla branch 5.2-dev<br />PHP 8.2, ci-admin / joomla-17082005 |
|jbt_60|[7060](http://localhost:7060/administrator)| /branch_60 | Joomla branch 6.0-dev<br />PHP 8.2, ci-admin / joomla-17082005 |
|jbt_mysql| **7011**:3306 | | MySQL version 8.1 |
|jbt_madb| **7012**:3306 | | MariaDB version 10.4 |
|jbt_pg| **7013**:5432 | | PostgrSQL version 12.20 |
|jbt_cypress| SMTP **7025**:7025 | | SMTP server is only running during test execution |
|jbt_phpmya|[7001](http://localhost:7001)| | root / root |
|jbt_pga|[7002](http://localhost:7002)| | admin@example.com / admin |

:eight_spoked_asterisk: The directories are available on Docker host to:
* Inspect and change the configuration files (`configuration.php` or `cypress.config.js`),
* To edit the test specifications below `tests/System` or
* To inspect screenshots from failed tests.

## Usage

### Cypress Headless System Tests

Test all (more than 100 – as defined in Cypress `specPattern`) specs in all four branches:
```
scripts/test.sh
```

Test all specs only in the branch 5.1-dev:
```
scripts/test.sh 51
```

Test one spec with all four branches (of course, the spec must exist in all branches) :
```
scripts/test.sh tests/System/integration/administrator/components/com_privacy/Consent.cy.js
```

Test all site specs with branch 4.4-dev using a pattern:
```
scripts/test.sh 44 'tests/System/integration/site/**/*.cy.{js,jsx,ts,tsx}'
```

To show `console.log` messages from Electron browser by setting environment variable: 
```
export ELECTRON_ENABLE_LOGGING=1
scripts/test.sh 44 tests/System/integration/administrator/components/com_actionlogs/Actionlogs.cy.js
```

### Cypress GUI System Tests

If a test specification fails, it is often helpful to watch the test in the browser and
see all Cypress log messages and to be able to repeat the test quickly. You have to give the needed version to run:
```
scripts/cypress.sh 51
```

### Switch Database and Database Driver

You can simply switch between one of the three supported databases (MariaDB, PostgreSQL or MySQL) and
the database driver used (MySQL improved or PHP Data Objects).
Firstly, the settings for the database server with `db_host` and the database driver with `db_type`
are adjusted in the configuration file `Cypress.config.cy.mjs`.
Secondly, a Joomla installation is performed with the Joomla System Tests.

:warning: The overall database content is lost. For example, Joomla Patch Tester component needs to be installed again.

Available variants are:
* mariadbi – MariaDB with MySQLi (improved)
* mariadb – MariaDB with MySQL PDO (PHP Data Objects)
* pgsql - PostgreSQL PDO (PHP Data Objects)
* mysqli – MySQL with MySQLi (improved)
* mysql – MySQL with MySQL PDO (PHP Data Objects)

Use MariaDB with driver MySQLi for Joomla 5.2-dev:
```
scripts/database.sh 52 mariadbi
```

Change all four Joomla instances to use PostgreSQL:
```
scripts/database.sh pgsql
```

:point_right: It can also be used to clean a Joomla installation.

### Install Joomla Patch Tester

For your comfort there is 


## Limitations

The different Joomla versions exist in parallel, but the test runs sequentially.

Only one PHP version (the one from the Joomla Docker image) and one database version is used.

### Notes

By using `host.docker.internal` inside the containers and outside on the Docker host,
it is possible to run everything with the same hostnames and URLs from inside and outside.
However, there is a performance issue with the database.
Therefore, for the database connection `host.docker.internal` is only used when you run Cypress GUI from outside.
There is no performance problem because you come from outside.

## License

MIT License, Copyright (c) 2024 Heiko Lübbe, see [LICENSE](LICENSE)

## Contact

Don't hesitate to ask if you have any questions or comments. If you encounter any problems or have suggestions for enhancements, please feel free to [open an issue](../../issues).
