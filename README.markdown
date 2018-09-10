[Heroku Buildpack](https://devcenter.heroku.com/articles/buildpacks) for [Kong](https://getkong.org/about/)
=========================
Deploy [Kong 0.14 Community Edition](https://konghq.com/kong-community-edition/) as a Heroku app.

🌈 This buildpack now deploys genuine Mashape Kong, [built from source on Github](bin/compile#L226); patches are no longer required for compatibility with Heroku.

🔬👩‍💻 This software is a community proof-of-concept: [MIT license](LICENSE)


Usage
-----

### Example

Deploy the [heroku-kong app](https://github.com/heroku/heroku-kong) to get started.

### Custom

Create a new git repo and Heroku app:

```bash
APP_NAME=my-kong-gateway # name this something unique for your app
mkdir $APP_NAME
cd $APP_NAME
git init
heroku create $APP_NAME
heroku buildpacks:set https://github.com/heroku/heroku-buildpack-kong.git
heroku addons:create heroku-postgresql:hobby-dev
```

Create the file `config/kong.conf.etlua` based on the [sample config file](config/kong.conf.etlua.sample). This is a config template which generates `config/kong.conf` at runtime.

```bash
git add config/kong.conf.etlua

echo '# Kong Proxy' > README.md
git add README.md

git commit -m '🐒'
git push heroku master
```

🚀 Check `heroku logs` and `heroku open` to verify Kong launches.

#### Plugins & other Lua source

  * [Kong plugins](https://getkong.org/plugins/)
    * [Development guide](https://docs.konghq.com/0.14.x/plugin-development/)
    * `lib/kong/plugins/{NAME}`
    * Add each Kong plugin name to the `custom_plugins` comma-separated list in `config/kong.conf.etlua` 
    * See: [Plugin File Structure](https://docs.konghq.com/0.14.x/plugin-development/file-structure/)
  * Lua rocks
    * specify in the app's `Rockfile`
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


#### Using Environment Variables in Plugins

To use env vars within your own code.

  1. Whitelist the variable name for use within Nginx 
     * In a custom Nginx config file add `env MY_VARIABLE;`
     * See: [Nginx config](#user-content-nginx-config) (below)
  2. Access the variable in Lua plugins
     * Use `os.getenv('MY_VARIABLE')` to retrieve the value.


#### Nginx config

Kong is an Nginx-based application. To customize the underlying Nginx configuration, commit the file `config/nginx.template` with contents based on [the docs](https://docs.konghq.com/0.14.x/configuration/#custom-nginx-configuration) or [this included sample](config/nginx.template.sample).

#### Testing

This buildpack supports [Heroku CI](https://devcenter.heroku.com/articles/heroku-ci) to automate test runs and integrate with deployment workflow.

Tests should follow the [Kong plugin testing](https://docs.konghq.com/0.14.x/plugin-development/tests/) guide.

App requirements:

  * `spec/kong_tests.conf` must contain the Kong configuration for running tests

See: sample [Heroku Kong app](https://github.com/heroku/heroku-kong) which contains a complete test suite.

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
