local sprotoparser = require "sprotoparser"

local proto = {}

local c2s_proto = nil
local  file = io.open("server/protocal/c2s.sproto")
c2s_proto=file:read("*a")
file:close()
proto.c2s=sprotoparser.parse(c2s_proto)

local s2c_proto = nil
file = io.open("server/protocal/s2c.sproto")
s2c_proto=file:read("*a")
file:close()
proto.s2c=sprotoparser.parse(s2c_proto)

return proto