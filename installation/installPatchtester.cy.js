/**
 * installPatchtester.cy.js - Cypress script to install Joomla Patch Tester component and fetch data
 *
 * Used by 'scripts/patchtester'.
 * 
 * Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 - 2025 Heiko Lübbe
 * https://github.com/muhme/joomla-branches-tester
 */

import { registerCommands } from "./registerCommands";
registerCommands();

describe("Install 'Joomla! Patch Tester' with", () => {

  beforeEach(() => {
    /*
     * Catch Joomla JavaScript exceptions; otherwise, Cypress will fail.
     * Use 'scripts/check' to view these exceptions after 'scripts/patchtester'.
     */
    Cypress.on('uncaught:exception', (err, runnable) => {
      console.log(`ERROR uncaught:exception err :${err}`);
      console.log(`ERROR uncaught:exception runnable :${runnable}`);
      return false;
    });
  });

  // Install extension
  it("install component", () => {
    const patchtester_url = Cypress.env("patchtester_url");
    if (!patchtester_url) {
      assert.fail("Patch Tester download URL is missing as environment variable 'patchtester_url'.");
    }
    cy.doAdministratorLogin();
    cy.installExtensionFromUrl(patchtester_url);
  });

  // Set the GitHub Token
  it("set GitHub token", () => {
    const token = Cypress.env("token");
    if (!token) {
      assert.fail("GitHub token is missing as environment variable 'token'.");
    }
    cy.doAdministratorLogin();
    cy.visit("administrator/index.php?option=com_patchtester&view=pulls");
    cy.get("#toolbar-options").click();
    cy.contains("button", "GitHub Authentication").click();
    cy.get("#jform_gh_token").clear().type(token);
    cy.clickToolbarButton("Save & Close");
  });

  function tryFetchOnce() {
    cy.visit('administrator/index.php?option=com_patchtester&view=pulls');
    cy.get('button.button-sync.btn.btn-primary').click();

    return cy.wait(Cypress.config('defaultCommandTimeout') * 3).then(() => {
      return cy.document().then((doc) => {
        const rows = doc.querySelectorAll('tr');
        return rows.length > 1;
      });
    });
  }
  it("fetch data with retry", () => {
    cy.doAdministratorLogin();

    tryFetchOnce().then((success) => {
      if (success) return;

      cy.log('First fetch failed, retrying...');
      tryFetchOnce().then((secondSuccess) => {
        expect(secondSuccess, 'Second fetch should succeed').to.equal(true);
      });
    });
  });
});
