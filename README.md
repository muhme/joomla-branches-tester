# Docker based Joomla System Tests

Running automated [Joomla system tests](https://github.com/joomla/joomla-cms/tree/4.4-dev/tests/System) with [Cypress](https://www.cypress.io/) in a [docker](https://www.docker.com/) container environment.

![scrupts/test.sh running screen shot](screen-shot.png)

The idea is to have the current four Joomla branches (currently 4.4-dev, 5.1-dev, 5.2-dev and 6.0-dev)
available in parallel for Joomla system tests. The only requirement is the ability to run a bash script and Docker.
The installation takes place in Docker containers and is automated with scripts.
The result is a pure Docker container installation without manual installations or configurations.

To simplify life, the standard Joomla images are used as starting point and overwritten with the Joomla
source code from the various software branches. The Joomla installation itself is executed by Cypress spec.

## Installation

```
git clone https://github.com/muhme/joomla-system-tests
cd joomla-system-test
scripts/create.sh
```

This takes about one hour and requires about 8.4 GB disk space.

:point_right: The scripts use [ANSI escape codes](https://en.wikipedia.org/wiki/ANSI_escape_code#Colors)
to color their own log and error messages.
This can be disabled by setting environment variable [NOCOLOR=1](https://no-color.org/).

## Containers

The abbreviation `jst` stands for joomla system test:

|Name|Port|Directory :eight_spoked_asterisk: |Comment|
|----|----|----------------------------------|-------|
|jst_mysql| | | version 8.2 |
|jst_cypress| host.docker.internal:7025 | | SMTP server is only running during test execution |
|jst_mysqladmin|[7001](http://localhost:7001)| | |
|jst_44|[7044](http://localhost:7044)| /branch_44 | Joomla branch 4.4-dev<br />PHP 8.1 |
|jst_51|[7044](http://localhost:7044)| /branch_50 | Joomla branch 5.1-dev<br />PHP 8.2 |
|jst_52|[7044](http://localhost:7044)| /branch_51 | Joomla branch 5.2-dev<br />PHP 8.2 |
|jst_60|[7044](http://localhost:7044)| /branch_52 | Joomla branch 6.0-dev<br />PHP 8.2 |

:eight_spoked_asterisk: The directories are available on Docker host e.g. to inspect and change the configuration
files (`configuration.php` or `cypress.config.js`) or the test specifications below `tests/System`.
And also one available in Joomla container and all together in `jst_cypress` container.

# Usage

Test all (more than 100) specs in all four branches:
```
scripts/test.sh
```

Test all specs in branch 5.1-dev:
```
scripts/test.sh 51
```

Test one spec with all four branches:
```
scripts/test.sh tests/System/integration/administrator/components/com_privacy/Consent.cy.js
```

Test all site specs with branch 4.4-dev:
```
scripts/test.sh 44 'tests/System/integration/site/**/*.cy.{js,jsx,ts,tsx}'
```

# Dependencies

You need only Docker installed. Developed with macOS 14 Sonoma.
Should basically run under Linux and Windows WSL2, please let me know if you have checked this.

## License

MIT License, Copyright (c) 2024 Heiko Lübbe, see [LICENSE](LICENSE)

## Contact

Don't hesitate to ask if you have any questions or comments. If you encounter any problems or have suggestions for enhancements, please feel free to [open an issue](../../issues).
