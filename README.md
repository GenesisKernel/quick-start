About Genesis
==========

Genesis is an open source blockchain platform which implemented as blockchain network consisting of nodes communicating each other. Each node is backend service having own database and can be interacted by the end user with a client or web ui.

The goal of this quick start solution is to run a local testing network of several Genesis nodes (backends with GUI clients) to give the end user an idea of how Genesis blockchain works and provide usage examples of graphical interface elements as well as smart-contracts.

The backend-side (backend itlsef and database engine) software runs in docker containers and clients run nativly on the host system side.
As soon as clients start user can interact with local testing Genesis blockchain network.

Usage
=====

Currently Genesis quick start was tested on Mac and Linux.
Windows support is comming.

Use manage.sh to manage Genesis testbed on Linux/Mac and manage.exe to
manage Genesis testbed on Windows.

### Linux/Mac

To create testing network of 5 nodes on Linux/Mac use the following command:

```shell
./manage.sh install 5
```

This will download and install all required software (docker if it's not installed yet, docker containers with Genesis backends and databases and Genesis clients)
and start 5 Genesis backend instances and 5 accordingly connected Genesis clients.

To stop clients and to stop and delete docker containers run this command:

```shell
./manage delete
```

To stop clients and to stop and delete docker containers and images run this command:

```shell
./manage delete-all
```

To check the status of testing network run this command:

```shell
./manage status
```

To start database shell connected to appropriate backend's database run:

```shell
./manage db-shell N
```

where N is the number of a backend.

To stop all clients run:

```shell
./manage stop-clients
```

To start clients again run:

```shell
./manage start-clients
```

To reinstall (delete all Genesis-related containers and run installation again with the last installation parameters) run:

```shell
./manage reinstall
```
### Windows

Please see [Genesis Quick Start for Windows](https://github.com/GenesisKernel/quick-start-win)

Client Application
==================

A password is required to confirm transactions. The default password is 'genesis'.

Exposed ports
=============

By default docker backends and database listening ports are exposed to system by
 the following rules:

* Database port is exposed to the system port 15432
* Web frontend ports are exposed to 'web port shift' value (8300 by default) plus the index number of a backend, for example the listening port of the first backend by default is exposed to 8301, the second - to 8302 and so on
* Client ports are exposed to 'client port shift' value  (17300 by default) plus the index number of a backend, for example the listening port of the first backend by default is exposed to 17301, the second - to 17302 and so on

These default ports shifts values can be changed during installation:

```shell
./manage.sh install N WPS CPS DBP
```

where:

* N - the number of backends (maximum 5);
* WPS - web port shift - optional parameter, default value: 8300;
* CPS - client port shift - optional parameter, default value: 17300;
* DBP - database port - optional parameter, default value: 15432.

So running this command:

```shell
./manage.sh install 4 9000 19000 6000
```

will start 4 backends and 4 clients, and fronend ports will be exposed to system port: 9001, 9002, 9003, 9004, clients ports will be exposed to system ports: 19001, 19002, 19003, 19004, and database port will be exposed to system port 6000

### Useful links

* [Genesis Quick Start for Windows](https://github.com/GenesisKernel/quick-start-win)

* [Genesis Applications](https://genesiskernel.github.io/apps/)

* [Genesis Blockchain](https://github.com/GenesisKernel/go-genesis)

* [Genesis Frontend](https://github.com/GenesisKernel/genesis-front)

* [Genesis Frontend](https://github.com/GenesisKernel/genesis-front)
