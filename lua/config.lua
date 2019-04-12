
local _M = {}

_M["redisMaster"] = {
	["host"] = "10.1.102.169",
	["port"] = "6379",
	["password"] = ""
}

_M["redisOld"] = {
	["host"] = "10.1.102.169",
	["port"] = "6378",
	["password"] = ""
}

_M["url"] = "http://www.xxx.com"   --redis如果挂了，从这个url取

return _M
