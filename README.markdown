[Heroku Buildpack](https://devcenter.heroku.com/articles/buildpacks) for [Kong](https://getkong.org/about/)
=========================
Deploy [Kong 0.11.0 Community Edition](http://blog.mashape.com/kong-ce-0-11-0-released/) as a Heroku app.


🌈 **This buildpack now deploys the release version of Kong.** Patches are no longer required for compatibility with Heroku.


Usage
-----

### Example

Deploy the [heroku-kong app](https://github.com/heroku/heroku-kong) to get started.

### Custom

Create a new git repo and Heroku app:

```bash
mkdir my-kong-app
cd my-kong-app
git init
heroku create $APP_NAME
heroku buildpacks:set https://github.com/heroku/heroku-buildpack-kong
heroku addons:create heroku-postgresql:hobby-dev
```

Create the file `config/kong.conf.etlua` based on the [sample config file](config/kong.conf.etlua.sample). This is a config template which generates `config/kong.conf` at runtime.

```bash
git add config/kong.conf.etlua
git commit -m '🐒'
git push heroku master
```

🚀 Check `heroku logs` and `heroku open` to verify Kong launches.

#### Plugins & other Lua source

  * [Kong plugins](https://getkong.org/plugins/)
    * [Development guide](https://getkong.org/docs/0.11.x/plugin-development/)
    * `lib/kong/plugins/{NAME}`
    * Add each Kong plugin name to the `custom_plugins` comma-separated list in `config/kong.conf.etlua` 
    * See: [Plugin File Structure](https://getkong.org/docs/0.11.x/plugin-development/file-structure/)
  * Lua rocks
    * specify in the app's `.luarocks` file
    * each line is `{NAME} {VERSION}`
  * Other Lua source modules
    * `lib/{NAME}.lua` or
    * `lib/{NAME}/init.lua`

#### Environment variables

  * `PORT` exposed on the app/dyno
    * set automatically by the Heroku dyno manager
  * `KONG_GIT_URL` git repo URL for Kong source
    * example `https://github.com/Mashape/kong.git`
  * `KONG_GIT_COMMITISH` git branch/tag/commit for Kong source
    * example `master`
  * `DATABASE_URL`
    * set automatically by [Heroku Postgres add-on](https://elements.heroku.com/addons/heroku-postgresql)

Background
----------
The first time this buildpack builds an app, the build time will be significantly longer as Kong and its dependencies are compiled from source. **The compiled artifacts are cached to speed up subsequent builds.**

We vendor the sources for Lua, LuaRocks, & OpenResty/Nginx and compile them with a writable `/app/.heroku` prefix. Attempts to bootstrap Kong on Heroku using existing [Lua](https://github.com/leafo/heroku-buildpack-lua) & [apt](https://github.com/heroku/heroku-buildpack-apt) buildpacks failed due to their compile-time prefixes of `/usr/local` which is read-only in a dyno.

OpenSSL 1.0.2 (required by OpenResty) is also compiled from source.


### Modification

This buildpack caches its compilation artifacts from the sources in `vendor/`. Changes to the sources in `vendor/` will be detected and the cache ignored.

If you need to trigger a full rebuild without changing the source, use the [Heroku Repo CLI plugin](https://github.com/heroku/heroku-repo) to purge the cache:

```bash
heroku repo:purge_cache
```
