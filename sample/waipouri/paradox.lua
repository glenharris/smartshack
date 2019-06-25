if ( not paradox ) then
  log('Initialising paradox')
  local Paradox = require('user.smartshack-paradox')
  local ParadoxPrt3 = Paradox.Prt3
  local ParadoxConfig = Paradox.Config

  local config = ParadoxConfig:new()
  --[[
  config:addZone(1, {0,1,'H1CJ Hall Entry'})
  config:addZone(2, {0,1,'H1CA Hall outside Kids'})
  config:addZone(3, {0,1,'R8CM Garage Entry'})
  config:addZone(4, {0,1,'H1CF Hall outside Nursery'})
  config:addZone(5, {0,1,'B1CE Master Bathroom'})
  config:addZone(15, {0,1,'D7 Kids Toilet'})
  config:addZone(16, {0,1,'D4 Linen'})
  config:addZone(43, {0,1,'D19 Master Toilet'})
  config:addZone(47, {0,1,'R8CD Garage East'})
  config:addZone(48, {0,1,'R10CD Scullery'})
  config:addZone(52, {0,1,'D16 Wine'})
  config:addZone(61, {0,1,'R7CB Laundry'})
  config:addZone(72, {0,1,'D26 Laundry External'})
  config:addZone(113, {0,1,'L3CD Games'})
  config:addZone(161, {0,1,'R8CC Garage West'})
  config:ignoreZone(13) -- W7
  config:ignoreZone(14) -- W5
  config:ignoreZone(78) -- R2
  config:ignoreZone(79) -- R4CG
  config:ignoreZone(86) -- R3CE
  config:ignoreZone(87) -- L2CE
  config:ignoreZone(108) -- R5CC
  config:ignoreZone(109) -- R1CE
  config:ignoreZone(111) -- R9CB
  config:ignoreZone(159) -- L1CH
  config:ignoreZone(173) -- D25
--]]
  paradox = ParadoxPrt3:new()
--  paradox.logger:showTrace()
  if ( not paradox:initialiseFirst('/dev/ttyUSB', config)) then
    paradox:dispose()
    paradox = nil
    log('Unable to open paradox - waiting one minute...')
    os.sleep(60)
  end
end
if ( paradox ) then
  --log('runEventLoop')
  paradox:runEventLoop(60)
  --log('done')
end


