local socket = require "skynet.socket"
local retry_table = {}

function pack_udp_data(session, data, ... )
	return string.pack(">I4s2", session, data)
end

function unpack_udp_date(str, ...)
	local session, data = string.unpack(">I4s2", str)
	return session, data
end

function check_package_ack(session, data, ...)
	if session == 0 then
		return tonumber(data)
	end
end

-- a 0 session for ack
function pack_udp_ack(session, ...)
	return pack_udp_data(0, session)
end

function clear_udp_package_retry(session, ...)
	retry_table[session] = nil
end

-- session index the data, and how session pack in data handle by the high level
function udp_write_socket(fd, data, session, dest, retry_count, ...)
	if session and session > 0 and retry_count ~= 0 then -- seesion 0 is not retry usually use in ack
		retry_table[session] = {data = data, dest = dest, timeout = os.time() + 3, retry_count = retry_count or 5}
	end

	socket.sendto(fd, dest, data)
end

function check_and_resend_udp_package(fd, ...)
	local k, v
	local now = os.time()
	local remove_list = {}
	for k, v in pairs(retry_table) do
		if v and v.timeout <= now then
			v.retry_count = v.retry_count - 1
			udp_write_socket(fd, v.data, k, v.dest, v.retry_count)
			table.insert(remove_list, k)
		end
	end

	local i
	for i = 1, #remove_list do
		retry_table[remove_list[i]] = nil
	end
end