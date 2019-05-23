local Logger = require('user.smartshack-logger')
local Check = require('user.smartshack-check')
local Cbus = require('user.smartshack-cbus')
local Channel = require('user.smartshack-channel')

local Prt3 = {
  serialPort = nil,
  currentRead = '',
  LINE_TERMINATOR = '\r',
  readLines = {},
  writeLineDatas = {}
}

local Protocol = {
  EVENT_GROUP_ZONE_OK = 0,
	EVENT_GROUP_ZONE_OPEN = 1,
	EVENT_GROUP_ZONE_TAMPERED = 2,
	EVENT_GROUP_ZONE_FIRE_LOOP_TROUBLE = 3,
	EVENT_GROUP_NON_REPORTABLE = 4,
	EVENT_GROUP_SPECIAL_EVENTS = 45,
	EVENT_GROUP_UTILITY_KEY = 48,
	EVENT_GROUP_STATUS_2 = 65,
}

function Prt3:new(object, name)
  -- create object if user does not provide one
  name = name or 'Default'
  object = object or {}   
  setmetatable(object, self)
  self.__index = self
  self.logger = Logger:new('PRT3')
  self.logger:showInfo()
  self.channel = Channel:new('PRT3:' .. name)
  return object
end

function Prt3:sendCommandUtilityKey(utilityKeyIndex) 
  self.logger:info('sendCommandUtilityKey %d', utilityKeyIndex)
  self:sendCommand(string.format('UK%03d', utilityKeyIndex))
end

function Prt3:sendCommandArmInstant(partitionIndex, password)
  self.logger:info('sendCommandArmInstant %d', partitionIndex)
  self:sendCommand(string.format('AA%03dI%s', partitionIndex, password))
end

function Prt3:sendCommandDisarmInstant(partitionIndex, password)
  self.logger:info('sendCommandDisarmInstant %d', partitionIndex)
  self:sendCommand(string.format('AD%03dI%s', partitionIndex, password))
end

function Prt3:sendCommand(command)
  self.logger:info('sendCommand %s', command)
  local action = {}
  action.command = command
  self.channel:write(action)
end

function Prt3:initialiseFirst(portPathPrefix, config)
  if ( not portPathPrefix ) then
    portPathPrefix = '/dev/ttyUSB'
    self.logger:warn('Assuming %sx', portPathPrefix)
  end
  if ( self:initialise(portPathPrefix .. '0', config) ) then
    return true
  end
  if ( self:initialise(portPathPrefix .. '1', config) ) then
    return true
  end
  if ( self:initialise(portPathPrefix .. '2', config) ) then
    return true
  end
  return false
end

function Prt3:initialise(portPath, config)
  Check.state(not self.serialPort)
  local serial = require('serial')
  local err
  local port, err = serial.open(portPath, {
    baudrate=57600,
    databits=8,
    stopbits=1,
    parity='none',
    duplex='full'
    })
  if ( not port ) then
    self.logger:warn('Could not open %s - %s',portPath, err)
    return false
  end
  self.logger:info('opened %s', portPath)
  port:flush()
  self.logger:debug('flushed')
  self.serialPort = port
  self.config = config
  self.discoveredZones = {}
  self.logger:debug('zones %d', table.maxn(config.zones))
  for unused, zone in pairs(config.zones ) do
    self:queryZoneStatus(zone.index)
  end
  return true
end

function Prt3:dispose()
  if ( self.serialPort ) then
    self.serialPort:close()
    self.serialPort = nil
  end
