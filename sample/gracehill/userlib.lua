-- user function library
local Control = require('user.smartshack-control')
local Cbus = require('user.smartshack-cbus')
local Cache = require('user.smartshack-cache')
local AutoTimer = require('user.smartshack-autotimer')
local Paradox = require('user.smartshack-paradox')
local Check = require('user.smartshack-check')

local ParadoxPrt3 = Paradox.Prt3
local paradox = ParadoxPrt3:new()

function triggerParadoxUtilityKey(key)
  log(string.format('triggerParadoxUtilityKey %d', key))
  paradox:sendCommandUtilityKey(key)
end
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

function securityPirPresenceLight(event, lights, durationSeconds)
  local value = event.getvalue()
  log(string.format('securityPirPresenceLight %s %d', event.dst, value))
  if ( value == 0 ) then -- PIR inactive
    pulseMultipleAutoLevel(lights, durationSeconds)
  else
    cancelMultipleAutoOff(lights)
    setMultipleAutoLevel(lights)
  end
end
function securityPirPresenceLightEntertain(event, lights, options)
  local entertainMode = GetTriggerLevel(20)
  local value = event.getvalue()
  if ( entertainMode ~= 0 ) then
    if ( value == 0 ) then
	    log(string.format('securityPirPresenceLightEntertain ignoring %s %s', event.dst, value))
  	  return
    end
  end
  log(string.format('securityPirPresenceLightEntertain %s %s', event.dst, value))
  local control = Cache.getOptionalItem('PirPresence', event.dst)
  if ( not control ) then
    log(string.format('create %s %s', event.dst, triggerName))
    local lightCbusGas = Cbus.getCanonicalGas(lights)
    control = Control.PirPresence:new(lightCbusGas, options)
    Cache.setItem('PirPresence', event.dst, control)
  end
  control:processPirEvent(value)
end

function securityDoorRoomOpenLight(event, lights, durationSeconds)
  -- Used for a wine cellar - keep the light on, only for as long as the door is open, off when the door closes
  local value = event.getvalue()
  if ( value == 0 ) then -- Door closed
    setMultipleLevel(lights, 0)
  else
    pulseMultipleAutoLevel(lights, durationSeconds)
  end
end
function securityDoorRoomClosedLight(event, lights, durationClosedSeconds, durationOpenSeconds)
  -- Used for a toilet - keep the light on, only for as long as the door is closed, and then for a little while once it is opened
  local value = event.getvalue()
  log(string.format('securityDoorRoomClosedLight %s %d', event.dst, value))
  if ( value == 0 ) then -- Door closed
    local durationSeconds = durationClosedSeconds or durationOpenSeconds
    pulseMultipleAutoLevel(lights, durationSeconds)
  else
    local durationSeconds = durationOpenSeconds or durationClosedSeconds
    pulseMultipleAutoLevel(lights, durationSeconds)
  end 
end

function nextTriggerValue(event, triggerId, maxValue) 
  log(string.format('nextTriggerValue %s %d %d', event.dst, triggerId, maxValue))
  Cbus.changeTriggerValue( triggerId, 1, 0, maxValue, 1, 10)
end
function nextSceneLevel(event, triggerName, options) 
  log(string.format('nextSceneLevel %s %s', event.dst, triggerName))
  local control = Cache.getOptionalItem('Scene', triggerName)
  if ( not control ) then
    log(string.format('create %s %s', event.dst, triggerName))
    local cbusGa = Cbus.getCanonicalGa(triggerName)
    control = Control.Scene:new(cbusGa, options)
    Cache.setItem('Scene', triggerName, control)
  end
  control:nextLevel()
end
function setTriggerLevelFromEvent(event, triggerName, onLevel)
  local cbusGa = Cbus.getCanonicalGa(triggerName)
  Check.argument(cbusGa[1] == 0, 'Must be default network (%d)', cbusGa[1])
  Check.argument(cbusGa[2] == 202, 'Must be trigger application (%d)', cbusGa[2])
  local triggerId = cbusGa[3]
  local eventValue = event.getvalue()
  if ( eventValue ~= 0 ) then
    if ( onLevel ) then
	    eventValue = onLevel
    end
  end
  log(string.format('setTriggerLevelFromEvent %s %d %d', event.dst, event.getvalue(), eventValue))
  SetTriggerLevel(triggerId, eventValue)
