⚠️ Under construction ⚠️ 

# Docker based Joomla Branches Tester

<img align="right" src="images/magic_world.png">
Imagine a little slice of a parallel universe where testing all used Joomla branches becomes a fluffy, cosy, and almost magical experience. In this universe, you can effortlessly test with the Patch Tester, glide through the Cypress GUI, or even enjoy the smooth efficiency of Cypress Headless. Picture the warmth of being able to peer into any database table as if through a magical glass, or seamlessly switch between five different database variants with just a small wave of a magic wand. Wouldn't that create a truly fluffy and cosy environment to work in?
<br /><br />
Alright, alright, apologies to those who enjoyed the whimsical writing style, but now it's time to dive into the technical depths. Let's transition from the cozy, magical universe into the world of technical documentation, where we'll explore the numerous options, parameters, and configurations that power this experience ...

## Software Architecture
All used Joomla development branches with the different Joomla versions run in parallel in a [Docker](https://www.docker.com/) container environment.
*Used* Joomla development branches refers to GitHub [joomla-cms](https://github.com/joomla/joomla-cms) with default, active and stale branches.
Use one, multiple, or all branches for:
* Manual testing, including database inspections and email verifications.
* [Joomla System Tests](https://github.com/joomla/joomla-cms//blob/HEAD/tests/System)
  with [Cypress](https://www.cypress.io/) GUI (interactive mode) or headless (automated mode).
* Automated installation of the [Joomla Patch Tester](https://github.com/joomla-extensions/patchtester).
* Switch between the three database options (MySQL, MariaDB, or PostgreSQL) and the two database drivers
  (MySQLi or PHP Data Objects).
* Switch between the PHP versions (8.1, 8.2, or 8.3) as supported by the official Docker images.
* Install Joomla from a cloned 'joomla-cms' Git repository.
* Grafting a Joomla package onto a branch.

![Joomla Branches Software Architecture](images/joomla-branches-tester.svg)

The idea is to have all used Joomla development branches
(in this picture 4.4-dev, 5.1-dev, 5.2-dev and 6.0-dev) are available for testing in parallel.
The installation is carried out with a dozen Docker containers,
and everything is scripted.
You see the four orange Web Server containers with the four different Joomla versions.
They are based on the `branch_*` folders, which are also available on the Docker host.

:point_right: The version numbers referenced are current as of early August 2024.
              Since used branches are subject to frequent changes,
              the latest version numbers are always be retrieved directly from the `joomla-cms` repository.
              As of late August 2024, `5.1-dev` has been removed, and `5.3-dev` has been introduced.

On the right you see three blue containers with the databases MySQL, MariaDB and PostgreSQL.
To be able to check the databases, two further blue containers with phpMyAdmin and pgAdmin are installed.
The green Docker container runs Cypress based Joomla System Tests with GUI or headless.
If you need to inspect a failed test spec, you can run Cypress with the interactive GUI.

The two red mail containers triplicate all emails from manual Joomla tests or System Tests and
make them readable via a web application.

The `/scripts` folder contains all the scripts and also configuration files.
Your current working directory must always be `joomla-branches-tester`.

On the Docker Host system (left side), your red web browser is running.
On macOS and Ubuntu, the native Cypress GUI is shown in green.

:point_right: For the complete list of all scripts see [scripts/README.md](scripts/README.md).

:fairy: The scripts have a sprinkle of *hacks* and just a touch of magic to keep things fluffy.
        For those with a taste for the finer details, the comments are a gourmet treat.

<details>
  <summary>There are a dozen Docker containers that provide the functionality.</summary>

---

The abbreviation `jbt` stands for Joomla Branches Tester:

|Name|Host Port:<br />Container Inside|Directory :eight_spoked_asterisk: |Comment|
|----|----|----------------------------------|-------|
|jbt_44| **[7044](http://host.docker.internal:7044/administrator)** | /branch_44 | Web Server Joomla branch 4.4-dev<br />user ci-admin / joomla-17082005 |
|jbt_51| **[7051](http://host.docker.internal:7051/administrator)** | /branch_51 | Web Server Joomla branch 5.1-dev<br />user ci-admin / joomla-17082005 |
|jbt_52| **[7052](http://host.docker.internal:7052/administrator)** | /branch_52 | Web Server Joomla branch 5.2-dev<br />user ci-admin / joomla-17082005 |
|jbt_53| **[7053](http://host.docker.internal:7053/administrator)** | /branch_53 | Web Server Joomla branch 5.3-dev<br />user ci-admin / joomla-17082005 |
|jbt_60| **[7060](http://host.docker.internal:7060/administrator)** | /branch_60 | Web Server Joomla branch 6.0-dev<br />user ci-admin / joomla-17082005 |
|jbt_mysql| **7011**:3306 | | Database Server MySQL version 8.1 |
|jbt_madb| **7012**:3306 | | Database Server MariaDB version 10.4 |
|jbt_pg| **7013**:5432 | | Database Server PostgreSQL version 12.20 |
|jbt_cypress| SMTP :7125 | | Cypress Headless Test Environment<br />SMTP server is only running during test execution |
|jbt_phpmya| **[7001](http://host.docker.internal:7001)** | | Web App to manage MariaDB and MySQL<br />auto-login configured, root / root |
|jbt_pga| **[7002](http://host.docker.internal:7002)** | | Web App to manage PostgreSQL<br />auto-login configured, root / root, postgres / prostgres |
|jbt_mail| **[7003](http://host.docker.internal:7003)** <br /> SMTP **7225**:1025 | | Web interface to verify emails. |
|jbt_relay| SMTP **7025**:7025 | | SMTP relay triplicator |

:eight_spoked_asterisk: The directories are available on Docker host to:
* Inspect and change the configuration files (`configuration.php` or `cypress.config.js`),
* To edit the test specs below `tests/System` or
* To inspect screenshots from failed tests or
* To inspect and hack the Joomla sources from Docker host system.

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
  <summary>Ubuntu Setup Script</summary>

---

For setting up and configuring an Ubuntu Linux environment with required Git, Docker, and firewall configuration,
one of the gnomes has provided the [ubuntu_setup.sh](scripts/ubuntu_setup.sh) script.
This script is designed to work on both a fresh Ubuntu desktop installation and Ubuntu
on Windows Subsystem for Linux (WSL).

Download the script to your current working directory and run with superuser privileges:
```
sudo bash ./ubuntu_setup.sh
```

---

</details>

## Installation

For the web server containers, to simplify life, the standard Docker Joomla images (`joomla:4` or `joomla:5`)
are used as a starting point and then overinstalled with the source code from the corresponding Joomla development branch.
The Joomla Web-Installer is executed by the Cypress spec `Installation.cy.js` from the Joomla System Tests.

Last tested in August 2024 with:
* Intel chip macOS 14 Sonoma,
* Apple silicon macOS 14 Sonoma,
* Windows 11 Pro WSL 2 Ubuntu and
* Ubuntu 24 Noble Numbat (the absolute minimum, if you also wish to use the Cypress GUI, is a VPS with 2 shared vCPUs and 4 GB RAM).

You can create all Docker containers and install the current (August 2024)
five Joomla instances using the `create.sh` script:

```
git clone https://github.com/muhme/joomla-branches-tester
cd joomla-branches-tester
scripts/create.sh
```
:point_right: The script can run without `sudo`,
but depending on the platform, it may ask you to enter your user password for individual sudo actions.

The initial script `create.sh` runs some time,
especially the very first time when the Docker images still need to be downloaded.
The `joomla-branches-tester` folder requires about of 2 GB of disc space.
Docker needs additional about of 20 GB for images and volumes.
If you are installing for the first time and downloading all necessary Docker images,
you will need to download approximately 4 GB of data over the network.

<details>
  <summary>The script can be parameterised with optional arguments.</summary>
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
6. To force a fresh build with `no-cache`, defaults to build from cache.
</details>

:point_right: In case of trouble, see [Trouble-Shooting](#trouble-shooting).

<details>
  <summary>Windows WSL2 Ubuntu Setup</summary>

---

1. Install Windows WSL 2 if it has not already been done. Open PowerShell Window with administrator rights:
   ```
   wsl --install -d Ubuntu
   ```
   Restart your computer and in the terminal, type `wsl` to start the WSL environment.
   The first time you do this, you will be asked to create a user and set a password.

   :point_right: If `wsl` is not open, you may need again `wsl --install Ubuntu` after Windows restart.
2. Install `git` inside WSL 2 Ubuntu:
   ```
   sudo apt-get update
   sudo apt-get -y upgrade
   sudo apt-get -y install git
   ```
3. Clone Joomla Branches Tester repository e.g. in your home directory:
   ```
   cd
   git clone https://github.com/muhme/joomla-branches-tester
   ```
4. Continue the installation with the Ubuntu setup script:
   ```
   cd ~/joomla-branches-tester
   sudo scripts/ubuntu_setup.sh
   ```
   To run Docker as user it is needed to restart Ubuntu:
   ```
   sudo reboot
   ```
5. Open WSL again and verify Docker is running and you have access without sudo:
   ```
   docker ps
   ```
   Should show no containers:
   ```
   CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
   ```
   :point_right: It may take a moment for the Docker service to run.
   This can also be checked with `sudo service docker status` command.
6. Create a hosts entry on Windows to map `host.docker.internal` to `127.0.0.1`, follow these steps:
   * Open Notepad as Administrator
     * Press the Start button, type `Notepad`.
     * Right-click on Notepad and select Run as administrator.
   * Open the Hosts File:
     * In Notepad, click File -> Open.
     * Navigate to the hosts file location: `C:\Windows\System32\drivers\etc\`.
     * In the Open dialog, make sure to select All Files `(*.*)` in the file type dropdown
       at the bottom right (since the hosts file doesn't have a .txt extension).
       Select the hosts file and click Open.
   * Add the Host Entry:
     * At the end of the file, add a new line with the following entry:
       ```
       127.0.0.1 host.docker.internal
       ```
    * Save the Hosts File:
      * Click File -> Save to save your changes.
    * Test the New Hosts Entry:
      * Open Command Prompt and ping the host.docker.internal to ensure it resolves to 127.0.0.1:
        ```bash
        ping host.docker.internal
        ```
        It should return responses from 127.0.0.1.
7. Now you are ready to create Joomla Branches Tester:
   ```
   cd ~/joomla-branches-tester
   scripts/create.sh
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
scripts/create.sh
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
scripts/cypress.sh 53 local
```

---

</details>

<details>
  <summary>Ubuntu 22.04.3 LTS (Jammy Jellyfish) Setup</summary>

---

Installing with a user that is able to run `sudo`.

1. Install `git` if you not have already:
   ```
   sudo apt-get update
   sudo apt-get -y upgrade
   sudo apt-get -y install git
   ```
2. Clone Joomla Branches Tester repository e.g. in your home directory:
   ```
   cd
   git clone https://github.com/muhme/joomla-branches-tester
   ```
3. Continue the installation with the Ubuntu setup script:
   ```
   cd ~/joomla-branches-tester
   sudo scripts/ubuntu_setup.sh
   ```
4. To run Docker as user it is needed to restart Ubuntu:
   ```
   sudo reboot
   ```
5. Verify Docker is running:
   ```
   docker ps
   ```
   Should show no containers:
   ```
   CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
   ```
6. Now you are ready to create Joomla Branches Tester:
   ```
   cd ~/joomla-branches-tester
   scripts/create.sh
   ```

---

</details>

## Usage

### Manual Testing

From your Docker Host system you can test the Joomla Frontend e.g. for Joomla release 5.2
with [http://host.docker.internal:7052](http://host.docker.internal:7052) and the backend
[http://host.docker.internal:7052/administrator](http://host.docker.internal:7052/administrator).
User *ci-admin* and password *joomla-17082005* (Whose birthday is it anyway?) are from Joomla System Tests.

In parallel you can inspect MariaDB and MySQL database with [phpMyAdmin](https://www.phpmyadmin.net/) on
[http://host.docker.internal:7001](http://host.docker.internal:7001) or PostgreSQL database with [pgAdmin](https://www.pgadmin.org/) on
[http://host.docker.internal:7002](http://host.docker.internal:7002). And verify all emails from Joomla and the System Tests with
[MailDev](https://github.com/maildev/maildev/blob/master/docs/docker.md) on
[http://host.docker.internal:7003](http://host.docker.internal:7003).

If you need to inspect files, they are available in the directory `branch_52` for this Joomla release 5.2 sample.

### Cypress Automated System Tests

To simple run the Joomla System Tests with all specs - except for the installation -
from the [Joomla System Tests](https://github.com/joomla/joomla-cms//blob/HEAD/tests/System) in all branches with headless Cypress:
```
scripts/test.sh
```
Some Optional arguments are:

* **Joomla version number(s)**: All versions are tested by default.
* **Browser to be used**: Choose between electron (default), firefox, chrome, or edge.
* **Test spec pattern**: All test specs (except the installation) are used by default.

As an example, run all the test specs (except the installation) from branch 5.1-dev with Mozilla Firefox:
```
scripts/test.sh 51 firefox
```

Run one test spec with default Electron in all branches (of course, the spec must exist in all branches):
```
scripts/test.sh administrator/components/com_users/Users.cy.js
```

:point_right: When specifying a single test spec file,
              you can omit the `tests/System/integration/` path at the beginning.

Test all `site` specs with Microsoft Edge in the branches Joomla 5.1, 5.2 and 5.3 using a pattern:
```
scripts/test.sh 51 52 53 edge 'tests/System/integration/site/**/*.cy.{js,jsx,ts,tsx}'
```

To additional show `console.log` messages from Electron browser by setting environment variable: 
```
export ELECTRON_ENABLE_LOGGING=1
scripts/test.sh 44 administrator/components/com_actionlogs/Actionlogs.cy.js
```

One more optional argument is `novnc`.
VNC (Virtual Network Computing) enables remote desktop access over a network.
The `jbt_vnc` container allows to view the automated browser tests via a web-based VNC viewer.
This is useful for watching System Tests in real-time without needing a full GUI environment on your local machine.
In this case Cypress runs headed and uses `jbt_vnc` as DISPLAY and you can watch the
execution of the automated tests with the URL:
* [http://host.docker.internal:7900/vnc.html?autoconnect=true&resize=scale](http://host.docker.internal:7900/vnc.html?autoconnect=true&resize=scale)
```
scripts/test.sh administrator/components/com_users/Users.cy.js 53 novnc
```

:fairy: To protect you, the first step `Installation.cy.js` of the Joomla System Tests
  is excluded in the automated tests if you run all test specs.
  If you run the installation, this can lead to inconsistencies
  between the file system and the database, as the Joomla database will be recreated.

### Cypress Interactive System Tests

If a test spec fails, the screenshot is helpful. More enlightening is it to execute the single failed test spec
with the Cypress GUI in interactive mode. You can see all the Cypress log messages, use the time-traveling debugger and
observe how the browser runs in parallel.

Cypress GUI can be started from Docker container `jbt_cypress` with X11 forwarding
(recommeded for Windows 11 WSL 2 Ubuntu):
```
scripts/cypress.sh 51
```

Or from local installed Cypress (recommended for macOS and native Ubuntu) with additional argument `local`:
```
scripts/cypress.sh 51 local
```

The script will automatically install the appropriate Cypress version locally
for each branch if it doesn't already exist.
Using the Cypress container has the advantage of having Chrome, Edge, Electron, and Chromium pre-installed.
If you run Cypress locally, only the browsers installed on your Docker host system will be available.

:imp: Are you see the `Installation.cy.js` test spec? Here you finally have the chance to do it.
  Who cares about file system and database consistency? Go on, click on it. Go on, go on ...

### Check Email

To check the emails sent by Joomla,
the [MailDev](https://hub.docker.com/r/maildev/maildev) container offers you
provides you with a web interface at [http://host.docker.internal:7003](http://host.docker.internal:7003).
The Cypress based Joomla System Tests is using an own SMTP server `smtp-tester` to receive, check and delete emails.
Since we run Cypress locally or in a container, it is necessary to triple emails.
This is done by the SMTP relay triplicator `jbt_relay`.

:fairy: Oh, dear Gnome, now I can really read all the emails from the System Tests, thank you.

<details>
  <summary>:imp: "Postal dispatch nonsense picture? Don't open it, you'll get a triple headache!</summary>

---

:fairy: "Shut up and listen. The email traffic is explained using the Joomla branch 5.1-dev with
the use cases password reset and System Tests."

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
6. System Test is started with the bash script `test.sh` in the Cypress container `jbt_cypress`.
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

### Install Joomla Patch Tester

For your convenience [Joomla Patch Tester](https://github.com/joomla-extensions/patchtester)
can be installed on the Joomla instances. The script also sets the GitHub token and fetch the data.
This can be done without version number for all Joomla instances or for e.g. Joomla 5.3-dev:

```
scripts/patchtester.sh 53 ghp_4711n8uCZtp17nbNrEWsTrFfQgYAU18N542
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

:fairy: Remember, if you have changed the database version or the PHP version, you need to reinstall Joomla Patch Tester.

### Switch Database and Database Driver

You can simply switch between one of the three supported databases (MariaDB, PostgreSQL or MySQL) and
the database driver used (MySQL improved or PHP Data Objects).
Firstly, the settings for the database server with `db_host` and the database driver with `db_type`
are adjusted in the configuration file `Cypress.config.cy.mjs`.
Secondly, a Joomla installation is performed with the Joomla System Tests.

:warning: The overall database content is lost. For example, Joomla Patch Tester component needs to be installed again.

Five variants are available:
* mariadbi – MariaDB with MySQLi (improved)
* mariadb – MariaDB with MySQL PDO (PHP Data Objects)
* pgsql - PostgreSQL PDO (PHP Data Objects)
* mysqli – MySQL with MySQLi (improved)
* mysql – MySQL with MySQL PDO (PHP Data Objects)

Use MariaDB with driver MySQLi for Joomla 5.1 and Joomla 5.2:
```
scripts/database.sh 51 52 mariadbi
```

Change all Joomla instances to use PostgreSQL:
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

### Switch PHP Version

The Joomla Docker images are from the official images for Joomla
(see [docker-joomla](https://github.com/joomla-docker/docker-joomla)
and the [Docker Hub page](https://registry.hub.docker.com/_/joomla/)). Thank you! :pray:

You can switch between the available Images for PHP 8.1, PHP 8.2, and PHP 8.3
across all branches:
```
scripts/php.sh php8.3
```
Or specify the desired branches:
```
scripts/php.sh 44 51 php8.1
```
As we are based on the Docker images there are limitations (as of August 2024):
* There is no Docker image for Joomla 4.4 with PHP 8.3, there is a fall back to PHP 5.2 used.
* There are no Docker images for Joomla 5.3 and Joomla 6.0. The Joomla 5.2 images are being used instead.
  This should not cause any issues, as the source code for 5.3 and 6.0 is pulled from the respective
  GitHub branches.

### Grafting a Joomla Package

Not interested in testing the latest development branch but still need to test a Joomla package? No problem!
Just like in plant grafting, where a scion is joined to a rootstock,
you can graft a Joomla package onto the development branch for testing.
Simply choose the same major and minor version numbers from the development branch,
and graft the package for a seamless experience.:

```
scripts/graft.sh 52 ~/Downloads/Joomla_5.2.0-alpha4-dev-Development-Full_Package.zip
```

Mandatory arguments are the Joomla branch version and the local package file.
Supported file formats are .zip, .tar, .tar.zst, .tar.gz, and .tar.bz2.
An optional argument is the database variant, such as PostgreSQL in the following example:
```
scripts/graft.sh 51 pgsql ~/Downloads/Joomla_5.1.3-Stable-Full_Package.zip
```

After grafting, you can do everything except running `scripts/pull.sh`, such as switching the database variant,
switching PHP version, installing Joomla Patch Tester, or running Joomla System Tests. And grafting can be done multiple times. :smile:

What distinguishes a grafted Joomla from a standard package-installed Joomla?
A grafted Joomla contains three additional files and two directories from the development branch:
* Files: `cypress.config.dist.mjs`, `package.json` and `package-lock.json`
* Directories: `node_modules` and `tests/System`

### Syncing from GitHub Repository

To avoid recreating everything the next day, you can simply fetch and merge the latest changes from the
Joomla GitHub repository into your local branches. This can be done for all branches without any arguments,
or for specific versions:
```
scripts/pull.sh 53 60
```

If changes are pulled then:
* Just in case the command `composer install` ist executed.
* If `package-lock.json` file has changed the command `npm ci` is executed.

Finally, the Git status is displayed.

<img align="right" src="images/phpMyAdmin.png">

### :fairy: Gaze Into the Spellbook

In the mystical world of Joomla, the database is the enchanted tome where all the secrets are stored.
Sometimes, the wise must delve into this spellbook to uncover and weave new spells,
adjusting rows and columns with precision.

Fear not, for magical tools are at your disposal, each one a trusted companion.
They are so finely attuned to your needs that they require no login, no password — just a single click,
and the pages of the database open before you as if by magic:

* [http://host.docker.internal:7001](http://host.docker.internal:7001) phpMyAdmin – for MariaDB and MySQL
* [http://host.docker.internal:7002](http://host.docker.internal:7002) pgAdmin – for PostgreSQL

Simply approach these gateways, and the secrets of the database will reveal themselves effortlessly,
ready for your exploration.

### Info

You can retrieve some interesting Joomla Branches Tester status information:
```
scripts/info.sh
```
The following example illustrates an installation with three branches:
* `4.4-dev`: A development clone based on version 4.4.9.
* `5.1-dev`: Grafted with the Joomla 5.1.2 Stable package.
* `5.2-dev`: A development clone of version 5.2.0 with additional patches applied.
```
Docker version 24.0.6 is running with 11 containers and 21 images
Standard Containers:
  jbt_pga     is running, ports: 80/tcp -> 0.0.0.0:7002
  jbt_mya     is running, ports: 80/tcp -> 0.0.0.0:7001
  jbt_mysql   is running, ports: 3306/tcp -> 0.0.0.0:7011
  jbt_madb    is running, ports: 3306/tcp -> 0.0.0.0:7012
  jbt_pg      is running, ports: 5432/tcp -> 0.0.0.0:7013
  jbt_relay   is running, ports: 7025/tcp -> 0.0.0.0:7025
  jbt_mail    is running, ports: 1025/tcp -> 0.0.0.0:7225; 1080/tcp -> 0.0.0.0:7003
  jbt_cypress is running, ports: 7125/tcp -> 0.0.0.0:7125
Branch 4.4-dev:
  jbt_44 is running, ports: 80/tcp -> 0.0.0.0:7044
  Version: Joomla! 4.4.9 Development
  /branch_44: 448MB
  Repository branch_44: https://github.com/joomla/joomla-cms,  Branch: 4.4-dev,  Status: 0 changes
Branch 5.1-dev:
  jbt_51 is running, ports: 80/tcp -> 0.0.0.0:7051
  Version: Joomla! 5.1.2 Stable
  /branch_51: 395MB
Branch 5.2-dev:
  jbt_52 is running, ports: 80/tcp -> 0.0.0.0:7052
  Version: Joomla! 5.2.0 Development
  /branch_52: 497MB
  Repository branch_52: https://github.com/joomla/joomla-cms,  Branch: 5.2-dev,  Status: 2 changes
Branch 5.3-dev:
  jbt_53 is NOT running
  /branch_53 is NOT existing
Branch 6.0-dev:
  jbt_60 is NOT running
  /branch_60 is NOT existing
```

### Xdebug

Joomla web server containers are ready with a second PHP installation for switching to
[Xdebug](https://github.com/xdebug/xdebug).
You can switch to the PHP version with Xdebug for example:
```
scripts/xdebug.sh 53 on
```

A `.vscode/launch.json` file is also prepared.
In [Visual Studio Code](https://code.visualstudio.com/),
select 'Start Debugging' and choose the corresponding entry `Listen jbt_53`.

Finally, it may be reset again to improve performance:
```
scripts/xdebug.sh off
```

Used ports are 79xx, for the given example 7953.

### Cleaning Up

If you want to get rid of all these Docker containers and the 2 GB in the `branch_*` directories, you can do so:
```
scripts/clean.sh
```

## Trouble-Shooting

1. To fully grasp the process, it's helpful to both see the diagrams and read the explanations provided.
   For instance, if you create the Joomla Branches Tester only for branch 5.1-dev,
   you won’t be able to run tests on branch 5.2-dev.
   In this situation, it’s necessary to create a Joomla Branches Tester for all branches,
   ensuring you can work across all branches.
2. One advantage of Docker and scripting: you can easily start fresh.
   As Roy from The IT Crowd says, "Have you tried turning it off and on again?"
   It takes just 2.5 minutes on a 2024 entry-level MacBook Air to delete everything and
   create 9 new containers with Joomla 5.2-dev, PHP 8.3, and PostgreSQL.
   ```
   scripts/create.sh pgsql php8.3 52
   ```
3. Check the Docker container logs to monitor activity.
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
   `jbt_cypress:7125`, delivered to the mail catcher listening on `jbt_mail:7225`, and could not be delivered to local
   the locally running Cypress GUI `smtp-tester` listening on `localhost:7325` (equivalent host names are used for clarity).
4. Run a script with the option `-x` to enable detailed debugging output that shows each command
   executed along with its arguments, for example:
   ```
   bash -x scripts/pull.sh
   ```
5. If you encounter problems after running `scripts/create.sh` multiple times,
   try using the `no-cache` option to force a fresh build of the containers.
6. Open an [issue](../../issues).

## Limitations

* The different Joomla versions exist in parallel, but the test runs sequentially.
* Database server versions cannot be changed.
* The setup does not support HTTPS, secure connections issues are not testable.
* The predefined port range starts from 7000. If another service is already using this range, it may cause a conflict.

## License

Distributed under the GNU General Public License version 2 or later, see [LICENSE](LICENSE)

If it is used, I would like to pass it on to the Joomla! project.

## Contact

Don't hesitate to ask if you have any questions or comments. If you encounter any problems or have suggestions for enhancements, please feel free to [open an issue](../../issues).
