--
-- Created by IntelliJ IDEA.
-- User: legenove
-- Date: 17/6/2
-- Time: 上午10:31
-- To change this template use File | Settings | File Templates.
--
local node = require('lua.tree')
local print = print
local string_format = string.format
local table_getn = table.getn
local ipairs = ipairs
local pairs = pairs
-- *************************
--
-- for test
--
-- *************************




-- *************************
-- 0. print tree
-- *************************
local function printChildren(n, prefix)
    local n = n
    print(string_format("%d:%d:%s %s%s[%d] %d \r\n", n.priority, n.maxParams, tostring(n.wildChild), prefix, n.path, table_getn(n.children), n.nType))
    local prefix = prefix .. "----"
    for i = 1, table_getn(n.children) do
        local _n = n.children[i]
        printChildren(_n, prefix)
    end
end

local function printParams(ps)
    if ps then
        for i, param in ipairs(ps) do
            for k, v in pairs(param) do
                print(i, k, v)
            end
        end
    end
end

local function getRequests(tree, requests)
    for _, request in ipairs(requests) do
        local handler, ps, _ = tree:getValue(request[1])
        print('___________print:::::')
        if handler then
            print('*******handler:', handler())
            printParams(ps)
        else
            print('***no handler:', handler)
            printParams(ps)
        end
    end
end

-- *************************
-- 1. test tree add and get
-- *************************
local function fakeHandler(s)
    local function inner_func()
        return s
    end

    return inner_func
end

local function TestTreeAddAndGet()
    local tree = node:new()
    local routes = {
        "/hi",
        "/contact",
        "/co",
        "/c",
        "/a",
        "/ab",
        "/doc/",
        "/doc/go_faq.html",
        "/doc/go1.html",
        "/α",
        "/β",
    }
    for _, route in ipairs(routes) do
        tree:addRoute(route, fakeHandler(route))
    end
    printChildren(tree, '')
    getRequests(tree, {
        { "", false, "", nil },
        { "/a", false, "/a", nil },
        { "/", true, "", nil },
        { "/hi", false, "/hi", nil },
        { "/contact", false, "/contact", nil },
        { "/co", false, "/co", nil },
        { "/con", true, "", nil }, -- key mismatch
        { "/cona", true, "", nil }, -- key mismatch
        { "/no", true, "", nil }, -- no matching child
        { "/ab", false, "/ab", nil },
        { "/α", false, "/α", nil },
        { "/β", false, "/β", nil },
    })
end


-- *************************
-- 2. test tree wildcard
-- *************************
local function TestTreeWildCard()
    local tree = node:new()
    local routes = {
        "/",
        "/cmd/:tool/:sub",
        "/cmd/:tool/",
        "/src/*filepath",
        "/search/",
        "/search/:query",
        "/user_:name",
        "/user_:name/about",
        "/files/:dir/*filepath",
        "/doc/",
        "/doc/go_faq.html",
        "/doc/go1.html",
        "/info/:user/public",
        "/info/:user/project/:project",
    }
    for _, route in ipairs(routes) do
        tree:addRoute(route, fakeHandler(route))
    end
    printChildren(tree, '')
    getRequests(tree, {
        { "/", false, "/", nil },
        { "/cmd/test/", false, "/cmd/:tool/", nil },
        { "/cmd/test", true, "", nil },
        { "/cmd/test/3", false, "/cmd/:tool/:sub", nil },
        { "/src/", false, "/src/*filepath", nil },
        { "/src/some/file.png", false, "/src/*filepath", nil },
        { "/search/", false, "/search/", nil },
        { "/search/someth!ng+in+ünìcodé", false, "/search/:query", nil },
        { "/search/someth!ng+in+ünìcodé/", true, "", nil },
        { "/user_gopher", false, "/user_:name", nil },
        { "/user_gopher/about", false, "/user_:name/about", nil },
        { "/files/js/inc/framework.js", false, "/files/:dir/*filepath", nil },
        { "/info/gordon/public", false, "/info/:user/public", nil },
        { "/info/gordon/project/go", false, "/info/:user/project/:project", nil },
    })
end

-- *************************
-- 3. test tree wildcard conflict
-- *************************
local function testRoutes(routes)
    local tree = node:new()
    for i, route in ipairs(routes) do
        local res, err = pcall(tree.addRoute, tree, route[1], nil)
        print('-----------log :::::::::::', i)
        if route[1] == '/src/*filepathx' then printChildren(tree, '') end
        if route[2] then
            if err then else
                print(route[1])
                error('need conflict')
            end
        else
            if err then
                print(route[1])
                error('should no conflict')
            end
        end
        print('===========end log::::::::')
    end
