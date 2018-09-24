Upgrading the Kong buildpack for Heroku
=======================================

[v6.0.0](https://github.com/heroku/heroku-buildpack-kong/releases)
------

🚨 **Potentially breaking change** to support rapid deployments using a pre-compiled Kong binary.

Kong's filesystem prefix is changing in this buildpack:

> `/app/.heroku` → `/app/kong-runtime`

In your app's `config/kong.conf.etlua` file, change the **prefix** value to `/app/kong-runtime/`, & commit the change.

Search your app for `.heroku` to find any other instances of `/app/.heroku` that may need to be updated to `/app/kong-runtime`.

A backward-compatibility patch is applied automatically, linking `/app/.heroku` to `/app/kong-runtime`. We still advised using the new prefix to avoid any strange behavior from invoking executables through a symbolic link.
