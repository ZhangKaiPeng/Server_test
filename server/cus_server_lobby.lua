-- 大厅服务
package.path = "./server/?.lua;" .. package.path
local skynet = require "skynet"
require "common.lua_class"
require "skynet.manager"
require "common.function"
local datacenter = require "skynet.datacenter"
local cluster = require "skynet.cluster"
local local_nodename = skynet.getenv("cluster_nodename")

skynet.start(function ()
	-- body
	skynet.register("cus_server_lobby")
    skynet.error("cus_server_lobby server start")

end)
