local Check = require('user.smartshack-check')
local Logger = require('user.smartshack-logger')
local Cbus = require('user.smartshack-cbus')
local Channel = require('user.smartshack-channel')

local AutoTimer = {
    channel = Channel:new('AutoTimer'),
}

function AutoTimer:new()
  -- create object if user does not provide one
  object = {
    actions = {},
    logger = Logger:new('AutoTimer')
  }   
  setmetatable(object, self)
  self.__index = self
  --object.logger:showTrace()
  --object.logger:showDebug()
  object.logger:showInfo()
  return object
end

function AutoTimer.pushAutoOffCbusGa(cbusGa, timeSeconds)
  local targetTime = os.time() + timeSeconds
  log(string.format('AutoTimer: pushAutoOffCbusGa %d %d', timeSeconds, targetTime))
  local action = {
    targetTime = targetTime,
    autoOffCbusGa = cbusGa,
  }
  AutoTimer.channel:write(action)  
end
function AutoTimer.cancelAutoOffCbusGa(cbusGa)
  log(string.format('AutoTimer: cancelAutoOffCbusGa'))
  local action = {
    autoOffCbusGa = cbusGa,
  }
  AutoTimer.channel:write(action)  
end

function AutoTimer:runEventLoop(maxSeconds) 
  self.logger:debug('runEventLoop %d %d', maxSeconds, #self.actions)
  if ( self.logger:isTrace() ) then
    for index, action in ipairs(self.actions) do
      self.logger:trace('action %d %d', index, action.targetTime)
    end
  end
  local startTime = os.time()
  local finishTime = startTime + maxSeconds
  while (true ) do
    local currentTime = os.time()
    if ( currentTime >= finishTime ) then
      break
    end
    local actions = AutoTimer.channel:readList()
    if ( #actions > 0 ) then
      self.logger:debug('add %d', #actions)
      for index, action in ipairs(actions) do
        self:addAction(action)
      end
    end
    local nextAction = nil
    while ( true ) do
      nextAction = self:getNextAction()
      if ( nextAction) then
        if ( self:processAction(nextAction) ) then
	        self:removeAction(nextAction)
        else
          break
        end
      else
        break
      end
    end
    local sleepSeconds = 1
    if ( nextAction ) then
      if ( nextAction.targetTime) then
        local remainingSeconds = nextAction.targetTime - os.time()
        if ( remainingSeconds < sleepSeconds) then
          sleepSeconds = remainingSeconds
        end
      end
    end
    if ( sleepSeconds > 0 ) then
      self.logger:trace('sleep %d', sleepSeconds)
      os.sleep(sleepSeconds)
    end
	end
  self.logger:trace('runEventLoop finish')
end

function AutoTimer:processAction(action)
  self.logger:trace('processAction %d %d', action.targetTime, os.time())
  if ( action.targetTime ) then
    local remainingTime = action.targetTime - os.time()
    if ( remainingTime <= 0 ) then
      if ( action.autoOffCbusGa ) then
        self.logger:info('Turning off auto light')
        Cbus.setLevelIfAutoLevel(action.autoOffCbusGa, 0 )
      else
        self.logger:warn('Unable to process action %s', action)
      end
      return true
    else
      self.logger:debug('processAction not yet (%d)', remainingTime)
    end
  end
  return false
end

function AutoTimer:getNextAction()
  local earliestTime
  local earliestAction
  for index, action in ipairs(self.actions) do
    if ( action.targetTime ) then
      if ( not earliestTime or action.targetTime < earliestTime ) then
        earliestTime = action.targetTime
        earliestAction = action
      end
    end
  end
  return earliestAction
end

function AutoTimer:removeAction(action)
  for index, localAction in ipairs(self.actions) do
    if ( localAction == action ) then
      self.logger:info('Removing action')
      table.remove(self.actions, index)
      break
    end
  end
end

function AutoTimer:addAction(action)
  local existingAction
  if ( action.autoOffCbusGa ) then
    for index, localAction in ipairs(self.actions) do
      if ( localAction.autoOffCbusGa ) then
        if ( Cbus.isEqualCbusGa(localAction.autoOffCbusGa, action.autoOffCbusGa) ) then
          existingAction = localAction
          break
        end
      end
    end
  end
  if ( existingAction ) then
    if ( action.targetTime ) then
      if ( existingAction.targetTime ) then
        local deltaTime = action.targetTime - existingAction.targetTime
        if ( deltaTime > 0 ) then
          self.logger:info('Extending existing action %d', deltaTime)
        end
        if ( deltaTime < 0 ) then
          self.logger:info('Shortening existing action %d', deltaTime)
        end
        existingAction.targetTime = action.targetTime
        return
      end
    else
      self.logger:info('Removing existing action')
      self:removeAction(existingAction)
    end
  else
    if ( action.targetTime ) then
      self.logger:info('Inserting action')
      table.insert(self.actions, action)
    else
      self.logger:debug('Ignoring missing delete')
    end
  end
end

return AutoTimer