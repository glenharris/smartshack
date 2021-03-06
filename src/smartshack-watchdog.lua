local Check = require('user.smartshack-check')
local Logger = require('user.smartshack-logger')
local Cbus = require('user.smartshack-cbus')

local Zone = {}
function Zone:new(cbusGa, durationSeconds)
  local id = table.concat(cbusGa,'/')
  local object = {
    id = id,
    cbusGa = cbusGa,
    durationSeconds = durationSeconds,
    lastIsOn = false,
    maxOffTime = nil,
  }   
  setmetatable(object, self)
  self.__index = self
  return object
end
function Zone:updateLevel()
  local level = Cbus.getLevel(cbusGa)
  if ( level > 0 ) then
    self:updateState(true)
  else
    self:updateState(false)
  end
end
function Zone:updateState(isOn)
  local time = os.time()
  if ( isOn ) then
    if ( not self.lastIsOn ) then
      -- First time we have seen it on
      self.maxOffTime = time + self.durationSeconds;
    else
      if ( time > self.maxOffTime ) then
        alert(string.format('Watchdog is turning off %s after %s', self.id, self.durationSeconds))
        Cbus.setLevel(self.cbusGa, 0)
      end
    end
  else 
    self.maxOffTime = nil
  end
  self.lastIsOn = isOn
end

local Watchdog = {}

function Watchdog:new(prefix)
  -- create object if user does not provide one
  object = {
    zones = {}
  }   
  setmetatable(object, self)
  self.__index = self
  return object
end
function Watchdog:addZone(cbusGa, durationSeconds) 
  local cbusGa = Cbus.getCanonicalGa(cbusGa)
  local zone = Zone:new(cbusGa, durationSeconds)
  Check.argument(not self.zones[zone.id])
  self.zones[zone.id] = zone
  zone:updateLevel()
end
function Watchdog:updateZones()
  for index, zone in pairs(self.zones) do
    zone:updateLevel()
  end
end

return Watchdog