## Upcoming Version 0.6.16
* Update golang to v1.11: DONE
* Update scripts to v0.1.4: DONE
* Update demo apps to 0.9.17: IN PROGRESS
* Update backend to 0.9.7: IN PROGRESS
* Update Block Explorer to the latest with Aux DB support: IN PROGRESS

## Version 0.6.15 / 2018-Aug-20 05:40
* Add dump-be-all and restore-be-all command to dump/restore backends logs, data directories and databases
* Fix priv-keys command
* Fix frontend git version
* Fix build images commands in DOCKER.md
* Update scripts version to 0.1.2
* Update backend to version [hotfix/1103-rollback](https://github.com/GenesisKernel/go-genesis/tree/hotfix/1103-rollback): fix another one potential bug leading to desynchronizationwhile importing big XLSM data files

## Version 0.6.14 / 2018-Aug-15 17:01
* Update backend to version [0.9.4](https://github.com/GenesisKernel/go-genesis/releases/tag/0.9.4): fix potential hangs and/or errors while importing big XLSM data files
* Update applications to version [0.9.16](https://github.com/GenesisKernel/apps/releases/tag/quick-start-0.9.16)
* Update db container: update Dockerfile and PostgreSQL version to 9.6.10-1.pgdg90+1

## Version 0.6.13 / 2018-Aug-03 18:01
* Update backend to version [0.9.3](https://github.com/GenesisKernel/go-genesis/releases/tag/0.9.3): fix another potential desynchronization issue

## Version 0.6.12 / 2018-Aug-03 02:36
* Update backend to version tag [0.9.2](https://github.com/GenesisKernel/go-genesis/releases/tag/0.9.2)

## Version 0.6.11 / 2018-Jul-31 02:28
* Change supervisor unix socket file path to /dev/shm/supervisor.sock
* Switch backend to version tag [0.9.1](https://github.com/GenesisKernel/go-genesis/releases/tag/0.9.1)
* Switch frontend to version tag [v0.8.6-RC](https://github.com/GenesisKernel/genesis-front/releases/tag/v0.8.6-RC)
* Switch demo apps to vesion tag [quick-start-0.9.15](https://github.com/GenesisKernel/apps/releases/download/quick-start-0.9.15)
* Fix port checking function

## Version 0.6.10 / 2018-Jul-26 11:32
* Update scripts: switch backend running mode to PrivateBlockchain

## Version 0.6.9 / 2018-Jul-25 23:07
* Switch backend to version [master/2603ab1](https://github.com/GenesisKernel/go-genesis/commit/2603ab132201e58122cfd8473133399fa5d04e0e)
* Add backend restarting after importing
* Fix scripts print error function

## Version 0.6.8 / 2018-Jul-24 06:54

* Switch scripts branch to master
* Update scripts
* Fix stop-clients command
* Switch Block Explorer branch to master
* Turn off debugging forced copying of scripts
* Switch backends to [release/0.9.1 branch, commit da9a2a4](https://github.com/GenesisKernel/go-genesis/tree/release/0.9.1)

## Version 0.6.7 / 2018-Jul-22 05:30

* Add --disable-full-nodes-sync=true parameter to client start up functionality
* Update apla client to version [v0.8.6-RC](https://github.com/GenesisKernel/genesis-front/releases/tag/v0.8.6-RC)
* Update genesis client to version [v0.8.6-RC](https://github.com/AplaProject/apla-front/releases/tag/v0.8.6-RC)
* Change scripts branch to develop
* Remove genesis-front prebuild
* Fix settings.json format

## Version 0.6.6 / 2018-Jul-22 02:33

* Update frontend's settings.json format
* Split usage help to brief (default) and detailed.
* Add founder-key command. Remove --args from linux client start up parameters.
* Change back frontend preparing method to the building from the source
* Update scripts
* Fix detailed help function call
* Update frontend settings.json: add socketUrl and disableFullNodesSync parameters.

## Version 0.6.5 / 2018-Jul-11 03:45

* Add build-tag-push-all-images command
* Update Docker for Mac to version 18.03.1-ce-mac65 (24312)
* Update mac docker's expected app dir size
* Update mac client's expected app dir size
* Remove private keys from every starting clients except the founder's one

## Version 0.6.4 / 2018-Jun-04 23:17

* Fix backend index in backend_app_ctl
* Remove some debug output
* Add more sophisticated hack to backend apps start up functionality
* Increase db containers/processes waiting timeouts
* Update golang version to 1.10.3
* Update go-genesis version to [master/da97624](https://github.com/GenesisKernel/go-genesis/commit/da97624ef756d40c49848734f4b89619b321dac0)
* Update genesis-db Dockerfile: Remove purging of ca-certificates

## Version 0.6.3 / 2018-Jun-02 19:45

* Fix delete-all, stop, start commands functionality
* Add be-app-ctl command to manage particular backend
* Add wait-be-apps to check/wait backends availability
* Add hack (tricky start_be_apps function) to start backend in case it cannot be started when it's the single available backend by full nodes parameter list
