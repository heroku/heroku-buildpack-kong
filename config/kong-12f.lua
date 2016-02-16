local etlua = require "etlua"
local lub = require "lub"
local _ = require "moses"

local S = require "serpent"

local constants = require "kong.constants"
local config_loader = require "kong.tools.config_loader"
local services = require "kong.cli.utils.services"
local cluster_utils = require "kong.tools.cluster"
local serf_service = require "kong.cli.services.serf"

-- 12-factor config generator for Kong
-- execute with `kong-12f {template-file} {destination-dir}`

-- Use shell command arguments to set file locations
-- first arg: the ETLUA template
-- second arg: the buildpack/app directory
local template_filename = arg[1]
local config_filename   = arg[2].."/config/kong.yml"
local cert_filename     = arg[2].."/config/cassandra.cert"

-- not an `*.sh` file, because the Dyno manager should not exec
local env_filename  = arg[2].."/.profile.d/kong-env"

-- Read environment variables for runtime config
local assigned_port     = os.getenv("PORT") or 8000
local expose_service    = os.getenv("KONG_EXPOSE") -- `proxy` (default), `admin`, `proxyssl`, `dnsmasq`

local cluster_secret    = os.getenv("KONG_CLUSTER_SECRET")
if not cluster_secret then
  error("Configuration failed: requires `KONG_CLUSTER_SECRET` environment variable; create with `serf keygen`.")
end
local cluster_port      = os.getenv("KONG_CLUSTER_PRIVATE_PORT") or 7946
local cluster_address   = os.getenv("KONG_CLUSTER_PRIVATE_IP")
if not cluster_address then
  error("Configuration failed: requires `KONG_CLUSTER_PRIVATE_IP` environment variable.")
end
local cluster_listen    = cluster_address..":"..cluster_port

-- Configure Cassandra using Instaclustr or Heroku-style config vars
local cassandra_hosts   = {}
local cassandra_user
local cassandra_password
local cassandra_keyspace
local cassandra_ssl     = false
local cassandra_cert

if os.getenv("IC_CONTACT_POINTS") ~= nil then
  -- Detect Instaclustr from the `IC_CONTACT_POINTS` config var
  cassandra_user        = os.getenv("IC_USER")
  cassandra_password    = os.getenv("IC_PASSWORD")
  cassandra_cert        = os.getenv("IC_CERTIFICATE")
  local port            = os.getenv("IC_PORT")
  cassandra_hosts       = _.map(
    lub.split(os.getenv("IC_CONTACT_POINTS"), ","),
    function(k,v)
      if port then
        return v..":"..port
      else
        return v
      end
    end
  )
elseif os.getenv("CASSANDRA_URL") ~= nil then
  -- Default to parsing `CASSANDRA_URL`,
  -- a comma-separated list of Heroku-style database URLs
  local url_pattern     = "cassandra://([^:]+):([^@]+)@([^/]+)/([^,]+)"
  local cassandra_url   = os.getenv("CASSANDRA_URL")
  for user, password, host, keyspace in string.gmatch(cassandra_url, url_pattern) do
    cassandra_user      = user
    cassandra_password  = password
    cassandra_keyspace  = keyspace
    table.insert(cassandra_hosts, host)
  end
  cassandra_cert        = os.getenv("CASSANDRA_TRUSTED_CERT") 
else
  error("Configuration failed: requires `CASSANDRA_URL` or `IC_CONTACT_POINTS` environment variable.")
end

