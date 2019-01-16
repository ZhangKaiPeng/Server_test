package.path = "./server/?.lua;" .. package.path
local skynet=require "skynet"
local datacenter=require "skynet.datacenter"
local cluster=require "skynet.cluster"


skynet.start(function()
    local const =require "const"
    skynet.error("Server Main Start!!!") 
    print(const.playername)





end)