end

local function TestTreeWildCardConflic()
    local routes = {
        { "/cmd/:tool/:sub", false },
        { "/cmd/:tool/:sublkd", true },
        { "/cmd/vet", true },
        { "/src/*filepath", false },
        { "/src/*filepathx", true },
        { "/src/", true },
        { "/src1/", false },
        { "/src1/*filepath", true },
        { "/src2*filepath", true },
        { "/search/:query", false },
        { "/search/invalid", true },
        { "/user_:name", false },
        { "/user_x", true },
        { "/user_:name", false },
        { "/id:id", false },
        { "/id/:id", true },
    }
    testRoutes(routes)
end

local function TestTreeChildConflict()
    local routes = {
        { "/cmd/vet", false },
        { "/cmd/:tool/:sub", true },
        { "/src/AUTHORS", false },
        { "/src/*filepath", true },
        { "/user_x", false },
        { "/user_:name", true },
        { "/id/:id", false },
        { "/id:id", true },
        { "/:id", true },
        { "/*filepath", true },
    }
    testRoutes(routes)
end

local function TestTreeDupliatePath()
    local tree = node:new()
    local routes = {
        "/",
        "/doc/",
        "/src/*filepath",
        "/search/:query",
        "/user_:name",
    }
    for _, route in ipairs(routes) do
        tree:addRoute(route, fakeHandler(route))
        local res, err = pcall(tree.addRoute, tree, route, fakeHandler(route))
        if err == nil then
            error('dupliate need an error')
        end
    end
    printChildren(tree, '')
    getRequests(tree, {
        { "/", false, "/", nil },
        { "/doc/", false, "/doc/", nil },
        { "/src/some/file.png", false, "/src/*filepath", nil },
        { "/search/someth!ng+in+ünìcodé", false, "/search/:query", nil },
        { "/user_gopher", false, "/user_:name", nil },
    })
end

local function TestEmptyWildcardName()
    local tree = node:new()
    local routes = {
        "/user:",
        "/user:/",
        "/cmd/:/",
        "/src/*",
    }
    for _, route in ipairs(routes) do
        local res, err = pcall(tree.addRoute, tree, route, fakeHandler(route))
        if err == nil then
            error('empty need an error')
        end
    end
    printChildren(tree, '')
end

local function TestTreeCatchAllConflict()
    local routes = {
        { "/src/*filepath/x", true },
        { "/src2/", false },
        { "/src2/*filepath/x", true },
    }
    testRoutes(routes)
end

local function TestTreeCatchAllConflictRoot()
    local routes = {
        { "/", false },
        { "/*filepath", true },
    }
    testRoutes(routes)
end

local function TestEmptyWildcardName()
    local routes = {
        "/:foo:bar",
        "/:foo:bar/",
        "/:foo*bar",
    }
    for _, route in ipairs(routes) do
        local tree = node:new()
        local res, err = pcall(tree.addRoute, tree, route, fakeHandler(route))
        if err == nil then
            error('empty need an error')
        end
        printChildren(tree, '')
    end
end

