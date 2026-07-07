/**
 * Custom implementation of registerCommands() tailored for JBT-based installations and testing with joomla-cypress.
 *
 * This implementation is adapted from joomla-cypress/src/index.js, with direct imports of source files.
 * 
 * Distributed under the GNU General Public License version 2 or later
 * Copyright (c) 2024 - 2026 Heiko Lübbe and contributors
 * https://github.com/muhme/joomla-branches-tester
 */


const { joomlaCommands } = require('./joomla-cypress/src/joomla');
const { extensionsCommands } = require('./joomla-cypress/src/extensions');
const { supportCommands } = require('./joomla-cypress/src/support');
const { userCommands } = require('./joomla-cypress/src/user');
const { commonCommands } = require('./joomla-cypress/src/common');

const registerCommands = () => {
  joomlaCommands();
  extensionsCommands();
  supportCommands();
  userCommands();
  commonCommands();
};

module.exports = { registerCommands };
