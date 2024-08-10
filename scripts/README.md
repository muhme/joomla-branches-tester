# Scripts for a more pleasant and also faster development

This collection of scripts is the Joomla Branches Tester (see [../README.md](../README.md)).

| Script | Description | Additional Info |
| --- | --- | --- |
| [scripts/create.sh](create.sh) | (Re-)Build all docker containers. | Optional argument `build` will force a no-cache build. |
| [scripts/test.sh](test.sh) | Running System Tests on one or all branches. | |
| [scripts/clean.sh](clean.sh) | Delete all `jbt_*`-Docker containers and the `joomla-branches-tester_default` Docker network. | |
| [scripts/patchtester.sh](patchtester.sh) | Installs Joomla patch tester component in one or all Joomla instances. | |
| [scripts/patchtester.cy.js](patchtester.cy.js) | Cypress script used by `patchtester.sh`. | |
| [scripts/pull.sh](pull.sh) | Running `git pull` and `git status` on one or all branches. | |
| [scripts/ubuntu_setup.sh](ubuntu_setup.sh) | Helper script in an installation on standard Ubuntu Linux. | |
| [scripts/helper.sh](helper.sh) | Some commonly used bash script functions and definitions. | |

:point_right: The scripts use [ANSI escape codes](https://en.wikipedia.org/wiki/ANSI_escape_code#Colors)
to color their own log and error messages.
This can be disabled by setting environment variable [NOCOLOR=1](https://no-color.org/).

![scripts/test.sh running screen shot](../images/screen-shot.png)
