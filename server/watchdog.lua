package.path = "./server/?.lua;" .. package.path

local skynet = require "skynet"
local netpack = require "skynet.netpack"
local cjson = require "cjson"
local zlib = require "zlib"
local socket = require "skynet.socket"
local table = table
local datacenter = require "skynet.datacenter"
local args = {...}
local cluster = require "skynet.cluster"
local httpc = require "http.httpc"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"
local rc4 = require "common.rc4"

local verifyer_index_table = {
	["dy_login_wrapper"] = require "login.dy_login_wrapper",
	["xianyu_login_wrapper"] = require "login.xianyu_login_wrapper",
	["xiaomi_login_wrapper"] = require "login.xiaomi_login_wrapper",
	["oppo_login_wrapper"] = require "login.oppo_login_wrapper",
	["qihu360_login_wrapper"] = require "login.qihu360_login_wrapper",
	["huawei_login_wrapper"] = require "login.huawei_login_wrapper",
	["uc_login_wrapper"] = require "login.uc_login_wrapper",
	["vivo_login_wrapper"] = require "login.vivo_login_wrapper",
	["ysdk_login_wrapper"] = require "login.ysdk_login_wrapper",
	["bd_login_wrapper"] = require "login.bd_login_wrapper",
	["dy_unitization_login_wrapper"] = require "login.dy_unitization_login_wrapper",
	["facebook_login_wrapper"] = require "login.facebook_login_wrapper"
}

local verifyer_table = {}
local RC4_DEFAULT_KEY = skynet.getenv("dy_rc4_default_key")

require "skynet.manager"
require "common.debug_log"
require "common.function"
require "const.const"

CMD = {}
local SOCKET = {}
local gate
local agent = {}
local cache_permit_id = {}
local limit_ip_list = {}
local limit_account_id_list = {}
local dispatch_version = {}
local watchdog_login_token = {}

-- server address
local lobby_server = nil
local datahandle_server = nil
local cluster_balancer = nil

local socket_format_func = nil

local local_nodename = skynet.getenv("cluster_nodename")

local client_num = 0
local max_client_num = nil

local dispatch_avilable = true
local alert_send = false

local watchdog_address = nil
local sproto_host = nil
local send_request = nil

local BASE_PLAYER_STEP = 10000
function caculate_available_player_id(player_id, step)
    return BASE_PLAYER_STEP + step
end

function login_status_check(account_id, uid, device_identify, login_platform, login_channel, session, fd, ip)
	local info = skynet.call(datahandle_server, "lua", "find_one", "idfa_active_table", {idfa = idfa, channel = "heshengyiming"})
	if info then
		local response_code, response_data = httpc.get(info.callback)
		if response_code == 200 then
			local data = cjson.decode(response_data)
			if data.success then
				info.avilable = false
				skynet.call(datahandle_server, "lua", "update_data", "idfa_active_table", {idfa = idfa, channel = "heshengyiming"}, info, {upsert = true})
			end
		end
	end
end

function SOCKET.open(fd, addr)
	skynet.error("New client from : " .. addr)
	skynet.call(gate,"lua","forward",fd)

	-- stop dispatch when player full
	if dispatch_avilable and CMD.get_client_num_score() >= 0.9 then
		if not alert_send then
			alert_send = true
			skynet.call(cluster_balancer, "lua", "node_send_alert", "WATCHDOG client num over 90%, unregister balancer form agent_balancer")
		end
		local ok, err = skynet.pcall(function ( ... )
			log_warnning("too much client, current client ".. client_num .. " max client " .. max_client_num)
			local agent_balancer = datacenter.get("server_address", "agent_balancer_proxy")
			if agent_balancer then
				skynet.call(agent_balancer, "lua", "unregister_balancer", watchdog_address)
			end
			dispatch_avilable = false
		end)
		if not ok then
			log_info(err)
		end
	end
end

