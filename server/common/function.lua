require "common.hotfix"
local skynet = require "skynet"
local cluster = require "skynet.cluster"
local datacenter = require "skynet.datacenter"
local local_nodename = skynet.getenv("cluster_nodename")


function dy_pow(a, x)
    return a ^ x
end

function log_error( ... )
    print (os.date("[%c]") ,"[ERROR]", ...)
end

function log_warnning( ... )
    print (os.date("[%c]") ,"[WARN]", ...)
end

function log_info( ... )
    print (os.date("[%c]") ,"[INFO]", ...)
end

function split(szFullString, szSeparator)  
    local nFindStartIndex = 1  
    local nSplitIndex = 1  
    local nSplitArray = {}  
    while true do  
       local nFindLastIndex = string.find(szFullString, szSeparator, nFindStartIndex)  
       if not nFindLastIndex then  
        nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, string.len(szFullString))  
        break  
       end  
       nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, nFindLastIndex - 1)  
       nFindStartIndex = nFindLastIndex + string.len(szSeparator)  
       nSplitIndex = nSplitIndex + 1  
    end  
    return nSplitArray  
 end 

 function map(table, func, iter)
 	local iter = iter or pairs
 	local t = {}
 	for k, v in iter(table) do
 		t[k] = func(v)
 	end
 	return t
 end 

function midnight_click_diff()
    local cur_time_info = map(split(os.date("%H,%M,%S"),","),tonumber)
    return (23 - cur_time_info[1])*3600 + (59 - cur_time_info[2])*60 + 60 - cur_time_info[3]
end

function get_today_midnight_click()
    return os.time() + midnight_click_diff()
end

function get_system_refresh_daily_task_diff_click()
    local cur_click = os.time()
    local cur_time_info = map(split(os.date("%H,%M,%S"),","),tonumber)
    local sleep_click = 0
    if cur_time_info[1] > 3 then 
        local extra_lick = 14400
        local midnight_click = midnight_click_diff()
        sleep_click = midnight_click + extra_lick
    else
        sleep_click = (3 - cur_time_info[1])*3600 + (59 - cur_time_info[2])*60 + 60 - cur_time_info[3]
    end
    return sleep_click
end

function get_system_refresh_daily_task_absolute_click()
    return os.time() + get_system_refresh_daily_task_diff_click()
end

function get_system_refresh_daily_task_sleep_click()
    local sleep_click = get_system_refresh_daily_task_diff_click()
    log_info("sleep diff click",sleep_click)
    return math.ceil(sleep_click * 100)
end
 
