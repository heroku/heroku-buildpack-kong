Heroku Buildpack for [Kong](https://getkong.org)
=========================

Configuration
-------------

* Buildtime 
  * sources in the buildpack's [`vendor/`](vendor) used by [`bin/compile`](bin/compile)
  * additional system packages in the buildpack's [`apt-packages`](apt-packages)
  * Lua rocks: specify in the app's `.luarocks` file; each line is `{NAME} {VERSION}`
* Runtime
  * config template in `config/kong.yml.etlua`
    * buildpack detects this file in the app
    * [sample config file](config/kong.yml.etlua.sample)
* [Kong/Nginx plugins](https://getkong.org/docs/0.5.x/plugin-development/) & other Lua modules
  * Lua source in the app
    * [Kong plugins](https://getkong.org/docs/0.5.x/plugin-development/):
      * `lib/kong/plugins/{NAME}`
      * See: [Plugin File Structure](https://getkong.org/docs/0.5.x/plugin-development/file-structure/)
    * Other Lua modules:
      * `lib/{NAME}.lua` or
      * `lib/{NAME}/init.lua`
  * Add each Kong plugin name to the `plugins_available` list in `config/kong.yml.etlua` 

Usage
-----
To use this buildpack for an app, `config/kong.yml.etlua` must exist. Copy it from [this repo](config/kong.yml.etlua), or clone the [heroku-kong app](https://github.com/heroku/heroku-kong).

Execute `kong-12f` in the app root before every run, to configure from the environment.

For example, the default web process is:
```
kong-12f && kong start -c config/kong.yml
```

### Environment variables

  * Port exposed on the app/dyno
    * `PORT`
    * Listener assigned to the port:
      * `KONG_EXPOSE=proxy` for the gateway (default)
      * `KONG_EXPOSE=admin` for the Admin API
  * Cassandra datastore
    * Heroku-style config vars
      * `CASSANDRA_URL`
        ```
cassandra://username:password@x.x.x.x:port/keyspace,cassandra://username:password@y.y.y.y:port/keyspace
        ```
      * `CASSANDRA_TRUSTED_CERT` (SSL is disabled unless provided)
    * [Instaclustr add-on](https://elements.heroku.com/addons/instaclustr) config vars
      * `IC_CONTACT_POINTS`
        ```
x.x.x.x,y.y.y.y
        ```
      * `IC_PORT`
      * `IC_USER`
      * `IC_PASSWORD`
      * `IC_CERTIFICATE` (SSL is disabled unless provided)

Background
----------
The first time this buildpack builds an app, the build time will be significantly longer as Kong and its dependencies are compiled from source. **The compiled artifacts are cached to speed up subsequent builds.**

We vendor the sources for Lua, LuaRocks, & OpenResty/Nginx and compile them with a writable `/app/.heroku` prefix. Attempts to bootstrap Kong on Heroku using existing [Lua](https://github.com/leafo/heroku-buildpack-lua) & [apt](https://github.com/heroku/heroku-buildpack-apt) buildpacks failed due to their compile-time prefixes of `/usr/local` which is read-only in a dyno.

OpenResty is patched according to Kong's [compile from source docs](https://getkong.org/install/source/).

OpenSSL 1.0.2 (required by OpenResty) is also compiled from source, as the versions included in the Cedar 14 stack & apt packages for Ubuntu/Trusty are too old.

Kong source is vendored and installed via `luarocks`, because LuaRocks does not reliably provide `kong`. (Was the 0.5.4 version yanked?)


Modification
------------
This buildpack caches its compilation artifacts from the sources in `vendor/`. Changes to the sources in `vendor/` will be detected and the cache ignored.

If you need to trigger a full rebuild without changing the source, use the [Heroku Repo CLI plugin](https://github.com/heroku/heroku-repo) to purge the cache:

```bash
heroku repo:purge_cache
```
