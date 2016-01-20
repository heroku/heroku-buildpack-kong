local etlua = require "etlua"

-- 12-factor config generator for Kong
-- execute with `kong-12f {template-file} {destination-dir}`

-- Reads envirnoment variables for runtime config
local cassandra_url     = os.getenv("CASSANDRA_URL")
local cassandra_cert    = os.getenv("CASSANDRA_TRUSTED_CERT")
local assigned_port     = os.getenv("PORT") or 8000
local expose_service    = os.getenv("KONG_EXPOSE") -- `proxy` (default), `admin`, `proxyssl`, `dnsmasq`

local template_filename = arg[1]
local config_filename   = arg[2].."/kong.yml"
local cert_filename     = arg[2].."/cassandra.cert"

local proxy_port
local proxy_ssl_port
local admin_api_port
local dnsmasq_port

-- Configure the service to expose on PORT
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

-- Expand the comma-delimited list of Cassandra nodes
local cassandra_hosts = {}
local cassandra_user
local cassandra_password
local cassandra_keyspace
for user, password, host, keyspace in string.gmatch(cassandra_url, "cassandra://([^:]+):([^@]+)@([^/]+)/([^,]+)") do
  cassandra_user      = user
  cassandra_password  = password
  cassandra_keyspace  = keyspace
  table.insert(cassandra_hosts, host)
end

-- Render the Kong configuration file
local template_file = io.open(template_filename, "r")
local template = etlua.compile(template_file:read("*a"))
template_file:close()

local config = template({
  proxy_port          = proxy_port,
  proxy_ssl_port      = proxy_ssl_port,
  admin_api_port      = admin_api_port,
  dnsmasq_port        = dnsmasq_port,
  cassandra_hosts     = cassandra_hosts,
  cassandra_user      = cassandra_user,
  cassandra_password  = cassandra_password,
  cassandra_keyspace  = cassandra_keyspace,
  cassandra_cert      = cert_filename
})

local file
file = io.open(config_filename, "w")
file:write(config)
file:close()

file = io.open(cert_filename, "w")
file:write(cassandra_cert)
file:close()
