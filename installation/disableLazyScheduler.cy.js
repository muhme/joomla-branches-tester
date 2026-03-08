/**
 * disableLazyScheduler.cy.js - Cypress script to disable 'Lazy Scheduler'
 *
 * Used by 'scripts/setup.sh'.
 * 
 * Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024-2025 Heiko Lübbe
 * https://github.com/muhme/joomla-branches-tester
 * 
 * Can be single tested and watched with e.g.
 *   docker exec jbt-cypress sh -c "cd /jbt/installation && \
 *    CYPRESS_CACHE_FOLDER=/jbt/cypress-cache \
 *    DISPLAY=jbt-novnc:0 \
 *    CYPRESS_specPattern='/jbt/installation/disableLazyScheduler.cy.js' \
 *    npx cypress run --headed --config-file '/jbt/installation/joomla-54/cypress.config.js'"
 */

import { registerCommands } from "./registerCommands";
registerCommands();

describe('Disable Lazy Scheduler', () => {
  beforeEach(() => {

    // Backend super user log in
    cy.doAdministratorLogin(Cypress.env('username'), Cypress.env('password'));

    /*
     * Catch Joomla JavaScript exceptions; otherwise, Cypress will fail.
     * Use 'scripts/check' to view these exceptions after 'scripts/create|database|graft'.
     */
    Cypress.on('uncaught:exception', (err, runnable) => {
      console.log(`ERROR uncaught:exception err :${err}`);
      console.log(`ERROR uncaught:exception runnable :${runnable}`);
      return false;
    });

  });

  it(`Disables Lazy Scheduler`, () => {
    cy.visit('administrator/index.php?option=com_config&view=component&component=com_scheduler');
    cy.get('button[aria-controls="lazy_scheduler_config"]:visible').click();
    cy.get('input[name="jform[lazy_scheduler][enabled]"][value="0"]').check({ force: true });
    cy.contains('button', 'Save & Close').click();
    cy.log(`Lazy Scheduler has been disabled.`);
  });
});
