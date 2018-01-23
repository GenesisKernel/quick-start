Containers and images names
===========================

Database container, image and build directory names are specified in the Configuration section of manage.sh:

```shell
...
DB_CONT_NAME="genesis-db"
DB_CONT_IMAGE="str16071985/genesis-db"
DB_CONT_BUILD_DIR="genesis-db"
...

```

Backend/Frontend container, image and build directory names are specified in the Configuration section of manage.sh

```shell
...
BF_CONT_NAME="genesis-bf"
BF_CONT_IMAGE="str16071985/genesis-bf"
BF_CONT_BUILD_DIR="genesis-bf"
...

```

.env
====

Any variable of manage.sh can be customized through .env file.
Create .env file in the same directory where manage.sh is located and add your variables, for example:

```shell
APLA_CLIENT_APPIMAGE_DL_URL="https://github.com/AplaProject/apla-front/releases/download/v0.3.1/apla-0.3.1-x86_64.AppImage"
```

.env file is a part of .gitignore so it doesn't touch git repository state.

Build images
============

To build db container run: 

```shell
./manage build-db
```

To build backend/frontend container run: 

```shell
./manage build-bf
```

To build all (db and bf) containers run: 

```shell
./manage build
```

Usage
=====

Suppose we need to rebuild backend/frontend image and we are not going to change any default container names (container, image and build directory names).
So we just run './manage.sh build-bf'.
After a new container is built you can see it listed in 'docker images':

```shell
REPOSITORY                  TAG                 IMAGE ID            CREATED             SIZE
...
genesis-bf                  latest              2d6eec87f21a        2 minutes ago      1.68GB
...
```

Now if you run './manage install ...' or './manage reinstall' you get a new installation with your customized backend/frontend container.

Push image to remote repository
===============================

To push custom docker image into your repository you have to follow these:

* Run 'docker login' and log in to your hub.docker.com account (let's assume it's 'thawaytouganda').
* Build a new image (we already have a new genesis-bf image from the previous paragraph).
* Tag a new image running:

```shell
docker tag genesis-bf thawaytouganda/genesis-bf
```

* Push tagged image to the remote repository:

```shell
docker push thawaytouganda/genesis-bf
```

Use custom remote image
=======================

To use your customized remote images you have to follow these:

* Create .env file in the same directory where manage.sh script is located and add an update BF_CONT_IMAGE variable:

```shell
BF_CONT_IMAGE="thawaytouganda/genesis-bf"
```
* Start a new installation using './manage install ...' or './manage reinstall' and you get a new installation with your customized backend/frontend container image pulled from remote repository.
