/**
 * cypress.config.js - Cypress configuration for JBT-based installation and for testing joomla-cypress
 *
 * Used by scripts/database to create instance-specific Cypress installation/joomla-.../cypress.config[.local].js files
 * 
 * Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
 * https://github.com/muhme/joomla-branches-tester
 */
const { defineConfig } = require('../node_modules/cypress');

module.exports = defineConfig({
  env: {
    // Standard Joomla System Tests variables
    sitename: 'Joomla CMS Test',
    name: 'jane doe',
    email: 'admin@example.com',
    username: 'ci-admin',
    password: 'joomla-17082005',
    db_type: 'set by scripts/database.sh',
    db_host: 'set by scripts/database.sh',
    db_port: 'set by scripts/database.sh',
    db_name: 'set by scripts/database.sh',
    db_user: 'root',
    db_password: 'set by scripts/database.sh',
    db_prefix: 'set by scripts/database.sh',
    smtp_host: 'set by scripts/database.sh',
    smtp_port: 'set by scripts/database.sh',
    cmsPath: '.',
    // JBT added variables
    instance: 'set by scripts/database.sh',
    installationPath: 'set by scripts/database.sh'
  },
  e2e: {
    baseUrl: 'set by scripts/database.sh',
    supportFile: false,
    // Just in case we are coming from a failed installation test, start with the Joomla installation
    specPattern: ['cypress/joomla.cy.js', 'cypress/*.cy.js'],
    defaultBrowser: 'firefox',
    setupNodeEvents(on, config) {
      // For example, in a German environment, force the use of Firefox with British English.
      on("before:browser:launch", (browser, launchOptions) => {
        if (browser.family === "firefox") {
          launchOptions.preferences["intl.accept_languages"] = "en-GB";
        }
        return launchOptions;
      });
      return config;
    },
  },
});
