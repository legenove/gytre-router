local _T = {
    _VERSION = '0.01',
}


local string_sub = string.sub
local string_lower = string.lower
local string_upper = string.upper
local string_gsub = string.gsub
local string_byte = string.byte
local string_char = string.char
local string_rep = string.rep

local table_getn = table.getn
local table_insert = table.insert
local table_concat = table.concat
local error = error
local ipairs = ipairs
local setmetatable = setmetatable

-- nodeType: uint8
local static = 0
local root = 1
local param = 2
local catchAll = 3
-- nodeType

local buffer = {}
function buffer:new(o, str)
    o = o or {}
    self.__index = self
    setmetatable(o, self)
    if str then o:append(str) end
    return o
end

function buffer:append(str)
    if str then
        string_gsub(str, '.', function(w)
            if table_getn(self) < self.len then table_insert(self, string_byte(w)) end end)
    end
    return self
end

function buffer:concat()
    local res = {}
    for i, v in ipairs(self) do
        res[#res + 1] = string_char(v)
        if self.len and self.len == i then break end
    end
    return table_concat(res, nil)
end


local function min(a, b)
    if a <= b then
        return a
    end
    return b
end

local function countParams(path)
    local n = 0
    for i = 1, #path do
        if (string_sub(path, i, i) ~= ':' and string_sub(path, i, i) ~= '*') then

        else
            n = n + 1
        end
    end
    if n >= 255 then
        return 255
    end
    return n
end

local node = {
    path = "",
    wildChild = false,
    nType = static,
    maxParams = 0,
    indices = "",
    handle = nil,
    priority = 0,
    children = nil
}
function node:new(o)
    o = o or {}
    self.__index = self
    setmetatable(o, self)
    o.children = o.children or {}
    return o
end

-- increments priority of the given child and reorders if necessary
function node:incrementChildPrio(pos)
    local prio = self.children[pos].priority + 1
    self.children[pos].priority = prio
    -- adjust position (move to front)
    local newPos = pos
    while (newPos > 1 and self.children[newPos - 1].priority < prio)
    do
        -- swap node positions
        self.children[newPos - 1], self.children[newPos] = self.children[newPos], self.children[newPos - 1]
        newPos = newPos - 1
    end
    if newPos ~= pos then
        self.indices = string_sub(self.indices, 1, newPos - 1) ..
                string_sub(self.indices, pos, pos) ..
                string_sub(self.indices, newPos, pos - 1) ..
                string_sub(self.indices, pos + 1)
    end
    return newPos
end

-- addRoute adds a node with the given handle to the path.

function node:addRoute(path, handle)
    local fullPath = path
    local n = self

    n.priority = n.priority + 1
    local numParams = countParams(path)
    if #n.path > 0 or table_getn(n.children) > 0 then
        while (true) do
            while (true) do
                -- Update maxParams of the current node
                if numParams > n.maxParams then
                    n.maxParams = numParams
                end
                -- Find the longest common prefix.
                -- This also implies that the common prefix contains no ':' or '*'
                -- since the existing key can't contain those chars.
                -- 找到最长公共前缀
                local i = 1
                local max = min(#path, #n.path)
                -- 匹配相同的字符
                while (i <= max and string_sub(path, i, i) == string_sub(n.path, i, i)) do
                    i = i + 1
                end
                -- Split edge
                if i <= #n.path then
                    -- 将原本路径的i后半部分作为前半部分的child节点
                    local child = node:new({
                        path = string_sub(n.path, i),
                        wildChild = n.wildChild,
                        nType = static,
                        indices = n.indices,
                        handle = n.handle,
                        priority = n.priority - 1,
                        children = n.children
                    })
                    -- Update maxParams (max of all children)
                    -- 更新最大参数个数
                    for _, v in ipairs(child.children) do
                        if v.maxParams > child.maxParams then
                            child.maxParams = v.maxParams
                        end
                    end
                    n.handle = nil
                    n.children = { child, }
                    n.indices = string_sub(n.path, i, i)
                    n.path = string_sub(path, 0, i - 1)
                    n.wildChild = false
                end
                -- Make new node a child of this node
                -- 同时, 将新来的这个节点插入新的parent节点中当做孩子节点
                if i <= #path then
                    -- i的后半部分作为路径, 即上面例子support中的upport
                    path = string_sub(path, i)
                    -- 如果n是参数节点(包含:或者*)
                    if n.wildChild then
                        n = n.children[1]
                        n.priority = n.priority + 1
                        if numParams > n.maxParams then
                            n.maxParams = numParams
                        end
                        numParams = numParams - 1
                        -- Check if the wildcard matches
                        -- 例如: /blog/:ppp 和 /blog/:ppppppp, 需要检查更长的通配符
                        if #path >= #n.path and n.path == string_sub(path, 1, #n.path) and
                                (#n.path >= #path or string_sub(path, #n.path +1, #n.path+1) == '/') then
                            break -- 从新开始
                        else
                            error("path segment '" .. path ..
                                    "' conflicts with existing wildcard '"
                                    .. n.path ..
                                    "' in path '" .. fullPath .. "'")
                        end
                    end
                    local c = string_sub(path, 1, 1)
                    if n.nType == param and c == '/' and table_getn(n.children) == 1 then
                        n = n.children[1]
                        n.priority = n.priority + 1
                        break -- 从新开始
                    end

                    -- Check if a child with the next path byte exists
                    -- 检查路径是否已经存在, 例如search和support第一个字符相同
                    local b = false
                    for m = 1, #n.indices do
                        if c == string_sub(n.indices, m, m) then
                            m = n:incrementChildPrio(m)
                            n = n.children[m]
                            b = true
                            break
                        end
                    end
                    if b then break end
                    -- Otherwise insert it
                    -- new一个node
                    if c ~= ':' and c ~= '*' then
                        n.indices = n.indices .. c
                        local child = node:new({ maxParams = numParams })
                        table_insert(n.children, child)
                        n:incrementChildPrio(#n.indices)
                        n = child
                    end
                    n:insertChild(numParams, path, fullPath, handle)
                    return
                elseif i == #path + 1 then
                    if n.handle ~= nil then
                        error("a handle is already registered for path '" .. fullPath .. "'")
                    end
                    n.handle = handle
                end
                return
            end
        end
    else
        self:insertChild(numParams, path, fullPath, handle)
        -- TODO: root 赋值
        self.nType = root
    end
end


-- 插入节点函数
-- @1: 参数个数
-- @2: 输入路径
-- @3: 完整路径
-- @4: 路径关联函数
function node:insertChild(numParams, path, fullPath, handle)
    local offset = 1
    local n = self
    -- find prefix until first wildcard (beginning with ':'' or '*'')
    -- 找到前缀, 直到遇到第一个wildcard匹配的参数
    local _max = #path
    for i = 1, #path do
        local c = string_sub(path, i, i)
        if c ~= ':' and c ~= "*" then
        else
            local _end = i + 1
            while _end <= _max and string_sub(path, _end, _end) ~= '/' do
                local _e = string_sub(path, _end, _end)
                if _e == ':' or _e == "*" then
                    error("only one wildcard per path segment is allowed, has: '" ..
                            string_sub(path, i) .. "' in path '" .. fullPath .. "'")
                end
                _end = _end + 1
            end

            if table_getn(n.children) > 0 then
                error("wildcard route '" .. string_sub(path, i, _end - 1) ..
                        "' conflicts with existing children in path '" .. fullPath + "'")
            end
            if _end - i < 2 then
                error("wildcards must be named with a non-empty name in path '" .. fullPath .. "'")
            end
            -- 如果是':',那么匹配一个参数
            if c == ':' then
                -- split path at the beginning of the wildcard
                -- 节点path是参数前面那么一段, offset代表已经处理了多少path中的字符
                if i > 1 then
                    n.path = string_sub(path, offset, i - 1)
                    offset = i
                end
                -- 构造一个child
                local child = node:new({
                    nType = param,
                    maxParams = numParams,
                })
                n.children = { child, }
                n.wildChild = true
                -- 下次的循环就是这个新的child节点了
                n = child
                -- 最长匹配, 所以下面节点的优先级++
                n.priority = n.priority + 1
                numParams = numParams - 1

                -- if the path doesn't end with the wildcard, then there
                -- will be another non-wildcard subpath starting with '/'
                if _end <= _max then
                    n.path = string_sub(path, offset, _end - 1)
                    offset = _end

                    child = node:new({
                        maxParams = numParams,
                        priority = 1,
                    })
                    n.children = { child, }
                    n = child
                end
            else
                -- *匹配所有参数
                if _end - 1 ~= _max or numParams > 1 then
                    error("catch-all routes are only allowed at the end of the path in path '" .. fullPath .. "'")
                end

                if #n.path > 0 and string_sub(n.path, #n.path, #n.path) == '/' then
                    error("catch-all conflicts with existing handle for the path segment root in path '" .. fullPath .. "'")
                end

                i = i - 1
                if string_sub(path, i, i) ~= '/' then
                    error("no / before catch-all in path '" .. fullPath .. "'")
                end
                n.path = string_sub(path, offset, i - 1)
                -- first node: catchAll node with empty path
                local child = node:new({
                    wildChild = true,
                    nType = catchAll,
                    maxParams = 1,
                })
                n.children = { child, }
                n.indices = string_sub(path, i, i)
                n = child
                n.priority = n.priority + 1

                -- second node: node holding the variable
                child = node:new {
                    path = string_sub(path, i),
                    nType = catchAll,
                    maxParams = 1,
                    handle = handle,
                    priority = 1,
                }
                n.children = { child }
                return
            end
        end
    end
    n.path = string_sub(path, offset)
    n.handle = handle
end

-- Returns the handle registered with the given path (key). The values of
-- wildcards are saved to a map.
-- If no handle can be found, a TSR (trailing slash redirect) recommendation is
-- made if a handle exists with an extra (without the) trailing slash for the
-- given path.
function node:getValue(path)
    local handle
    local p = {}
    local tsr
    local n = self
    while (true) do
        while (true) do
            if #path > #n.path then
                if string_sub(path, 1, #n.path) == n.path then
                    path = string_sub(path, #n.path + 1)
                    -- If this node does not have a wildcard (param or catchAll)
                    -- child,  we can just look up the next child node and continue
                    -- to walk down the tree
                    if n.wildChild ~= true then
                        local c = string_sub(path, 1, 1)
                        local b = false
                        for i = 0, #n.indices do
                            if c == string_sub(n.indices, i, i) then
                                n = n.children[i]
                                b = true
                                break
                            end
                        end
                        if b then break end
                        -- Nothing found.
                        -- We can recommend to redirect to the same URL without a
                        -- trailing slash if a leaf exists for that path.
                        tsr = (path == "/" and n.handle ~= nil)
                        return handle, p, tsr
                    end

                    -- handle wildcard child
                    n = n.children[1]
                    if n.nType == param then
                        -- find param end (either '/' or path end)
                        local _end = 1
                        while _end <= #path and string_sub(path, _end, _end) ~= '/' do
                            _end = _end + 1
                        end

                        -- save param value
                        if p == nil then
                            -- lazy allocation
                            p = {}
                        end
                        table_insert(p, { [string_sub(n.path, 2)] = string_sub(path, 1, _end - 1) })
                        -- we need to go deeper!
                        if _end <= #path then
                            if table_getn(n.children) > 0 then
                                path = string_sub(path, _end)
                                n = n.children[1]
                                break
                            end

                            -- ... but we can't
                            tsr = (#path == _end)
                            return handle, p, tsr
                        end
                        handle = n.handle
                        if handle ~= nil then
                            return handle, p, tsr
                        elseif table_getn(n.children) == 1 then
                            -- No handle found. Check if a handle for this path + a
                            -- trailing slash exists for TSR recommendation
                            n = n.children[1]
                            tsr = (n.path == "/" and n.handle ~= nil)
                        end
                        return handle, p, tsr

                    elseif n.nType == catchAll then
                        -- save param value
                        if p == nil then
                            -- lazy allocation
                            p = {}
                        end
                        table_insert(p, { [string_sub(n.path, 3)] = path })
                        handle = n.handle
                        return handle, p, tsr
                    else
                        error("invalid node type")
                    end
                end
            elseif path == n.path then
                -- We should have reached the node containing the handle.
                -- Check if this node has a handle registered.
                handle = n.handle
                if handle ~= nil then return handle, p, tsr end

                if path == "/" and n.wildChild and n.nType ~= root then
                    tsr = true
                    return handle, p, tsr
                end

                -- No handle found. Check if a handle for this path + a
                -- trailing slash exists for trailing slash recommendation
                for i = 1, #n.indices do
                    if string_sub(n.indices, i, i) == '/' then
                        n = n.children[i]
                        tsr = (#n.path == 1 and n.handle ~= nil) or (n.nType == catchAll and n.children[1].handle ~= nil)
                        return handle, p, tsr
                    end
                end
                return handle, p, tsr
            end
            -- Nothing found. We can recommend to redirect to the same URL with an
            -- extra trailing slash if a leaf exists for that path
            tsr = (path == "/") or (#n.path == #path + 1 and string_sub(n.path, #path+1, #path+1) == '/' and path == string_sub(n.path, 1, #n.path - 1) and n.handle ~= nil)
            return handle, p, tsr
        end
    end
end

-- Makes a case-insensitive lookup of the given path and tries to find a handler.
-- It can optionally also fix trailing slashes.
-- It returns the case-corrected path and a bool indicating whether the lookup
-- was successful.

function node:findCaseInsensitivePath(path, fixTrailingSlash)
    return self:findCaseInsensitivePathRec(path, string_lower(path), buffer:new({ len = #path + 1 }), buffer:new({ len = 4 }, string_rep(string_char(0), 4)), fixTrailingSlash)
end

local function shiftNRuneBytes(rb, n)
    local len = table_getn(rb)
    for i=1,rb.len do
        if i + n <= len then
            rb[i] = rb[i + n]
        else
            rb[i] = 0
        end
    end
    return rb
end


function node:findCaseInsensitivePathRec(path, loPath, ciPath, rb, fixTrailingSlash)
    local n = self
    local loNPath = string_lower(n.path)
    local _walk = true
    while (_walk) do
        if #loPath >= #loNPath and (#loNPath == 0 or string_sub(loPath, 2, #loNPath) == string_sub(loNPath, 2)) then
            _walk = true
        else
            _walk = false
        end
        while (_walk) do
            -- add common path to result
            ciPath = ciPath:append(n.path)
            path = string_sub(path, #n.path + 1)
            if #path > 0 then
                local loOld = loPath
                loPath = string_sub(loPath, #loNPath + 1)
                -- If this node does not have a wildcard (param or catchAll) child,
                -- we can just look up the next child node and continue to walk down
                -- the tree
                if n.wildChild ~= true then
                    -- skip rune bytes already processed
                    rb = shiftNRuneBytes(rb, #loNPath)

                    if rb[1] ~= 0 then
                        -- old rune not finished
                        local b = false
                        for i = 1, #n.indices do
                            if string_sub(n.indices,i,i) == string_char(rb[1]) then
                                -- continue with child node
                                n = n.children[i]
                                loNPath = string_lower(n.path)
                                b = true
                                break
                            end
                        end
                        if b then break end
                    else
                        -- process a new rune
                        local rv = string_rep(string_char(0), 4)

                        -- find rune start
                        -- runes are up to 4 byte long,
                        -- -4 would definitely be another rune
                        local off = 0
                        local _max = min(#loNPath, 3)
                        while off < _max do
                            local i = #loNPath - off
                            if string_sub(loOld,i+1,i+1) then
                                -- read rune from cached lowercase path
                                rv = string_sub(loOld, i+1)
                                break
                            end
                            off = off +1
                        end
                        -- calculate lowercase bytes of current rune
                        rb = buffer:new({ len = 4 }, rv)
                        -- skipp already processed bytes
                        rb = shiftNRuneBytes(rb, off)
                        for i = 1, #n.indices do
                            -- lowercase matches
                            if string_sub(n.indices,i,i) == string_char(rb[1]) then
                                -- must use a recursive approach since both the
                                -- uppercase byte and the lowercase byte might exist
                                -- as an index
                                local _ciPath = buffer:new({ len = ciPath.len },ciPath:concat())
                                local _rb = buffer:new({ len = 4 }, rb:concat())
                                local out, found = n.children[i]:findCaseInsensitivePathRec(path, loPath, _ciPath, _rb, fixTrailingSlash)
                                if found then
                                    return out, true
                                end
                                break
                            end
                        end

                        -- same for uppercase rune, if it differs
                        local _up = string_upper(rv)
                        if _up ~= rv then
                            rb = buffer:new({ len = 4 }, _up)
                            rb = shiftNRuneBytes(rb, off)
                            local b = false
                            for i = 1, #n.indices do
                                -- uppercase matches
                                if string_sub(n.indices,i,i) == string_char(rb[1]) then
                                    n = n.children[i]
                                    loNPath = string_lower(n.path)
                                    b = true
                                    break
                                end
                            end
                            if b then break end
                        end
                    end

                    -- Nothing found. We can recommend to redirect to the same URL
                    -- without a trailing slash if a leaf exists for that path
                    return ciPath, (fixTrailingSlash and path == "/" and n.handle ~= nil)
                end
                n = n.children[1]
                if n.nType == param then
                    -- find param end (either '/' or path end)
                    local k = 1
                    while (k <= #path and string_sub(path,k,k) ~= '/') do
                        k = k + 1
                    end

                    -- add param value to case insensitive path
                    ciPath = ciPath:append(string_sub(path,1,k-1))
                    -- we need to go deeper!
                    if k <= #path then
                        if table_getn(n.children) > 0 then
                            -- continue with child node
                            n = n.children[1]
                            loNPath = string_lower(n.path)
                            loPath = string_sub(loPath,k)
                            path = string_sub(path,k)
                            rb = buffer:new({ len = 4 }, string_rep(string_char(0), 4))
                            -- TODO : continue
                            break
                        end

                        -- ... but we can't
                        if fixTrailingSlash and #path == k then
                            return ciPath, true
                        end
                        return ciPath, false
                    end

                    if n.handle ~= nil then
                        return ciPath, true
                    elseif fixTrailingSlash and table_getn(n.children) == 1 then
                        -- No handle found. Check if a handle for this path + a
                        -- trailing slash exists
                        n = n.children[1]
                        if n.path == "/" and n.handle ~= nil then
                            return ciPath:append('/'), true
                        end
                    end
                    return ciPath, false

                elseif n.nType == catchAll then
                    return ciPath:append(path), true
                else
                    error("invalid node type")
                end
            else
                -- We should have reached the node containing the handle.
                -- Check if this node has a handle registered.
                if n.handle ~= nil then
                    return ciPath, true
                end

                -- No handle found.
                -- Try to fix the path by adding a trailing slash
                if fixTrailingSlash then
                    for i = 1,#n.indices do
                        if string_sub(n.indices,i,i) == '/' then
                            n = n.children[i]
                            if #n.path == 1 and n.handle ~= nil or (n.nType == catchAll and n.children[1].handle ~= nil) then
                                return ciPath:append('/'), true
                            end
                            return ciPath, false
                        end
                    end
                end
                return ciPath, false
            end
            if #loPath >= #loNPath and (#loNPath == 0 or string_sub(loPath, 2, #loNPath) == string_sub(loNPath, 2)) then
                _walk = true
            else
                _walk = false
            end
        end
    end
    -- Nothing found.
    -- Try to fix the path by adding / removing a trailing slash
    if fixTrailingSlash then
        if path == "/" then
            return ciPath, true
        end
        if #loPath+1 == #loNPath and string_sub(loNPath,#loPath+1,#loPath+1) == '/' and string_sub(loPath,2) == string_sub(loNPath,2,#loPath) and n.handle ~= nil then
            return ciPath:append(n.path), true
        end
    end
    return ciPath, false
end

return node