/*
 * disableBC.cy.js - Cypress script to disable 'Behaviour - Backward Compatibility' plugin
 *
 * Used by scripts/database
 * 
 * Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
 * https://github.com/muhme/joomla-branches-tester
 */

import { registerCommands } from "joomla-cypress";
registerCommands();

const plugins = [
  'Behaviour - Backward Compatibility', // >= 4.4
  'Behaviour - Taggable',               // <= 4.3
  'Behaviour - Versionable'             // <= 4.3
];

describe('Disable Behaviour Plugins', () => {
  beforeEach(() => {
    // Log in once before the tests run.
    // Using hardcoded creds here or in the bash script — it makes no difference.
    cy.doAdministratorLogin('ci-admin', 'joomla-17082005');
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
