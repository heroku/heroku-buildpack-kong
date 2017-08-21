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
local template_filename = arg[1]
local config_filename   = arg[2].."/"..rel_config_file

-- not an `*.sh` file, because the Dyno manager should not exec
local env_filename  = arg[2].."/"..rel_env_file

-- Read environment variables for runtime config
local assigned_port     = os.getenv("PORT") or 8000
local expose_service    = os.getenv("KONG_EXPOSE") -- `proxy` (default), `admin`, `proxyssl`
local pg_url            = os.getenv("DATABASE_URL") or "postgres://localhost:5432/kong_dev"

local parsed_pg_url = url.parse(pg_url, default)

local pg_host = parsed_pg_url.host
local pg_port = parsed_pg_url.port
local pg_user = parsed_pg_url.user
local pg_password = parsed_pg_url.password
local pg_dbname = string.sub(parsed_pg_url.path, 2, -1)

-- Configure the service to expose on PORT
local proxy_port
local proxy_ssl_port
local admin_api_port
if expose_service == "admin" then
  print("Configuring as Kong admin API")
  proxy_port = 1 + assigned_port
  proxy_ssl_port = 2 + assigned_port
  admin_api_port = assigned_port
elseif expose_service == "proxyssl" then
  print("Configuring as Kong SSL proxy")
  proxy_port = 1 + assigned_port
  proxy_ssl_port = assigned_port
  admin_api_port = 2 + assigned_port
else
  print("Configuring as Kong proxy")
  proxy_port = assigned_port
  proxy_ssl_port = 1 + assigned_port
  admin_api_port = 2 + assigned_port
end

-- Render the Kong configuration file
local template_file = io.open(template_filename, "r")
local template = etlua.compile(template_file:read("*a"))
template_file:close()

local values = {
  proxy_port          = proxy_port,
  proxy_ssl_port      = proxy_ssl_port,
  admin_api_port      = admin_api_port,
  pg_host             = pg_host,
  pg_port             = pg_port,
  pg_user             = pg_user,
  pg_password         = pg_password,
  pg_dbname           = pg_dbname
}

local config = template(values)

local config_file
config_file = io.open(config_filename, "w")
config_file:write(config)
config_file:close()

print("Wrote Kong config: "..rel_config_file)

-- write env vars to `.profile.d` file for Heroku runtime
-- https://devcenter.heroku.com/articles/profiled
local env_file
env_file = io.open(env_filename, "a+")

-- env_file:write("export KONG_CONF=helloworld\n")

-- env_file:seek("set", 0)
-- print(".profile.d/kong-env.sh: \n"..env_file:read("*a"))

env_file:close()
print("Wrote environment exports: "..rel_env_file)
