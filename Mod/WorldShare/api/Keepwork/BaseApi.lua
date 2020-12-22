--[[
Title: Keepwork Base API
Author(s):  big
Date:  2019.11.8
Place: Foshan
use the lib:
------------------------------------------------------------
local KeepworkBaseApi = NPL.load("(gl)Mod/WorldShare/api/Keepwork/BaseApi.lua")
------------------------------------------------------------
]]

local Config = NPL.load('(gl)Mod/WorldShare/config/Config.lua')
local BaseApi = NPL.load('../BaseApi.lua')

local KeepworkBaseApi = NPL.export()

-- private
function KeepworkBaseApi:GetApi()
    return Config.keepworkServerList[BaseApi:GetEnv()] or ""
end

-- private
function KeepworkBaseApi:GetCdnApi()
    return Config.keepworkApiCdnList[BaseApi:GetEnv()] or ""
end

-- private
function KeepworkBaseApi:GetHeaders(headers)
    headers = type(headers) == 'table' and headers or {}

    local token = Mod.WorldShare.Store:Get("user/token")

    if not headers.notTokenRequest and token and not headers["Authorization"] then
        headers["Authorization"] = format("Bearer %s", token)
    end

    headers.notTokenRequest = nil

    return headers
end

-- public
function KeepworkBaseApi:Get(url, params, headers, success, error, noTryStatus, timeout, cdnState)
    local fullUrl
    
    if cdnState then
        fullUrl = self:GetCdnApi() .. url
    else
        fullUrl = self:GetApi() .. url
    end

    BaseApi:Get(fullUrl, params, self:GetHeaders(headers), success, self:ErrorCollect("GET", fullUrl, url, error), noTryStatus, timeout)
end

-- public
function KeepworkBaseApi:Post(url, params, headers, success, error, noTryStatus, timeout, cdnState)
    local fullUrl

    if cdnState then
        fullUrl = self:GetCdnApi() .. url
    else
        fullUrl = self:GetApi() .. url
    end

    BaseApi:Post(fullUrl, params, self:GetHeaders(headers), success, self:ErrorCollect("POST", fullUrl, url, error), noTryStatus, timeout)
end

-- public
function KeepworkBaseApi:Put(url, params, headers, success, error, noTryStatus, timeout, cdnState)
    local fullUrl
    
    if cdnState then
        fullUrl = self:GetCdnApi() .. url
    else
        fullUrl = self:GetApi() .. url
    end

    BaseApi:Put(fullUrl, params, self:GetHeaders(headers), success, self:ErrorCollect("PUT", fullUrl, url, error), noTryStatus, timeout)
end

-- public
function KeepworkBaseApi:Delete(url, params, headers, success, error, noTryStatus, timeout, cdnState)
    local fullUrl
    
    if cdnState then
        fullUrl = self:GetCdnApi() .. url
    else
        fullUrl = self:GetApi() .. url
    end
    
    BaseApi:Delete(fullUrl, params, self:GetHeaders(headers), success, self:ErrorCollect("DELETE", fullUrl, url, error), noTryStatus, timeout)
end

-- public
function KeepworkBaseApi:ErrorCollect(method, fullUrl, url, error)
    return BaseApi:Logger(method, fullUrl, url, error)
end
