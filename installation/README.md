# JBT Cypress Installation Environment

This is the [Joomla Branches Tester](../README.md) (JBT) [Cypress](https://www.cypress.io/) installation environment.

The Joomla installation itself and more actions are implemented by Cypress scripts:

| File | Description | Additional Info |
| --- | --- | --- |
| [disableBC.cy.js](disableBC.cy.js) | Disables the Joomla B/C plugins. | Used by `scripts/database.sh`. |
| [disableLazyScheduler.cy.js](disableLazyScheduler.cy.js) | Disable Lazy Scheduler (tasks are triggered with native cron). | Used by `scripts/setup.sh`. |
| [installJoomla.cy.js](installJoomla.cy.js) | Installs Joomla version 3.19 and higher. | Used by `scripts/database.sh`. |
| [installPatchtester.cy.js](installPatchtester.cy.js) | Install and configure Joomla Patch Tester component. | Used by `scripts/patchtester.sh`. |


* The **node_modules** directory is created initially using `npm ci` for Cypress.
* The **joomla-cypress** directory is created initially from
  [joomla-cypress](https://github.com/joomla-projects/joomla-cypress) support package as a clone of the `main` branch
  latest version to ensure the latest improvements are always included. This joomla-cypress version is used as
  JBT installation environment for the three files above.
* The **joomla-*** directories contain the JBT installation environment's `cypress.config.js` file and a copy
  of the Joomla `installation` folder. If a Joomla installation folder is deleted it is restored from this place.

  ## Testing

  You can run and watch the Cypress scripts by your own, e.g.
  ```
  docker exec jbt-cypress sh -c "cd /jbt/installation && \
    CYPRESS_CACHE_FOLDER=/jbt/cypress-cache \
    DISPLAY=jbt-novnc:0 \
    CYPRESS_specPattern='/jbt/installation/disableLazyScheduler.cy.js' \
    npx cypress run --headed --config-file '/jbt/installation/joomla-54/cypress.config.js'"
```
