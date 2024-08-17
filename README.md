⚠️ Under construction ⚠️ 

# Docker based Joomla Branches Tester

<img align="right" src="images/magic_world.png">
Imagine a little slice of a parallel universe where testing all four active Joomla branches becomes a fluffy, cosy, and almost magical experience. In this universe, you can effortlessly test with the Patch Tester, glide through the Cypress GUI, or even enjoy the smooth efficiency of Cypress Headless. Picture the warmth of being able to peer into any database table as if through a magical glass, or seamlessly switch between five different database variants with just a small wave of a magic wand. Wouldn't that create a truly fluffy and cosy environment to work in?
<br /><br />
Alright, alright, apologies to those who enjoyed the whimsical writing style, but now it's time to dive into the technical depths. Let's transition from the cozy, magical universe into the world of technical documentation, where we'll explore the numerous options, parameters, and configurations that power this experience ...

## Software Architecture
All four active Joomla branches run in parallel in a [Docker](https://www.docker.com/) container environment.
Use one or all four branches for:
* Automated [Joomla System Tests](https://github.com/joomla/joomla-cms//blob/HEAD/tests/System) with [Cypress](https://www.cypress.io/).
* Automated installation of the [Joomla Patch Tester](https://github.com/joomla-extensions/patchtester).
* Switch between the five combinations of database (MySQL, MariaDB or PostgreSQL) and
  the database driver (MySQL improved or PHP Data Objects).

![Joomla Branches Software Architecture](images/joomla-branches-tester.svg)

The idea is to have all active Joomla development branches (currently 4.4-dev, 5.1-dev, 5.2-dev and 6.0-dev) are
available for testing in parallel. The installation takes place in 10 Docker containers and everything is scripted.
You see the four orange Web Server containers with the four different Joomla versions.
They are based on the `branch_*` folders, which are also available on the Docker host.

:point_right: The version numbers used in this documentation are as of August 2024.
As the active branches change regularly, the current numbers are read from the `joomla-cms` repository.

On the right you see three blue containers with the databases MySQL, MariaDB and PostgreSQL.
To be able to check the databases, two further blue containers with phpMyAdmin and pgAdmin are installed.
As green Docker container Cypress runs headless for testing.
If you need to inspect a failed test spec, you can run Cypress with the interactive GUI.

The `/scripts` folder contains all the scripts and also configuration files.
It is assumed that your current working directory is `joomla-branches-tester` all the time.

:point_right: For the complete list of all scripts see [scripts/README.md](scripts/README.md).

:fairy: The scripts contain *hacks* and a bit of magic for all the fluffiness, enjoy reading the comments in the scripts.

### Notes

By using `host.docker.internal` it is possible to run everything with the same hostnames and
URLs from container inside and Docker host machine outside.
However, there is a performance issue with the database.
Therefore, for the database connection `host.docker.internal` is only used when you run Cypress GUI from outside.
There is no performance problem because you come from outside.

## Prerequisites

All you need is the ability to run Git, Docker and Bash scripts.
Thanks to Docker, it is not necessary to install one of the databases, the database management tools, PHP, Node or Composer.

[Git](https://git-scm.com/), [Docker](https://www.docker.com/) and a bash scripting environment are required and must be installed. The following `/etc/hosts` entry must exist:
```
127.0.0.1 host.docker.internal
```

<details>
  <summary>Ubuntu Setup Script</summary>

For setting up and configuring an Ubuntu Linux environment with required Git, Docker, and firewall configuration,
one of the gnomes has provided the [ubuntu_setup.sh](scripts/ubuntu_setup.sh) script.
This script is designed to work on both a fresh Ubuntu desktop installation and Ubuntu
on Windows Subsystem for Linux (WSL).

Download the script to your current working directory and run with superuser privileges:
```
sudo bash ./ubuntu_setup.sh
```
</details>

## Installation

For the four Web server containers, to simplify life, the standard Docker Joomla images (`joomla:4` or `joomla:5`)
are used as a starting point and then overinstalled with the source code from the corresponding Joomla development branch.
The Joomla installation itself is executed by the Cypress spec `Installation.cy.js` from the Joomla System Tests.

Last tested with
* macOS 14 Sonoma,
* Windows 11 Pro WSL 2 Ubuntu and
* Ubuntu 24 Noble Numbat.

You can create the Docker containers and install Joomla with script `create.sh`:

```
git clone https://github.com/muhme/joomla-branches-tester
cd joomla-branches-tester
scripts/create.sh
```

<img align="right" src="images/joomla-branches-tester-52.svg" width="400">
The script can be parameterised with arguments, all of which are optional:

1. Install for single version number, e.g. only `52` (your system architecture will look like the picture on the right), defaults to all,
2. The used database and database driver, e.g. `pgsql`, defaults to MariaDB with MySQLi driver and
3. To force a fresh build with `no-cache`, defaults to build from cache.

:point_right: The script can run without `sudo`,
but depending on the platform, it may ask you to enter your user password for individual sudo actions.

The initial script `create.sh` runs some time,
especially the very first time when the Docker images still need to be downloaded.
The `joomla-branches-tester` folder requires about of 2 GB of disc space.
Docker needs additional about of 20 GB for images and volumes.
If you are installing for the first time and downloading all necessary Docker images,
you will need to download approximately 4 GB of data over the network.

<details>
  <summary>Windows WSL2 Ubuntu Setup</summary>

1. Install Windows WSL 2 if it has not already been done. Open PowerShell Window with administrator rights:
   ```
   wsl --install -d Ubuntu
   ```
   Restart your computer and in the terminal, type `wsl` to start the WSL environment.
   The first time you do this, you will be asked to create a user and set a password.
2. Install `git` inside WSL 2 Ubuntu:
   ```
   sudo apt-get update
   sudo apt-get upgrade
   sudo apt-get install git
   ```
3. Clone repository:
   ```
   git clone https://github.com/muhme/joomla-branches-tester
   cd joomla-branches-tester
   ```
4. Continue the installion with the Ubuntu setup script:
   ```
   sudo scripts/ubuntu_setup.sh
   ```
   To run Docker as user it is needed to restart Ubuntu:
   ```
   sudo reboot
   ```
5. After open WSL 2 with Ubuntu again and you are ready to create Joomla Branches Tester:
   ```
   cd joomla-branches-tester
   scripts/create.sh
   ```

:point_right: To run the interactive Cypress GUI from the Docker container `jbt_cypress`,
  Windows 11 (with includd Windows Subsystem for Linux GUI – WSLg) is required.

</details>

<details>
  <summary>macOS Setup</summary>

TODO

</details>

<details>
  <summary>Ubuntu Setup</summary>

TODO

</details>

## Containers

The abbreviation `jbt` stands for Joomla Branches Tester:

|Name|Host Port:<br />Container Inside|Directory :eight_spoked_asterisk: |Comment|
|----|----|----------------------------------|-------|
|jbt_44| **[7044](http://localhost:7044/administrator)** | /branch_44 | Web Server Joomla branch 4.4-dev<br />PHP 8.1, ci-admin / joomla-17082005 |
|jbt_51| **[7051](http://localhost:7051/administrator)** | /branch_51 | Web Server Joomla branch 5.1-dev<br />PHP 8.2, ci-admin / joomla-17082005 |
|jbt_52| **[7052](http://localhost:7052/administrator)** | /branch_52 | Web Server Joomla branch 5.2-dev<br />PHP 8.2, ci-admin / joomla-17082005 |
|jbt_60| **[7060](http://localhost:7060/administrator)** | /branch_60 | Web Server Joomla branch 6.0-dev<br />PHP 8.2, ci-admin / joomla-17082005 |
|jbt_mysql| **7011**:3306 | | Database Server MySQL version 8.1 |
|jbt_madb| **7012**:3306 | | Database Server MariaDB version 10.4 |
|jbt_pg| **7013**:5432 | | Database Server PostgrSQL version 12.20 |
|jbt_cypress| SMTP **7025**:7025 | | Cypress Headless Test Environment<br />SMTP server is only running during test execution |
|jbt_phpmya| **[7001](http://localhost:7001)** | | Web App to manage MariaDB and MySQL<br />auto-login configured, root / root |
|jbt_pga| **[7002](http://localhost:7002)** | | Web App to manage PostgreSQL<br />auto-login configured, root / root, postgres / prostgres |

:eight_spoked_asterisk: The directories are available on Docker host to:
* Inspect and change the configuration files (`configuration.php` or `cypress.config.js`),
* To edit the test specs below `tests/System` or
* To inspect screenshots from failed tests or
* To inspect and hack the Joomla sources from Docker host system.

## Usage

### Cypress Headless System Tests

To simple run the Joomla System Tests with all specs - except for the installation -
from the [Joomla System Tests](https://github.com/joomla/joomla-cms//blob/HEAD/tests/System) in all four branches:
```
scripts/test.sh
```

Three optional arguments are possible, in the following order:
1. Joomla version number, all versions are tested by default
2. Browser to be used, you can choose between electron (default), firefox, chrome or edge
3. Test spec pattern, all test specs (except the installation) are used by default

As an example, run all the test specs (except the installation) from branch 5.1-dev with Mozilla Firefox:
```
scripts/test.sh 51 firefox
```

Run one test spec with default Electron in all four branches (of course, the spec must exist in all branches):
```
scripts/test.sh tests/System/integration/administrator/components/com_privacy/Consent.cy.js
```

Test all `site` specs with Microsoft Edge in the branch 4.4-dev using a pattern:
```
scripts/test.sh 44 edge 'tests/System/integration/site/**/*.cy.{js,jsx,ts,tsx}'
```

To additional show `console.log` messages from Electron browser by setting environment variable: 
```
export ELECTRON_ENABLE_LOGGING=1
scripts/test.sh 44 tests/System/integration/administrator/components/com_actionlogs/Actionlogs.cy.js
```

:fairy: To protect you, the first step `Installation.cy.js` of the Joomla System Tests
  is excluded here when you run all test specs. If you run the installation, this can lead to inconsistencies
  between the file system and the database, as the Joomla database will be recreated.

### Cypress GUI System Tests

If a test spec fails, the screenshot is helpful. More enlightening is it to execute the single failed test spec
with the Cypress GUI in interactive mode. You can see all the Cypress log messages, use the time-traveling debugger and
observe how the browser runs in parallel.

Cypress GUI can be started from Docker container `jbt_cypress` with X11 forwarding
(recommeded for Windows 11 WSL 2 and Ubuntu):
```
scripts/cypress.sh 51
```

Or from local installed Cypress (recommended for macOS) with additional argument `local`:
```
scripts/cypress.sh 51 local
```

:imp: Are you see the `Installation.cy.js` test spec? Here you finally have the chance to do it.
  Who cares about file system and database consistency? Go on, click on it. Go on, go on ...

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

:warning: **Caution:** In your Joomla installation, the database and the files may now have diverged.
  This can be a problem if you have installed extensions.
  As an example, the autoload classes file `autoload_psr4.php` and
  the directories `administrator/components/com_patchtester`, `api/components/com_patchtester` and
  `media/com_patchtester` must be deleted before the next installation of the Joomla Patch Tester.
  This script takes care of this and you can reinstall Joomla Patch Tester without any problems.

:fairy: The good fairy waves her magic wand and says:
  "When in doubt, it's wiser to use `create.sh` to ensure a clean installation.
  With a sprinkle of stardust, you can specify the desired database variant,
  and if you're only installing one Joomla version, it will be done in the blink of an eye."

### Install Joomla Patch Tester

For your convenience [Joomla Patch Tester](https://github.com/joomla-extensions/patchtester)
can be installed on one or all four Joomla instances. The script also sets GitHub token and fetch the data.
This can be done without version number for all four Joomla instances or e.g. for Joomla 5.2-dev:

```
scripts/patchtester.sh 52 ghp_4711n8uCZtp17nbNrEWsTrFfQgYAU18N542
```

```
  Running:  patchtester.cy.js                             (1 of 1)
    Install 'Joomla! Patch Tester' with
    ✓ install component (7747ms)
    ✓ set GitHub token (2556ms)
    ✓ fetch data (6254ms)
```

:point_right: The GitHub token can also be given by environment variable `JBT_GITHUB_TOKEN`.

:fairy: Remember, if you have changed the database version, you will need to reinstall Joomla Patch Tester.

### Syncing from GitHub Repository

Script to fetch and merge all the latest changes from the Joomla GitHub repository into your local branches.
And again, this can be done for all four branches without argument, or for one version such as 5.2-dev:
```
scripts/pull.sh 52
```
Finally, the Git status of the branch is displayed.

<img align="right" src="images/phpMyAdmin.png">

### Gaze Into the Spellbook

In the mystical world of Joomla, the database is the enchanted tome where all the secrets are stored.
Sometimes, the wise must delve into this spellbook to uncover and weave new spells,
adjusting rows and columns with precision.

Fear not, for magical tools are at your disposal, each one a trusted companion.
They are so finely attuned to your needs that they require no login, no password—just a single click,
and the pages of the database open before you as if by magic:

* [phpMyAdmin](http://localhost:7001) for MariaDB and MySQL
* [pgAdmin](http://localhost:7002) for PostgreSQL

Simply approach these gateways, and the secrets of the database will reveal themselves effortlessly,
ready for your exploration.

### Cleaning Up

If you want to get rid of all these Docker containers and the 2 GB in the `branch_*` directories, you can do so:
```
scripts/clean.sh
```

## Limitations

* The different Joomla versions exist in parallel, but the test runs sequentially.
* Only one PHP version (the one from the Joomla Docker image) and one database version is used.
* The setup does not support HTTPS, secure connections issues are not testable.

## License

MIT License, Copyright (c) 2024 Heiko Lübbe, see [LICENSE](LICENSE)

## Contact

Don't hesitate to ask if you have any questions or comments. If you encounter any problems or have suggestions for enhancements, please feel free to [open an issue](../../issues).