local function TestTreeFindCaseInsensitivePath()
    local tree = node:new()
    local routes = {
        "/hi",
        "/b/",
        "/ABC/",
        "/search/:query",
        "/cmd/:tool/",
        "/src/*filepath",
        "/x",
        "/x/y",
        "/y/",
        "/y/z",
        "/0/:id",
        "/0/:id/1",
        "/1/:id/",
        "/1/:id/2",
        "/aa",
        "/a/",
        "/doc",
        "/doc/go_faq.html",
        "/doc/go1.html",
        "/doc/go/away",
        "/no/a",
        "/no/b",
        "/Π",
        "/u/apfêl/",
        "/u/äpfêl/",
        "/u/öpfêl",
        "/v/Äpfêl/",
        "/v/Öpfêl",
        "/w/♬", -- 3 byte
        "/w/♭/", -- 3 byte, last byte differs
        "/w/𠜎", -- 4 byte
        "/w/𠜏/", -- 4 byte
    }
    for _, route in ipairs(routes) do
        local res, err = pcall(tree.addRoute, tree, route, fakeHandler(route))
        if err ~= nil then
            error(err)
        end
    end
    printChildren(tree, '')

    for _, route in ipairs(routes) do
        local out, found = tree:findCaseInsensitivePath(route, true)
        if (found == false) then
            error("Route '%s' not found!")
        end
        if (out:concat() == route) then
        else
            error('Route out error!')
        end
    end

    for _, route in ipairs(routes) do
        local out, found = tree:findCaseInsensitivePath(route, false)
        if (found == false) then
            error("Route '%s' not found!")
        end
        if (out:concat() == route) then
        else
            error('Route out error!')
        end
    end

    local tests = {
        {"/HI", "/hi", true, false},
		{"/HI/", "/hi", true, true},
		{"/B", "/b/", true, true},
		{"/B/", "/b/", true, false},
		{"/abc", "/ABC/", true, true},
		{"/abc/", "/ABC/", true, false},
		{"/aBc", "/ABC/", true, true},
		{"/aBc/", "/ABC/", true, false},
		{"/abC", "/ABC/", true, true},
		{"/abC/", "/ABC/", true, false},
		{"/SEARCH/QUERY", "/search/QUERY", true, false},
		{"/SEARCH/QUERY/", "/search/QUERY", true, true},
		{"/CMD/TOOL/", "/cmd/TOOL/", true, false},
		{"/CMD/TOOL", "/cmd/TOOL/", true, true},
		{"/SRC/FILE/PATH", "/src/FILE/PATH", true, false},
		{"/x/Y", "/x/y", true, false},
		{"/x/Y/", "/x/y", true, true},
		{"/X/y", "/x/y", true, false},
		{"/X/y/", "/x/y", true, true},
		{"/X/Y", "/x/y", true, false},
		{"/X/Y/", "/x/y", true, true},
		{"/Y/", "/y/", true, false},
		{"/Y", "/y/", true, true},
		{"/Y/z", "/y/z", true, false},
		{"/Y/z/", "/y/z", true, true},
		{"/Y/Z", "/y/z", true, false},
		{"/Y/Z/", "/y/z", true, true},
		{"/y/Z", "/y/z", true, false},
		{"/y/Z/", "/y/z", true, true},
		{"/Aa", "/aa", true, false},
		{"/Aa/", "/aa", true, true},
		{"/AA", "/aa", true, false},
		{"/AA/", "/aa", true, true},
		{"/aA", "/aa", true, false},
		{"/aA/", "/aa", true, true},
		{"/A/", "/a/", true, false},
		{"/A", "/a/", true, true},
		{"/DOC", "/doc", true, false},
		{"/DOC/", "/doc", true, true},
		{"/NO", "", false, true},
		{"/DOC/GO", "", false, true},
--		{"/π", "/Π", true, false},
--		{"/π/", "/Π", true, true},
--		{"/u/ÄPFÊL/", "/u/äpfêl/", true, false},
--		{"/u/ÄPFÊL", "/u/äpfêl/", true, true},
--		{"/u/ÖPFÊL/", "/u/öpfêl", true, true},
--		{"/u/ÖPFÊL", "/u/öpfêl", true, false},
--		{"/v/äpfêL/", "/v/Äpfêl/", true, false},
--		{"/v/äpfêL", "/v/Äpfêl/", true, true},
--		{"/v/öpfêL/", "/v/Öpfêl", true, true},
--		{"/v/öpfêL", "/v/Öpfêl", true, false},
		{"/w/♬/", "/w/♬", true, true},
		{"/w/♭", "/w/♭/", true, true},
		{"/w/𠜎/", "/w/𠜎", true, true},
		{"/w/𠜏", "/w/𠜏/", true, true},
    }
    for i, test in ipairs(tests) do
        local out, found = tree:findCaseInsensitivePath(test[1], true)
        if (found ~= test[3]) or (found and out:concat() ~= test[2] ) then
            error("Route error not found!")
        end
    end

    for i, test in ipairs(tests) do
        local out, found = tree:findCaseInsensitivePath(test[1], false)
        if test[4] then
            if found then
                error('cant found')
            end
        else
            if (found ~= test[3]) or (found and out:concat() ~= test[2]) then
                error("Route error not found!")
            end
        end
    end
end

local function TestTreeInvalidNodeType()
    local tree = node:new()
    local routes = {
        "/",
        "/:page",
    }
    for _, route in ipairs(routes) do
        tree:addRoute(route, fakeHandler(route))
    end

    tree.getValue(tree,'/test')

    tree.findCaseInsensitivePath(tree, '/test', true)

end



TestTreeAddAndGet()
TestTreeWildCard()
TestTreeCatchAllConflictRoot()
TestTreeFindCaseInsensitivePath()

TestTreeInvalidNodeType()