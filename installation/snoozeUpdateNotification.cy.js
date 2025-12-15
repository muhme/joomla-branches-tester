/**
 * snoozeUpdateNotification.cy.js - Cypress script to snooze Joomla 6 notification for all users.
 *
 * Used by 'scripts/database.sh'.
 * 
 * Distributed under the GNU General Public License version 2 or later, Copyright (c) 2025 Heiko Lübbe
 * https://github.com/muhme/joomla-branches-tester
 */

import { registerCommands } from "./registerCommands";
registerCommands();

it('Snoozes Joomla 6 notification if present', () => {

  // Admin log in before disabling a plugin.
  cy.doAdministratorLogin(Cypress.env('username'), Cypress.env('password'));
  cy.visit('/administrator/index.php');

  const selector = 'button.eosnotify-snooze-btn';
  const deadline = Date.now() + 3000;

  const checkAndClick = () => {
    cy.get('body').then(($body) => {
      const $btn = $body.find(selector);

      if ($btn.length) {
        cy.wrap($btn)
          .contains('Snooze this message for all users')
          .click();
        cy.log('Joomla 6 notification snoozed.');
        return;
      }

      if (Date.now() < deadline) {
        cy.wait(200);
        checkAndClick();
      } else {
        cy.log('Joomla 6 notification not shown within 3 seconds.');
      }
    });
  };

  checkAndClick();
});

