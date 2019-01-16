package.path = "./server/?.lua;" .. package.path
local skynet=require "skynet"
local datacenter=require "skynet.datacenter"
local cluster=require "skynet.cluster"


skynet.start(function()
    local const =require "server_const.const"
    skynet.error("Server Main Start!!!") 
    





end)