function shuffle(list)
    -- make and fill array of indices
    local indices = {}
    local shuffled = {}
    for i = 1, #list do
        table.insert(shuffled, list[i])
    end

    for i = 1, #shuffled - 1 do
        local index = math.random(#shuffled - i) + i
        local temp = shuffled[i]
        shuffled[i] = shuffled[index]
        shuffled[index] = temp
    end

    return shuffled
end

function int_weight_shuffle(list)
    local shuffled = {}
    local weight_sum = 0
    table.sort(list, function(a,b)
        return a.weight < b.weight
    end)
    
    for i = 1, #list do
        weight_sum = weight_sum + list[i].weight
    end
    local random_index = math.random(1, weight_sum)
    local return_num = nil
    local tmp_num = 0
    for i = 1, #list do
        tmp_num = tmp_num + list[i].weight

        if random_index < tmp_num then
            return_num = list[i].value
            break
        end
    end   
    if not return_num then
        log_error("weight_shuffle error no return_num")
    end 
    return return_num
end

function simple_deepcopy(list)
    local t = {}
    for k,v in pairs(list) do 
        if type(v) == "table" then 
            t[k] = simple_deepcopy(v)
        else
            t[k] = v
        end
    end
    return t
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function simple_deepassignment(list, target)
    local t = target or {}
    for k,v in pairs(list) do 
        if type(v) == "table" then 
            t[k] = t[k] or {}
            t[k] = simple_deepassignment(v, t[k])
        else
            t[k] = v
        end
    end
    return t
end

function urlencode(str)
   if (str) then
      str = string.gsub (str, "\n", "\r\n")
      str = string.gsub (str, "([^%w ])",
         function (c) return string.format ("%%%02X", string.byte(c)) end)
      str = string.gsub (str, " ", "+")
   end
   return str    
end

function urldecode(s)
    s = string.gsub(s, '%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)
    return s
end

function iso_datepars(str)
    local datetime = str
    local pattern = "(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)"
    local xyear, xmonth, xday, xhour, xminute, 
            xseconds, xmillies, xoffset = datetime:match(pattern)
    
    local convertedTimestamp = os.time({year = xyear, month = xmonth, day = xday, hour = xhour, min = xminute, sec = xseconds})
    return convertedTimestamp
end

function list_contain(list, target, ...)
    local i
    for i = 1, #list do
        if list[i] == target then
            return true
        end
    end
    return false
end

-- {{weight = 0, target = 0}}
function weight_select(select_list, ...)
    local total_weight = 0
    local i = 1
    local match_list = {}
    local shuffle_select_list = shuffle(select_list)
    for i = 1, #shuffle_select_list do
        if shuffle_select_list[i].weight > 0 then
            total_weight = shuffle_select_list[i].weight + total_weight
            table.insert(match_list, {weight = total_weight, target = shuffle_select_list[i].target})
        end
    end

    if total_weight > 0 then
        local random_weight = math.random(total_weight)
        for i = 1, #match_list do
            if match_list[i].weight >= random_weight then
                return match_list[i].target
            end
        end
    else
        log_error("weight select total weight 0")
        logv (select_list)
        return nil
    end
end

function format_websocket_frame(fin, opcode, mask_outgoing, data)
    local finbit, mask_bit
    if fin then
        finbit = 0x80
    else
        finbit = 0
    end

    local frame = string.pack("B", finbit | opcode)
    local l = #data

    if mask_outgoing then
        mask_bit = 0x80
    else
        mask_bit = 0
    end

    if l < 126 then
        frame = frame .. string.pack("B", l | mask_bit)
    elseif l < 0xFFFF then
        frame = frame .. string.pack(">BH", 126 | mask_bit, l)
    else 
        frame = frame .. string.pack(">BL", 127 | mask_bit, l)
    end

    if mask_outgoing then
    end

    frame = frame .. data
    return frame
end

function call_skynet_service(addr, nodename, protocal, ... )
    if not nodename or local_nodename == nodename then
        return skynet.call(addr, "lua", protocal, ...)
    else
        return cluster.call(nodename, addr, protocal, ...)
    end
end

function find_in_list(list, key, ...)
    local i
    for i = 1, #list do
        if list[i] == key then
            return true
        end
    end
    return false
end

-- 合并技能数据
function merge_skill_info(info_base, info_power, ...)
    local ret = {}
    for k, v in pairs(info_base) do
        if type(v) == "table" then
            ret[k] = merge_skill_info(v, info_power[k] or {})
        else
            if v * (info_power[k] or 0) > 0 then -- 增益仅对同符号有效
                ret[k] = v + (info_power[k] or 0)
            else
                ret[k] = v
            end
        end
    end
    return ret
end

-- 合并表数据
function merge_table(base, addtion, ...)
    for k, v in pairs(addtion) do
        if type(v) == "table" then
            base[k] = merge_table(base[k] or {}, v)
        elseif type(v) == "string" then
            base[k] = table.concat({base[k], v})
        else
            base[k] = (base[k] or 0) + v
        end
    end
    return base
end

-- php chunk_split
function chunk_split(paramString, paramLength)
    local paramEnd = "\n"
    local p = {}
    local s = paramString
    while (#s > paramLength) do
        local s1 = string.sub(s, 1, paramLength);
        local s2 = string.sub(s, paramLength + 1, #s);
        s = s2;
        table.insert(p, s1);
    end

    if #s > 0 then
        table.insert(p, s);
    end

    table.insert(p, '');
    return table.concat(p, paramEnd);
end

function safe_set_env(key, value, ...)
    if value and skynet.getenv(key) == nil then
        skynet.setenv(key, value)
    else
        if value then
            skynet.error("ENV", key, "setup faild!", key, value)
        end
    end
end

function cluster_reset_config(config_table, ...)
    cluster.reload(config_table)
    datacenter.set("cluster_conifg", "address", config_table)
end

-- 设置环境变量
function setup_env( ... )
    


    
end