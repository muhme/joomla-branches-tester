const joomlaCommands = () => {

  // Install Joomla via the user interface
  const installJoomla = (config) => {
    cy.log('**Install Joomla**')
    cy.log('Config: ' + config)

    // Load installation page and check for language dropdown
    cy.visit('installation/index.php')
    cy.get('#jform_language').should('be.visible')

    // Select en-GB as installation language
    cy.get('#jform_language').select('en-GB')
    cy.get('#jform_language-lbl').should('contain', 'Select Language')

    // Fill Sitename
    cy.get('#jform_site_name').type(config.sitename)
    cy.get('#step1').click()

    // Fill Admin credentials
    cy.get('#jform_admin_user').type(config.name)
    cy.get('#jform_admin_username').type(config.username)
    cy.get('#jform_admin_password').type(config.password)
    cy.get('#jform_admin_email').type(config.email)
    cy.get('#step2').click()

    // Fill database configuration
    // muhme, 9 August 2024 'hack' as long as waiting for PRy
    let connection = config.db_host
    if (config.db_port && config.db_port.trim() !== "") {
      connection += `:${config.db_port.trim()}`;
    }
    cy.get('#jform_db_type').select(config.db_type)
    cy.get('#jform_db_host').clear().type(connection)
    cy.get('#jform_db_user').type(config.db_user)

    if (config.db_password) {
      cy.get('#jform_db_pass').type(config.db_password)
    }

    cy.get('#jform_db_name').clear().type(config.db_name)
    cy.get('#jform_db_prefix').clear().type(config.db_prefix)
    cy.intercept('index.php?task=installation.create*').as('ajax_create')
    cy.intercept('index.php?task=installation.populate1*').as('ajax_populate1')
    cy.intercept('index.php?task=installation.populate2*').as('ajax_populate2')
    cy.intercept('index.php?task=installation.populate3*').as('ajax_populate3')
    cy.intercept('index.php?view=remove&layout=default').as('finished')
    cy.get('#setupButton').click()
    cy.wait(['@ajax_create', '@ajax_populate1', '@ajax_populate2', '@ajax_populate3', '@finished'], {timeout: 120000})
    cy.get('#installCongrat').should('be.visible')

    cy.log('--Install Joomla--')
  }

  Cypress.Commands.add('installJoomla', installJoomla)

  
  // Cancel Tour
  const cancelTour = () => {
    cy.log('**Cancel Tour**')

    cy.get('.shepherd-cancel-icon', { timeout: 40000 }).should('exist').click()

    cy.log('--Cancel Tour--')
  }

  Cypress.Commands.add('cancelTour', cancelTour)


  // Disable Statistics
  const disableStatistics = () => {
    cy.log('**Disable Statistics**')

    cy.get('.js-pstats-btn-allow-never', { timeout: 40000 }).should('be.visible').click()

    cy.log('--Disable Statistics--')
  }

  Cypress.Commands.add('disableStatistics', disableStatistics)


  // Set Errorreporting to dev mode
  const setErrorReportingToDevelopment = () => {
    cy.log('**Set error reporting to dev mode**')

    cy.visit('administrator/index.php?option=com_config')

    cy.contains('.page-title', 'Global Configuration').scrollIntoView()
    cy.get("div[role='tablist'] button[aria-controls='page-server']").click()
    cy.get('#jform_error_reporting').select('Maximum')

    cy.intercept('index.php?option=com_config*').as('config_save')
    cy.clickToolbarButton('save')
    cy.wait('@config_save')
    cy.contains('.page-title', 'Global Configuration').should('exist')
    cy.contains('#system-message-container', 'Configuration saved.').should('exist')

    cy.log('--Set error reporting to dev mode--')
  }

  Cypress.Commands.add('setErrorReportingToDevelopment', setErrorReportingToDevelopment)


  // Install Joomla as a multi language site
  const installJoomlaMultilingualSite = (config, languages = []) => {
    cy.log('**Install Joomla as a multi language site**')

    if (!languages.length)
    {
        // If no language is passed French will be installed by default
        languages = ['French']
    }

    cy.installJoomla(config)

    cy.get('#installAddFeatures').then(($btn) => {
      cy.wrap($btn.text().trim()).as('installAddFeaturesBtnText');
    })

    cy.get('#installAddFeatures').click()

    cy.get('@installAddFeaturesBtnText').then((text) => {
      cy.contains('legend', text).should('exist')
    })

    languages.forEach((language) => {
        cy.contains('label', language).click()
    })

    cy.get('#installLanguagesButton').click()

    cy.get('#installCongrat', { timeout: 30000 }).should('be.visible')

    cy.get('#defaultLanguagesButton').click()
    cy.get('#system-message-container .alert-message').should('have.length', 2)

    // delete installation
    cy.get('body').then((body) => {
      // Joomla 5: check element with ID 'removeInstallationFolder' exists
      if (body.find('#removeInstallationFolder').length > 0) {
        cy.get('#removeInstallationFolder').click()
      } else {
        // Joomla 4: simple click 1st button to complete installation and delete installation folder
        cy.get('.complete-installation').eq(0).click()
      }
    });

    // check installation is no more available
    cy.visit("/installation", { failOnStatusCode: false }); // prevent Cypress from failing
    cy.title().should("include", "404"); // page title have to contain 404

    cy.log('Joomla is now installed')

    cy.log('--Install Joomla as a multi language site--')
  }

  Cypress.Commands.add('installJoomlaMultilingualSite', installJoomlaMultilingualSite)
}

module.exports = {
    joomlaCommands
}