end
function bistableNextTriggerValueNew(event, triggerName, options) 
  log(string.format('bistableNextTriggerValueNew %s %s', event.dst, triggerName))
  local control = Cache.getOptionalItem('BistableSwitch', triggerName)
  if ( not control ) then
    log(string.format('create %s %s', event.dst, triggerName))
    local cbusGa = Cbus.getCanonicalGa(triggerName)
    control = Control.BistableSwitch:new(cbusGa, options)
    Cache.setItem('BistableSwitch', triggerName, control)
    local test = Cache.getOptionalItem('BistableSwitch', triggerName)
    if ( not test ) then
      log('hello')
    end
  end
  control:processSwitchEvent(event.getvalue())
end
function bistableNextTriggerValue(event, triggerId, maxValue) 
  log(string.format('bistableNextTriggerValue %s %d %d', event.dst, triggerId, maxValue))
  local value = event.getvalue()
  local triggerLevel = GetTriggerLevel(triggerId)
  if ( triggerLevel > 100 ) then
    triggerLevel = triggerLevel - 100
  end
  if ( value == 0 ) then
    SetTriggerLevel(triggerId, 0)
    -- Remember the last value
    SetTriggerLevel(triggerId, triggerLevel + 100)
  else
    triggerLevel = triggerLevel + 1
    if ( triggerLevel > maxValue ) then
      triggerLevel = 1
    end
    SetTriggerLevel(triggerId, triggerLevel)
  end
end
function bistableSwitch(event, cbusGa) 
  local value = event.getvalue()
  log(string.format('bistableSwitch %s %s', event.dst, table.concat(cbusGa,'/')))
  Cbus.setLevel( cbusGa, value)
end

--[[

function updateTrigger(triggerId, value, maxValue) 
  log('updateTrigger', triggerId, value, maxValue)
  local name = 'trigger-' .. tostring(triggerId)
  local clockId = 'trigger-' .. tostring(triggerId) .. '-clock'
  local newValue
  local currentValue
  if value == 0 then
    newValue = 0
  elseif value == 248 then
    newValue = maxValue
  elseif value == 100 then
    -- Next value, with off in between each
    currentValue = GetCBusLevel(0,202,triggerId)
    if currentValue > 0 then
      newValue = 0
    else 
      if checkClockGreaterThan(clockId, 10000) then
        newValue = maxValue
      else
        local lastValue = storage.get(name .. '-value', 0)
        newValue = lastValue - 1
      end
    end
  elseif value == 10 then
    -- Next value, without off in between each, but off when wrapping
    if checkClockGreaterThan(clockId, 10000) then
      newValue = maxValue
    else
      currentValue = GetTriggerLevel(triggerId)
      newValue = currentValue - 1
    end
  elseif value == 210 then
    -- Dummy stage in between levels from momentaries
    return
  end
  if newValue ~= nil then
    if newValue == -1 then
      newValue = maxValue
    end
    if newValue < 0 then
      log('updateTrigger clamp', newValue)
      newValue = 0
    end
    if newValue > maxValue then
      log('updateTrigger clamp', newValue, maxValue)
      newValue = maxValue
    end
    log('updateTrigger setting', currentValue, newValue)
    if newValue > 0 then
      storage.set(name .. '-value', newValue)
    end
    SetTriggerLevel(triggerId,newValue)
    log('updateTrigger final', GetTriggerLevel(triggerId))
    updateClock(clockId)
  else
    log('updateTrigger unknown', value) 
  end
end

function toggleTrigger(triggerId, value, maxValue) 
  local currentTrigger = GetTriggerLevel(triggerId)
  local numSeconds = 10
  log('toggleTrigger', triggerId, value, currentTrigger, maxValue)
  local nextTrigger = 0
  if ( currentTrigger < maxValue ) then
    nextTrigger = currentTrigger + 1
  end
  -- Havent timed out, so move to next state
  if ( nextTrigger > 0 ) then
    log('toggleTrigger pulse', nextTrigger)
    SetTriggerLevel(triggerId,nextTrigger)
    sleep(numSeconds)
    currentTrigger = GetTriggerLevel(triggerId)
    if ( currentTrigger == nextTrigger) then
      log('toggleTrigger idle', nextTrigger)
      SetTriggerLevel(triggerId, 255)
    end
  else
    -- Was on, now need to set off
    log('toggleTrigger off')
    SetTriggerLevel(triggerId, nextTrigger, 0)
  end  
  log('toggleTrigger2 done')
end
function updateGroup(applicationId, groupId, value) 
  --log('updateGroup', applicationId, groupId, value)
  -- Set application 56 group 1 on the local network to full brightness over 12 seconds.
  SetCBusLevel(0, applicationId, groupId, value, 0)
end
--]]
local COLORS = {};
COLORS[1]={255,0,0}
COLORS[2]={0,255,0}
COLORS[3]={0,0,255}
COLORS[4]={255,69,0}
COLORS[5]={167,0,255}
local COLOR_NAMES = {"red", "green", "blue", "orange", "purple"}
for i, name in ipairs(COLOR_NAMES) do
  COLORS[name]=COLORS[i]
