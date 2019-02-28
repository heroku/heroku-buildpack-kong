[Heroku Buildpack](https://devcenter.heroku.com/articles/buildpacks) for [Kong](https://getkong.org/about/)
=========================

Deploy [Kong 1.1.0rc1](https://konghq.com) as a Heroku app.

🔬👩‍💻 This software is a community proof-of-concept: [MIT license](LICENSE)

Usage
-----

⏩ **Deploy the [heroku-kong app](https://github.com/heroku/heroku-kong) to get started.**

### Upgrading

Potentially breaking changes are documented in [UPGRADING](UPGRADING.md).

### Custom

While it's possible to use this buildpack directly, you'll be giving up quite a few features of the [heroku-kong app](https://github.com/heroku/heroku-kong):

* Admin API will not be automatically proxied for secure external access
* Admin Console via `heroku run` will require manual setup
* local development is not preconfigured

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

  * [Kong plugins](https://docs.konghq.com/hub/)
    * [Development guide](https://docs.konghq.com/1.0.x/plugin-development/)
    * `lib/kong/plugins/{NAME}`
    * Add each Kong plugin name to the `custom_plugins` comma-separated list in `config/kong.conf.etlua`
    * See: [Plugin File Structure](https://docs.konghq.com/1.0.x/plugin-development/file-structure/)
  * Lua rocks
    * specify in the app's `Rockfile`
    * each line is `{NAME} {VERSION}`
  * Other Lua source modules
    * `lib/{NAME}.lua` or
    * `lib/{NAME}/init.lua`

#### Environment variables

  * `PORT` exposed on the app/dyno
    * set automatically by the Heroku dyno manager
  * `DATABASE_URL`
    * set automatically by [Heroku Postgres add-on](https://elements.heroku.com/addons/heroku-postgresql)
  * Kong itself may be configured with [`KONG_` prefixed variables](https://docs.konghq.com/1.0.x/configuration/#environment-variables)
  * Heroku build configuration:
    * These variables only effect new deployments.
    * `KONG_RUNTIME_ARCHIVE_URL` location of [pre-compiled Kong runtime archive](DEV.md#pre-compiled-runtime-archive)
    * ⏱ **Setting these will lengthen build-time, usually 4-8 minutes for compilation from source.** By default, this buildpack downloads pre-compiled, cached Kong binaries to accelerate deployment time. (More details available in [DEV](DEV.md).)
    * `KONG_GIT_URL` git repo URL for Kong source
      * default: `https://github.com/kong/kong.git`
    * `KONG_GIT_COMMITISH` git branch/tag/commit for Kong source
      * default: `1.1.0rc1`


#### Using Environment Variables in Plugins

To use env vars within your own code.

  1. Whitelist the variable name for use within Nginx
     * In a custom Nginx config file add `env MY_VARIABLE;`
     * See: [Nginx config](#user-content-nginx-config) (below)
  2. Access the variable in Lua plugins
     * Use `os.getenv('MY_VARIABLE')` to retrieve the value.


#### Nginx config

Kong is an Nginx-based application. To customize the underlying Nginx configuration, commit the file `config/nginx.template` with contents based on [the docs](https://docs.konghq.com/1.0.x/configuration/#custom-nginx-templates) or [this included sample](config/nginx.template.sample).

#### Pre-release script

This buildpack installs a [release phase](https://devcenter.heroku.com/articles/release-phase) script to automatically run Kong's database migrations for each deployment.

Apps can define a custom pre/post-release script which will be automatically invoked before/after the built-in release phase script.

Simply commit your executable script to the app's repo as `bin/prerelease` or `bin/postrelease`, and then that script will be run for every release. The release will fail if the script exits with non-zero status.

#### Testing

This buildpack supports [Heroku CI](https://devcenter.heroku.com/articles/heroku-ci) to automate test runs and integrate with deployment workflow.

Tests should follow the [Kong plugin testing](https://docs.konghq.com/1.0.x/plugin-development/tests/) guide.

App requirements:

  * `spec/kong_tests.conf` must contain the Kong configuration for running tests

See: sample [Heroku Kong app](https://github.com/heroku/heroku-kong) which contains a complete test suite.

Background
----------
We vendor the sources for Lua, LuaRocks, & OpenResty/Nginx and compile them with a writable `/app/kong-runtime` prefix. Attempts to bootstrap Kong on Heroku using existing [Lua](https://github.com/leafo/heroku-buildpack-lua) & [apt](https://github.com/heroku/heroku-buildpack-apt) buildpacks failed due to their compile-time prefixes of `/usr/local` which is read-only in a dyno.

OpenSSL (version required by OpenResty) is also compiled from source.

### Modification

This buildpack normally downloads an archive of the pre-compiled Kong runtime, and so skips a very lengthy (~10-minute) build process. To skip that cache speed-up and compile it, set either [`KONG_GIT_URL` or `KONG_GIT_COMMITISH`](#user-content-environment-variables). To create a new archive, see [DEV notes](DEV.md#pre-compiled-runtime-archive).

This buildpack caches its compilation artifacts from the sources in `vendor/`. Changes to the sources in `vendor/` will be detected and the cache ignored.

If you need to trigger a full rebuild without changing the source, use the [Heroku Repo CLI plugin](https://github.com/heroku/heroku-repo) to purge the cache:

```bash
heroku repo:purge_cache
```
