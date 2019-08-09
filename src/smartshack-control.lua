local Logger = require('user.smartshack-logger')
local Check = require('user.smartshack-check')
local Cbus = require('user.smartshack-cbus')

function pulseMultipleAutoLevel(cbusGas, durationSeconds)
  log(string.format('pulseMultipleAutoLevel %d %d', #cbusGas, durationSeconds))
  -- Switch on, only if off or in autolevel
  for index, cbusGa in ipairs(cbusGas) do 
    if ( Cbus.setAutoLevelIfAutoLevel(cbusGa, 0) ) then
      AutoTimer.pushAutoOffCbusGa(cbusGa, durationSeconds)
    end
  end
end
function cancelMultipleAutoOff(cbusGas)
  log(string.format('cancelMultipleAutoOff %d', #cbusGas))
  for index, cbusGa in ipairs(cbusGas) do 
    AutoTimer.cancelAutoOffCbusGa(cbusGa)
  end
end
function setMultipleAutoLevel(cbusGas)
  log(string.format('setMultipleAutoLevel %d', #cbusGas))
  for index, cbusGa in ipairs(cbusGas) do 
    Cbus.setAutoLevel(cbusGa)
  end
end
function setMultipleLevel(cbusGas, level)
	log(string.format('setMultipleLevel %d %s', #cbusGas, level))
  for index, cbusGa in ipairs(cbusGas) do 
  	Cbus.setLevel(cbusGa, level)
  end
end

local SceneControl = {
  logger = Logger:new('SceneControl'),
}
function SceneControl:new(cbusGa, options)
  local object = {}   
  setmetatable(object, self)
  self.__index = self
  self.cbusGa = cbusGa
  Check.argument(cbusGa[1] == 0, 'Must be default network (%d)', cbusGa[1])
  Check.argument(cbusGa[2] == 202, 'Must be trigger application (%d)', cbusGa[2])
  self.maxLevel = options.maxLevel
  Check.argument(self.maxLevel, 'Must define maxLevel')
  self.minLevel = options.minLevel or 0
  self.startLevel = options.startLevel or 1
  self.timeoutSeconds = options.timeoutSeconds or 10
  self.offLevel = options.offLevel or 0
  self.lastTime = 0
  self.logger:showDebug()
  return object
end

function SceneControl:nextLevel()
  Cbus.changeTriggerValue(self.cbusGa[3], 1, self.minLevel, self.maxLevel, self.startLevel, self.timeoutSeconds)
end

function SceneControl:nextLevel2()
  local triggerId = self.cbusGa[3]
  local currentLevel = Cbus.getTriggerLevelWithDefault(triggerId, 0)
  self.logger:debug('nextLevel %d %d', triggerId, currentLevel)
  local nowTime = os.time()
  local elapsedSeconds = nowTime - self.lastTime
  self.lastTime = nowTime
  self.logger:debug('nextLevel %d', elapsedSeconds)
  local nextLevel
  if ( currentLevel == self.offLevel ) then
    -- Does not matter how much time has elapsed
    nextLevel = self.startLevel
  else
    if ( elapsedSeconds >= self.timeoutSeconds ) then
      nextLevel = self.offLevel
    else
      nextLevel = currentLevel + 1
      if ( nextLevel > self.maxLevel ) then
        nextLevel = self.minLevel
      end
      if ( nextLevel < self.minLevel ) then
        nextLevel = self.maxLevel
      end
    end
  end
  self.logger:debug('changeTriggerValue change %d', nextLevel)
  SetTriggerLevel(triggerId,nextLevel)
end  

local PirPresence = {
  logger = Logger:new('PirPresence'),
}
function PirPresence:new(lightCbusGas, options)
  local object = {}   
  setmetatable(object, self)
  self.__index = self
  self.lightCbusGas = lightCbusGas
  self.durationSeconds = options.durationSeconds or 60
  return object
end
function PirPresence:processPirEvent(eventValue)
  PirPresence.logger:info('processPirEvent %d', eventValue)
  if ( eventValue == 0 ) then -- PIR inactive
    pulseMultipleAutoLevel(self.lightCbusGas, self.durationSeconds)
  else
    cancelMultipleAutoOff(self.lightCbusGas)
    setMultipleAutoLevel(self.lightCbusGas)
  end
end

local DoorOpenPresence = {
  logger = Logger:new('DoorOpenPresence'),
}
function DoorOpenPresence:new(lightCbusGas, options)
  local object = {}   
  setmetatable(object, self)
  self.__index = self
  self.lightCbusGas = lightCbusGas
  self.durationSeconds = options.durationSeconds or 60
  return object
end
function DoorOpenPresence:processDoorEvent(eventValue)
  DoorOpenPresence.logger:info('processDoorEvent %d', eventValue)
  if ( eventValue == 0 ) then -- Door closed
    setMultipleLevel(self.lightCbusGas, 0)
  else
    pulseMultipleAutoLevel(self.lightCbusGas, self.durationSeconds)
  end
end

local DoorClosedPresence = {
  logger = Logger:new('DoorClosedPresence'),
}
function DoorClosedPresence:new(lightCbusGas, options)
  local object = {}   
  setmetatable(object, self)
  self.__index = self
  self.lightCbusGas = lightCbusGas
  self.closedDurationSeconds = options.closedDurationSeconds or 300
  self.openDurationSeconds = options.openDurationSeconds or 60
  return object
end
function DoorClosedPresence:processDoorEvent(eventValue)
  DoorClosedPresence.logger:info('processDoorEvent %d', eventValue)
  if ( eventValue == 0 ) then -- Door closed
    local durationSeconds = self.closedDurationSeconds or self.openDurationSeconds
    pulseMultipleAutoLevel(self.lightCbusGas, durationSeconds)
  else
    local durationSeconds = self.openDurationSeconds or self.closedDurationSeconds
    pulseMultipleAutoLevel(self.lightCbusGas, durationSeconds)
  end 
end

local BistableSwitch = {
  logger = Logger:new('BistableSwitch'),
}
function BistableSwitch:new(cbusGa, options)
  local object = {}   
  setmetatable(object, self)
  self.__index = self
  self.cbusGa = cbusGa
  Check.argument(cbusGa[1] == 0, 'Must be default network (%d)', cbusGa[1])
  Check.argument(cbusGa[2] == 202, 'Must be trigger application (%d)', cbusGa[2])
  self.triggerId = cbusGa[3]
  self.maxLevel = options.maxLevel
  Check.argument(self.maxLevel, 'Must define maxLevel')
  self.minLevel = options.minLevel or 0
  self.startLevel = options.startLevel or 1
  self.timeoutSeconds = options.timeoutSeconds or 10
  return object
end
function BistableSwitch:processSwitchEvent(eventValue)
  BistableSwitch.logger:info('processSwitchEvent %d', eventValue)
  local triggerLevel = Cbus.getTriggerLevelWithDefault(self.triggerId, 0)
  if ( triggerLevel > 100 ) then
    triggerLevel = triggerLevel - 100
  end
  if ( eventValue == 0 ) then
    -- Off
    SetTriggerLevel(self.triggerId, 0)
    -- Remember the last value
    local saveLevel = triggerLevel + 100
    SetTriggerLevel(self.triggerId, saveLevel)
    os.sleep(self.timeoutSeconds)
    triggerLevel = GetTriggerLevel(self.triggerId)
    if ( triggerLevel == saveLevel) then
      -- No changes in the last while
      self.logger:info('Resetting')
      SetTriggerLevel(self.triggerId, self.startLevel + 100 -1)
    end
  else
    triggerLevel = triggerLevel + 1
    if ( triggerLevel > self.maxLevel ) then
      triggerLevel = self.minLevel
    end
    SetTriggerLevel(self.triggerId, triggerLevel)
  end
end

local Control = {
  Scene = SceneControl,
  PirPresence = PirPresence,
  DoorOpenPresence = DoorOpenPresence,
  DoorClosedPresence = DoorClosedPresence,
  BistableSwitch = BistableSwitch,
}
return Control

