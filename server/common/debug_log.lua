function print_lua_table(log_info)
	local indent=0
	if type(log_info) ~="table" or (not log_info) then 
		print(log_info)
		return
	end
    
    for i,v in ipairs(log_info) do
    	if type(k) == "string" then
			k = string.format("%q", k)
		end
		local szSuffix = ""
		if type(v) == "table" then
			szSuffix = "{"
		end
		local szPrefix = string.rep("    ", indent)
		formatting = szPrefix.."["..k.."]".." = "..szSuffix
		if type(v) == "table" then
			print(formatting)
			print_lua_table(v, indent + 1)
			print(szPrefix.."},")
		else
			local szValue = ""
			if type(v) == "string" then
				szValue = string.format("%q", v)
			else
				szValue = tostring(v)
			end
			print(formatting..szValue..",")
		end
    end
end

function logv( ... )
	local arg = {...}
	for i=1,#arg do
		print_lua_table(arg[i])
	end
end