package.path = "./server/?.lua;" .. package.path
local skynet=require "skynet"
local datacenter=require "skynet.datacenter"
local cluster=require "skynet.cluster"
require "common.function"
require "server_const.const"

--设置ENV
setup_env()

local watchdog_port = tonumber(skynet.getenv("normal_watchdog_port"))
local max_client = tonumber(skynet.getenv("max_client_num"))

skynet.start(function()
    
    skynet.error("Server Main Start!!!") 
    
    --启动唯一服务(协议加载)
    skynet.uniqueservice("protoloader") 
   
    
    -- 签到服务
	local sign_server = skynet.newservice("signin_server")
	datacenter.set("server_address", "signin_server", sign_server)

end)