-- Prefer replication factor of three or less (then, the number of hosts)
local cassandra_replication_factor = math.min(3, #cassandra_hosts)

-- Default keyspace to value of `CASSANDRA_KEYSPACE` or simply "kong".
cassandra_keyspace = cassandra_keyspace or os.getenv("CASSANDRA_KEYSPACE") or "kong"

-- SSL with Cassandra is enabled when a certificate was
-- provided via `CASSANDRA_TRUSTED_CERT` or `IC_CERTIFICATE`.
if cassandra_cert and string.match(cassandra_cert, '-----BEGIN CERTIFICATE-----') then
  local cert_file
  cert_file = io.open(cert_filename, "w")
  cert_file:write(cassandra_cert)
  cert_file:close()

  cassandra_ssl = true
end

-- Configure the service to expose on PORT
local proxy_port
local proxy_ssl_port
local admin_api_port
local dnsmasq_port
if expose_service == "admin" then
  print("Configuring as Kong admin API")
  proxy_port = 1 + assigned_port
  proxy_ssl_port = 2 + assigned_port
  admin_api_port = assigned_port
  dnsmasq_port = 3 + assigned_port
elseif expose_service == "proxyssl" then
  print("Configuring as Kong SSL proxy")
  proxy_port = 1 + assigned_port
  proxy_ssl_port = assigned_port
  admin_api_port = 2 + assigned_port
  dnsmasq_port = 3 + assigned_port
elseif expose_service == "dnsmasq" then
  print("Configuring as Kong dnsmasq")
  proxy_port = 1 + assigned_port
  proxy_ssl_port = 2 + assigned_port
  admin_api_port = 3 + assigned_port
  dnsmasq_port = assigned_port
else
  print("Configuring as Kong proxy")
  proxy_port = assigned_port
  proxy_ssl_port = 1 + assigned_port
  admin_api_port = 2 + assigned_port
  dnsmasq_port = 3 + assigned_port
end

-- Render the Kong configuration file
local template_file = io.open(template_filename, "r")
local template = etlua.compile(template_file:read("*a"))
template_file:close()

local values = {
  proxy_port          = proxy_port,
  proxy_ssl_port      = proxy_ssl_port,
  admin_api_port      = admin_api_port,
  cluster_listen      = cluster_listen,
  cluster_secret      = cluster_secret,
  dnsmasq_port        = dnsmasq_port,
  cassandra_hosts     = cassandra_hosts,
  cassandra_user      = cassandra_user,
  cassandra_password  = cassandra_password,
  cassandra_keyspace  = cassandra_keyspace,
  cassandra_ssl       = cassandra_ssl,
  cassandra_cert      = cert_filename,
  cassandra_replication_factor = cassandra_replication_factor
}

local config = template(values)

local config_file
config_file = io.open(config_filename, "w")
config_file:write(config)
config_file:close()

-- Call into kong.cli.services modules to prepare the services (nginx, dnsmasq, serf)

local configuration, configuration_path = config_loader.load_default(config_filename)
local prepared_services, err = services.prepare_all(configuration, configuration_path)
if err then
  error('Preparation of Kong services failed: '..err)
end

-- print("Kong configuration "..S.block(configuration))
-- print("Kong prepared_services "..S.block(prepared_services))

-- write env vars to `.profile.d` file for Heroku runtime
-- https://devcenter.heroku.com/articles/profiled
local env_file
env_file = io.open(env_filename, "a+")

env_file:write("export KONG_CONF="..prepared_services.nginx._configuration_path.."\n")

env_file:write("export NGINX_WORKING_DIR="..configuration.nginx_working_dir.."\n")
env_file:write("export NGINX_CONFIG="..constants.CLI.NGINX_CONFIG.."\n")

env_file:write("export DNSMASQ_PORT="..configuration.dns_resolver.port.."\n")

env_file:write("export SERF_CLUSTER_LISTEN="..configuration.cluster_listen.."\n")
env_file:write("export SERF_CLUSTER_LISTEN_RPC="..configuration.cluster_listen_rpc.."\n")
env_file:write("export SERF_ENCRYPT="..(configuration.cluster.encrypt or '""').."\n")
env_file:write("export SERF_NODE_NAME="..cluster_utils.get_node_name(configuration).."\n")
-- In the event handler, "kong" value is a copy of hardcoded,
-- local var `EVENT_NAME` in kong.cli.services.serf
env_file:write("export SERF_EVENT_HANDLER=".."member-join,member-leave,member-failed,member-update,member-reap,user:kong="..prepared_services.serf._script_path.."\n")

-- env_file:seek("set", 0)
-- print(".profile.d/kong-env.sh: \n"..env_file:read("*a"))

env_file:close()
