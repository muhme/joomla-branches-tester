/**
 * installJoomla.cy.js - Cypress script to install Joomla 3 ... Joomla 6
 * 
 * Used by 'scripts/database.sh'.
 * 
 * Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
 * https://github.com/muhme/joomla-branches-tester
 */

import { registerCommands } from "./registerCommands";
registerCommands();

describe('Install Joomla', () => {

  beforeEach(() => {
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

  it('Install Joomla', () => {
    const config = {
      sitename: Cypress.env('sitename'),
      name: Cypress.env('name'),
      username: Cypress.env('username'),
      password: Cypress.env('password'),
      email: Cypress.env('email'),
      db_type: Cypress.env('db_type'),
      db_host: Cypress.env('db_host'),
      db_port: Cypress.env('db_port'),
      db_user: Cypress.env('db_user'),
      db_password: Cypress.env('db_password'),
      db_name: Cypress.env('db_name'),
      db_prefix: Cypress.env('db_prefix'),
    };
    // Get major minor version, e.g. 44
    const instance = parseInt(Cypress.env('instance'), 10);

    if (instance >= 40 && instance != 310) {
      // Using NPM module 'joomla-cypress'
      cy.installJoomla(config);
      /* Installing from tag (not from branch) we have the 'Congratulations!' screen with
       * either 'Install Additional Languages', 'Open Site' or 'Open Administrator'.
       * It is needed to click one of them to complete the installation.
       */
      cy.get('body').then($body => {
        if ($body.find('button[complete-installation]').length > 0) {
          cy.get('button[complete-installation]').first().click({ force: true })
        }
      })
      cy.doAdministratorLogin(config.username, config.password, false);
      if (instance >= 51) {
        // on 4.0 disableStatistics | cy.searchForItem(statisticPlugin) fails with: .filter-search-bar__button not found
        cy.cancelTour();
      }
      if (instance > 40) {
        cy.disableStatistics();
      }
      cy.setErrorReportingToDevelopment();

    } else {
      // Joomla 3

      // Load installation page
      cy.visit("installation/index.php");

      // Select en-GB as installation language
      cy.get("#jform_language").select("English (United Kingdom)", { force: true });

      // 1st screen: Fill sitename and admin
      cy.get("#jform_site_name").type(config.sitename);
      cy.get("#jform_admin_user").type(config.username);
      cy.get("#jform_admin_password").type(config.password);
      cy.get("#jform_admin_password2").type(config.password);
      cy.get("#jform_admin_email").type(config.email);

      // Click Next
      cy.get("a.btn.btn-primary", { force: true  }).first().click();

      // 2nd screen: Database
      cy.get("#jform_db_type").invoke('removeAttr', 'style').select(config.db_type, { force: true });
      cy.get("#jform_db_host").clear().type(config.db_host);
      cy.get("#jform_db_user").clear().type(config.db_user);
      cy.get("#jform_db_pass").clear().type(config.db_password);
      cy.get("#jform_db_name").clear().type(config.db_name);

      // Click Next
      cy.get("a.btn.btn-primary").first().click();

      // 3rd screen Finalisation - click Next
      cy.get("a.btn.btn-primary").first().click();

      // Wait for the installation process to finish before proceeding
      cy.get('#loading-logo', { timeout: 30000 }).should('not.be.visible');

      // 4th screen - Congratulations!
      // Delete installation directory
      cy.get(".btn.btn-warning", { timeout: 30000 }).first().click({force: true});
    }
  });
});
