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
    local lobby = skynet.newservice("lobby")
    datacenter.set("server_address", "lobby", lobbys)

    -- 签到服务
	local sign_server = skynet.newservice("signin_server")
	datacenter.set("server_address", "signin_server", sign_server)

  
    print("Server Init Finish!", os.date("%Y%m%d", math.floor(skynet.time())))
    skynet.exit()

end)
