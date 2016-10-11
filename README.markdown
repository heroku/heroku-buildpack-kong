[Heroku Buildpack](https://devcenter.heroku.com/articles/buildpacks) for [Kong](https://getkong.org)
=========================
Based on [Kong version 0.7.0](http://blog.mashape.com/kong-0-7-0-released/) patched for compatibility with Heroku.


🚨 **This Heroku buildpack is no longer in development. It uses an outdated version of Kong.** It remains here on Github only to support existing deployments.


Usage
-----

### Beginner

Deploy the [heroku-kong app](https://github.com/heroku/heroku-kong) to get started.

### Expert

* `kong.yml`
  * config template in `config/kong.yml.etlua`
    * buildpack detects this file in the app
    * [sample config file](config/kong.yml.etlua.sample)
* Lua source in the app
  * [Kong plugins](https://getkong.org/docs/0.7.x/plugin-development/):
    * `lib/kong/plugins/{NAME}`
    * Add each Kong plugin name to the `plugins_available` list in `config/kong.yml.etlua` 
    * See: [Plugin File Structure](https://getkong.org/docs/0.7.x/plugin-development/file-structure/)
  * Lua rocks
    * specify in the app's `.luarocks` file
    * each line is `{NAME} {VERSION}`
  * Other Lua source modules
    * `lib/{NAME}.lua` or
    * `lib/{NAME}/init.lua`

### Environment variables

  * `PORT` exposed on the app/dyno
    * set automatically by the Heroku dyno manager
  * `KONG_CLUSTER_SECRET` symmetric encryption key
    * generate value with command `serf keygen`; requires [Serf](https://www.serfdom.io/downloads.html)
  * `KONG_GIT_URL` git repo URL for Kong source
    * example `https://github.com/mars/kong.git`
  * `KONG_GIT_COMMITISH` git branch/tag/commit for Kong source
    * example `0.7.0-external-supervisor.1` or `master`
  * Cassandra datastore
    * Heroku-style config vars
      * `CASSANDRA_URL`
         
        ```
cassandra://username:password@x.x.x.x:port/keyspace,cassandra://username:password@y.y.y.y:port/keyspace
        ```  
        
          `username:password` must be the same for all instances.
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

OpenSSL 1.0.2 (required by OpenResty) is also compiled from source, as the versions included in the Cedar 14 stack & apt packages for Ubuntu/Trusty are too old.

Kong is installed from a forked source repo that includes [minimal changes for compatibility with the Heroku runtime](https://github.com/Mashape/kong/compare/release/0.7.0...mars:0.7.0-external-supervisor).


Modification
------------
This buildpack caches its compilation artifacts from the sources in `vendor/`. Changes to the sources in `vendor/` will be detected and the cache ignored.

If you need to trigger a full rebuild without changing the source, use the [Heroku Repo CLI plugin](https://github.com/heroku/heroku-repo) to purge the cache:

```bash
heroku repo:purge_cache
```
