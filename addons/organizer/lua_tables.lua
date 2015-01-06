-- Lua Table quasi-lib

local lt = {}
local ind_sp = 2
local Lua_table = {}

local function tokey(val)
    -- Does not handle table keys
    if type(val) == 'string' then
        return '"'..(val:gsub('\"','\\\"'))..'"'
    else
        return tostring(val)
    end
end

local function generate_whitespace(wsl)
    local cur_wsl,str = 0,''
    while cur_wsl < wsl do
        str = str..'  '
        cur_wsl = cur_wsl + 1
    end
    return str
end

local function table_to_string(t,wsl)
    if type(t) ~= 'table' then return tokey(t) end
    wsl = (wsl or 0) +1
    local str = '{\n'
    for i,v in pairs(t) do
        if i ~= '__raw' then
            str = str..generate_whitespace(wsl)..'['..tokey(i)..'] = '..table_to_string(v,wsl)..',\n'
        end
    end
    return str..generate_whitespace(wsl)..'}'
end

function Lua_table.new()
    return setmetatable({},{__index=function(t,k) if rawget(t,k) then return rawget(t,k) else return rawget(lt,k) end end,
        __tostring = table_to_string})
end

function lt:tostring()
    return tostring(self)
end

return Lua_table