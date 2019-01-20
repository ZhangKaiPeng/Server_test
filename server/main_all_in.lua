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
    skynet.error(tostring(const.ITEM_TAG));




end)
