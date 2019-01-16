require "common.lua_class"

clist=class()
function clist:ctor( ... )
	self.m_list={}
end

function clist:push_front(value)
	table.insert(self.m_list,1,value)
end

function clist:push_back(value)
	table.insert(self.m_list,value)
end

function clist:pop_front()
	return table.remove(self.m_list,1)
end

function clist:front()
	return self.m_list[1]
end

function clist:back()
	return self.m_list[#self.m_list]
end

function clist:pop_back()
	table.remove(self.m_list)
end

function clist:get_size()
	return #self.m_list
end

function clist:list( ... )
	-- body
	return self.m_list
end