local Logger = require('user.smartshack-logger')
local Check = require('user.smartshack-check')
local CBus = require('user.smartshack-cbus')

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
  CBus.changeTriggerValue(self.cbusGa[3], 1, self.minLevel, self.maxLevel, self.startLevel, self.timeoutSeconds)
end

function SceneControl:nextLevel2()
  local triggerId = self.cbusGa[3]
  local currentLevel = CBus.getTriggerLevelWithDefault(triggerId, 0)
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

local Control = {
  Scene = SceneControl,
}
return Control
