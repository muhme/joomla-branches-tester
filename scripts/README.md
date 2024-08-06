# Scripts for a more pleasant and also faster development

This collection of scripts is the Joomla Branches Tester (see [../README.md](../README.md)).

| Script | Description | Additional Info |
| --- | --- | --- |
| [scripts/create.sh](create.sh) | (Re-)Build all docker containers. | Optional argument `build` will force a no-cache build. |
| [scripts/test.sh](test.sh) | Running System Tests on one or all branches. | |
| [scripts/clean.sh](clean.sh) | Delete all `jst_*`-Docker containers and the `joomla-system-tests_default` Docker network. | |
| [scripts/patchtester.sh](patchtester.sh) | Installs Joomla patch tester component in one or all Joomla instances. | |
| [scripts/patchtester.cy.js](patchtester.cy.js) | Cypress script used by `patchtester.sh`. | |
| [scripts/pull.sh](pull.sh) | Running `git pull` and `git status` on one or all branches. | |
| [scripts/ubuntu_setup.sh](ubuntu_setup.sh) | Helper script in an installation on standard Ubuntu Linux. | |
| [scripts/helper.sh](helper.sh) | Some commonly used bash script functions and definitions. | |

The scripts are used on the Mac command line and inside Docker container, but should also work on Linux and the Windows subsystem for Linux.
