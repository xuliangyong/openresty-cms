local conf = require "config"

function query_slave_redis(cacheKey, field)

	local redis = require "resty.redis_iresty"
	local cfg = {timeout = 1000, host = conf.redisSlave.host, port = conf.redisSlave.port, conf.redisSlave.password}
	local red = redis:new(cfg)	
				
	local resp, err = red:hget(cacheKey, field)  
	if not resp then  
		ngx.log(ngx.ERR, err)
		return
	end 
						
	return resp;
end

function query_master_redis(cacheKey, field)

	local redis = require "resty.redis_iresty"
	local cfg = {timeout = 1000, host = conf.redisMaster.host, port = conf.redisMaster.port, password = conf.redisMaster.password}
	local red = redis:new(cfg)	
				
	local resp, err = red:hget(cacheKey, field)  
	if not resp then 
		ngx.log(ngx.ERR, err)
		return 
	end 
						
	return resp;
end


----------------------- 查询老redis缓存 -----------------------
function query_old_redis(cacheKey, field)

	local redis = require "resty.redis_iresty"
	local cfg = {timeout = 1000, host = conf.redisOld.host, port = conf.redisOld.port, password = conf.redisOld.password}
	local red = redis:new(cfg)	
				
	local resp, err = red:hget(cacheKey, field)  
	if not resp then 
		ngx.log(ngx.ERR, err)
		return 
	end 
						
	return resp;
end

function encodeURI(s)
    s = string.gsub(s, "([^%w%.%- ])", function(c) return string.format("%%%02X", string.byte(c)) end)
    return string.gsub(s, " ", "+")
end

-----------------------  比较头尾和body最新更新时间，取最近更新时间  -----------------------
function getNewestLastModified(headerLastModified, bodyLastModified)
	if headerLastModified == nil then 
		return bodyLastModified
	end 
	if bodyLastModified == nil then
		return headerLastModified
	end
	
	local headerTime = ngx.parse_http_time(headerLastModified)
	local bodyTime = ngx.parse_http_time(bodyLastModified)
	
	if headerTime > bodyTime then 
		return headerLastModified
	else 
		return bodyLastModified
	end	
	
end

--------------- 托底方案： 查询redis失败后，最后通过url动态查询 ----------------
function load_url(key)
	local http = require "resty.http"
	local httpc = http.new()  
	local resp_body = nil
	
	local resp, err = httpc:request_uri( conf.url, {
			method="GET",
			path = "/dynamicPage.jhtml?url=" .. encodeURI(key),
			headers = {  
				["User-Agent"] = "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/40.0.2214.111 Safari/537.36"  
			} 
	})
	
	if not resp then  
		ngx.log(ngx.ERR, "request error :", err)  
		return  
	end 
	
--	ngx.status = resp.status
	
	for k, v in pairs(resp.headers) do  
	--	if k ~= "Transfer-Encoding" and k ~= "Connection" then  
			ngx.header[k] = v  
	--	end  
	end  
	--响应体  
--	ngx.say(resp.body)  
	resp_body = resp.body
	
	httpc:close()
	
	return resp_body
end

---------  start  --------
local args = ngx.req.get_uri_args()
local version = args["version"]
local configKey = ngx.req.get_headers()["host"] .. "/config"
local bodyKey = ngx.req.get_headers()["host"] .. ngx.var.uri
local IfModifiedSince = ngx.req.get_headers()["If-Modified-Since"]
local headerLastModified = query_master_redis(configKey, "LastModified")
local bodyLastModified = query_master_redis(bodyKey, "LastModified")
local newestLastModified = getNewestLastModified(headerLastModified, bodyLastModified)


ngx.log(ngx.ERR, 'configKey:', configKey)
ngx.log(ngx.ERR, 'bodyKey:', bodyKey)

ngx.log(ngx.ERR, 'IfModifiedSince:',IfModifiedSince)
ngx.log(ngx.ERR, 'headerLastModified:', headerLastModified)
ngx.log(ngx.ERR, 'bodyLastModified:', bodyLastModified)
ngx.log(ngx.ERR, 'newestLastModified:', newestLastModified)
--ngx.log(ngx.ERR, os.date("%a, %d %b %Y %X GMT", 1490684142))
--ngx.log(ngx.ERR, ngx.parse_http_time(IfModifiedSince))





-- 304		
if newestLastModified ~= nil then 
	if newestLastModified == IfModifiedSince then 
		ngx.exit(ngx.HTTP_NOT_MODIFIED)
	end	
end	

if version ~= "preview" then 				
	version = "production"
end	

--ngx.log(ngx.INFO, "load slave redis...")
--local resp = query_slave_redis(cacheKey, version)

			
--if resp == nil then
--	ngx.log(ngx.INFO, "load master redis...")
--  resp = query_master_redis(cacheKey, version)
--end
local headerHtml = query_master_redis(configKey, "header")
local footerHtml = query_master_redis(configKey, "footer")
local bodyHtml = query_master_redis(bodyKey, version)

--ngx.log(ngx.ERR, 'headerHtml:', headerHtml)
--ngx.log(ngx.ERR, 'footerHtml:', footerHtml)
--ngx.log(ngx.ERR, 'bodyHtml:', bodyHtml)







local responseHtml = nil
-- 查询redis
if bodyHtml ~= nil and headerHtml ~= nil and footerHtml ~= nil then 
	responseHtml = headerHtml .. bodyHtml .. footerHtml
end	

-- 查询老redis
if responseHtml == nil then 
	ngx.log(ngx.ERR, "query old redis:", conf.redisOld.host, ":", conf.redisOld.port)
	responseHtml = query_old_redis(bodyKey, version)
end 

-- 查询动态链接
if responseHtml == nil then 
	ngx.log(ngx.ERR, "load http://www.gxyj.com/dynamicPage.jhtml?url=", bodyKey)
	responseHtml = load_url(bodyKey)
end 

ngx.header["Content-Type"] = "text/html;charset=utf-8"

if newestLastModified ~= nil then 
	ngx.header["Last-Modified"] = newestLastModified
end 

if responseHtml == nil then 
	ngx.exit(ngx.HTTP_NOT_FOUND)
else 
	ngx.say(responseHtml)
end

