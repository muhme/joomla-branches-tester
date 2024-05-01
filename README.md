# Docker based Joomla System Tests

Running automated [Joomla system tests](https://github.com/joomla/joomla-cms/tree/4.4-dev/tests/System) with [Cypress](https://www.cypress.io/) in a [docker](https://www.docker.com/) container environment.

The idea is to have all four branches running parallel in four containers, available in host directory and mounted in Cypress container. To simplify the live Joomla standard containers are used and overwritten with the branch versions. Joomla installation itself is executed by Cypress spec.

## Installation

```
git clone https://github.com/muhme/joomla-system-test
cd joomla-system-test
scripts/create.sh
```

## Containers

|Name|Port|Directory|Comment|
|----|----|-------|--------
|jst_mysql| | |
|jst_cypress| | |
|jst_mysqladmin|[7001](http://localhost:7001)| |
|jst_44|[7044](http://localhost:7044)| /branch_44 | Joomla branch 4.4-dev |
|jst_51|[7044](http://localhost:7044)| /branch_50 | Joomla branch 5.1-dev |
|jst_52|[7044](http://localhost:7044)| /branch_51 | Joomla branch 5.2-dev |
|jst_60|[7044](http://localhost:7044)| /branch_52 | Joomla branch 6.0-dev |

# Usage

```
scripts/test.sh tests/System/integration/administrator/components/com_privacy/Consent.cy.js
```

# Dependencies

You need only Docker installed. Developed with macOS 14 Sonoma.
Should basically run under Linux and Windows WSL2, please let me know if you have checked this.

## License

MIT License, Copyright (c) 2024 Heiko Lübbe, see [LICENSE](LICENSE)

## Contact

Don't hesitate to ask if you have any questions or comments. If you encounter any problems or have suggestions for enhancements, please feel free to [open an issue](../../issues).
