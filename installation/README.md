# JBT Cypress Installation Environment

This is the [Joomla Branches Tester](../README.md) (JBT) [Cypress](https://www.cypress.io/) installation environment.

The Joomla installation itself, the installation of the [Joomla Patch Tester](https://github.com/joomla-extensions/patchtester) or the disabling of 'Behaviour - Backward Compatibility' (B/C) plugins are implemented by Cypress scripts:

| File | Description | Additional Info |
| --- | --- | --- |
| [disableBC.cy.js](disableBC.cy.js) | Disable Joomla B/C plugins. | Used by `scripts/database`. |
| [installJoomla.cy.js](installJoomla.cy.js) | Install Joomla version 3.19 and higher. | Used by `scripts/database`. |
| [installPatchtester.cy.js](installPatchtester.cy.js) | Install and configure Joomla Patch Tester component. | Used by `scripts/patchtester`. |

The `installation/node_modules` directory is created initially using `npm ci` for Cypress.
Then, it is extended with the [joomla-cypress](https://github.com/joomla-projects/joomla-cypress) support package as a clone of the `main` branch to ensure the latest improvements are always included.

The `joomla-*` directories contain the JBT installation environment's `cypress.config.js` file and a copy of the Joomla `installation` folder.
