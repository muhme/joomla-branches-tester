# JBT – Joomla Branches Tester

<img align="right" src="images/magic_world.png">
Imagine a little slice of a parallel universe where testing different Joomla versions becomes a fluffy,
cosy and almost magical experience.
In this universe, you can effortlessly test with the Patch Tester, glide through the Cypress GUI,
or even enjoy the smooth efficiency of Cypress Headless.
Picture the warmth of being able to peer into any database table as if through a magical glass,
or seamlessly switch between ten different database variants with just a small wave of a magic wand.
Wouldn't that create a truly fluffy and cosy environment to work in?
<br /><br />
Alright, alright, apologies to those who enjoyed the whimsical writing style, but now it's time to dive into the technical depths.
Let's transition from the cozy, magical universe into the world of technical documentation,
where we'll explore the numerous options, parameters and configurations that power this experience ...

<br />:point_right: See a live demo in the [JoomlaDay DACH, September 2024 presentation](https://www.youtube.com/watch?v=jGi0InmjScM) (German with optional English subtitles).

## Software Architecture
Within [Docker](https://www.docker.com/) container environment you are able to:
* Use more than 300 different Joomla versions, based on the Git development branches or Git tags (Joomla 3.9.0 ... 6.0-dev).
* Running one Joomla version or multiple Joomla versions in parallel.
* Manual testing, including database inspections and email verifications.
* Running [Joomla System Tests](https://github.com/joomla/joomla-cms//blob/HEAD/tests/System)
  with [Cypress](https://www.cypress.io/) in interactive mode (GUI) or automated mode (headless or with noVNC).
* Executing unit tests, verifying coding standards and checking CSS styles and JavaScript standards, just like Drone.
* Automated [Joomla Patch Tester](https://github.com/joomla-extensions/patchtester) installation.
* Apply pull requests (PR) from Git repositories `joomla-cms`, `joomla-cypress` and `joomla-framework/database`.
* Switching between 10 database variants (MySQL, MariaDB, or PostgreSQL and the two database drivers:
  MySQLi or PHP Data Objects and the option to use Unix sockets, instead of TCP host).
* Switching between PHP versions (PHP 7.4 ... 8.4).
* Installing Joomla from a cloned 'joomla-cms' Git repository.
* Grafting a Joomla package.
* Using Xdebug for PHP debugging.
* Using IPv6 network.
* Allows patching and testing of the `joomla-cypress` NPM module.

![Joomla Branches Software Architecture](images/joomla-branches-tester-52.svg)

The software architecture picture shows the simplest installation with only one Joomla 5.2 web server container plus the 9 base containers.
You'll notice the one orange Joomla 5.2 Web Server container,
based on the `joomla-52` folder, which is available inside and outside Docker.
On the right, you can see the three blue containers running the databases: MySQL, MariaDB and PostgreSQL.
To inspect the databases, two additional blue containers are included: phpMyAdmin (for MySQL and MariaDB) and pgAdmin (for PostgreSQL).
A green Docker container runs Cypress-based Joomla System Tests, either with a GUI or in headless mode.
The green noVNC container enables real-time viewing of automated Cypress System Tests.
If you need to investigate a failed test spec, you can easily switch to running Cypress with the interactive GUI.

The red mail relay container triplicates all emails sent during manual Joomla tests or System Tests.
The second red mail catcher container makes these emails accessible via a web application for easy review.

On the Docker Host system (left side), your red web browser is running.
On macOS and Ubuntu, the native Cypress GUI is displayed in green.

Everything is fully scripted and can be easily parameterised for maximum flexibility.
The `/scripts` folder serves as the source of JBT functionality.
Ensure that your current working directory is always the `joomla-branches-tester` directory.

:point_right: For the complete list of all scripts see [scripts/README.md](scripts/README.md).

:fairy: *"The scripts have a sprinkle of hacks and just a touch of magic to keep things fluffy.
        For those with a taste for the finer details, the comments are a gourmet treat."*

By default (without specifying a Joomla version number) `scripts/create` takes all **used** Joomla development branches.
**Used** Joomla development branches refer to the GitHub [joomla-cms](https://github.com/joomla/joomla-cms) repository, including default, active and stale branches.
At the beginning of May 2025, these are `4.4-dev`, `5.3-dev`, `5.4-dev` and `6.0-dev`.

:point_right: Since **used** branches are subject to frequent changes,
              the latest version numbers are always be retrieved directly from the `joomla-cms` repository.

For the web server containers, PHP-Apache Docker images (e.g., `php:8.4-apache`) are used as a starting point.
Within the container, the source code from the corresponding Joomla Git development branch or tag is copied and the Cypress-based Joomla installation from the System Tests is run.
Refer to the [Versions](#versions) section for a list of all usable Joomla versions.

### JBT Parallel Installation Environment

JBT has its own Cypress installation environment located in the `installation` folder.
This environment includes Cypress, the latest main branch version of `joomla-cypress` and three Cypress scripts:
* Install Joomla
* Disable Joomla B/C plugins
* Install and configure Joomla Patch Tester

The scripts capture Joomla web application JavaScript errors to prevent Cypress from stopping unexpectedly.
The JavaScript errors are displayed, logged and can be verified using `scripts/check`.

The installation environment retains each Joomla release's `installation` folder
to preserve it for future use, allowing restoration when needed, such as switching databases after grafting.

The `installation/joomla-cypress` folder is also used to test the `joomla-cypress` NPM module itself.
For more details, see the [Testing NPM Module joomla-cypress](#testing-npm-module-joomla-cypress) section.

### Version Naming

When using `scripts/create`, Joomla versions are either a Git branch (e.g. `5.4-dev`) or a Git tag (e.g. `5.1.4-rc3`).

You can always provide the full name (e.g. `5.4.0-alpha1`) or simplify with only the major and minor version numbers.
If a development branch exists for that version (e.g. `5.4-dev` for `54`), it will be used.
Otherwise, the highest available patch version matching the major and minor will be selected (e.g. `3.9.28` for `39`).

Once the Joomla instances are created, all other scripts refer to them using just the major and minor version (e.g.
`310` for `3.10.12`), as for each major and minor version number only one Joomla web server container exists. For
example, an instance created from the Git tag `3.10.12` will run as `jbt-310`, and you can continue to refer to it
simply as `310`.

<details>
  <summary>See the detailed list of Docker containers.</summary>

---

The abbreviation `jbt` stands for Joomla Branches Tester.

|Name|Docker IPs|Host Port:<br />Container Inside|Directory :eight_spoked_asterisk: |Comment|
|----|----------|--------------------------------|----------------------------------|-------|
|jbt-mya| 10.0.0.2<br />fd00::2 | **[7002](http://host.docker.internal:7002)** | | Web App to manage MariaDB and MySQL<br />auto-login configured, root / root |
|jbt-pga| 10.0.0.3<br />fd00::3 | **[7003](http://host.docker.internal:7003)** | | Web App to manage PostgreSQL<br />auto-login configured, root / root, postgres / prostgres |
|jbt-mail| 10.0.0.4<br />fd00::4 | **[7004](http://host.docker.internal:7004)** <br /> SMTP **7225**:1025 | | Web interface to verify emails. |
|jbt-novnc| 10.0.0.5<br />fd00::5 | **[7005](http://host.docker.internal:7005/vnc.html?autoconnect=true&resize=scale)** | | If you run automated Cypress System Tests with the `novnc` option, you can watch them. |
|jbt-relay| 10.0.0.6<br />fd00::6 | SMTP **7025**:7025 | | SMTP relay triplicator |
|jbt-cypress| 10.0.0.7<br />fd00::7 | SMTP :7125 | | Cypress Headless Test Environment<br />SMTP server is only running during test execution<br />PHP 8.4 is installed for `cli/joomla.php` Joomla Command Line Interface, executed from Joomla System Tests |
|jbt-mysql| 10.0.0.11<br />fd00::11 :eight_pointed_black_star: | **7011**:3306 | | Database Server MySQL version 8.1 |
|jbt-madb| 10.0.0.12<br />fd00::12 | **7012**:3306 | | Database Server MariaDB version 10.4 |
|jbt-pg| 10.0.0.13<br />fd00::13 | **7013**:5432 | | Database Server PostgreSQL version 12.20 |
|jbt-39| 10.0.0.39<br />fd00::39 | **[7039](http://host.docker.internal:7039/administrator)** | /joomla-39 | Web Server Joomla e.g. tag 3.9.28<br />user ci-admin / joomla-17082005 |
|jbt-310| 10.0.3.10<br />fd00::310 | **[7310](http://host.docker.internal:7310/administrator)** | /joomla-310 | Web Server Joomla e.g. tag 3.10.12<br />user ci-admin / joomla-17082005 |
| ... | | | | |
|jbt-54| 10.0.0.54<br />fd00::54 | **[7054](http://host.docker.internal:7054/administrator)** | /joomla-54 | Web Server Joomla e.g. 5.4-dev<br />user ci-admin / joomla-17082005 |
|jbt-60| 10.0.0.60<br />fd00::60 | **[7060](http://host.docker.internal:7060/administrator)** | /joomla-60 | Web Server Joomla e.g. 6.0-dev<br />user ci-admin / joomla-17082005 |

:eight_spoked_asterisk: The directories are available on the Docker host inside `/jbt` to:
* Inspect and change the configuration files (`configuration.php` or `cypress.config.mjs`),
* To edit the test specs below `tests/System` or
* To inspect screenshots from failed tests or
* To inspect and hack the Joomla sources from Docker host system.

:eight_pointed_black_star: Gnome: *"Yes, yes, I know that `11` in decimal is `B` in hex, but can you instantly recall that `44` is `2C`? That's why, for easier visual recognition, we're sticking with `11` — it just needs to be unique!"*

:point_right: Using `host.docker.internal` ensures consistent hostnames and URLs between containers and the Docker host machine.
              However, there are exclusions to note:

1. **Database Performance**: For database connections, the Docker container name and the default
    database port are used to avoid performance issues.
2. **Running Cypress GUI on the Docker host**: `localhost` and the mapped database port are used instead,
    as Docker container hostnames aren't accessible outside Docker,
    and no performance issues have been observed in this configuration.

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

For setting up and configuring an Ubuntu Linux environment with required Git, Docker and firewall configuration,
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

Last tested in early November 2024 with:
* Intel chip macOS 15 Sequoia,
* Apple silicon macOS 15 Sequoia,
* Windows 11 Pro WSL 2 Ubuntu and
* Ubuntu 24 Noble Numbat (the absolute minimum, if you also wish to use the Cypress GUI, is a VPS with 2 shared vCPUs and 4 GB RAM).

You can create all base Docker containers and the current (early May 2025)
four Joomla dev-branch containers using `scripts/create` without any arguments:

```
git clone https://github.com/muhme/joomla-branches-tester
cd joomla-branches-tester
scripts/create
```
:point_right: The script can run without `sudo`,
but depending on the platform, it may ask you to enter your user password for individual sudo actions.

The initial `scripts/create` runs some time,
especially the very first time when the Docker images still need to be downloaded.
For this installation with five Joomla web server containers the
`joomla-branches-tester` folder requires about 2 GB of disc space.
Docker needs additionally about 20 GB for images and volumes.
If you are installing for the first time and downloading all necessary Docker images,
you will need to download approximately 4 GB of data over the network.

<details>
  <summary>Optional <code>scripts/create</code> Parameters</summary>

---

<img align="right" src="images/joomla-branches-tester.svg" width="400">

*  Install can use multiple Joomla versions, e.g. two tags and two dev-branches `3.9.28 3.10.12 52 60`
   (your system architecture will look like the picture on the right), defaults to all dev-branches.
*  The used database and database driver, e.g. `pgsql`, defaults to use MariaDB with MySQLi driver.
*  The used PHP version. For available PHP versions see [Versions](#versions) section. Defaults to `highest`.
   See more details in [Switch PHP Version](#switch-php-version).
*  Instead using `joomla-cms` repository, you can specify a different Git repository and branch.
   For example, using `https://github.com/Elfangor93/joomla-cms:mod_community_info`.
   In this case, exactly one version must be provided,
   and it should match the version of the given `joomla-cms` cloned repository.
*  The Docker `jbt-network`, used by all containers, defaults to IPv4.
   To use IPv6, run the script with the `IPv6` option.
*  The optional `recreate` option is used to create or recreate one Joomla web server container
   for the specified version. Base containers and unnamed Joomla web server containers remain unchanged.
*  To force a fresh build with `no-cache`, defaults to build from cache.

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

:point_right: To run the interactive Cypress GUI from the Docker container `jbt-cypress`,
  Windows 11 (with included Windows Subsystem for Linux GUI – WSLg) is required.

---

</details>

<details>
  <summary>macOS Setup</summary>

---

To install the required Docker and Git, one possible approach is to follow these four steps:

1. [Install Docker Desktop on Mac](https://docs.docker.com/desktop/install/mac-install/) for either Apple silicon or Intel chip and then run it.
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

Once Docker and Git are installed, open a terminal window, clone the repository and create
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
for each instance the first time you open it:
```
scripts/cypress 53 local
```

---

</details>

<details>
  <summary>Ubuntu Setup</summary>

---

Installing the Joomla Branches Tester on Ubuntu with a user that is able to run `sudo`.

1. To setup Git, Docker and firewall configuration download the [ubuntu_setup.sh](scripts/ubuntu_setup.sh) script as a raw file, run in terminal window with superuser privileges and reboot the system:
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
- The `installation` folder remains intact after the installation.
  - Earlier Joomla versions delete the `installation` folder after setup.
    If the folder is missing, it is restored from JBT installation environment backup-copy.
  - Starting with Joomla version 5.0, a `DEV_STATUS = ‘Stable’` is changed to `DEV_STATUS = ‘JBT’`
    to avoid being forced to delete the `installation` folder.
- Error Reporting is set to `Maximum` in `Global Configuration | Server`.
- A cron job is configured to run the Joomla Task Scheduler every minute.
- The 'System - Joomla! Statistics' plugin is disabled to prevent prompting users on the backend Home Dashboard.
- All the 'Behaviour - Backward Compatibility' plugins are disabled to detect backward compatibility issues
  (see [installation/disableBC.cy.js](installation/disableBC.cy.js)).
- The automatic run of the 'Welcome to Joomla!' guided tour is canceled from Joomla version 5.1 onwards.
- Not configured for logging, due to deprecation warnings.
- Using 'filesystem' for session handler to prevent logging in again after a few minutes,
  for whatever reason this differs from 'database'.

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

If you need to inspect files, they are available in the directory `joomla-52` for this Joomla release 5.2 sample.

### Drone-like Tests

A subset of seven tests from the full Joomla [Drone](https://www.drone.io/) CI test suite has been implemented:

* `php-cs-fixer` – PHP Coding Standards Fixer (dry-run)
* `phpcs` – PHP Coding Sniffer
* `unit` - PHP Testsuite Unit
* `lint:css` - CSS Linter
* `lint:js` - JS Linter
* `lint:testjs` – JS Linter for Tests
* `system` – System Tests

Running all seven tests on all instances is simple with the following command:
```
scripts/test
```

Some optional arguments are:

* Joomla version number(s): Choose one or multiple versions; all versions are tested by default.
* Test name(s): Choose one or multiple tests; all tests are executed by default.

For example run the linter tests on three Joomla instances:
```
scripts/test 51 52 53 lint:css lint:js lint:testjs
```

To avoid issues with running `php-cs-fixer`, the auto-generated file `administrator/cache/autoload_psr4.php` is corrected beforehand.
And the configurations for `php-cs-fixer` and `phpcs` has been extended to exclude the `com_patchtester` component.

:point_right: The PHP Unit Test Suite integration and the Phan static analyzer for PHP have not been implemented.
              Additionally, the tests are not configured to run on multiple PHP versions, as Drone typically does in the Joomla CI environment.

### Cypress Automated System Tests

To simply run the Joomla System Tests with all specs - except for the installation step -
from the [Joomla System Tests](https://github.com/joomla/joomla-cms//blob/HEAD/tests/System) in all Joomla instances with headless Cypress:
```
scripts/test system
```

:warning: Currently (May 2025) the Joomla System Tests do not work independently.
          A Joomla installation is required before running the test suite again.
          Be aware the entire database content of the Joomla instance will be lost.
          See [Database and File System Consistency](#database-and-file-system-consistency) for more details.
```
scripts/test system install/Installation.cy.js
```

Some more optional arguments for System Tests are:

* Browser to be used: Choose between electron (default), firefox, chrome, or edge.
* Test spec pattern: All test specs (except the installation) are used by default.

As an example, run all the test specs (except the installation) on 5.1 instance with Mozilla Firefox:
```
scripts/test 51 system firefox
```

Run one test spec with default Electron in all Joomla instances (of course, Cypress System Tests and the spec must exist):
```
scripts/test system administrator/components/com_users/Users.cy.js
```

:point_right: When specifying a single test spec file,
              you can omit the `tests/System/integration/` path at the beginning.

Test all `site` specs with Microsoft Edge in the Joomla instances 5.1, 5.2 and 5.3 using a pattern:
```
scripts/test 51 52 53 system edge 'tests/System/integration/site/**/*.cy.{js,jsx,ts,tsx}'
```

One more optional argument is `novnc`.
The `jbt-vnc` container allows to view the automated browser tests via the web-based VNC viewer [noVNC](https://github.com/novnc/noVNC).
This is useful for watching the automated Cypress System Tests in real-time, for example,
when the gnome is too impatient to wait for the 120-second timeout from `installJoomla` again.
In this case Cypress runs headed and uses `jbt-vnc` as DISPLAY and you can watch the
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

If a test spec fails, the screenshot is helpful. More enlightening is to execute the single failed test spec
with the Cypress GUI in interactive mode. You can see all the Cypress log messages, use the time-traveling debugger and
observe how the browser runs in parallel.

Cypress GUI can be started from Docker container `jbt-cypress` with X11 forwarding
(recommended for Windows 11 WSL 2 Ubuntu):
```
scripts/cypress 51
```

Or from locally installed Cypress (recommended for macOS and native Ubuntu) with additional argument `local`:
```
scripts/cypress 51 local
```

The script will automatically install the appropriate Cypress version locally
for each Joomla instance if it doesn't already exist.
Using the Cypress container has the advantage of having Chrome, Edge, Electron and Chromium browsers pre-installed.
If you run Cypress locally, only the browsers installed on your Docker host system will be available.

### Check Email

To check the emails sent by Joomla,
the [MailDev](https://hub.docker.com/r/maildev/maildev) container
provides you with a web interface at [http://host.docker.internal:7004](http://host.docker.internal:7004).
The Cypress based Joomla System Tests is using an own SMTP server `smtp-tester` to receive, check and delete emails.
Since we run Cypress locally or in a container,
it is necessary to triple the emails for the three potential recipients.
This is done by the SMTP relay triplicator `jbt-relay`.

:fairy: *"Oh, dear Gnome, now I can really read all the emails from the System Tests, thank you."*

<details>
  <summary>:imp: <i>"Postal dispatch nonsense picture? Don't open it, you'll get a triple headache!"</i> </summary>

---

:fairy: *"Shut up and listen. The email traffic is explained using a Joomla 5.1 instance with
        the use cases of password reset and System Tests."*

![Joomla Branches Tester – Email Traffic](images/email.svg)

1. A user (not in the Super User group) requests a password reset by clicking 'Forgot your Password?' in their web browser.
   This request is sent to the Joomla PHP code on the web server `jbt-51`.
2. An email is sent via SMTP from the web server `jbt-51` to the email relay `jbt-relay`.
   In the Joomla `configuration.php` file, the `smtpport` is configured as `7025`.
3. The email relay `jbt-relay` triplicates the email and sends the first email via SMTP to the email catcher `jbt-mail`.
4. The email relay `jbt-relay` tries to deliver the second email to `smtp-tester`.
   But no System Tests is running, the email cannot be delivered and is thrown away.
5. The email relay `jbt-relay` tries to deliver the third email to locally running Cypress GUI with `smtp-tester`.
   But no Cypress GUI is running, the email cannot be delivered and is thrown away.
6. System Test is started with `scripts/test` in the Cypress container `jbt-cypress`.
   In the Cypress `cypress.config.mjs` file, the `smtp_port` is configured as `7125`.
   While the System Tests is running `smtp-tester` is listening on port 7125.
7. One of the System Tests specs executes an action in Joomla PHP code that generates an email.
8. Again the email is sent via SMTP from the web server `jbt-51` to the email relay `jbt-relay`.
9. Again the email relay `jbt-relay` triplicates the email and
   sends the one email via SMTP to the `jbt-cypress` container with `smtp-tester` running in .
   The Cypress test can check and validate the email.
10. Again the email relay `jbt-relay` sents one copy via SMTP to the email catcher `jbt-mail`.
11. Again the email relay `jbt-relay` tries to deliver the third email to locally running Cypress GUI with
    `smtp-tester`. But no Cypress GUI is running, the email cannot be delivered and is thrown away.

Therefore, the `cypress.config.mjs` file uses a different SMTP port (7125) than the `configuration.php` file (7025).
Additionally, the `cypress.config.local.mjs` file is used with yet another SMTP port (7325)
for running the Cypress GUI locally.

---

</details>

### Databases

The Joomla Branches Tester includes one container for each of the three supported databases (version numbers as of the beginning of May 2025):
* `jbt-mysql` – MySQL version 8.1.0 Community Server
* `jbt-madb` – MariaDB version 10.4.34
* `jbt-pg` – PostgreSQL version 15.8

You can set the desired database and database driver using `scripts/create` or switch them later with `scripts/database`.

#### Switch Database and Database Driver

You can simply switch between one of the three supported databases (MariaDB, PostgreSQL or MySQL) and
the database driver used (MySQL improved or PHP Data Objects).
Firstly, the settings for the database server with `db_host` and the database driver with `db_type`
are adjusted in the configuration file `Cypress.config.cy.mjs`.
Secondly, a Joomla installation is performed with the Joomla System Tests.

Five database and driver combinations are available:
* mariadbi – MariaDB with MySQLi (improved)
* mariadb – MariaDB with MySQL PDO (PHP Data Objects)
* pgsql - PostgreSQL PDO (PHP Data Objects)
* mysqli – MySQL with MySQLi (improved)
* mysql – MySQL with MySQL PDO (PHP Data Objects)

:warning: The entire database content of the Joomla instance will be lost.
          See [Database and File System Consistency](#database-and-file-system-consistency) for more details.
          
:fairy: The good fairy waves her magic wand and says:
  *"When in doubt, it's wiser to use `scripts/create` to ensure a clean installation.
  With a sprinkle of stardust, you can specify the desired database variant,
  and with `recreate` option you're only installing one Joomla version, it will be done in the blink of an eye."*
          
Use MariaDB with driver MySQLi for Joomla 5.1 and Joomla 5.2:
```
scripts/database 51 52 mariadbi
```

Change all Joomla instances to use PostgreSQL:
```
scripts/database pgsql
```

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
docker exec -it jbt-pg bash -c "psql -h /var/run/postgresql -U root -d test_joomla_44"
docker exec -it jbt-madb bash -c "mariadb --socket=/var/run/mysqld/mysqld.sock -u root -proot"
docker exec -it jbt-mysql bash -c "mysql --socket=/var/run/mysqld/mysqld.sock -u root -proot"
```

### Switch PHP Version

You can choose the PHP version from 7.4 to 8.4 and you should choose a PHP version supported by your Joomla version.
You can use `highest` PHP version available for a Joomla version. For example PHP 8.4 for Joomla 5.3.
To check which PHP versions are available use `help` argument:
```
scripts/php help
```

You can switch the PHP version for all installed Joomla instances:
```
scripts/php highest
```
Or specify the desired Joomla instances:
```
scripts/php 54 60 php8.4
```

### Grafting a Joomla Package

Do you have a prebuilt Joomla package to test? No problem!
Just like in plant grafting, where a scion is joined to a rootstock,
you can graft a Joomla package onto the Joomla instance for testing.
Simply choose the same major and minor version numbers
and graft the full package for a seamless experience:

```
scripts/graft 60 Joomla_6.0.0-alpha2-dev+pr.43793-Development-Full_Package.tar.zst
```

:warning: The content of the file system of the Joomla instance is overwritten.
          See [Database and File System Consistency](#database-and-file-system-consistency) for more details.

Mandatory arguments are the Joomla instance version and the local package file.
Supported file formats are .zip, .tar, .tar.zst, .tar.gz and .tar.bz2.
An optional argument is the database variant, such as PostgreSQL in the following example:
```
scripts/graft 51 pgsql ~/Downloads/Joomla_5.1.3-Stable-Full_Package.zip
```

After grafting, you can still switch the database variant, change the PHP version,
install the Joomla Patch Tester, or run Joomla System Tests.
There is no Git repository, so you cannot run the other tests and `scripts/pull` will be skipped.
Grafting can also be done multiple times. :smile:

What distinguishes a JBT grafted Joomla from a standard package-installed Joomla?
A JBT grafted Joomla contains additional files and two directories from the development branch:
* Files: `cypress.config.*` and `package*.json`
* Directories: `node_modules` and `tests/System`

### Syncing from GitHub Repository

To avoid recreating Joomla dev-branch instances the next day, you can simply fetch and merge the latest changes from the
Joomla GitHub repository into your local dev-branch based instances.
This can be done for all installed Joomla instances without any arguments or for specific versions:
```
scripts/pull 53 60
```

If changes are pulled then:
* Just in case the command `composer install` is executed.
* If `package-lock.json` file has changed the command `npm ci` is executed.

Finally, the Git status is displayed.

👉 This works only for dev-branch based Joomla instances.
   If the instance was installed from a tag or is a grafted one, then `scripts/pull` skips over the instance.

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

Simply approach these gateways and the secrets of the database will reveal themselves effortlessly,
ready for your exploration.

### Xdebug

<img align="right" src="images/Xdebug.png">

Joomla web server containers are ready with a second PHP installation for switching to
[Xdebug](https://github.com/xdebug/xdebug).
You can switch to the PHP version with Xdebug for example:
```
scripts/xdebug 53 on
```

A `.vscode/launch.json` file is also prepared for all enabled instances.
In [Visual Studio Code](https://code.visualstudio.com/),
select 'Start Debugging' and choose the corresponding entry `Listen jbt-53`.

Finally, it may be reset again to improve performance:
```
scripts/xdebug off
```

Enabling Xdebug requires at least PHP 8.0. Used ports are 79xx, for the given example 7953 and for Joomla version 3.10 using port 7910.

### IPv6

As shown in the [Installation](#installation) chapter,
you can create the Docker Branches Tester instance using `scripts/create`
with the `IPv6` option instead of the default IPv4 network.
IP addresses are fixed from the predefined private, non-routable subnet `fd00::/8`.

You can use the IPv6 address (instead of the hostname) to open the PostgreSQL interactive terminal:
```
docker exec -it jbt-pg bash -c "PGPASSWORD=root psql -h fd00::13 -U root -d postgres"
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
can be installed on the Joomla instances from version 4.2 onwards.
The script also sets the GitHub token and fetches the data.
This can be done without version number for all Joomla instances or for e.g. Joomla 5.3:

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

:fairy: *"You will need to reinstall the Joomla Patch Tester if, for example, you switch the database.
        For more details, see [Database and File System Consistency](#database-and-file-system-consistency)."*

:point_right: Alternatively, to apply patches, you can use `scripts/patch`, see [Back to the Future - Patch](#back-to-the-future---patch).

### Back to the Future - Patch

As Doc Brown said: *"Roads? Where we're going, we don't need roads."*

JBT can install patches using Git merge from pull requests (PRs) with `scripts/patch` (or even with `scripts/create`),
applicable to the following repositories:
* joomla-cms - [joomla/joomla-cms](https://github.com/joomla/joomla-cms)
* joomla-cypress - [joomla-projects/joomla-cypress](https://github.com/joomla-projects/joomla-cypress)
* database - [joomla-framework/database](https://github.com/joomla-framework/database)

This can be done for all installed Joomla instances without any arguments, or for specific versions:
```
# Apply non-standard database port for Joomla 4.4 and 5.2 instances
scripts/patch 44 52 joomla-cypress-33 joomla-cms-43968

# Allow to specify port number or UNIX socket in Joomla 5.3 instance
scripts/patch 53 database-310
```

:warning: Be cautious when applying patches, as we perform a full merge, which could introduce additional changes beyond the original pull request.
          Always pay attention to the number of changed lines. If you encounter merge conflicts, you will need to resolve them or recreate the instance.

While there's no way to remove a patch, you can use the `scripts/create recreate` to *go back in time* and restore the instance to the original state.

:point_right: Alternatively, to apply `joomla-cms` patches, you can use [Joomla Patch Tester](#install-joomla-patch-tester).

:point_right: All these patches are for the web server Docker containers running the Joomla instances.
              JBT uses its own Cypress installation environment with the latest `joomla-cypress` main branch clone.

### Testing NPM module joomla-cypress

The NPM module [joomla-cypress](https://github.com/joomla-projects/joomla-cypress)
has its own Cypress-based test suite. For more information
see [joomla-cypress/tests](https://github.com/joomla-projects/joomla-cypress/tree/main/tests).

The JBT `installation/joomla-cypress` directory contains the latest version of the `main` branch
for Cypress-based Joomla-installation. And this can also be used to test the NPM module itself.

👉 There are different installations of `installation/joomla-cypress` used for JBT installation and
  testing the module itself, and `node_modules/joomla-cypress`,
  which is installed in each Joomla instance for Joomla System Tests.

Patching `installation/joomla-cypress`:
```
scripts/patch installation joomla-cypress-37
```

Running `joomla-cypress` Cypress tests headlessly with Joomla version 5.2:
```
scripts/test 52 joomla-cypress
```

:warning: Using the `cypress/joomla.cy.js` test spec results in Joomla being installed multiple times and
          the entire database content of the Joomla instance will be lost.
          See [Database and File System Consistency](#database-and-file-system-consistency) for more details.

Running `joomla-cypress` Cypress tests without `installLanguage` and `installJoomlaMultiLanguage`
on Joomla version 6.0 (if language packages are not yet available and tests would fail with error
`Unable to detect manifest file.`):
```
CYPRESS_SKIP_INSTALL_LANGUAGES=1 scripts/test 60 joomla-cypress
```

Running only the `user.cy.js` test spec file and watching the progress with NoVNC:
```
scripts/test 52 joomla-cypress tests/e2e/user.cy.js novnc
```

Running the tests with local Cypress GUI:
```
scripts/cypress 60 joomla-cypress local
```

JBT automatically restores the `installation` folder if it is missing and
runs `npm ci` if you use either `scripts/test` or `scripts/cypress`.

The environment variable `CYPRESS_SERVER_UPLOAD_FOLDER`, required for the `installExtensionFromFolder` test,
is set for you.

👉 Restoring the `installation` folder only works once per test run.
  You cannot open the GUI and run `joomla.cy.js` test spec twice.

👉 JBT's Joomla installation (using `scripts/create` or `scripts/database`) disables
  all the 'Behaviour - Backward Compatibility' plugins; see [installation/disableBC.cy.js](installation/disableBC.cy.js)).
  However, when running `joomla-cypress` tests, Joomla is reinstalled and the B/C plugins are not disabled.
  To have the B/C plugins disabled again, you will need to recreate the Joomla instance.

### Versions

Running `scripts/versions` will display all available branches and tags with Joomla versions.
These can be used as arguments for the `scripts/create` command:
```
scripts/versions
```
```
5 Usable Branches from the 'joomla-cms' Repository
    4.4-dev       5.1-dev       5.2-dev       5.3-dev       6.0-dev

292 Usable Tags from the 'joomla-cms' Repository
    3.9.0         3.9.0-alpha   3.9.0-beta    3.9.0-beta2   3.9.0-beta3   3.9.0-beta4   3.9.0-rc      3.9.0-rc2
    ...
    5.2.0         5.2.0-alpha1  5.2.0-alpha2  5.2.0-alpha3  5.2.0-beta1   5.2.0-beta2   5.2.0-beta3   5.2.0-rc1
    5.2.0-rc2     5.2.0-rc3     5.2.0-rc4     5.2.1
```

**Usable** Joomla development branches refer to the GitHub [joomla-cms](https://github.com/joomla/joomla-cms) repository, including default, active and stale branches in the format `number.number-dev`. See [joomla-cms/branches](https://github.com/joomla/joomla-cms/branches) for details.

### Info

You can retrieve some interesting Joomla Branches Tester status information.
If no argument is provided, all information will be displayed:
```
scripts/info
```
The following example illustrates an IPv4 installation with three Joomla instances:
* `jbt-310` – Cloned from Joomla 3.10.12 tag, based on PHP 8.0, using MySQL with PDO driver
* `jbt-44` – Grafted 4.4.13 Full Joomla package, running PHP 8.2 with xdebug, using MariaDB with MySQLi driver
* `jbt-54` – Cloned from 5.4-dev branch with additional patches applied, running PHP 8.4 and using PostgreSQL socket
```
Joomla Branches Tester (JBT) version 2.2.1
  Docker version 27.4.0 is running with 18 containers and 52 images
  EnableIPv6: false
Base Containers
  jbt-mysql   is running, ports: 3306/tcp -> 0.0.0.0:7011
  jbt-madb    is running, ports: 3306/tcp -> 0.0.0.0:7012
  jbt-pg      is running, ports: 5432/tcp -> 0.0.0.0:7013
  jbt-mya     is running, ports: 80/tcp -> 0.0.0.0:7002
  jbt-pga     is running, ports: 80/tcp -> 0.0.0.0:7003
  jbt-mail    is running, ports: 1025/tcp -> 0.0.0.0:7225; 1080/tcp -> 0.0.0.0:7004
  jbt-novnc   is running, ports: 8080/tcp -> 0.0.0.0:7005
  jbt-relay   is running, ports: 7025/tcp -> 0.0.0.0:7025
  jbt-cypress is running, ports: 7125/tcp -> 0.0.0.0:7125
jbt-310 Tag 3.10.12
  Container jbt-310 is running, ports: 80/tcp -> 0.0.0.0:7310
  Joomla Version: Joomla! 3.10.12 Stable
  PHP 8.0.30
  Database: Type 'pdomysql', Host 'jbt-mysql', Name 'test_joomla_310'
  /joomla-310: 87MB
  Git Repository joomla-310/
    Remote Origin: https://github.com/joomla/joomla-cms
    Tag: 3.10.12
    Status: 277 changes
jbt-44 ¿Grafted?
  Container jbt-44 is running, ports: 80/tcp -> 0.0.0.0:7044
  Joomla Version: Joomla! 4.4.13 Stable
  PHP 8.2.28
  Database: Type 'mysqli', Host 'jbt-madb', Name 'test_joomla_44'
  /joomla-44: 372MB
jbt-54 Tag 5.3.0-83-g2da7e19c0a
  Container jbt-54 is running, ports: 80/tcp -> 0.0.0.0:7054
  Joomla Version: Joomla! 5.4.0 Development
  PHP 8.4.7 with Xdebug
  Database: Type 'pgsql', Host 'unix:/var/run/postgresql-socket', Name 'test_joomla_54'
  /joomla-54: 872MB
  Git Repository joomla-54/
    Remote Origin: https://github.com/joomla/joomla-cms
    Branch: jbt-merged joomla-cms-44910
    Status: 0 changes
JBT Instance History
*** 250516 10:03:04 >>> 'scripts/create.sh 3.10.12 44 54 no-cache' started
*** 250516 10:14:42 <<< 'scripts/create.sh' finished in 11:38
 
*** 250516 10:20:30 >>> 'scripts/database.sh 310 mysql' started
*** 250516 10:20:44 <<< 'scripts/database.sh' finished in 14 seconds
 
*** 250516 10:44:42 >>> 'scripts/graft.sh 44 /Users/hlu/Downloads/Joomla_4.4.13-Stable-Full_Package.tar.gz' started
*** 250516 10:45:43 <<< 'scripts/graft.sh' finished in 1:01
 
*** 250516 10:47:27 >>> 'scripts/patch.sh 54 joomla-cms-44910' started
*** 250516 10:48:00 <<< 'scripts/patch.sh' finished in 33 seconds
 
*** 250516 10:48:11 >>> 'scripts/database.sh 54 pgsql socket' started
*** 250516 10:48:46 <<< 'scripts/database.sh' finished in 35 seconds
 
*** 250516 10:48:54 >>> 'scripts/xdebug.sh 54 on' started
*** 250516 10:48:55 <<< 'scripts/xdebug.sh' finished in 1 second
```

Optional arguments that can be combined as desired are:
* `instance` to display Joomla Branches Tester instance information only,
* `base` to display information about all base containers only,
* `history` to display JBT activites only,
* version number to display information about this version number web server container only.

For example, to check only JBT instance and `jbt-44` container information:
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

Example to see last file JBT log messages only:
```
scripts/check jbt
```

Sometimes everything appears to be working fine, but errors may still occur.
For example, Joomla JavaScript exceptions might be caught during installation.
As there are numerous log messages, you might overlook them.
However, you can run `scripts/check` after running `scripts/create`,
`scripts/database`, `scripts/patchtester` or `scripts/graft` and you will see the error.
You can then investigate the JavaScript exception in the log file. For example:

```
[6927:1114/174511.623420:INFO:CONSOLE(1230)] "ERROR uncaught:exception err :TypeError: The following error originated from your application code, not from Cypress.
  > Cannot read properties of null (reading 'getAttribute')
```

### Cleaning Up

If you want to be rid of all Docker containers and free up multiple gigabytes of disk space from the `joomla-*` and other directories, simply run:

```
scripts/clean
```

## Database and File System Consistency

The entire database content of the Joomla instance will be lost during the Joomla installation,
including any customisations or extensions installed.
For example, if you have installed the Joomla Patch Tester or made specific configuration changes,
these will need to be reinstalled or reapplied afterwards.

The following operations will break database and file system consistency,
as the Joomla database will be recreated:
* `scripts/database`
* `scripts/create` and `scripts/create recreate`
* `scripts/test` running `Installation.cy.js` from Joomla System tests or `joomla-cypress`
* `scripts/cypress` running `Installation.cy.js` from Joomla System tests or `joomla-cypress`

Grafting a Joomla package with `scripts/graft` will break database consistency with the file system.
You will lose all additionally installed extensions, as the files will be overwritten by those from the package.
This means that, in this case, consistency is broken from the file system.

Switching between PHP versions using `scripts/php` or
enabling/disabling Xdebug with `scripts/xdebug` does not affect consistency.
The Joomla files and the database remain unchanged.

If you've used `scripts/patchtester` to install the Joomla Patch Tester,
remember that it’s a Joomla extension.
To protect you, `scripts/database` (which is also used by `scripts/create`)
will clear the autoload classes cache file and remove all `com_patchtester`
directories to prevent issues during the next installation.
After that, you'll need to reinstall the Joomla Patch Tester using `scripts/patchtester`.

:fairy: *"The first step `Installation.cy.js` of the Cypress based Joomla System Tests is excluded if you run all `system` test specs.
          But currently (May 2025) the Joomla System Tests do not work independently.
          A Joomla installation step is required before running the Joomla System Tests again."*

## Trouble-Shooting

1. To fully grasp the process, it's helpful to both see the diagrams and read the explanations provided.
2. Simply try running it a second time. All scripts are designed to be run multiple times without issues.<br />
   On `scripts/create`, if you see the log message `Base installation is completed`, you can use the `recreate` option if one Joomla instance fails during installation.
3. One advantage of Docker and scripting: you can easily start fresh.
   As Roy from The IT Crowd says, *"Have you tried turning it off and on again?"*
   It takes just 6 minutes on a entry-level MacBook Air M3 to delete everything and
   create the 10 containers with Joomla 5.4-dev branch in using Docker Compose `no-cache` to be save.
   ```
   scripts/create 54 no-cache
   ```
4. Check the Docker container logs to monitor activity.
   For example, the `jbt-relay` container logs will display information about receiving and delivering emails.
   ```
   docker logs jbt-relay
   ```
   ```
   2024-08-22 10:09:34,082 - INFO - SMTP relay running on port 7025 and forwarding emails...
   2024-08-22 10:21:45,082 - INFO - ('192.168.65.1', 31625) >> b'MAIL FROM:<admin@example.com>'
   2024-08-22 10:21:45,083 - INFO - ('192.168.65.1', 31625) >> b'RCPT TO:<test@example.com>'
   2024-08-22 10:21:45,219 - INFO - Email forwarded to host.docker.internal:7125
   2024-08-22 10:21:45,345 - INFO - Email forwarded to host.docker.internal:7225
   2024-08-22 10:21:45,346 - ERROR - Failed to forward email to host.docker.internal:7325: [Errno 111] Connection refused
   ```
   An email is received by `jbt-relay:7025` and delivered to the Cypress container `smtp-tester` listening on
   `jbt-cypress:7125`, delivered to the mail catcher listening on `jbt-mail:7225`,
   and could not be delivered to the locally running Cypress GUI `smtp-tester` listening on `localhost:7325` (equivalent host names are used for clarity).
5. Run a script with the option `-x` to enable detailed debugging output that shows each command
   executed along with its arguments. You have to use the `.sh` variant, for example:
   ```
   bash -x scripts/pull.sh 53
   ```
6. It is generally recommended to use the latest patch level of a Joomla version and the highest compatible PHP version possible.
7. Always use the latest version of Docker software. And I mean it – do it, I’m not joking here!
8. And always keep JBT up to date. You’ll get a reminder when you run `scripts/info`, and you should run `git pull` to stay current.
9. If you need to cancel a running script, send an interrupt by pressing **\<Ctrl\> + \<C\>** together.
   You may need to press the keys multiple times to fully stop the process.

   Automated Cypress System Test runs may persist even after the `scripts/test` process is terminated.
   If you attempt to run another Cypress System Tests,
   you might encounter the: `Error: listen EADDRINUSE: address already in use :::7125`.
   To stop the still-running Cypress System Tests, use the command: `docker restart jbt-cypress`.
10. Open an [issue](../../issues).

## Limitations

* The different Joomla versions exist in parallel, but the test runs sequentially, as there is the one Cypress container used.
* Database server versions cannot be changed.
* The setup does not support HTTPS, secure connections issues are not testable. → [#7](https://github.com/muhme/joomla-branches-tester/issues/7)
* If IPv6 networking is chosen, it is used only within Docker.
* The predefined port range run from 7000 to 7960. If another service is already using this range, it may cause a conflict. → [#3](https://github.com/muhme/joomla-branches-tester/issues/3)
* Usable Joomla Git tags start with `3.9.0` (for earlier versions `apt-get update` does not work so easily).
* For each Joomla major and minor version (e.g., 5.2, 5.3), only one Docker container is possible.
  This means you can run containers for versions such as 52 (for Joomla 5.2.) and 53 (for Joomla 5.3.),
  but you cannot have multiple containers for different patch versions like 5.2.0 and 5.2.1 running in parallel.
* Tests `phan` and `integration`are not implemented yet. → [#4](https://github.com/muhme/joomla-branches-tester/issues/4)

## More Information

* **Join the Discussion**: Connect with the community on Mattermost in the [joomla-branches-tester](https://joomlacommunity.cloud.mattermost.com/main/channels/joomla-branches-tester) channel.
* **Watch the presentation**: Learn about the architecture and see a live demo in the [JoomlaDay DACH, September 2024 presentation](https://www.joomla.de/wissen/joomla-event-videos/joomla-day-deutschland/jd24dach-joomla-branches-tester) (German with optional English subtitles on YouTube).

## License

Distributed under the GNU General Public License version 2 or later, see [LICENSE](LICENSE)

If it is used, I would like to pass it on to the Joomla! project.

## Contact

Don't hesitate to ask if you have any questions or comments. If you encounter any problems or have suggestions for enhancements, please feel free to [open an issue](../../issues).

"A day without a smile is a wasted day." :smile:<br />
Charlie Chaplin
