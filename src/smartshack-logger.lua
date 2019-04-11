local Check = require('user.smartshack-check')

local Logger = {}
function Logger:new(prefix)
  -- create object if user does not provide one
  local object = {
    level = 1,
    prefix = prefix or ''
  }   
  setmetatable(object, self)
  self.__index = self
  return object
end
function Logger:showInfo()
  self.level = 2
end
function Logger:showDebug()
  self.level = 1
end
function Logger:showTrace()
  self.level = 0
end
function Logger:trace(...)
  if ( self.level < 1 ) then
    log(Check.getMessage(self.prefix, ...))
  end
end
function Logger:debug(...)
  if ( self.level < 2 ) then
    log(Check.getMessage(self.prefix, ...))
  end
end
function Logger:info(...)
  if ( self.level < 3 ) then
    log(Check.getMessage(self.prefix, ...))
  end
end
function Logger:warn(...)
  log('WARN: ' .. Check.getMessage(self.prefix, ...))
end
function Logger:error(...)
  log('ERROR: ' .. Check.getMessage(self.prefix, ...))
end

return Logger