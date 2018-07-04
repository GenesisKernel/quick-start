## Version 0.6.4 / 2018-June-04 23:17

* Fix backend index in backend_app_ctl
* Remove some debug output
* Add more sophisticated hack to backend apps start up functionality
* Increase db containers/processes waiting timeouts
* Update golang version to 1.10.3
* Update go-genesis version to [master/da97624](https://github.com/GenesisKernel/go-genesis/commit/da97624ef756d40c49848734f4b89619b321dac0)

## Version 0.6.3 / 2018-June-02 19:45

* Fix delete-all, stop, start commands functionality
* Add be-app-ctl command to manage particular backend
* Add wait-be-apps to check/wait backends availability
* Add hack (tricky start_be_apps function) to start backend in case it cannot be started when it's the single available backend by full nodes parameter list
