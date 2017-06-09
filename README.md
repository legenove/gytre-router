# gytre-router
router by ngx-lua

## How to use
```lua
local router = require('lua.gytre.router')
Router = router:new()
--rejister handle to tree
Router:Register('tree','/panel/games', 'lua.panel.games')
--get handle from tree
Router:GetHandle('tree','/panel/games')
```

# reference 
[GO httprouter](https://github.com/julienschmidt/httprouter/blob/master/router.go)
