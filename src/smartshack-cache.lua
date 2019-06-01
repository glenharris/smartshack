local Logger = require('user.smartshack-logger')
local Check = require('user.smartshack-check')

local Cache = {
  logger = Logger:new('Cache'),
  items = {},
}
function Cache.getOptionalItem(itemType, itemName)
  local key = itemType .. itemName
  return Cache.items[key]
end

function Cache.setItem(itemType, itemName, item)
  local key = itemType .. itemName
  Cache.items[key] = item
end

return Cache