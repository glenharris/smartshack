-- user function library
-- user function library
local Control = require('user.smartshack-control')
local Cbus = require('user.smartshack-cbus')
local Cache = require('user.smartshack-cache')
local AutoTimer = require('user.smartshack-autotimer')
 
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
    cancelAutoOff(lights)
    setMultipleAutoLevel(lights)
  end
end
function securityPirPresenceLightOld(event, lights, durationSeconds)
  local value = event.getvalue()
  log(string.format('securityPirPresenceLight %s %d', event.dst, value))
  if ( value == 0 ) then -- PIR inactive
    -- Do nothing when closing
  else
    pulseMultipleAutoLevel(lights, durationSeconds)
  end
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
  Cbus.changeTriggerValue( triggerId, 1, 0, maxValue, 0, 10)
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
  log(string.format('bistableSwitch %s %d %d', event.dst, table.concat(cbusGa,'/')))
  Cbus.setLevel( cbusGa, value)
end

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
