/**
 * disableBC.cy.js - Cypress script to disable 'Behaviour - Backward Compatibility' plugins
 *
 * Used by 'scripts/database.sh'.
 * 
 * Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024-2025 Heiko Lübbe
 * https://github.com/muhme/joomla-branches-tester
 */

import { registerCommands } from "./registerCommands";
registerCommands();

// Don't disable 'Behaviour - Taggable' or 'Behaviour - Versionable' plugins or you can't use tags/versions
const plugins = [
  'Behaviour - Backward Compatibility 6', // >= 5.4
  'Behaviour - Backward Compatibility',   // >= 4.4
];

describe('Disable Behaviour Plugins', () => {
  beforeEach(() => {

    // Admin log in before disabling a plugin.
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

  plugins.forEach(plugin => {
    it(`Disables '${plugin}' plugin if found`, () => {
      // Procedure inspired from joomla-cypress custom command `disableStatistics`
      cy.visit('/administrator/index.php?option=com_plugins&view=plugins');
      cy.searchForItem(plugin);

      // Check if the plugin exists in the search results
      cy.get('body').then(($body) => {
        if ($body.find(`a:contains(${plugin})`).length > 0) {
          // Click on the plugin name to edit it
          cy.get('a').contains(plugin).click();
          // Set the status to "Disabled"
          cy.get('select#jform_enabled').select('Disabled');
          // Save the changes
          cy.get('button.button-save.btn.btn-success').click();
          cy.log(`${plugin} has been disabled.`);
        } else {
          cy.log(`${plugin} was not found.`);
        }
      });
    });
  });
});