local function close_agent(fd)
	local a = agent[fd]
	if a then
		agent[fd] = nil
		local player_id = skynet.call(a, "lua", "get_agent_player_id")
		skynet.call(lobby_server, "lua", "lobby_unregister_player", a)
		skynet.call(cluster_balancer, "lua", "unregister_local_player_agent_address", a)
		skynet.call(datahandle_server, "lua", "insert_data", "watchdog_logout", {player_id = player_id, time = os.time()})
		skynet.send(a, "lua", "quit_self")
		socket.close(fd)

		client_num = client_num - 1

		if not dispatch_avilable and CMD.get_client_num_score() < 0.7 then
			if alert_send then
				alert_send = false
				skynet.call(cluster_balancer, "lua", "node_send_announcement", "WATCHDOG client num CHEK PASS, register balancer to agent_balancer")
			end
			local ok, err = skynet.pcall(function ( ... )
				local agent_balancer = datacenter.get("server_address", "agent_balancer_proxy")
				if agent_balancer then
					skynet.call(agent_balancer, "lua", "register_balancer", watchdog_address, nil, nil, datacenter.get("config_cache", "dy_game_version"), skynet.getenv("dy_game_avilable_platform"), SERVER_VERIFY_MODE, SERVER_TEST_MODE, skynet.getenv("dispatch_avilable_channel"))
				end
				dispatch_avilable = true
			end)
			if not ok then
				log_info(err)
			end
		end
	end
end

function SOCKET.close(fd)
	log_info("socket close",fd)
	close_agent(fd)
end

function SOCKET.error(fd, msg)
	log_info("socket error",fd, msg)
	close_agent(fd)
end

function SOCKET.warning(fd, size)
	-- size K bytes havn't send out in fd
	log_info("socket warning", fd, size)
end

function CMD.agent_timeout(timeout_agent)
	local fd, fd_agent, timeout_f = nil, nil, nil
	log_info("socket error agent timeout",timeout_agent)
	for fd, fd_agent in pairs(agent) do 
		if fd_agent == timeout_agent then
			timeout_fd = fd
			break
		end
	end
	if timeout_fd then
		close_agent(timeout_fd)
		agent[timeout_fd] = nil
	end
end

local function response_to_client(fd, pack)
	local str = nil
	local send_rc4 = rc4(RC4_DEFAULT_KEY)
	if #pack < 100 then
		str = "\0"
	else
		str = "\1"
	end

	if str == "\1" then
		package = socket_format_func(str .. send_rc4(zlib.deflate(9,31)(pack, "finish")))
	else
		package = socket_format_func(str .. send_rc4(pack))
	end
	socket.write(fd, package)
end

function watchdog_token_login(token, device_identify, login_platform, login_channel, response, fd, ip)
	if not watchdog_login_token[token] or watchdog_login_token[token].outdate < os.time() then
		response_to_client(fd, response({result = ErrorCode.invalid_login, in_battle = false}))
		socket.close(fd)
		return 
	end

	local login = skynet.call(datahandle_server, "lua", "find_one", "login", {player_id = watchdog_login_token[token].player_id})
	if not login then
		response_to_client(fd, response({result = ErrorCode.invalid_login, in_battle = false}))
		socket.close(fd)
		return
	end

	-- 封号
	local time = os.time()
	if ((login.login_ban_start_time == login.login_ban_end_time and (login.login_ban_end_time or 0) == -1) or (time >= (login.login_ban_start_time or 0) and time <= (login.login_ban_end_time or 0))) then
		response_to_client(fd, response({result = ErrorCode.login_baned, in_battle = false}))
		socket.close(fd)
		return	
	end

	local old_agent = skynet.call(lobby_server, "lua", "lobby_get_register_player_agent", login.player_id)
	if old_agent then
		log_info("player login repeat",login.player_id)
		local old_agent_nodename = skynet.call(lobby_server, "lua", "lobby_get_register_player_nodename", login.player_id)
		skynet.pcall(function()
			if old_agent_nodename == local_nodename then
				skynet.call(old_agent, "lua", "kicking_clean_up")
				skynet.call(old_agent, "lua", "system_error",ErrorCode.repeat_login) 
				skynet.call(old_agent, "lua", "agent_timeout")
			else
				cluster.call(old_agent_nodename, old_agent, "kicking_clean_up")
				cluster.call(old_agent_nodename, old_agent, "system_error",ErrorCode.repeat_login) 
				cluster.call(old_agent_nodename, old_agent, "agent_timeout")
			end
		end)
	end
	agent[fd] = CMD.start_local_player_agent(login.player_id, lobby_server, login_platform, login_channel, extern_param, args[1])
	skynet.call(gate, "lua", "set_agent", fd, agent[fd])
	local start_ret = skynet.call(agent[fd], "lua", "start", fd, login.player_id, session, unique_id, skynet.self(), login_channel)
    
	pcall(login_status_check, account_id, uid, device_identify, login_platform, login_channel, session, fd, ip)

	-- 登陆LOG
    if agent[fd] then
        skynet.call(datahandle_server, "lua", "insert_data", "watchdog_login", {player_id = login.player_id, time = os.time()})
    end

    response_to_client(fd, response({result = ErrorCode.ok, in_battle = start_ret.in_battle}))

    -- 登陆后处理
    skynet.call(agent[fd], "lua", "init_player_post_login_event")

    watchdog_login_token[token] = nil
