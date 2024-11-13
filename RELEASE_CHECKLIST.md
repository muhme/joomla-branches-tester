# Release Check List

- Increase major.minor in RELEASE to the new one
- Running in one system != development system
  - click all links, copy&paste all script samples
  - Test all user scripts with help and wrong_argument
  - Test one script without network access
  - Test one script from inside scripts directory and with absolute path
  - Try to run internal script helper.sh and setup.sh
  - Check version update hint from scripts/info
  - Manual Testing
    - Try links from docu, frontend, backend, phpMyAdmin - both servers, pgAdmin - open database, MailDev with emails
- Check one Joomla instance for
  - Debug System
  - Log Almost Everything
- Log Deprecated API
- Test with Windows, macOS and Ubuntu
  - Installation as described, copy&paste for all code samples
  - scripts/create - one installation with all branches
  - go through all Usage use cases
    - in Cypress GUI run test administrator/components/com_users/User.cy.js and check email
    - after each database change: scripts/test system administrator/components/com_users/User.cy.js

We can have a whole dozen Joomla containers:
```
scripts/create 3.9.28 3.10.12 4.0.4 4.1.5 4.2.9 4.3.4 44 5.0.2 51 52 53 60
```
