if ( not autoTimer ) then
	local AutoTimer = require('user.smartshack-autotimer')
	autoTimer = AutoTimer:new()
  autoTimer.logger:showDebug()
end
if ( autoTimer) then
	autoTimer:runEventLoop(20) 
end