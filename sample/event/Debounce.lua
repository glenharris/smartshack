local currentControl=event.getvalue()
log(string.format('tvLift %d',currentControl))
-- States:
-- 0: Closed
-- 1: Closing
-- 255: Open
-- 254: Opening

local controlGroup=34
local stateGroup=35
local currentState=getCbusTriggerLevelWithDefault(stateGroup, nil)
local newState
if ( currentControl == 0 ) then
  -- User wants it to be closed
  if ( currentState == nil or currentState == 255 ) then
    newState = 1
  end
end
if ( currentControl == 255 ) then
  -- User wants it to be Open
  if ( currentState == nil or currentState == 0 ) then
    newState = 254
  end
end
log(string.format('tvLift %s->%s',currentState, newState))
if ( newState ) then
  SetTriggerLevel(stateGroup, newState)
  log(string.format('tvLift set %s',currentControl))
  --SetCBusState(0,56,30, currentControl)
  local transitionSeconds=20 -- seconds
  os.sleep(transitionSeconds)
  local updatedState=getCbusTriggerLevelWithDefault(stateGroup, nil)
  local updatedControl=getCbusTriggerLevelWithDefault(controlGroup, nil)
  log(string.format('tvLift updateState %s->%d->%d %d->%d',currentState, newState, updatedState, currentControl, updatedControl))
  SetTriggerLevel(stateGroup,currentControl)
  if ( updatedControl ~= currentControl ) then
    log(string.format('tvLift reverse %d->%d',currentControl,updatedControl))
    SetTriggerLevel(controlGroup,updatedControl)
  end
else
  log(string.format('tvLift ignoring %d %s',currentControl, currentState))  
end
