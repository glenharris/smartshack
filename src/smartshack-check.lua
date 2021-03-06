local Check = {}
local function expand(format, arguments)
  local value = table.remove(arguments, 1)
  if ( value == nil ) then
    return '<nil>'
  end
  return string.format(format, value)
end
function Check.getMessage(caller, message, ...)
  if ( not caller ) then
    error('Invalid caller')
  end
  local returnValue = caller
  
  local arguments = {...}
  if ( message ) then
    returnValue = returnValue .. ': ' .. message:gsub('(%%%w)', function (match) return expand(match, arguments) end )
  end
  return returnValue
end
function Check.argument(condition, message, ...)
  if ( not condition ) then
    error(Check.getMessage('Check.argument', message, ...))
  end
end
function Check.state(condition, message, ...)
  if ( not condition ) then
    error(Check.getMessage('Check.state', message, ...))
  end
end

return Check