package.path = "./server/?.lua;" .. package.path
local skynet=require "skynet"
local datacenter=require "skynet.datacenter"
local cluster=require "skynet.cluster"
require "common.function"
require "server_const.const"

--设置ENV
setup_env()

local watchdog_port = 8888
local max_client = 64

skynet.start(function()
    
    skynet.error("Server Start!!!") 
    
    --启动唯一服务(协议加载)
    skynet.uniqueservice("protoloader") 
   
    -- listen
    skynet.newservice("debug_console",8000)
    skynet.newservice("simpledb")
    local watchdog = skynet.newservice("watchdog")
    skynet.call(watchdog, "lua", "start", {
        port = watchdog_port,
        maxclient = max_client,
        nodelay = true,
    })
    skynet.error("Watchdog listen on", watchdog_port)

    --大厅服务
    local lobby = skynet.newservice("cus_server_lobby")
    datacenter.set("server_address", "cus_server_lobby", lobby)
    
    skynet.error("Server Init Finish!!!") 
    skynet.exit()

end)
