local Logger = require('user.smartshack-logger')
local Check = require('user.smartshack-check')

local Cbus = {
  logger = Logger:new('Cbus'),
  AUTO_LEVEL = 254,
  TIMEOUT_LEVEL = 254,
}
function Cbus.getCanonicalGa(cbusGa)
  local returnValue
  local inputType = type(cbusGa)
  if ( inputType == 'table' ) then
    returnValue = {unpack(cbusGa)}
    if ( type(cbusGa[1])=='string' ) then
      returnValue[1] = GetCBusNetworkAddress(cbusGa[1])
    end
    if ( type(cbusGa[2])=='string' ) then
      returnValue[2] = GetCBusApplicationAddress(returnValue[1], cbusGa[2])
    end
    if ( type(cbusGa[3])=='string' ) then
      returnValue[3] = GetCBusGroupAddress(returnValue[1], returnValue[2], cbusGa[3])
      Check.argument(returnValue[3], 'Invalid group address %s', cbusGa[3])
    end
  elseif ( inputType == 'number' ) then
      returnValue = {0,56, cbusGa}
  elseif ( inputType == 'string' ) then
    returnValue = {0,56, GetCBusGroupAddress(0, 56, cbusGa)}
  end
  return returnValue
end
function Cbus.isEqualCbusGa(first, second)
  if ( first and second ) then
    if ( #first == 3 and #second == 3 ) then
      return first[1] == second[1]  and first[2] == second[2] and first[3]==second[3]
    end
  else
    if ( not first and not second ) then
      return true
    end
  end
  return false
end
function Cbus.setLevel(cbusGa, level)
  Cbus.logger:debug('setLevel %s %d', table.concat(cbusGa,'/'), level) 
  if ( cbusGa[2]==202 and cbusGa[1] == 0 ) then
    SetTriggerLevel(cbusGa[3],level)
  else
    SetCBusLevel(cbusGa[1],cbusGa[2],cbusGa[3],level,0)
  end
end
--[[
function Cbus.pulseAutoLevel(cbusGa, durationSeconds)
  local currentValue = GetCBusLevel(cbusGa[1],cbusGa[2],cbusGa[3])
  if ( currentValue == 0 or currentValue == 254) then
	  Cbus.logger:debug('pulseAutoLevel %s %d', table.concat(cbusGa,'/'), durationSeconds) 
    PulseCBusLevel(cbusGa[1],cbusGa[2],cbusGa[3], 254, 0, durationSeconds, 0)
  else
    Cbus.logger:debug('pulseAutoLevel ignoring %s %d', table.concat(cbusGa,'/'), currentValue) 
  end
end
]]--
function Cbus.setAutoLevel(cbusGa)
  Cbus.logger:debug('setAutoLevel %s', table.concat(cbusGa,'/')) 
  SetCBusLevel(cbusGa[1],cbusGa[2],cbusGa[3],Cbus.AUTO_LEVEL,0)
end
function Cbus.setAutoLevelIfAutoLevel(cbusGa, testLevel)
  Cbus.logger:debug('setAutoLevelIfAutoLevel %s', table.concat(cbusGa,'/'))
  local currentLevel = GetCBusLevel(cbusGa[1],cbusGa[2],cbusGa[3])
  local isMatch = false
  local isAutoLevel = false
  if ( currentLevel) then
    if ( currentLevel == Cbus.AUTO_LEVEL ) then
      -- Do nothing
      isAutoLevel = true
    elseif ( testLevel and currentLevel == testLevel) then
      isMatch = true
    end
  end
  if ( isMatch ) then
    Cbus.setLevel(cbusGa,Cbus.AUTO_LEVEL)
    isAutoLevel = true
  else
	  Cbus.logger:debug('setAutoLevelIfAutoLevel ignoring %s %d %s', table.concat(cbusGa,'/'), currentLevel, testLevel) 
  end
  return isAutoLevel
end
function Cbus.setLevelIfAutoLevel(cbusGa, level, testLevel)
  Cbus.logger:debug('setLevelIfAutoLevel %s %d', table.concat(cbusGa,'/'), level)
  local currentLevel = GetCBusLevel(cbusGa[1],cbusGa[2],cbusGa[3])
  local isMatch = false
  if ( currentLevel) then
    if ( currentLevel == Cbus.AUTO_LEVEL ) then
      isMatch = true
    elseif ( testLevel and currentLevel == testLevel) then
      isMatch = true
    end
  end
  if ( isMatch ) then
    Cbus.setLevel(cbusGa,level)
  else
	  Cbus.logger:debug('setLevelIfAutoLevel ignoring %s %d %s', table.concat(cbusGa,'/'), currentLevel, testLevel) 
  end
  return isMatch
end

function Cbus.pulseMultipleAutoLevel(cbusGas, durationSeconds)
  Cbus.logger:debug('pulseMultipleAutoLevel %d %d', #cbusGas, level)
  -- Switch on, only if off or in autolevel
  for index, cbusGa in ipairs(cbusGas) do
    Cbus.setAutoLevelIfAutoLevel(cbusGa, 0)
  end
  os.sleep(durationSeconds)
  for index, cbusGa in ipairs(cbusGas) do
    Cbus.setLevelIfAutoLevel(cbusGa, 0)
  end
end

function Cbus.changeTriggerValue(triggerId, delta, minValue, maxValue, timeoutValue, timeoutSeconds)
  local currentTrigger = GetTriggerLevel(triggerId)
  Cbus.logger:debug('changeTriggerValue %d %d %d (%d-%d) %d after %d', triggerId, currentTrigger, delta, minValue, maxValue, timeoutValue, timeoutSeconds)
  local numSeconds = 10
  local nextTrigger = currentTrigger + delta
  if ( currentTrigger == Cbus.TIMEOUT_LEVEL ) then
    nextTrigger = timeoutValue
  end
  if ( currentTrigger < minValue ) then
    nextTrigger = maxValue
  end
  if ( currentTrigger > maxValue ) then
    nextTrigger = minValue
  end
  Cbus.logger:debug('changeTriggerValue change %d', nextTrigger)
  SetTriggerLevel(triggerId,nextTrigger)
  if ( nextTrigger ~= timeoutValue ) then
    os.sleep(numSeconds)
      --Check to see if we have changed during this time
    currentTrigger = GetTriggerLevel(triggerId)
    if ( currentTrigger == nextTrigger) then
      Cbus.logger:debug('toggleTrigger idle', nextTrigger)
      SetTriggerLevel(triggerId, Cbus.TIMEOUT_LEVEL)
    end
  end
end
            
return Cbus
