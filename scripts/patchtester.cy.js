/*
 * patchtester.cy.js - Cypress script to install Joomla Patch Tester component and fetch data
 *
 * cypress run --env token=ghp_4711...42 --config specPattern=/scripts/patchtester.cy.js
 * 
 * MIT License, Copyright (c) 2024 Heiko Lübbe
 * https://github.com/muhme/joomla-branches-tester
 */

// It would be nice if you had a latest link.
const DOWNLOAD_URL =
  "https://github.com/joomla-extensions/patchtester/releases/download/4.3.1/com_patchtester_4.3.1.tar.bz2";
const COMPONENT = 'Joomla! Patch Tester';

describe(`Install '${COMPONENT}' with`, () => {

  // Install extension
  it("install component", () => {
    cy.doAdministratorLogin();
    cy.installExtensionFromUrl(DOWNLOAD_URL);
  });

  // Problems with patchtester seen after switching database, therefore uninstall and install again
  // 42P01, 7, ERROR: relation "jos44_patchtester_pulls_labels" does not exist LINE 2: FROM "jos44_patchtester_pulls_labels"
  it("uninstall component", () => {
    cy.doAdministratorLogin();
    cy.uninstallExtension(COMPONENT);
  });

  // Install extension 2nd time
  it("install component again", () => {
    cy.doAdministratorLogin();
    cy.installExtensionFromUrl(DOWNLOAD_URL);
  });

  // Set the GitHub Token
  it("set GitHub token", () => {
    const token = Cypress.env("token");
    if (!token) {
      assert.fail("GitHub token is missing as environment variable TOKEN");
    }
    cy.doAdministratorLogin();
    cy.visit("administrator/index.php?option=com_patchtester&view=pulls");
    cy.get("#toolbar-options").click();
    cy.contains("button", "GitHub Authentication").click();
    cy.get("#jform_gh_token").clear().type(token);
    cy.clickToolbarButton("Save & Close");
  });

  // Fetch the data
  it("fetch data", () => {
    cy.doAdministratorLogin();
    cy.visit('administrator/index.php?option=com_patchtester&view=pulls');
    cy.get('button.button-sync.btn.btn-primary').click();
    cy.get('tr', { timeout: Cypress.config('defaultCommandTimeout') * 10 }).should('have.length.greaterThan', 1);
  });
});