end


function watchdog_system_login(account_id, uid, device_identify, login_platform, login_channel, response, fd, ip)
	local unique_id = nil
	local extern_param = nil
	print ("watchdog login", account_id, uid)
	if SERVER_DEBUG_MODE then
		unique_id = account_id
	else
		if account_id then 
			local login_verifior = verifyer_table[login_channel]
			if not login_verifior then
				login_verifior = verifyer_index_table["facebook_login_wrapper"]
			end

			unique_id, extern_param = login_verifior.verify_login(account_id, uid)
			if not unique_id then 
				response_to_client(fd, response({result = ErrorCode.invalid_login, in_battle = false}))
				socket.close(fd)
				return	
			end
		else
			response_to_client(fd, response({result = ErrorCode.invalid_login, in_battle = false}))
			socket.close(fd)
			return	
		end
	end

	local login_acction_list = skynet.call(datahandle_server, "lua", "find_all", "login", {uid = unique_id})
	local login = login_acction_list[1] -- 账号选择
	if not login then
		login = CMD.create_login_info(unique_id)
	end

	-- 封号
	local time = os.time()
	if ((login.login_ban_start_time == login.login_ban_end_time and (login.login_ban_end_time or 0) == -1) or (time >= (login.login_ban_start_time or 0) and time <= (login.login_ban_end_time or 0))) then
		response_to_client(fd, response({result = ErrorCode.login_baned, in_battle = false}))
		socket.close(fd)
		return	
	end

	client_num = client_num + 1

	local old_agent = skynet.call(lobby_server, "lua", "lobby_get_register_player_agent", login.player_id)
	if old_agent then
		log_info("player login repeat",login.player_id)
		local old_agent_nodename = skynet.call(lobby_server, "lua", "lobby_get_register_player_nodename", login.player_id)
		skynet.pcall(function()
			if old_agent_nodename == local_nodename then
				skynet.call(old_agent, "lua", "kicking_clean_up")
				skynet.call(old_agent, "lua", "system_error",ErrorCode.repeat_login) 
				skynet.call(old_agent, "lua", "agent_timeout")
			else
				cluster.call(old_agent_nodename, old_agent, "kicking_clean_up")
				cluster.call(old_agent_nodename, old_agent, "system_error",ErrorCode.repeat_login) 
				cluster.call(old_agent_nodename, old_agent, "agent_timeout")
			end
		end)
	end
	agent[fd] = CMD.start_local_player_agent(login.player_id, lobby_server, login_platform, login_channel, extern_param, args[1])
	skynet.call(gate, "lua", "set_agent", fd, agent[fd])
	local start_ret = skynet.call(agent[fd], "lua", "start", fd, login.player_id, session, unique_id, skynet.self(), login_channel)
    
	pcall(login_status_check, account_id, uid, device_identify, login_platform, login_channel, session, fd, ip)

	-- 登陆LOG
    if agent[fd] then
        skynet.call(datahandle_server, "lua", "insert_data", "watchdog_login", {player_id = login.player_id, time = os.time()})
    end

    response_to_client(fd, response({result = ErrorCode.ok, in_battle = start_ret.in_battle}))

    -- 登陆后处理
    skynet.call(agent[fd], "lua", "init_player_post_login_event")
end

