Heroku Buildpack for Kong
=========================


Configuration
-------------

* Buildtime
  * sources in [`vendor/`](vendor) used by [`bin/compile`](bin/compile)
  * additional system packages in [`apt-packages`](apt-packages)
* Runtime
  * config template in `config/kong.yml.etlua` (Kong buildpack detects this file in the app)


Running
-------

Execute `kong-12f` in the app root before every run, to configure from the environment.

For example, the default web process is:
```
kong-12f && kong start -c config/kong.yml
```

* Kong config via environment variables
  * `CASSANDRA_URL`
  * `CASSANDRA_TRUSTED_CERT`
  * `PORT`
  * `KONG_EXPOSE`
* Parses the `CASSANDRA_URL` as a comma-delimited list of contact points with the format:
  ```
  cassandra://username:password@x.x.x.x:port/keyspace,cassandra://username:password@y.y.y.y:port/keyspace
  ```
* Exposes a single service per instance (app/dyno)
  * `KONG_EXPOSE=proxy` for the gateway (default)
  * `KONG_EXPOSE=admin` for the Admin API


Provisioning into a Heroku Private Space
----------------------------------------

1. `heroku spaces:create 8th-wonder --org heroku-cto --region virginia`
1. `heroku apps:create kong-proxy --space 8th-wonder`
1. `heroku buildpacks:set https://github.com/heroku/heroku-buildpack-multi.git -a kong-proxy`
1. `heroku config:set GITHUB_AUTH_TOKEN={repo_access_token} -a kong-proxy` (access to private Kong buildpack)
1. `heroku apps:create kong-admin --space 8th-wonder`
1. `heroku buildpacks:set https://github.com/heroku/heroku-buildpack-multi.git -a kong-admin`
1. `heroku config:set GITHUB_AUTH_TOKEN={repo_access_token} KONG_EXPOSE=admin -a kong-admin` (access to private Kong buildpack)
1. `heroku sudo addons:create heroku-cassandra:alpha-dev -a kong-proxy`
1. `heroku addons:attach {cassandra-id} -a kong-admin`
1. `heroku run "kong-12f && kong migrations reset -c config/kong.yml" -a kong-proxy`
