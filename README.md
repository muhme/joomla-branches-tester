# JBT – Joomla Branches Tester

<img align="right" src="images/magic_world.png">
Imagine a little slice of a parallel universe where testing all used Joomla branches becomes a fluffy, cosy, and almost magical experience. In this universe, you can effortlessly test with the Patch Tester, glide through the Cypress GUI, or even enjoy the smooth efficiency of Cypress Headless. Picture the warmth of being able to peer into any database table as if through a magical glass, or seamlessly switch between five different database variants with just a small wave of a magic wand. Wouldn't that create a truly fluffy and cosy environment to work in?
<br /><br />
Alright, alright, apologies to those who enjoyed the whimsical writing style, but now it's time to dive into the technical depths. Let's transition from the cozy, magical universe into the world of technical documentation, where we'll explore the numerous options, parameters, and configurations that power this experience ...

## Software Architecture
All **used** Joomla development branches, representing different Joomla versions, run in parallel in a [Docker](https://www.docker.com/) container environment. **Used** Joomla development branches refer to the GitHub [joomla-cms](https://github.com/joomla/joomla-cms) repository, including default, active, and stale branches.
Use one, multiple, or all branches for:
* Manual testing, including database inspections and email verifications.
* Running [Joomla System Tests](https://github.com/joomla/joomla-cms//blob/HEAD/tests/System)
  with [Cypress](https://www.cypress.io/) in interactive mode (GUI) or automated mode (headless or with noVNC).
* Executing unit tests, verifying coding standards, and checking CSS styles and JavaScript standards, just like Drone.
* Automated [Joomla Patch Tester](https://github.com/joomla-extensions/patchtester) installation.
* Apply pull requests (PR) from Git repositories `joomla-cms`, `joomla-cypress` and `joomla-framework/database`.
* Switching between 10 database variants (MySQL, MariaDB, or PostgreSQL, and the two database drivers:
  MySQLi or PHP Data Objects, and the option to use Unix sockets, instead of TCP host).
* Switching between PHP versions (8.1, 8.2, or 8.3).
* Installing Joomla from a cloned 'joomla-cms' Git repository.
* Grafting a Joomla package onto a development branch.
* Using Xdebug for PHP debugging.
* Using IPv6 network.

![Joomla Branches Software Architecture](images/joomla-branches-tester.svg)

The goal is to have all used Joomla development branches (such as 4.4-dev, 5.1-dev, 5.2-dev, and 6.0-dev) available for parallel testing.
This setup is achieved using 13 Docker containers.
Everything is fully scripted and can be easily parameterized for maximum flexibility.
You'll notice the four orange Web Server containers, each running a different Joomla version.
These containers are based on the `branch_*` folders, which are also available on the Docker host.

:point_right: The version numbers referenced are current as of early August 2024.
              Since used branches are subject to frequent changes,
              the latest version numbers are always be retrieved directly from the `joomla-cms` repository.
              As of late August 2024, an additional version, `5.3-dev`, has been introduced.

On the right, you can see the three blue containers running the databases: MySQL, MariaDB, and PostgreSQL.
To inspect the databases, two additional blue containers are included: phpMyAdmin (for MySQL and MariaDB) and pgAdmin (for PostgreSQL).
A green Docker container runs Cypress based Joomla System Tests, either with a GUI or in headless mode.
The green noVNC container enables real-time viewing of automated Cypress System Tests.
If you need to investigate a failed test spec, you can easily switch to running Cypress with the interactive GUI.

The red mail relay container triplicates all emails sent during manual Joomla tests or System Tests.
The second red mail catcher container makes these emails accessible via a web application for easy review.

The `/scripts` folder contains all the necessary scripts as well as configuration files. Ensure that your current working directory is always the `joomla-branches-tester` directory.

On the Docker Host system (left side), your red web browser is running.
On macOS and Ubuntu, the native Cypress GUI is displayed in green.

:point_right: For the complete list of all scripts see [scripts/README.md](scripts/README.md).

:fairy: *"The scripts have a sprinkle of hacks and just a touch of magic to keep things fluffy.
        For those with a taste for the finer details, the comments are a gourmet treat."*

<details>
  <summary>As of early October 2024, there are currently 14 Docker containers providing the functionality.</summary>

---

The abbreviation `jbt` stands for Joomla Branches Tester.

|Name|Docker IPs|Host Port:<br />Container Inside|Directory :eight_spoked_asterisk: |Comment|
|----|----------|--------------------------------|----------------------------------|-------|
|jbt_phpmya| 10.0.0.2<br />fd00::2 | **[7002](http://host.docker.internal:7002)** | | Web App to manage MariaDB and MySQL<br />auto-login configured, root / root |
|jbt_pga| 10.0.0.3<br />fd00::3 | **[7003](http://host.docker.internal:7003)** | | Web App to manage PostgreSQL<br />auto-login configured, root / root, postgres / prostgres |
|jbt_mail| 10.0.0.4<br />fd00::4 | **[7004](http://host.docker.internal:7004)** <br /> SMTP **7225**:1025 | | Web interface to verify emails. |
|jbt_novnc| 10.0.0.5<br />fd00::5 | **[7005](http://host.docker.internal:7005/vnc.html?autoconnect=true&resize=scale)** | | If you run automated Cypress System Tests with the `novnc` option, you can watch them. |
|jbt_relay| 10.0.0.6<br />fd00::6 | SMTP **7025**:7025 | | SMTP relay triplicator |
|jbt_cypress| 10.0.0.7<br />fd00::7 | SMTP :7125 | | Cypress Headless Test Environment<br />SMTP server is only running during test execution |
|jbt_mysql| 10.0.0.11<br />fd00::11 :eight_pointed_black_star: | **7011**:3306 | | Database Server MySQL version 8.1 |
|jbt_madb| 10.0.0.12<br />fd00::12 | **7012**:3306 | | Database Server MariaDB version 10.4 |
|jbt_pg| 10.0.0.13<br />fd00::13 | **7013**:5432 | | Database Server PostgreSQL version 12.20 |
|jbt_44| 10.0.0.44<br />fd00::44 | **[7044](http://host.docker.internal:7044/administrator)** | /branch_44 | Web Server Joomla branch 4.4-dev<br />user ci-admin / joomla-17082005 |
|jbt_51| 10.0.0.51<br />fd00::51 | **[7051](http://host.docker.internal:7051/administrator)** | /branch_51 | Web Server Joomla branch 5.1-dev<br />user ci-admin / joomla-17082005 |
|jbt_52| 10.0.0.52<br />fd00::52 | **[7052](http://host.docker.internal:7052/administrator)** | /branch_52 | Web Server Joomla branch 5.2-dev<br />user ci-admin / joomla-17082005 |
|jbt_53| 10.0.0.52<br />fd00::52 | **[7053](http://host.docker.internal:7053/administrator)** | /branch_53 | Web Server Joomla branch 5.3-dev<br />user ci-admin / joomla-17082005 |
|jbt_60| 10.0.0.60<br />fd00::60 | **[7060](http://host.docker.internal:7060/administrator)** | /branch_60 | Web Server Joomla branch 6.0-dev<br />user ci-admin / joomla-17082005 |

:eight_spoked_asterisk: The directories are available on the Docker host inside `/jbt` to:
* Inspect and change the configuration files (`configuration.php` or `cypress.config.mjs`),
* To edit the test specs below `tests/System` or
* To inspect screenshots from failed tests or
* To inspect and hack the Joomla sources from Docker host system.

:eight_pointed_black_star: Gnome: *"Yes, yes, I know that `11` in decimal is `B` in hex, but can you instantly recall that `44` is `2C`? That's why, for easier visual recognition, we're sticking with `11` — it just needs to be unique!"*

:point_right: Using `host.docker.internal` ensures consistent hostnames and URLs between containers and the Docker host machine.
              However, there are exceptions to note:

1. **Database Performance**: For database connections, the Docker container name and the default
    database port are used to avoid performance issues.
    
2. **Running Cypress GUI on the Docker host**: `localhost` and the mapped database port are used instead,
    as Docker container hostnames aren't accessible outside Docker,
    and no performance issues have been observed in this configuration.<br /><br />
    Therefore, there is a separate Cypress configuration file `cypress.config.local.mjs`
    for the local execution of Cypress GUI on the Docker host.

---

</details>

## Prerequisites

All you need is the ability to run Git, Docker and Bash scripts.
Thanks to Docker, it is not necessary to install one of the databases, the database management tools, PHP, Node or Composer.

[Git](https://git-scm.com/), [Docker](https://www.docker.com/) and a bash scripting environment are required and must be installed. The following `/etc/hosts` entry will be created:
```
127.0.0.1 host.docker.internal
```

<details>
  <summary>Setup Script for Ubuntu (Native and WSL 2 on Windows)</summary>

---

For setting up and configuring an Ubuntu Linux environment with required Git, Docker, and firewall configuration,
one of the helpful gnomes has crafted the [ubuntu_setup.sh](scripts/ubuntu_setup.sh) script.
This script is designed to work on both a fresh Ubuntu desktop installation and Ubuntu running
on Windows Subsystem for Linux (WSL).

Download the script as raw file to any directory and run in terminal window with superuser privileges:
```
sudo bash ./ubuntu_setup.sh
```

After the script completes, please run `sudo reboot`.
Once your system has rebooted, verify the Docker installation by running `docker ps`.

---

</details>

## Installation

For the web server containers, to simplify life, the standard Docker Joomla images (`joomla:4` or `joomla:5`)
are used as a starting point and then overinstalled with the source code from the corresponding Joomla development branch.
The Joomla Web-Installer is executed by the Cypress spec `Installation.cy.js` from the Joomla System Tests.

Last tested in early October 2024 with:
* Intel chip macOS 15 Sequoia,
* Apple silicon macOS 15 Sequoia,
* Windows 11 Pro WSL 2 Ubuntu and
* Ubuntu 24 Noble Numbat (the absolute minimum, if you also wish to use the Cypress GUI, is a VPS with 2 shared vCPUs and 4 GB RAM).

You can create all Docker containers and install the current (early October 2024)
five Joomla instances using `scripts/create`:

```
git clone https://github.com/muhme/joomla-branches-tester
cd joomla-branches-tester
scripts/create
```
:point_right: The script can run without `sudo`,
but depending on the platform, it may ask you to enter your user password for individual sudo actions.

The initial `scripts/create` runs some time,
especially the very first time when the Docker images still need to be downloaded.
The `joomla-branches-tester` folder requires about of 2 GB of disc space.
Docker needs additional about of 20 GB for images and volumes.
If you are installing for the first time and downloading all necessary Docker images,
you will need to download approximately 4 GB of data over the network.

<details>
  <summary>The script can be parameterised with optional arguments.</summary>

---

<img align="right" src="images/joomla-branches-tester-52.svg" width="400">

1. Install for a single version number, e.g. `52` only
   (your system architecture will look like the picture on the right), default setting is for all branches.
   You can also give multiple Joomla versions like `53 60`.
2. The used database and database driver, e.g. `pgsql`, defaults to use MariaDB with MySQLi driver.
3. The used PHP version. You can choose between `php8.1`, `php8.2`, and `php8.3`. Defaults to `php8.1`.
   See more details in [Switch PHP Version](#switch-php-version).
4. Instead using `joomla-cms` repository, you can specify a different Git repository and branch.
   For example, using `https://github.com/Elfangor93/joomla-cms:mod_community_info`.
   In this case, exactly one version must be provided,
   and it should match the version of the given `joomla-cms` cloned repository.
5. The Docker `jbt_network`, used by all containers, defaults to IPv4.
   To use IPv6, run the script with the `IPv6` option.
   This will configure the Docker network to use IPv6.
6. The optional `recreate` option is used to create or recreate one web server container
   for the specified version. Base containers and unnamed web server containers remain unchanged.
7. To force a fresh build with `no-cache`, defaults to build from cache.

---

</details>

:point_right: In case of trouble, see [Trouble-Shooting](#trouble-shooting).

For the different operating systems, there are more detailed descriptions available:

<details>
  <summary>Windows WSL2 Ubuntu Setup</summary>

---

1. Install Windows WSL 2 (if not already installed).
   Open PowerShell Window with administrator rights and run:
   ```
   wsl --install -d Ubuntu
   ```
   Restart your computer after the installation.
2. Install Ubuntu by creating a user and setting a password. Open PowerShell as a regular user and run:
   ```
   wsl --install Ubuntu
   ```
   :point_right:  In the future, simply type `wsl` to start WSL 2 with Ubuntu.
3. Install `git` inside WSL 2 Ubuntu:
   ```
   sudo apt-get update
   sudo apt-get -y upgrade
   sudo apt-get -y install git
   ```
4. Clone Joomla Branches Tester repository e.g. in your home directory:
   ```
   cd
   git clone https://github.com/muhme/joomla-branches-tester
   ```
5. Continue the installation with the Ubuntu setup script:
   ```
   cd ~/joomla-branches-tester
   sudo scripts/ubuntu_setup.sh
   ```
   To run Docker as regular user it is needed to restart Ubuntu:
   ```
   sudo reboot
   ```
6. Open WSL again and verify Docker is running and you have access without sudo:
   ```
   docker ps
   ```
   Should show no containers:
   ```
   CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
   ```
   :point_right: It may take a moment for the Docker service to run.
   This can also be checked with `sudo service docker status` command.
7. Create a hosts entry on Windows to map `host.docker.internal` to `127.0.0.1`, follow these steps:
   * Open Notepad as Administrator
     * Press the Start button, type `Notepad`.
     * Right-click on Notepad and select Run as administrator.
   * Open the Hosts File:
     * In Notepad, click File -> Open.
     * Navigate to the hosts file location: `C:\Windows\System32\drivers\etc\`.
     * In the Open dialog, make sure to select All Files `(*.*)` in the file type dropdown
       at the bottom right (since the hosts file doesn't have a .txt extension).
       Select the `hosts` file and click Open.
   * Add the Host Entry:
     * At the end of the file, add a new line with the following entry:
       ```
       127.0.0.1 host.docker.internal
       ```
    * Save the Hosts File:
      * Click File -> Save to save your changes.
    * Test the New Hosts Entry:
      * Open Windows Command Prompt Terminal and ping the host.docker.internal to ensure it resolves to 127.0.0.1:
        ```bash
        ping host.docker.internal
        ```
        It should return responses from 127.0.0.1.
8. Now you are ready to create Joomla Branches Tester. Open WSL Ubuntu and run:
   ```
   cd ~/joomla-branches-tester
   scripts/create
   ```

:point_right: To run the interactive Cypress GUI from the Docker container `jbt_cypress`,
  Windows 11 (with included Windows Subsystem for Linux GUI – WSLg) is required.

---

</details>

<details>
  <summary>macOS Setup</summary>

---

To install the required Docker and Git, one possible approach is to follow these four steps:

1. [Install Docker Desktop on Mac](https://docs.docker.com/desktop/install/mac-install/) for either Apple silicon or Intel chip, and then run it.
2. Verify Docker is running:
   ```
   docker ps
   ```
   Should show no containers:
   ```
   CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
   ```
3. Install [Homebrew](https://brew.sh/) and follow the instructions to
   add `/opt/homebrew/bin` to your `PATH`.
4. Install git
```
brew install git
```

Once Docker and Git are installed, open a terminal window, clone the repository, and create
the Joomla Branches Tester:
```
git clone https://github.com/muhme/joomla-branches-tester
cd joomla-branches-tester
scripts/create
```

If you like to run Cypress GUI locally you have to install Node.js. Actual use LTS version 20 and follow the instructions to extend `PATH`:

```
brew install node@20
echo 'export PATH="/opt/homebrew/opt/node@20/bin:$PATH"' >> ~/.zshrc
```

You can now run System Tests using the Cypress GUI locally.
The script will automatically install the appropriate version specified
for each branch the first time you open it:
```
scripts/cypress 53 local
```

---

</details>

<details>
  <summary>Ubuntu Setup</summary>

---

Installing the Joomla Branches Tester on Ubuntu with a user that is able to run `sudo`.

1. To setup Git, Docker, and firewall configuration, download the [ubuntu_setup.sh](scripts/ubuntu_setup.sh) script as a raw file, run in terminal window with superuser privileges and reboot the system:
   ```
   sudo bash ./ubuntu_setup.sh
   sudo reboot
   ```
2. Clone Joomla Branches Tester repository e.g. in your home directory:
   ```
   cd
   git clone https://github.com/muhme/joomla-branches-tester
   ```
3. Now you are ready to create Joomla Branches Tester:
   ```
   cd ~/joomla-branches-tester
   scripts/create
   ```

---

</details>

## Usage

### Joomla Configuration

The Joomla development version installed in the web server container is configured with the following settings:

- Joomla Super User: `ci-admin` with the password `joomla-17082005` (used from CI System Tests).
- Used language Pack is English (United Kingdom) (`en-GB`).
- The `/installation` folder remains intact after the installation.
- Error Reporting is set to `Maximum` in `Global Configuration | Server`.
- A cron job is configured to run the Joomla Task Scheduler every minute.
- The 'System - Joomla! Statistics' plugin is disabled to prevent prompting users on the backend Home Dashboard.
- The 'Behaviour - Backward Compatibility' plugin is disabled to detect backward compatibility issues.
- The automatic run of the 'Welcome to Joomla!' guided tour is canceled from Joomla version 5.1 onwards.
- Not configured for logging, due to deprecation warnings.

### Manual Testing

From your Docker Host system you can test the Joomla Frontend e.g. for Joomla release 5.2
with [http://host.docker.internal:7052](http://host.docker.internal:7052) and the backend
[http://host.docker.internal:7052/administrator](http://host.docker.internal:7052/administrator).
User *ci-admin* and password *joomla-17082005* (Whose birthday is it anyway?) are from Joomla System Tests.

In parallel you can inspect MariaDB and MySQL database with [phpMyAdmin](https://www.phpmyadmin.net/) on
[http://host.docker.internal:7002](http://host.docker.internal:7002) or PostgreSQL database with [pgAdmin](https://www.pgadmin.org/) on
[http://host.docker.internal:7003](http://host.docker.internal:7003). And verify all emails from Joomla and the System Tests with
[MailDev](https://github.com/maildev/maildev/blob/master/docs/docker.md) on
[http://host.docker.internal:7004](http://host.docker.internal:7004).

If you need to inspect files, they are available in the directory `branch_52` for this Joomla release 5.2 sample.

### Drone-like Tests

A subset of seven tests from the full Joomla [Drone](https://www.drone.io/) CI test suite has been implemented:

* `php-cs-fixer` – PHP Coding Standards Fixer (dry-run)
* `phpcs` – PHP Coding Sniffer
* `unit` - PHP Testsuite Unit
* `lint:css` - CSS Linter
* `lint:js` - JS Linter
* `lint:testjs` – JS Linter for Tests
* `system` – System Tests

Running all seven tests on all branches is simple with the following command:
```
scripts/test
```

Some optional arguments are:

* Joomla version number(s): Choose one or multiple versions; all versions are tested by default.
* Test name(s): Choose one or multiple tests; all tests are executed by default.

For example run the linter tests on three branches:
```
scripts/test 51 52 53 lint:css lint:js lint:testjs
```

To avoid issues with running `php-cs-fixer`, the auto-generated file `administrator/cache/autoload_psr4.php` is corrected beforehand.
And the configurations for `php-cs-fixer` and `phpcs` has been extended to exclude the `com_patchtester` component.

:point_right: The PHP Unit Test Suite integration and the Phan static analyzer for PHP have not been implemented.
              Additionally, the tests are not configured to run on multiple PHP versions, as Drone typically does in the Joomla CI environment.

### Cypress Automated System Tests

To simple run the Joomla System Tests with all specs - except for the installation step -
from the [Joomla System Tests](https://github.com/joomla/joomla-cms//blob/HEAD/tests/System) in all branches with headless Cypress:
```
scripts/test system
```

:fairy: <i>"To protect you, the first step `Installation.cy.js` of the Joomla System Tests
  is excluded in the automated tests if you run all test specs.
  If you run the installation, this can lead to inconsistencies
  between the file system and the database, as the Joomla database will be recreated.</i>

Some more optional arguments for System Tests are:

* Browser to be used: Choose between electron (default), firefox, chrome, or edge.
* Test spec pattern: All test specs (except the installation) are used by default.

As an example, run all the test specs (except the installation) from branch 5.1-dev with Mozilla Firefox:
```
scripts/test 51 system firefox
```

Run one test spec with default Electron in all branches (of course, the spec must exist in all branches):
```
scripts/test system administrator/components/com_users/Users.cy.js
```

:point_right: When specifying a single test spec file,
              you can omit the `tests/System/integration/` path at the beginning.

Test all `site` specs with Microsoft Edge in the branches Joomla 5.1, 5.2 and 5.3 using a pattern:
```
scripts/test 51 52 53 system edge 'tests/System/integration/site/**/*.cy.{js,jsx,ts,tsx}'
```

One more optional argument is `novnc`.
The `jbt_vnc` container allows to view the automated browser tests via the web-based VNC viewer [noVNC](https://github.com/novnc/noVNC).
This is useful for watching the automated Cypress System Tests in real-time, for example,
when the gnome is too impatient to wait for the 120-second timeout from `installJoomla` again.
In this case Cypress runs headed and uses `jbt_vnc` as DISPLAY and you can watch the
execution of the automated tests with the URL:
* [http://host.docker.internal:7005/vnc.html?autoconnect=true&resize=scale](http://host.docker.internal:7005/vnc.html?autoconnect=true&resize=scale)
```
scripts/test 53 system novnc administrator/components/com_users/Users.cy.js
```

To additional show `console.log` messages from Electron browser by setting environment variable: 
```
export ELECTRON_ENABLE_LOGGING=1
scripts/test 44 system administrator/components/com_actionlogs/Actionlogs.cy.js
```

### Cypress Interactive System Tests

If a test spec fails, the screenshot is helpful. More enlightening is it to execute the single failed test spec
with the Cypress GUI in interactive mode. You can see all the Cypress log messages, use the time-traveling debugger and
observe how the browser runs in parallel.

Cypress GUI can be started from Docker container `jbt_cypress` with X11 forwarding
(recommended for Windows 11 WSL 2 Ubuntu):
```
scripts/cypress 51
```

Or from local installed Cypress (recommended for macOS and native Ubuntu) with additional argument `local`:
```
scripts/cypress 51 local
```

The script will automatically install the appropriate Cypress version locally
for each branch if it doesn't already exist.
Using the Cypress container has the advantage of having Chrome, Edge, Electron, and Chromium pre-installed.
If you run Cypress locally, only the browsers installed on your Docker host system will be available.

:imp: <i>Are you see the `Installation.cy.js` test spec? Here you finally have the chance to do it.
      Who cares about [Database and File System Consistency](#database-and-file-system-consistency)?
      Go on, click on it. Go on, go on ...</i>

### Check Email

To check the emails sent by Joomla,
the [MailDev](https://hub.docker.com/r/maildev/maildev) container offers you
provides you with a web interface at [http://host.docker.internal:7004](http://host.docker.internal:7004).
The Cypress based Joomla System Tests is using an own SMTP server `smtp-tester` to receive, check and delete emails.
Since we run Cypress locally or in a container, it is necessary to triple emails.
This is done by the SMTP relay triplicator `jbt_relay`.

:fairy: *"Oh, dear Gnome, now I can really read all the emails from the System Tests, thank you."*

<details>
  <summary>:imp: <i>"Postal dispatch nonsense picture? Don't open it, you'll get a triple headache!"</i> </summary>

---

:fairy: *"Shut up and listen. The email traffic is explained using the Joomla branch 5.1-dev with
the use cases password reset and System Tests."*

![Joomla Branches Tester – Email Traffic](images/email.svg)

1. A user (not in the Super User group) requests a password reset by clicking 'Forgot your Password?' in their web browser.
   This request is sent to the Joomla PHP code on the web server jbt_51.
2. An email is sent via SMTP from the web server `jbt_51` to the email relay `jbt_relay`.
   In the Joomla `configuration.php` file, the `smtpport` is configured as `7025`.
3. The email relay `jbt_relay` triplicates the email and sends the first email via SMTP to the email catcher `jbt_mail`.
4. The email relay `jbt_relay` tries to deliver the second email to `smtp-tester`.
   But no System Tests is running, the email cannot be delivered and is thrown away.
5. The email relay `jbt_relay` tries to deliver the third email to locally running Cypress GUI with `smtp-tester`.
   But no Cypress GUI is running, the email cannot be delivered and is thrown away.
6. System Test is started with `scripts/test` in the Cypress container `jbt_cypress`.
   In the Cypress `cypress.config.mjs` file, the `smtp_port` is configured as `7125`.
   While the System Tests is running `smtp-tester` is listening on port 7125.
7. One of the System Tests specs executes an action in Joomla PHP code that generates an email.
8. Again the email is sent via SMTP from the web server `jbt_51` to the email relay `jbt_relay`.
9. Again the email relay `jbt_relay` triplicates the email and
   sends the one email via SMTP to the `jbt_cypress` container with `smtp-tester` running in .
   The Cypress test can check and validate the email.
10. Again the email relay `jbt_relay` sents one copy via SMTP to the email catcher `jbt_mail`.
11. Again the email relay `jbt_relay` tries to deliver the third email to locally running Cypress GUI with
    `smtp-tester`. But no Cypress GUI is running, the email cannot be delivered and is thrown away.

Therefore, the `cypress.config.mjs` file uses a different SMTP port (7125) than the `configuration.php` file (7025).
Additionally, the `cypress.config.local.mjs` file is used with yet another SMTP port (7325)
for running the Cypress GUI locally.

---

</details>

### Databases

The Joomla Branches Tester includes one container for each of the three supported databases (version numbers as of September 2024):
* `jbt_mysql` – MySQL version 8.1.0 Community Server
* `jbt_madb` – MariaDB version 10.4.34
* `jbt_pg` – PostgreSQL version 15.8

You can set the desired database and database driver using `scripts/create` or switch them later with `scripts/database`.

#### Switch Database and Database Driver

You can simply switch between one of the three supported databases (MariaDB, PostgreSQL or MySQL) and
the database driver used (MySQL improved or PHP Data Objects).
Firstly, the settings for the database server with `db_host` and the database driver with `db_type`
are adjusted in the configuration file `Cypress.config.cy.mjs`.
Secondly, a Joomla installation is performed with the Joomla System Tests.

Five variants are available:
* mariadbi – MariaDB with MySQLi (improved)
* mariadb – MariaDB with MySQL PDO (PHP Data Objects)
* pgsql - PostgreSQL PDO (PHP Data Objects)
* mysqli – MySQL with MySQLi (improved)
* mysql – MySQL with MySQL PDO (PHP Data Objects)

Use MariaDB with driver MySQLi for Joomla 5.1 and Joomla 5.2:
```
scripts/database 51 52 mariadbi
```

Change all Joomla instances to use PostgreSQL:
```
scripts/database pgsql
```

:warning: The overall database content is lost.
          If you have installed the Joomla Patch Tester, you need to reinstall it now.
          For more details, see [Database and File System Consistency](#database-and-file-system-consistency).

:fairy: The good fairy waves her magic wand and says:
  *"When in doubt, it's wiser to use `scripts/create` to ensure a clean installation.
  With a sprinkle of stardust, you can specify the desired database variant,
  and if you're only installing one Joomla version, it will be done in the blink of an eye."*

#### Database Unix Sockets

Database Unix sockets are available in the Cypress and Joomla Web Server containers:
```
/jbt/run/postgresql-socket
/jbt/run/mysql-socket/mysqld.sock
/jbt/run/mysql-socket/mysqlx.sock
/jbt/run/mariadb-socket/mysqld.sock
```
They are used in `scripts/create` and `scripts/database` with the `socket` option.
Without this option, the database connection defaults to using the TCP host.

```
scripts/database mysqli socket
```

Without using the Unix sockets for Joomla,
you can still take advantage of them with command-line client tools. For example:
```
docker exec -it jbt_pg bash -c "psql -h /var/run/postgresql -U root -d test_joomla_44"
docker exec -it jbt_madb bash -c "mariadb --socket=/var/run/mysqld/mysqld.sock -u root -proot"
docker exec -it jbt_mysql bash -c "mysql --socket=/var/run/mysqld/mysqld.sock -u root -proot"
```

:point_right: Be aware that for the Joomla System Tests,
              Unix sockets currently work (as of early October 2024) only for the installation step,
              but not for custom database commands that are JavaScript-based,
              you need to install PR [44092](https://github.com/joomla/joomla-cms/pull/44092).
              See [Back to the Future - Patch](#back-to-the-future---patch).

### Switch PHP Version

The Joomla Docker images are from the official images for Joomla
(see [docker-joomla](https://github.com/joomla-docker/docker-joomla)
and the [Docker Hub page](https://registry.hub.docker.com/_/joomla/)). Thank you! :pray:

You can switch between the available Images for PHP 8.1, PHP 8.2, and PHP 8.3
across all branches:
```
scripts/php php8.3
```
Or specify the desired branches:
```
scripts/php 44 51 php8.1
```
As we are based on the Docker images there are limitations (as of early October 2024):
* There is no Docker image for Joomla 4.4 with PHP 8.3, there is a fall back to PHP 8.2 used.
* There are no Docker images for Joomla 5.3 and Joomla 6.0. The Joomla 5.2 images are being used instead.
  This should not cause any issues, as the source code for 5.3 and 6.0 is pulled from the respective
  GitHub branches.

### Grafting a Joomla Package

Not interested in testing the latest development branch but still need to test a Joomla package? No problem!
Just like in plant grafting, where a scion is joined to a rootstock,
you can graft a Joomla package onto the development branch for testing.
Simply choose the same major and minor version numbers from the development branch,
and graft the package for a seamless experience:

```
scripts/graft 52 ~/Downloads/Joomla_5.2.0-alpha4-dev-Development-Full_Package.zip
```

Mandatory arguments are the Joomla branch version and the local package file.
Supported file formats are .zip, .tar, .tar.zst, .tar.gz, and .tar.bz2.
An optional argument is the database variant, such as PostgreSQL in the following example:
```
scripts/graft 51 pgsql ~/Downloads/Joomla_5.1.3-Stable-Full_Package.zip
```
:warning: The overall database content is lost.
          If you have installed the Joomla Patch Tester, you need to reinstall it now.
          For more details, see [Database and File System Consistency](#database-and-file-system-consistency).

After grafting, you can still switch the database variant, change the PHP version,
install the Joomla Patch Tester, or run Joomla System Tests.
There is no Git repository, so you cannot run the other tests, and scripts/pull will be skipped.
Grafting can also be done multiple times. :smile:

What distinguishes a grafted Joomla from a standard package-installed Joomla?
A grafted Joomla contains three additional files and two directories from the development branch:
* Files: `cypress.config.dist.mjs`, `package.json` and `package-lock.json`
* Directories: `node_modules` and `tests/System`

### Syncing from GitHub Repository

To avoid recreating everything the next day, you can simply fetch and merge the latest changes from the
Joomla GitHub repository into your local branches. This can be done for all branches without any arguments,
or for specific versions:
```
scripts/pull 53 60
```

If changes are pulled then:
* Just in case the command `composer install` is executed.
* If `package-lock.json` file has changed the command `npm ci` is executed.

Finally, the Git status is displayed.

<img align="right" src="images/phpMyAdmin.png">
<img align="right" src="images/pgAdmin.png" width="240px">

### :fairy: Gaze Into the Spellbook

In the mystical world of Joomla, the database is the enchanted tome where all the secrets are stored.
Sometimes, the wise must delve into this spellbook to uncover and weave new spells,
adjusting rows and columns with precision.

Fear not, for magical tools are at your disposal, each one a trusted companion.
They are so finely attuned to your needs that they require no login, no password — just a single click,
and the pages of the database open before you as if by magic:

* [http://host.docker.internal:7002](http://host.docker.internal:7002) phpMyAdmin – for MariaDB and MySQL
* [http://host.docker.internal:7003](http://host.docker.internal:7003) pgAdmin – for PostgreSQL

Simply approach these gateways, and the secrets of the database will reveal themselves effortlessly,
ready for your exploration.

### Xdebug

<img align="right" src="images/Xdebug.png">

Joomla web server containers are ready with a second PHP installation for switching to
[Xdebug](https://github.com/xdebug/xdebug).
You can switch to the PHP version with Xdebug for example:
```
scripts/xdebug 53 on
```

A `.vscode/launch.json` file is also prepared
(to simplify life, it's created in advance for all versions,
even if they are not installed or Xdebug is not enabled).
In [Visual Studio Code](https://code.visualstudio.com/),
select 'Start Debugging' and choose the corresponding entry `Listen jbt_53`.

Finally, it may be reset again to improve performance:
```
scripts/xdebug off
```

Used ports are 79xx, for the given example 7953.

### IPv6

As shown in the [Installation](#installation) chapter,
you can create the Docker Branches Tester instance using `scripts/create`
with the `IPv6` option instead of the default IPv4 network.
IP addresses are fixed from the predefined private, non-routable subnet `fd00::/8`.

You can use the IPv6 address (instead of the hostname) to open the PostgreSQL interactive terminal:
```
docker exec -it jbt_pg bash -c "PGPASSWORD=root psql -h fd00::13 -U root -d postgres"
```
:point_right: IPv6 networking is limited to within Docker.
              The `host.docker.internal` feature generally defaults to IPv4,
              and there is no built-in IPv6 equivalent.
              As `scripts/cypress local` works with `host.docker.internal`,
              the database custom commands executed by a local running Cypress GUI
              use the IPv4 address to access the database.

### Install Joomla Patch Tester

For your convenience, the latest version of the
[Joomla Patch Tester](https://github.com/joomla-extensions/patchtester)
can be installed on the Joomla instances.
The script also sets the GitHub token and fetch the data.
This can be done without version number for all Joomla instances or for e.g. Joomla 5.3-dev:

```
scripts/patchtester 53 ghp_4711n8uCZtp17nbNrEWsTrFfQgYAU18N542
```

```
  Running:  patchtester.cy.js                             (1 of 1)
    Install 'Joomla! Patch Tester' with
    ✓ install component (7747ms)
    ✓ set GitHub token (2556ms)
    ✓ fetch data (6254ms)
```

:point_right: The GitHub token can also be given by environment variable `JBT_GITHUB_TOKEN`.
              And of course the sample token does not work.

:fairy: *"You need to reinstall the Joomla Patch Tester if, for example you switch the database.
        For more details, see [Database and File System Consistency](#database-and-file-system-consistency)."*

:point_right: Alternatively, to apply patches, you can use `scripts/patch`, see [Back to the Future - Patch](#back-to-the-future---patch).

### Back to the Future - Patch

As Doc Brown said: *"Roads? Where we're going, we don't need roads."*

JBT can install patches on its own using Git merge from pull requests (PRs) with `scripts/patch` (or even with `scripts/create`),
applicable to the following repositories:
* joomla-cms - [joomla/joomla-cms](https://github.com/joomla/joomla-cms)
* joomla-cypress - [joomla-projects/joomla-cypress](https://github.com/joomla-projects/joomla-cypress)
* database - [joomla-framework/database](https://github.com/joomla-framework/database)

This can be done for all branches without any arguments, or for specific versions:
```
# Apply non-standard database port for 4.4-dev and 5.2-dev branches
scripts/patch 44 52 joomla-cypress-33 joomla-cms-43968

# Allow to specify port number or UNIX socket in 5.3-dev branch
scripts/patch 53 database-310
```

:warning: Be cautious when applying patches, as we perform a full merge, which could introduce additional changes to the original pull request. Always monitor the number of modified lines.

As of early October 2024, the default installation remains unpatched.
While there's no way to remove a patch, you can use the `scripts/create recreate` to *go back in time* and restore the branch to the original state.

:point_right: Alternatively, to apply `joomla-cms` patches, you can use [Joomla Patch Tester](#install-joomla-patch-tester).

#### DeLorean

You can take a seat and pick up additional code from the future on your own.
As of early October 2024, the following pull requests (PRs) have not yet been merged, released, or included in certain branches - but tested to be included in the branches:

* :wrench: [joomla-cypress-33](https://github.com/joomla-projects/joomla-cypress/pull/33) Install Joomla with non-standard db_port
  * Working for 4.4-dev, 5.1-dev (and updates joomla-cypress from 1.0.3 to 1.1.1 -  which is a good idea anyway), 5.2-dev, 5.3-dev and 6.0-dev
* :wrench: [joomla-cms-43968](https://github.com/joomla/joomla-cms/pull/43968) [cypress] Add db_port in Installation.cy.js
  * Working for 4.4-dev, 5.2-dev and 5.3-dev
* :wrench: [joomla-cypress-36](https://github.com/joomla-projects/joomla-cypress/pull/36) Wrap IPv6 address in brackets \[ \] if needed
  * Working for 4.4-dev, 5.1-dev (and updates joomla-cypress from 1.0.3 to 1.1.1 -  which is a good idea anyway), 5.2-dev, 5.3-dev and 6.0-dev
* :wrench: [database-310](https://github.com/joomla-framework/database/pull/310) [3.x] Allow to specify port number or UNIX socket in host option also for MySQL (PDO) and PostgreSQL (PDO)
  * Working for 5.1-dev, 5.2-dev, 5.3-dev and 6.0-dev
* :wrench: [joomla-cms-44084](https://github.com/joomla/joomla-cms/pull/44084) [cypress] Using NPM Module 'pg' for 'postgres'
  * Working for 4.4-dev
* :wrench: [joomla-cms-44092](https://github.com/joomla/joomla-cms/pull/44092) [cypress] Database Unix Sockets for System Tests
  * Working for 4.4-dev

### Info

You can retrieve some interesting Joomla Branches Tester status information.
If no argument is provided, all information will be displayed:
```
scripts/info
```
The following example illustrates an IPv6 installation with three branches:
* `4.4-dev`: A development clone based on version 4.4.9, PHP 8.1 is running with Xdebug, using PostgreSQL with driver PDO
* `5.1-dev`: Grafted with the Joomla 5.1.3 Stable package, PHP 8.2, using MariaDB with driver MySQLi
* `5.2-dev`: A development clone of version 5.2.0 with additional patches applied, using MySQL with driver PDO
```
Joomla Branches Tester (JBT) version 1.0.39
  Docker version 27.2.0 is running with 12 containers and 14 images
  EnableIPv6: true
Standard Containers:
  jbt_mysql   is running, ports: 3306/tcp -> 0.0.0.0:7011; 3306/tcp -> [::]:7011
  jbt_madb    is running, ports: 3306/tcp -> 0.0.0.0:7012; 3306/tcp -> [::]:7012
  jbt_pg      is running, ports: 5432/tcp -> 0.0.0.0:7013; 5432/tcp -> [::]:7013
  jbt_mya     is running, ports: 80/tcp -> 0.0.0.0:7002; 80/tcp -> [::]:7002
  jbt_pga     is running, ports: 80/tcp -> 0.0.0.0:7003; 80/tcp -> [::]:7003
  jbt_cypress is running, ports: 7125/tcp -> 0.0.0.0:7125; 7125/tcp -> [::]:7125
  jbt_novnc   is running, ports: 8080/tcp -> 0.0.0.0:7005; 8080/tcp -> [::]:7005
  jbt_relay   is running, ports: 7025/tcp -> 0.0.0.0:7025; 7025/tcp -> [::]:7025
  jbt_mail    is running, ports: 1025/tcp -> 0.0.0.0:7225; 1025/tcp -> [::]:7225; 1080/tcp -> 0.0.0.0:7004; 1080/tcp -> [::]:7004
Branch 4.4-dev:
  jbt_44 is running, ports: 80/tcp -> 0.0.0.0:7044; 80/tcp -> [::]:7044
  Version: Joomla! 4.4.9 Development
  PHP 8.1.29 with Xdebug
  PostgreSQL(PDO), jbt_pg, ''
  /branch_44: 438MB
  Repository branch_44: https://github.com/joomla/joomla-cms,  Branch: 4.4-dev,  Status: 0 changes
Branch 5.1-dev:
  jbt_51 is running, ports: 80/tcp -> 0.0.0.0:7051; 80/tcp -> [::]:7051
  Version: Joomla! 5.1.3 Stable
  PHP 8.2.23
  MySQLi, jbt_madb, ''
  /branch_51: 386MB
Branch 5.2-dev:
  jbt_52 is running, ports: 80/tcp -> 0.0.0.0:7052; 80/tcp -> [::]:7052
  Version: Joomla! 5.2.0 Development
  PHP 8.3.11
  MySQL(PDO), jbt_mysql, ''
  /branch_52: 481MB
  Repository branch_52: https://github.com/joomla/joomla-cms,  Branch: 5.2-dev,  Status: 2 changes
Branch 5.3-dev:
  jbt_53 is NOT running
  /branch_53 is NOT existing
```

:blossom: If you see '42' (the answer to all questions) as one of the release numbers,
          it indicates that the system is offline and a default set of version numbers is being used.

Optional arguments that can be combined as desired are:
* `instance` to display Joomla Branches Tester instance information,
* `base` to display information about all base containers,
* version number to display information about this version number web server container.

For example, to check only instance and `4.4-dev` branch information:
```
scripts/info instance 44
```

### Check & Logging

Most scripts automatically duplicate their output to a log file in the `logs` folder.
The `scripts/check` command supports searching JBT log files for critical issues or specific information.
You can run `scripts/check` without any arguments to check the latest log file,
or specify a log file name to review a particular log.

Optional Arguments:
* `scripts`: Show only the start and end lines of scripts.
* `jbt`: Show only JBT-specific log messages.

If no argument is provided, the log file will be checked for errors and critical messages by default.

Example:
```
scripts/check jbt
```

### Cleaning Up

If you want to rid of all Docker containers and free up multiple gigabytes of disk space from the `branch_*` and other directories, simply run:

```
scripts/clean
```

## Database and File System Consistency

When installing extensions, it's important to be aware of database and file system consistency.
The following operations will break that consistency, as the Joomla database will be recreated:
* `scripts/database`
* `scripts/create` and `scripts/create recreate`
* `scripts/test system install/Installation.cy.js`

While grafting a Joomla package with `scripts/graft` doesn't break consistency,
you will lose all additionally installed extensions.

Switching between PHP versions using `scripts/php` or
enabling/disabling Xdebug with `scripts/xdebug` does not affect consistency.
Both the file system and the database remain unchanged.

If you've used `scripts/patchtester` to install the Joomla Patch Tester,
remember that it’s a Joomla extension.
To protect you, `scripts/database` (which is also used by `scripts/create`)
will clear the autoload classes cache file and remove all `com_patchtester`
directories to prevent issues during the next installation.
After that, you'll need to reinstall the Joomla Patch Tester using `scripts/patchtester`.

:fairy: *"To protect you, the first step `Installation.cy.js` of the Cypress based Joomla System Tests is excluded if you run all `system` test specs."*

## Trouble-Shooting

1. To fully grasp the process, it's helpful to both see the diagrams and read the explanations provided.
   For instance, if you create the Joomla Branches Tester only for branch 5.1-dev,
   you won’t be able to run tests on branch 5.2-dev.
   In this situation, it’s necessary to create a Joomla Branches Tester for all branches,
   ensuring you can work across all branches.
2. Simply try running it a second time. All scripts are designed to be run multiple times without issues.
3. One advantage of Docker and scripting: you can easily start fresh.
   As Roy from The IT Crowd says, *"Have you tried turning it off and on again?"*
   It takes just 2.5 minutes on a 2024 entry-level MacBook Air to delete everything and
   create 9 new containers with Joomla 5.2-dev, PHP 8.3, and PostgreSQL.
   ```
   scripts/create pgsql php8.3 52
   ```
4. Check the Docker container logs to monitor activity.
   For example, the `jbt_relay` container logs will display information about receiving and delivering emails.
   ```
   docker logs jbt_relay
   ```
   ```
   2024-08-22 10:09:34,082 - INFO - SMTP relay running on port 7025 and forwarding emails...
   2024-08-22 10:21:45,082 - INFO - ('192.168.65.1', 31625) >> b'MAIL FROM:<admin@example.com>'
   2024-08-22 10:21:45,083 - INFO - ('192.168.65.1', 31625) >> b'RCPT TO:<test@example.com>'
   2024-08-22 10:21:45,219 - INFO - Email forwarded to host.docker.internal:7125
   2024-08-22 10:21:45,345 - INFO - Email forwarded to host.docker.internal:7225
   2024-08-22 10:21:45,346 - ERROR - Failed to forward email to host.docker.internal:7325: [Errno 111] Connection refused
   ```
   An email is received by `jbt_relay:7025` and delivered to the Cypress container `smtp-tester` listening on
   `jbt_cypress:7125`, delivered to the mail catcher listening on `jbt_mail:7225`,
   and could not be delivered to the locally running Cypress GUI `smtp-tester` listening on `localhost:7325` (equivalent host names are used for clarity).
5. Run a script with the option `-x` to enable detailed debugging output that shows each command
   executed along with its arguments. You have to use the `.sh` variant, for example:
   ```
   bash -x scripts/pull.sh 53
   ```
6. If you encounter problems after running `scripts/create` multiple times,
   try using the `no-cache` option to force a fresh build of the containers.
7. Always use the latest version of Docker software. And I mean it – do it, I’m not joking here!
8. And always keep JBT up to date. You’ll get a reminder when you run `scripts/info`, and you should run `git pull` to stay current.
9. If you need to cancel a running script, send an interrupt by pressing **\<Ctrl\> + \<C\>** together.
   You may need to press the keys multiple times to fully stop the process.

   Automated Cypress System Test runs may persist even after the `scripts/test` process is terminated.
   If you attempt to run another Cypress System Tests,
   you might encounter the: `Error: listen EADDRINUSE: address already in use :::7125`.
   To stop the still-running Cypress System Tests, use the command: `docker restart jbt_cypress`.
10. Open an [issue](../../issues).

## Limitations

* The different Joomla versions exist in parallel, but the test runs sequentially.
* Database server versions cannot be changed.
* The setup does not support HTTPS, secure connections issues are not testable.
* If IPv6 networking is chosen, it is used only within Docker.
* The predefined port range run from 7000 to 7900. If another service is already using this range, it may cause a conflict.

## More Information

* Join the discussion on Mattermost: [joomla-branches-tester](https://joomlacommunity.cloud.mattermost.com/main/channels/joomla-branches-tester)
* Watch the presentation on the architecture and live demo (in German) from JoomlaDay DACH, September 2024: [Video Ticket](https://dach.joomladay.org/de/tickets)

## License

Distributed under the GNU General Public License version 2 or later, see [LICENSE](LICENSE)

If it is used, I would like to pass it on to the Joomla! project.

## Contact

Don't hesitate to ask if you have any questions or comments. If you encounter any problems or have suggestions for enhancements, please feel free to [open an issue](../../issues).