function SOCKET.data(fd, msg, sz, ip)
	local byte_str = skynet.tostring(msg,sz)
	local request_rc4 = rc4(RC4_DEFAULT_KEY)
    local decode_type =  string.sub(byte_str, 1, 1)
    local decode_str = request_rc4(string.sub(byte_str, 2, -1))
    if decode_type == "\1" then
       	decode_str = zlib.inflate()(decode_str)
    end
	local _, name, data, response = sproto_host:dispatch(decode_str, #decode_str)

	local proto_name = name
	local version = data.version
	local account_id = data.account_id
	local uid = data.uid
	local device_identify = data.device_identify
	local login_platform = data.platform
	local login_channel = data.channel
	local login_token = data.token
	log_info("watchdog expect system_login",proto_name,ip)

	local login_avilable = datacenter.get("server_status", "login_avilable")
	if login_avilable and #limit_ip_list > 0 and not SERVER_DEBUG_MODE then
		local i
		login_avilable = false
		for i = 1, #limit_ip_list do
			if limit_ip_list[i] == split(ip , ":")[1] then
				login_avilable = true
			end
		end
	end

	if login_avilable and #limit_account_id_list > 0 and not SERVER_DEBUG_MODE then
		local i
		login_avilable = false
		for i = 1, #limit_account_id_list do
			if limit_account_id_list[i] == account_id then
				login_avilable = true
			end
		end
	end

	print ("server debug mode", SERVER_DEBUG_MODE, proto_name, login_avilable)

	if proto_name and proto_name == "system_login" and (SERVER_DEBUG_MODE or (version and dispatch_version[version])) and login_avilable then
		watchdog_system_login(account_id, uid, device_identify, login_platform, login_channel, response, fd, ip, args[1])
	elseif proto_name and proto_name == "system_token_login" and (SERVER_DEBUG_MODE or (version and dispatch_version[version])) and login_avilable then
		watchdog_token_login(login_token, device_identify, login_platform, login_channel, response, fd, ip, args[1])
	else
		response_to_client(fd, response({
			result = ErrorCode.invalid_version,
		}))
		socket.close(fd)
	end
end

function CMD.reset_limit_ip_list( ... )
	limit_ip_list = {...}
end

function CMD.reset_limit_account_id_list( ... )
	limit_account_id_list = {...}
end

function CMD.reset_agentbalancer_address( ... )
	local agent_balancer = datacenter.get("server_address", "agent_balancer_proxy")
	skynet.call(agent_balancer, "lua", "unregister_balancer", watchdog_address)
	skynet.call(agent_balancer, "lua", "register_balancer", watchdog_address, nil, nil, datacenter.get("config_cache", "dy_game_version"), skynet.getenv("dy_game_avilable_platform"), SERVER_VERIFY_MODE, SERVER_TEST_MODE, skynet.getenv("dispatch_avilable_channel"))
end

function CMD.start(conf)
	max_client_num = conf.maxclient
	skynet.call(gate, "lua", "open" , conf)
end

function CMD.get_client_num( ... )
	return client_num
end

function CMD.get_client_num_score( ... )
	return client_num / max_client_num
end

function CMD.create_login_info(unique_id, ... )
    local login = nil
    -- local login_info = skynet.call(datahandle_server, "lua", "find_and_modify", "login_info", {query = {name = "login_info"}, update = {["$inc"] = {max_player_id = 1}}, new = true, upsert = true})
    local login_info = skynet.call(datahandle_server, "lua", "find_and_field_increase", "login_info", {name = "login_info"}, "max_player_id", 1)
    login = {uid = unique_id, player_id = login_info.max_player_id}
    login.player_id = caculate_available_player_id(login.player_id, login_info.max_player_id)
    skynet.call(datahandle_server, "lua", "insert_data", "login", login)
    return login
end

function CMD.register_token_login_key(player_id, token, ...)
	watchdog_login_token[token] = {player_id = player_id, outdate = os.time() + 60}
end

function CMD.reset_master_address( ... )
    lobby_server = datacenter.get("server_address", "lobby")
end

function CMD.init(host, ...)
	sproto_host = sprotoloader.load(1):host "package"
	send_request = sproto_host:attach(sprotoloader.load(2))

	lobby_server = datacenter.get("server_address", "lobby")
	datahandle_server = datacenter.get("server_address", "datahandle")
	cluster_balancer = ".clusterbalance"
	watchdog_address = host

	skynet.pcall(function ( ... )
		local dy_game_version = skynet.getenv("dy_game_version")
		game_version_list = split(dy_game_version, ";")
		local i
		for i = 1, #game_version_list do
			dispatch_version[game_version_list[i]] = true
		end
	end)

	skynet.pcall(function ( ... )
		local white_list_config = skynet.getenv("watchdog_white_list")
		limit_account_id_list = split(white_list_config, ";")
		log_info("watchdog init white list", table.concat(limit_account_id_list, ","))
	end)

	if #limit_account_id_list > 0 then
		log_info("watchdog init account white list active")
	else
		log_info("watchdog init account white list inactive")
	end

	skynet.pcall(function ( ... )
		local white_list_config = skynet.getenv("watchdog_ip_list")
		limit_ip_list = split(white_list_config, ";")
		log_info("watchdog init white list", table.concat(limit_ip_list, ","))
	end)

	if #limit_ip_list > 0 then
		log_info("watchdog init ip white list active")
	else
		log_info("watchdog init ip white list inactive")
	end

	skynet.pcall(function ( ... )
		local channel_list_config = skynet.getenv("channel_login_wrapper_list")
		channel_item = split(channel_list_config, ";")
		local i 
		for i = 1, #channel_item do
			local wrapper_channel_list = split(channel_item[i], ":")
			if #wrapper_channel_list == 2 then
				log_info("setup channel " .. wrapper_channel_list[1] .. " wrapper " .. wrapper_channel_list[2])
				verifyer_table[wrapper_channel_list[1]] = verifyer_index_table[wrapper_channel_list[2]]
			end
		end
	end)
end

function CMD.reset_channel_login_wrapper(read_string, ...)
	local channel_list_config = read_string
	channel_item = split(channel_list_config, ";")
	local i 
	for i = 1, #channel_item do
		local wrapper_channel_list = split(channel_item[i], ":")
		if #wrapper_channel_list == 2 then
			log_info("setup channel " .. wrapper_channel_list[1] .. " wrapper " .. wrapper_channel_list[2])
			verifyer_table[wrapper_channel_list[1]] = verifyer_index_table[wrapper_channel_list[2]]
		end
	end
end

function CMD.start_local_player_agent(player_id, lobby, login_platform, login_channel, extern_param, args)
	log_info("agent balancer create new_agent")
    
    local new_agent = skynet.newservice("agent", args)

    if new_agent then 
    	skynet.call(cluster_balancer, "lua", "register_local_player_agent_address", player_id, new_agent, login_platform, login_channel, extern_param)
    	skynet.call(lobby, "lua", "lobby_register_player", player_id, new_agent, local_nodename, login_platform, login_channel, extern_param)
    end
    return new_agent
end

skynet.start(function()
	local old_print = print
    print = function(...)
        skynet.error("[Watchdog]", ...)
    end

	log_info ("sanguokill2 watchdog start!")

	-- skynet.timeout(1000, function( ... )
	-- 	print ("fb login test")
	-- 	local login_verifior = verifyer_index_table["facebook_login_wrapper"]
	-- 	login_verifior:verify_login("629836964080807", "EAACfuwsRHekBAJKIlt4BURghLkE4XbY1fVU58uNNU6ueQBIxdRJ1JsjNUgPEIfqQgqVM4Rpr7pHaZBZBaRVV459AGG3la9H9QoZBm0c16zgNxDGd9F1QpB0o6OuoCOCj0KOWKLIgXGZC4PSYygSjrSAuEiNrKWwcLvzF0kBZCrP0lzyCZAQU2GYSeZB2ld7CqrpnmoK4HK6Bx4qAwq7Mh5zEq0PijRZATjoZD")
	-- end)
	

	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
		if cmd == "socket" then
			local f = SOCKET[subcmd]
			f(...)
			-- socket api don't need return
		else
			local f = CMD[cmd]
			if f then
				skynet.ret(skynet.pack(f(subcmd, ...)))
			else
				if cmd ~= "LINK" then
					print ("watchdog call error", cmd)
					assert(false)
				end
			end
		end
	end)

	if args[1] == "websocket" then
		gate = skynet.newservice("sgkwsgate")
		socket_format_func = function ( ... )
			return format_websocket_frame(true, 0x2, false, string.pack(">s2", ...))
		end
	else
		gate = skynet.newservice("sgkgate")
		socket_format_func = function ( ... )
			return string.pack(">s2", ...)
		end
	end
end)
