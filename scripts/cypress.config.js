/*
 * cypress.config.js - Cypress configuration for Joomla 3.0 ... 4.2 JBT-based installation
 *
 * Used by scripts/database
 * 
 * Inspired by the Cypress-based installation method from https://github.com/muhme/quote_joomla
 * 
 * Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
 * https://github.com/muhme/joomla-branches-tester
 */
const { defineConfig } = require('../node_modules/cypress');

module.exports = defineConfig({
  e2e: {
    setupNodeEvents(on, config) {},
    baseUrl: 'set by scripts/database.sh',
    supportFile: false,
  },
  env: {
    instance: 'set by scripts/database.sh',
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
  },
});
