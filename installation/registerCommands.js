/**
 * Custom implementation of registerCommands() tailored for JBT-based installations and testing with joomla-cypress.
 *
 * This implementation is adapted from joomla-cypress/src/index.js, with direct imports of source files.
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