end
function Prt3:runEventLoop(maxSeconds)
  Check.state(self.serialPort)
  local startSeconds = os.time()
  local readSeconds = 1
  local readBytes = 13 -- Normal size of a packet 'G000N000A000\r'
  local finishSeconds = startSeconds + maxSeconds
  --log('time', currentSeconds, finishSeconds)
  local mustRead = false
  while ( (os.time() < finishSeconds) or mustRead ) do
    local actions = self.channel:readList()
    if ( #actions > 0 ) then
      self.logger:info('add %d actions', #actions)
      for index, action in ipairs(actions) do
        self:addAction(action)
      end
    end
    while ( table.getn(self.writeLineDatas) > 0 ) do
      local writeLine = table.remove(self.writeLineDatas,1) .. self.LINE_TERMINATOR
      self.logger:trace('write %s', writeLine)
      self.serialPort:write(writeLine)
    end
    self.logger:trace('reading')
    mustRead = false
    local data, err = self.serialPort:read(readBytes,readSeconds)
   	if data then
      self.logger:trace('read %s', data:len(), err)
      mustRead = true
      self:addReadData(data)
      while ( table.getn(self.readLines) > 0 ) do
        local readLine = table.remove(self.readLines,1)
        self:processReadLine(readLine)
      end
    else
      if err == 'timeout' then
        self.logger:trace('timeout')
      else
        self.logger:error('read error', err)
      end
    end
	end
  self.logger:trace('done')
end
function Prt3:addAction(action)
  if ( action.command ) then
    self:addWriteLineData(action.command)
  else
    self.logger:error('Unknown action')
  	log('addAction',action)
  end
end
function Prt3:addReadData(data)
  local currentRead = self.currentRead .. data
  repeat
    local index = currentRead:find(self.LINE_TERMINATOR)
    self.logger:trace('currentRead %d %d', index, currentRead:len())
    if ( index ) then
      local line = currentRead:sub(1, index-1)
      currentRead = currentRead:sub(index+1)
      if ( line:len() > 0 ) then
	      table.insert(self.readLines, line)
      end
    end
  until (not index)
  self.currentRead = currentRead
end
function Prt3:processReadLine(line)
  self.logger:trace('processReadLine %d %s',line:len(), line)
  if ( line:len() == 10 ) then
    if ( line:find('RZ')==1 ) then
      self:parseQueryZoneStatusResponse(line:sub(3))
      return
    end
  elseif ( line:len() == 12 ) then
    if ( line:sub(1,1)=='G' and line:sub(5,5) == 'N' and line:sub(9,9)=='A') then
      local eventGroup
      if ( line:sub(2,2)=='G') then
      	eventGroup = tonumber(line:sub(3,4))
      else
      	eventGroup = tonumber(line:sub(2,4))
      end
      local eventNumber = tonumber(line:sub(6,8))
      local areaNumber = tonumber(line:sub(10,12))
      self:processEvent(eventGroup, eventNumber, areaNumber)
      return
    end
  end
  if ( line:find('ZL')==1 ) then
    self:parseQueryZoneLabelResponse(line:sub(3))
    return
  end
  if ( line:find('UK')==1 ) then
    self.logger:warn('Utility Key confirmation received')
    return
  end
  self.logger:warn('Unknown line %d %s', line:len(), line)
end
function Prt3:processEvent(eventGroup, eventNumber, areaNumber)
  self.logger:trace('processEvent %d %d %d', eventGroup, eventNumber, areaNumber)
  if ( eventGroup == Protocol.EVENT_GROUP_ZONE_OK ) then
    self:updateZoneStatus(eventNumber, 0)
    return
  elseif ( eventGroup == Protocol.EVENT_GROUP_ZONE_OPEN ) then
    self:updateZoneStatus(eventNumber, 255)
    return
  elseif ( eventGroup == Protocol.EVENT_GROUP_ZONE_TAMPERED ) then
    self:updateZoneStatus(eventNumber, 255)
    return
  elseif ( eventGroup == Protocol.EVENT_GROUP_ZONE_FIRE_LOOP_TROUBLE ) then
    self:updateZoneStatus(eventNumber, 255)
    return
  elseif ( eventGroup == Protocol.EVENT_GROUP_NON_REPORTABLE ) then
    if ( eventNumber == 7 ) then
      self.logger:info('Remote access')
    else
	    self.logger:info('Non-reportable event %d %d', eventNumber, areaNumber)
    end
    return
  elseif ( eventGroup == Protocol.EVENT_GROUP_SPECIAL_EVENTS ) then
    if ( eventNumber == 4 ) then
      self.logger:info('Winload connected')
    else
      self.logger:info('Special event %d %d', eventNumber, areaNumber)
    end
    return
  elseif ( eventGroup == Protocol.EVENT_GROUP_UTILITY_KEY ) then
    self.logger:info('Utility key %d', eventNumber)
    return
  elseif ( eventGroup == Protocol.EVENT_GROUP_STATUS_2 ) then
    local partition = tostring(eventNumber)
    if ( partition == '0' ) then
      partition = 'All'
    end
    if ( areaNumber == 0 ) then
      self.logger:info('Partition %s ready', partition)
    else
      self.logger:info('Partition %s event %d', partition, areaNumber)
    end
    return
  end
  self.logger:warn('Unknown event %d %d %d', eventGroup, eventNumber, areaNumber)
end
function Prt3:updateZoneStatus(zoneIndex, value)
  Check.argument(zoneIndex>0)
  self.logger:trace('updateZoneStatus %d %d', zoneIndex, value)
  local zone = self.config.zones[zoneIndex]
  if ( zone ) then
    if ( zone.shouldIgnore ) then
      -- Do nothing
      return
    end
    if ( zone.cbusGa ) then
      self.logger:trace('SetCbusLevel %d %d %d %d', zone.cbusGa[1], zone.cbusGa[2], zone.cbusGa[3], value)
      Cbus.setLevel(zone.cbusGa, value)
--	    SetCBusLevel(zone.cbusGa[1], zone.cbusGa[2], zone.cbusGa[3], value, 0)
    end
    return
  end
  if ( self.discoveredZones) then
    if ( not self.discoveredZones[zoneIndex] ) then
      self.discoveredZones[zoneIndex] = true
      self.logger:warn('Discovered zone %d', zoneIndex)
      self:queryZoneLabel(zoneIndex)
    end
  end
end

function Prt3:queryZoneStatus(zoneIndex)
  Check.argument(zoneIndex>0)
  self.logger:debug('queryZoneStatus %d', zoneIndex)
  self:addWriteLineData(string.format('RZ%03d', zoneIndex))
end
function Prt3:parseQueryZoneStatusResponse(zoneStatus)
  Check.argument(zoneStatus:len()==8)
  local zoneIndex = tonumber(zoneStatus:sub(1,3))
  local status = zoneStatus:sub(4)
  if ( status == 'OOOOO' ) then
    self:updateZoneStatus(zoneIndex, 255)
    return
  elseif ( status == 'COOOO' ) then
    self:updateZoneStatus(zoneIndex, 0)
    return
  elseif ( status == 'TOOOO' ) then
    self:updateZoneStatus(zoneIndex, 255)
    return
  elseif ( status == 'FOOOO' ) then
    self:updateZoneStatus(zoneIndex, 255)
    return
  end
  self.logger:error('Invalid zone status %s', status)
end
function Prt3:queryZoneLabel(zoneIndex)
  Check.argument(zoneIndex>0)
  self.logger:debug('queryZoneLabel %d', zoneIndex)
  self:addWriteLineData(string.format('ZL%03d', zoneIndex))
end
function Prt3:parseQueryZoneLabelResponse(zoneStatus)
  local zoneIndex = tonumber(zoneStatus:sub(1,3))
  local label = zoneStatus:sub(4)
  self.logger:warn('Found zone label %d %s', zoneIndex, label)
end
function Prt3:addWriteLineData(writeLineData)
  self.logger:debug('addWriteLineData %s', writeLineData)
  table.insert(self.writeLineDatas, writeLineData)
end


local Config = {}
function Config:new(object)
  -- create object if user does not provide one
  object = object or {}   
  setmetatable(object, self)
  self.__index = self
  self.zones = {}
  self.logger = Logger:new('Config',0)
  return object
end

function Config:addZone(zoneIndex, cbusGa) 
  Check.argument(not self.zones[zoneIndex])
  local zone = {
    index = zoneIndex,
    cbusGa = Cbus.getCanonicalGa(cbusGa)
  }
  self.zones[zoneIndex] = zone
  self.logger:debug('addZone %d %s', zoneIndex, zone)
end

function Config:ignoreZones(...)
  for index, zoneIndex in ipairs{...} do
    self:ignoreZone(zoneIndex)
  end
end

function Config:ignoreZone(zoneIndex)
  Check.argument(not self.zones[zoneIndex])
  local zone = {
    index = zoneIndex,
    shouldIgnore = true
    }
  self.zones[zoneIndex] = zone
  self.logger:debug('ignoreZone %d', zoneIndex)
end


return {
  Config = Config,
  Prt3 = Prt3,
}