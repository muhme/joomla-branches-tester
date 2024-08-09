# Docker based Joomla Branches Tester

All four active Joomla branches run in parallel in a [Docker](https://www.docker.com/) container environment. Use one or all four branches for:
* Automated [Joomla System Tests](https://github.com/joomla/joomla-cms/tree/4.4-dev/tests/System) with [Cypress](https://www.cypress.io/).
* Automated installation of the [Joomla Patch Tester](https://github.com/joomla-extensions/patchtester).
* And you have the free choice to switch between the three supported databases MySQL, MariaDB and PostgreSQL.

![Joomla Branches Software Architecture](images/joomla-branches-tester.svg)

The idea is to have all active Joomla development branches (currently 4.4-dev, 5.1-dev, 5.2-dev and 6.0-dev)
available in parallel for testing. First for Joomla System Tests.
The test specifications are mostly branch-independent
and you can quickly test a new test specification or an error on all four branches.

And secondly, that the Joomla Patch Tester is automatically installed in all Joomla instances.

And thirdly, the option to change the database used.

For the list of all Joomla Branches Tester scripts see [scripts/README.md](scripts/README.md).



## Prerequisites

As a prerequisite, it is sufficient to be able to run git, Docker and a bash script.
Thanks to Docker, it is not necessary to install any of the databases, the database adminitration tools, Cypress, PHP, Node or Composer.
The installation takes place in 10 Docker containers and everything is scripted.
The result is a pure Docker container installation without manual installations or configurations.

[Git](https://git-scm.com/), [Docker](https://www.docker.com/) an a bash scripting environment are required and must be installed. The following `/etc/hosts` entry must exist:
```
127.0.0.1 host.docker.internal
```

<details>
  <summary>Ubuntu Setup Script</summary>
  
👉 For Ubuntu Linux there is the script [ubuntu_setup.sh](scripts/ubuntu_setup.sh) available to install Docker, open the firewall port, set `host.docker.internal` entry etc.:

```
sudo scripts/ubuntu_setup.sh
```
</details>

## Installation

For the four Web server containers, to simplify life, the standard Docker Joomla images (`joomla:4` or `joomla:5`) are used as a starting point and
then overinstalled with the source code from the corresponding Joomla development branch.
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

The initial script `create.sh` runs for about an hour (is only needed once) and requires about 7 GB disk space.

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
|jbt_44|[7044](http://localhost:7044)| /branch_44 | Joomla branch 4.4-dev<br />PHP 8.1 |
|jbt_51|[7051](http://localhost:7051)| /branch_51 | Joomla branch 5.1-dev<br />PHP 8.2 |
|jbt_52|[7052](http://localhost:7052)| /branch_52 | Joomla branch 5.2-dev<br />PHP 8.2 |
|jbt_60|[7060](http://localhost:7060)| /branch_60 | Joomla branch 6.0-dev<br />PHP 8.2 |
|jbt_my| **7011**:3306 | | MySQL version 8.1 |
|jbt_madb| **7012**:3306 | | MariaDB version 10.4 |
|jbt_pg| **7013**:5432 | | PostgrSQL version 11.16 |
|jbt_cypress| SMTP **7025**:7025 | | SMTP server is only running during test execution |
|jbt_mya|[7001](http://localhost:7001)| | user root / password root |
|jbt_pga|[7002](http://localhost:7002)| | admin@example.com / password admin |

:eight_spoked_asterisk: The directories are available on Docker host e.g. to inspect and change the configuration
files (`configuration.php` or `cypress.config.js`) or the test specifications below `tests/System`.
Filesystem is available for example to inspect screenshots from failed tests.

## Usage



:point_right: On Ubuntu with default enabled Uncomplicated Firewall (UFW) you need to allow SMTP port:
```
ufw allow 7025
```

Test all (more than 100 – as defined in Cypress `specPattern`) specs in all four branches:
```
scripts/test.sh
```

Test all specs only in branch 5.1-dev:
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

## Limitations

The different Joomla versions exist in parallel, but the test runs sequentially.

Only one PHP version (the one from the Joomla Docker image) and one database version is used.

TODO The Docker based Joomla System Tests are only intended for the headless operation of Cypress, the Cypress GUI is not available.

## License

MIT License, Copyright (c) 2024 Heiko Lübbe, see [LICENSE](LICENSE)

## Contact

Don't hesitate to ask if you have any questions or comments. If you encounter any problems or have suggestions for enhancements, please feel free to [open an issue](../../issues).
