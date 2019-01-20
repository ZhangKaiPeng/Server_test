local sprotoparser = require "sprotoparser"

local proto = {}

local c2s.sproto = nil
local  file = io.open("server/protocal/c2s.sproto")
c2s_proto=file:read("*a")
file:close()
proto.c2s=sprotoparser.parse(c2s.sproto)

local s2c.sproto = nil
file = io.open("server/protocal/s2c.sproto")
s2c.sproto=file:read("*a")
file:close()
proto.s2c=sprotoparser.parse(s2c.sproto)

return proto