end

function getColor(index)
  if index == 0 then
    return {0,0,0}
  end
  local color = COLORS[index]
  if color ~= nil then
    return color
  end
  return {255,255,255}
end

function updateGroupColor(networkId, applicationId, groupIds, color)
  local redId,blueId,greenId = unpack(groupIds)
  local redColor, blueColor, greenColor = unpack(color)
  SetCBusLevel(0, applicationId, redId, redColor, 0)
  SetCBusLevel(0, applicationId, blueId, blueColor, 0)
  SetCBusLevel(0, applicationId, greenId, greenColor, 0)
end
--[[

function updateClock(id)
  storage.set(id, os.time())
end

function checkClockGreaterThan(id, thresholdSeconds)
  local last = storage.get(id)
  if last == nil then
    return true
  end
  local now = os.time()
  if now - last > thresholdSeconds then
    return true
  end
  return false
end
--]]
-- send an e-mail
function mail(to, subject, message)
  -- make sure these settings are correct
  local settings = {
    -- "from" field, only e-mail must be specified here
    from = 'example@gmail.com',
    -- smtp username
    user = 'example@gmail.com',
    -- smtp password
    password = 'mypassword',
    -- smtp server
    server = 'smtp.gmail.com',
    -- smtp server port
    port = 465,
    -- enable ssl, required for gmail smtp
    secure = 'sslv23',
  }

  local smtp = require('socket.smtp')

  if type(to) ~= 'table' then
    to = { to }
  end

  for index, email in ipairs(to) do
    to[ index ] = '<' .. tostring(email) .. '>'
  end

  -- message headers and body
  settings.source = smtp.message({
    headers = {
      to = table.concat(to, ', '),
      subject = subject,
      ['Content-type'] = 'text/html; charset=utf-8',
    },
    body = message
  })

  -- fixup from field
  settings.from = '<' .. tostring(settings.from) .. '>'
  settings.rcpt = to

  return smtp.send(settings)
end

-- sunrise / sunset calculation
function rscalc(latitude, longitude, when)
  local pi = math.pi
  local doublepi = pi * 2
  local rads = pi / 180.0

  local TZ = function(when)
    local ts = os.time(when)
    local utcdate, localdate = os.date('!*t', ts), os.date('*t', ts)
    localdate.isdst = false

    local diff = os.time(localdate) - os.time(utcdate)
    return math.floor(diff / 60) / 60
  end

  local range = function(x)
    local a = x / doublepi
    local b = doublepi * (a - math.floor(a))
    return b < 0 and (doublepi + b) or b
  end

  when = when or os.date('*t')

  local y2k = { year = 2000, month = 1, day = 1 }
  local y2kdays = os.time(when) - os.time(y2k)
  y2kdays = math.ceil(y2kdays / 86400)

  local meanlongitude = range(280.461 * rads + 0.9856474 * rads * y2kdays)
  local meananomaly = range(357.528 * rads + 0.9856003 * rads * y2kdays)
  local lambda = range(meanlongitude + 1.915 * rads * math.sin(meananomaly) + rads / 50 * math.sin(2 * meananomaly))

  local obliq = 23.439 * rads - y2kdays * rads / 2500000

  local alpha = math.atan2(math.cos(obliq) * math.sin(lambda), math.cos(lambda))
  local declination = math.asin(math.sin(obliq) * math.sin(lambda))

  local LL = meanlongitude - alpha
  if meanlongitude < pi then
    LL = LL + doublepi
  end

  local dfo = pi / 216.45

  if latitude < 0 then
    dfo = -dfo
  end

  local fo = math.min(math.tan(declination + dfo) * math.tan(latitude * rads), 1)
  local ha = 12 * math.asin(fo) / pi + 6

  local timezone = TZ(when)
  local equation = 12 + timezone + 24 * (1 - LL / doublepi) - longitude / 15

  local sunrise, sunset = equation - ha, equation + ha

  if sunrise > 24 then
    sunrise = sunrise - 24
  end

  if sunset > 24 then
    sunset = sunset - 24
  end

  return math.floor(sunrise * 60), math.ceil(sunset * 60)
end
