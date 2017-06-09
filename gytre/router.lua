--
--
--local router = require('lua.router')
--Router = router:new()
--Router:GET('/panel/games', 'lua.panel.games')
--


local string_sub = string.sub
local error = error
local setmetatable = setmetatable

local node = require('lua.tree')

local router = {
    trees = nil,
    RedirectTrailingSlash = true,
    RedirectFixedPath = true,
    HandleMethodNotAllowed = true,
    HandleOPTIONS = true,
    NotFound = function() end,
    MethodNotAllowed = function() end,
    PanicHandler = function() end,
}

function router:new(o)
    o = o or {}
    self.__index = self
    setmetatable(o, self)
    o.trees = o.trees or {}
    return o
end

function router:Register(tree, path, handle)
    if string_sub(path, 1, 1) ~= '/' then
        error("path must begin with '/' in path '" .. path .. "'")
    end

    if self.trees == nil then
        self.trees = {}
    end
    local root = self.trees[tree]
    if root == nil then
        root = node:new()
        self.trees[tree] = root
    end

    root:addRoute(path, handle)
end

function router:GetHandle(tree, path)
    local root = self.trees[tree]
    if root ~= nil then
        return root:getValue(path)
    end
    return nil, nil, false
end

return router