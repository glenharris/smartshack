local Logger = require('user.smartshack-logger')

local Channel = {}
function Channel:new(name)
  -- create object if user does not provide one
  local object = {
    name = name,
    logger = Logger:new('Channel-'..name)
  }   
  setmetatable(object, self)
  self.__index = self
  object.logger:showInfo()
  return object
end
function Channel:write(value)
  self.logger:debug('write %s', value)
  local writeIndex = self:optionalStorageGet('WriteIndex')
  if ( not writeIndex ) then
    self.logger:debug('write initialising')
    -- Initialise the channel
    writeIndex = 0
    self:storageSet('WriteIndex',writeIndex)
    self:storageSet('ReadIndex',0)
    self:storageSet('Data'..writeIndex, value)
    self:storageSet('WriteIndex', writeIndex + 1)
    return
  else
    if ( writeIndex > 100 ) then
      -- try to reset the channel
	  	local readIndex = self:optionalStorageGet('ReadIndex')
      if ( readIndex and readIndex == writeIndex ) then
        self.logger:debug('write resetting')
        writeIndex = 0
        self:storageSet('Data'..writeIndex, value)
        self:storageSet('WriteIndex', writeIndex + 1)
        self:storageSet('ReadIndex', 0)
        return
      end
    end
  end
  self:storageSet('Data'..writeIndex, value)
  self:storageSet('WriteIndex', writeIndex + 1)
end
function Channel:optionalRead()
  self.logger:debug('optionalRead')
  local readIndex = self:optionalStorageGet('ReadIndex')
  local writeIndex = self:optionalStorageGet('WriteIndex')
  if ( readIndex and writeIndex ) then
    if ( readIndex < writeIndex ) then
      local value = self:optionalStorageGetAndDelete('Data'..readIndex)
      self:storageSet('ReadIndex', readIndex+1)
      return value
    end
  end
end
function Channel:readList()
  self.logger:debug('readList')
  local returnValues = {}
  local readIndex = self:optionalStorageGet('ReadIndex')
  local writeIndex = self:optionalStorageGet('WriteIndex')
  if ( readIndex and writeIndex ) then
    if ( readIndex < writeIndex ) then
      while ( readIndex < writeIndex ) do
	      local value = self:optionalStorageGetAndDelete('Data'..readIndex)
        table.insert(returnValues, value)
        readIndex = readIndex + 1
      end
      self:storageSet('ReadIndex', readIndex)
    end
  end
  return returnValues
end
function Channel:dispose()
  self.logger:debug('dispose')
  local readIndex = self:optionalStorageGetAndDelete('ReadIndex')
  local writeIndex = self:optionalStorageGetAndDelete('WriteIndex')
  if ( readIndex and writeIndex ) then
    while ( readIndex < writeIndex ) do
      self:optionalStorageGetAndDelete('Data'..readIndex)
      readIndex = readIndex + 1
    end
  end
end
function Channel:optionalStorageGetAndDelete(key)
  local fullKey = string.format('Channel-%s-%s', self.name, key)
  local value = storage.get(fullKey)
  self.logger:trace('optionalStorageGetAndDelete %s %s', fullKey, value)
  storage.delete(fullKey)
  return value
end
function Channel:optionalStorageGet(key)
  local fullKey = string.format('Channel-%s-%s', self.name, key)
  local value = storage.get(fullKey)
  self.logger:trace('optionalStorageGet %s %s', fullKey, value)
  return value
end
function Channel:storageSet(key, value)
  local fullKey = string.format('Channel-%s-%s', self.name, key)
  self.logger:trace('optionalStorageSet %s %s', fullKey, value)
  storage.set(fullKey, value)
end

return Channel