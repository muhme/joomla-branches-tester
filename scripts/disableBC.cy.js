/*
 * disableBC.cy.js - Cypress script to disable 'Behaviour - Backward Compatibility' plugin
 *
 * Used by scripts/database
 * 
 * Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
 * https://github.com/muhme/joomla-branches-tester
 */

const plugin = 'Behaviour - Backward Compatibility';

describe(`${plugin}`, () => {
  it('Disable Plugin', () => {
    // Hardcoded creds here or in the bash script — it makes no difference.
    cy.doAdministratorLogin('ci-admin', 'joomla-17082005');
    // Same procedure as in joomla-cypress custom command `disableStatistics`
    cy.visit('/administrator/index.php?option=com_plugins&view=plugins');
    cy.searchForItem(plugin);
    cy.get('a').contains(plugin).click();
    cy.get('select#jform_enabled').select('Disabled');
    cy.get('button.button-save.btn.btn-success').click();
  });
});
