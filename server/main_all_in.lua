package.path = "./server/?.lua;" .. package.path
local skynet=require "skynet"
local datacenter=require "skynet.datacenter"
local cluster=require "skynet.cluster"
local const =require "server_const.const"
require "common.function"

--设置ENV
setup_env()

skynet.start(function()
    
    skynet.error("Server Main Start!!!") 
    
    local t = 1
    if t == const.ITEM_TAG then 
    	skynet.error("equal")
    else
        skynet.error("not equal")
    end 




end)
