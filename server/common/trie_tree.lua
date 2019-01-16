require "common.lua_class"

trie_node = class()

function trie_node:ctor(tag, param)
	self.trie_tag = tag
	self.childen = {}
	self.param = param
end

function trie_node:add_child(node)
	if node.trie_tag then
		self.childen[node.trie_tag] = node
	end
end

function trie_node:get_next(tag, ...)
	return self.childen[tag]
end