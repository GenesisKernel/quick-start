curl
====

## curl: (77) SSL: can't load CA certificate file

manage.sh uses curl to download dmg, AppImage and other files.
In case of an old CA certificate file download error can happen when HTTP-URL's used:

``` shell
curl: (77) SSL: can't load CA certificate file
```

To fix this you need to update CA certificate file. 
Please read https://curl.haxx.se/docs/sslcerts.html for details.
See also https://curl.haxx.se/docs/caextract.html for download URLs.

#### Mac

To update curl's CA certificate file you can:

* Download the latest the latest version of CA certificate from by URL: https://curl.haxx.se/ca/cacert.pem
* Copy (replace existing) downloaded cacert.pem to /usr/local/etc/openssl/certs/cacert.pem
* Run manage.sh <COMMAND> again


#### Linux

To update curl's CA certificate file you can:

* Update curl, openssl

or:

* Download the latest the latest version of CA certificate from by URL: https://curl.haxx.se/ca/cacert.pem
* Copy (replace existing) downloaded cacert.pem to /usr/local/etc/openssl/certs/cacert.pem
* Run manage.sh <COMMAND> again


