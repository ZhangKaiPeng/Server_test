--[[
	lrc4 - Native Lua/LuaJIT RC4 stream cipher library - https://github.com/CheyiLin/lrc4
	
	The MIT License (MIT)
	
	Copyright (c) 2015 Cheyi Lin <cheyi.lin@gmail.com>
	
	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:
	
	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.
	
	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
]]

local require = require
local setmetatable = setmetatable

local string_char = string.char
local table_concat = table.concat

local new_ks = function (key)
	local st = {}
	for i = 0, 255 do st[i] = i end
	
	local len = #key
	local j = 0
	for i = 0, 255 do
		j = (j + st[i] + key:byte((i % len) + 1)) % 256
		st[i], st[j] = st[j], st[i]
	end
	
	return {x=0, y=0, st=st}
end
		
	
local rc4_crypy = function (ks, input)
	local x, y, st = ks.x, ks.y, ks.st
	
	local t = {}
	for i = 1, #input do
		x = (x + 1) % 256
		y = (y + st[x]) % 256;
		st[x], st[y] = st[y], st[x]
		t[i] = string_char((input:byte(i) ~ (st[(st[x] + st[y]) % 256])))
	end
	
	ks.x, ks.y = x, y
	return table_concat(t)
end

local function new_rc4(m, key)
	local o = new_ks(key)
	return setmetatable(o, {__call=rc4_crypy, __metatable=false})
end


return setmetatable({}, {__call=new_rc4, __metatable=false})
