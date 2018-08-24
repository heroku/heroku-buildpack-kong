local etlua  = require "etlua"
local socket = require "socket"
local url    = require "socket.url"

local rel_config_file = "config/kong.conf"
local rel_env_file    = ".profile.d/kong-env"

-- 12-factor config generator for Kong
-- execute with `kong-12f {template-file} {destination-dir}`

-- Use shell command arguments to set file locations
-- first arg: the ETLUA template
-- second arg: the buildpack/app directory
-- third arg: this will be used as a prefix
-- to dynamically create specific
-- env var names to retrieve values specific to
-- non-web processes in a private space (optional)
local template_filename = arg[1]
local config_filename   = arg[2].."/"..rel_config_file
local prefix            = arg[3] and arg[3]:upper() or ""
-- not an `*.sh` file, because the Dyno manager should not exec
local env_filename  = arg[2].."/"..rel_env_file

local address       = "0.0.0.0"
local default_proxy_port      = 8000
local default_proxy_port_ssl  = 8443
local default_admin_port      = 8001
local default_admin_port_ssl  = 8444

-- Read environment variables for runtime config
local port              = os.getenv(prefix.."_PORT") or os.getenv("PORT") or default_proxy_port
local pg_url            = os.getenv("DATABASE_URL") or "postgres://localhost:5432/kong"
local expose_service    = os.getenv(prefix.."_KONG_EXPOSE") or os.getenv("KONG_EXPOSE") -- `proxy` (default), `admin`, `adminssl`, `proxyssl`

local parsed_pg_url = url.parse(pg_url, default)

local pg_host = parsed_pg_url.host
local pg_port = parsed_pg_url.port
local pg_user = parsed_pg_url.user
local pg_password = parsed_pg_url.password
local pg_database = string.sub(parsed_pg_url.path, 2, -1)

-- Configure the service to expose on PORT
local proxy_listen
local proxy_listen_ssl
local admin_listen
local admin_listen_ssl
if expose_service == "admin" then
  print("Configuring as Kong admin API")
  proxy_listen     = address..":"..default_proxy_port
  proxy_listen_ssl = address..":"..default_proxy_port_ssl
  admin_listen     = address..":"..port
  admin_listen_ssl = address..":"..default_admin_port_ssl
elseif expose_service == "adminssl" then
  print("Configuring as Kong admin SSL API")
  proxy_listen     = address..":"..default_proxy_port
  proxy_listen_ssl = address..":"..default_proxy_port_ssl
  admin_listen     = address..":"..default_admin_port
  admin_listen_ssl = address..":"..port
elseif expose_service == "proxyssl" then
  print("Configuring as Kong SSL proxy")
  proxy_listen     = address..":"..default_proxy_port
  proxy_listen_ssl = address..":"..port
  admin_listen     = address..":"..default_admin_port
  admin_listen_ssl = address..":"..default_admin_port_ssl
else
  print("Configuring as Kong proxy")
  proxy_listen     = address..":"..port
  proxy_listen_ssl = address..":"..default_proxy_port_ssl
  admin_listen     = address..":"..default_admin_port
  admin_listen_ssl = address..":"..default_admin_port_ssl
end

-- Render the Kong configuration file
local template_file = io.open(template_filename, "r")
local template = etlua.compile(template_file:read("*a"))
template_file:close()

local values = {
  proxy_listen          = proxy_listen,
  proxy_listen_ssl      = proxy_listen_ssl,
  admin_listen      = admin_listen,
  admin_listen_ssl  = admin_listen_ssl,
  pg_host             = pg_host,
  pg_port             = pg_port,
  pg_user             = pg_user,
  pg_password         = pg_password,
  pg_database         = pg_database
}

local config = template(values)

local config_file
config_file = io.open(config_filename, "w")
config_file:write(config)
config_file:close()

print("Wrote Kong config: "..rel_config_file)

-- Also set KONG env vars which **override** config file values.
-- write env vars to `.profile.d` file for Heroku runtime
-- https://devcenter.heroku.com/articles/profiled
local env_file
env_file = io.open(env_filename, "a+")

env_file:write("export KONG_PROXY_LISTEN=${KONG_PROXY_LISTEN:-"..proxy_listen.."}\n")
env_file:write("export KONG_PROXY_LISTEN_SSL=${KONG_PROXY_LISTEN_SSL:-"..proxy_listen_ssl.."}\n")
env_file:write("export KONG_ADMIN_LISTEN=${KONG_ADMIN_LISTEN:-"..admin_listen.."}\n")
env_file:write("export KONG_ADMIN_LISTEN_SSL=${KONG_ADMIN_LISTEN_SSL:-"..admin_listen_ssl.."}\n")

env_file:write("export KONG_PG_HOST="..pg_host.."\n")
env_file:write("export KONG_PG_PORT="..pg_port.."\n")
env_file:write("export KONG_PG_USER="..pg_user.."\n")
env_file:write("export KONG_PG_PASSWORD="..pg_password.."\n")
env_file:write("export KONG_PG_DATABASE="..pg_database.."\n")

-- env_file:seek("set", 0)
-- print(".profile.d/kong-env: \n"..env_file:read("*a"))

env_file:close()
print("Wrote environment exports: "..rel_env_file)
