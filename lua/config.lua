
local _M = {}

_M["redisMaster"] = {
	["host"] = "10.1.102.169",
	["port"] = "6379",
	["password"] = "foobared"
}

_M["redisOld"] = {
	["host"] = "10.1.102.169",
	["port"] = "6378",
	["password"] = "GxyJ.,Redis6&*!"
}

_M["url"] = "http://www.gxyj.com"   --redis如果挂了，从这个url取

return _M