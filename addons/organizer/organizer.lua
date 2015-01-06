--Copyright (c) 2014, Byrthnoth
--All rights reserved.

--Redistribution and use in source and binary forms, with or without
--modification, are permitted provided that the following conditions are met:

--    * Redistributions of source code must retain the above copyright
--      notice, this list of conditions and the following disclaimer.
--    * Redistributions in binary form must reproduce the above copyright
--      notice, this list of conditions and the following disclaimer in the
--      documentation and/or other materials provided with the distribution.
--    * Neither the name of <addon name> nor the
--      names of its contributors may be used to endorse or promote products
--      derived from this software without specific prior written permission.

--THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
--ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
--WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
--DISCLAIMED. IN NO EVENT SHALL <your name> BE LIABLE FOR ANY
--DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
--(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
--LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
--ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
--(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
--SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

res = require 'resources'
files = require 'files'
require 'pack'
Items = require 'items'
Lua_table = require 'lua_tables'
extdata = require 'extdata'
require 'tables'
require 'functions'

_addon.name = 'Organizer'
_addon.author = 'Byrth'
_addon.version = 0.042914
_addon.command = 'org'

if not windower.dir_exists('data') then
    windower.create_dir('data')
end

_global = {
    language = 'english',
    language_log = 'english_log',
    }

_settings = {dump_bags = {1,4,2},
             bag_priority = {1,4,2,5,6,7}
             }


windower.register_event('addon command',function(...)
    local inp = {...}
    -- get (g) = Take the passed file and move everything to its defined location.
    -- tidy (t) = Take the passed file and move everything that isn't in it out if my active inventory.
    -- organize (o) = get followed by tidy.
    local command = table.remove(inp,1):lower()
    local bag
    if inp[1] and (_static.bag_ids[inp[1]:lower()] or inp[1]:lower() == 'all') and #inp > 1 then
        bag = table.remove(inp,1):lower()
    end
    file_name = table.concat(inp,' ')
    if file_name:sub(-4) ~= '.lua' then
        file_name = file_name..'.lua'
    end
    
    if _static.valid_commands[command] then
        --if not files.exists('data/'..file_name) then error('File not found.') end
        _static.valid_commands[command](thaw(file_name,bag))
    elseif command == 'freeze' and bag then
        local items = Items.new(windower.ffxi.get_items(),true)
        items[3] = nil -- Don't export temporary items
        
        if _static.bag_ids[bag] then
            freeze(file_name,bag,items)
        else
            for bag_id,item_list in items:it() do
                freeze(file_name,res.bags[bag_id].english:lower(),items)
            end
        end
        
    elseif command == 'test' then
        windower.send_command('org freeze test;wait 2;org thaw test')
    elseif command == 'eval' then
        assert(loadstring(file_name))()
    end
end)

function get(goal_items,current_items)
    if goal_items then
        current_items = current_items or Items.new()
        goal_items, current_items = clean_goal(goal_items,current_items)
        for bag_id,inv in goal_items:it() do -- Should really be using #res.bags +1 for this instead of 9
            for ind,item in inv:it() do
                if not item.annihilated then
                    local start_bag, start_ind = current_items:find(item)
                    -- Table contains a list of {bag, pos, count}
                    if start_bag then
                        if not current_items:route(start_bag,start_ind,bag_id) then
                            org_warning('Unable to move item.')
                        end
                    else
                        -- Need to adapt this for stacking items somehow.
                        org_warning(res.items[item.id].english..' not found')
                    end
                end
            end
        end
    end
    return goal_items, current_items
end

function freeze(file_name,bag,items)
    local lua_export = Lua_table.new()
    for slot_id,item_table in items[_static.bag_ids[bag]]:it() do
        local temp_ext,augments = extdata.decode(item_table)
        if temp_ext.augments then
            augments = table.filter(temp_ext.augments,-functions.equals('none'))
        end
        lua_export[#lua_export +1] = {name = item_table.name,log_name=item_table.log_name,
            id=item_table.id,extdata=item_table.extdata:hex(),augments = augments,count=item_table.count}
    end
    
    local export_file = files.new('/data/'..bag..'/'..file_name,true)
    export_file:write('return '..tostring(lua_export))
end

function tidy(goal_items,current_items,usable_bags)
    -- Move everything out of items[0] and into other inventories (defined by the passed table)
    if goal_items and goal_items[0] and goal_items[0]._info.n > 0 then
        current_items = current_items or Items.new()
        goal_items, current_items = clean_goal(goal_items,current_items)
        for index,item in current_items[0]:it() do
            if not goal_items[0]:contains(item,true) then
                current_items[0][index]:put_away(usable_bags)
            end
        end
    end
    return goal_items, current_items
end

function organize(goal_items)
    windower.add_to_chat(8,'start!')
    local current_items = Items.new()
    if current_items[0].n == 80 then
        tidy(goal_items,current_items,_settings.dump_bags)
    end
    if current_items[0].n == 80 then
        org_error('Unable to make space, aborting!')
        return
    end
    
    local remainder = math.huge
    while remainder do
        goal_items, current_items = get(goal_items,current_items)
        
        goal_items, current_items = clean_goal(goal_items,current_items)
        goal_items, current_items = tidy(goal_items,current_items,_settings.dump_bags)
        remainder = incompletion_check(goal_items,remainder)
        windower.add_to_chat(1,tostring(remainder)..' '..current_items[0]._info.n)
    end
    goal_items, current_items = tidy(goal_items,current_items)
end

function clean_goal(goal_items,current_items)
    for i,inv in goal_items:it() do
        for ind,item in inv:it() do
            local potential_ind = current_items[i]:contains(item)
            if potential_ind then
                -- If it is already in the right spot, delete it from the goal items and annihilate it.
                goal_items[i][ind]:annihilate()
                current_items[i][potential_ind]:annihilate()
            end
        end
    end
    return goal_items, current_items
end

function incompletion_check(goal_items,remainder)
    -- Does not work. On cycle 1, you fill up your inventory without purging unnecessary stuff out.
    -- On cycle 2, your inventory is full. A gentler version of tidy needs to be in the loop somehow.
    local remaining = 0
    for i,v in goal_items:it() do
        for n,m in v:it() do
            if not m.annihilated then
                remaining = remaining + 1
            end
        end
    end
    if remaining < remainder and remaining ~= 0 then
        -- Still making progress
        return remaining
    else
        return false
    end
end

function thaw(file_name,bag)
    local bags = _static.bag_ids[bag] and {[bag]=_static.bag_ids[bag]} or table.reassign({},_static.bag_ids) -- One bag name or all of them if no bag is specified
    bags.temporary = nil
    local inv_structure = {}
    for bag in pairs(bags) do
        local f,err = loadfile(windower.addon_path..'data/'..bag..'/'..file_name)
        if f and not err then
            local success = false
            success, inv_structure[bag] = pcall(f)
            if not success then
                org_warning('User File Error 2: '..inv_structure[bag])
                inv_structure[bag] = nil
            end
        else
            org_warning('User File Error 1: '..err)
        end
    end
    -- Convert all the extdata back to a normal string
    for i,v in pairs(inv_structure) do
        for n,m in pairs(v) do
            if m.extdata then
                inv_structure[i][n].extdata = string.parse_hex(m.extdata)
            end
        end
    end
    return Items.new(inv_structure)
end

function org_warning(msg)
    --windower.add_to_chat(123,'Organizer: '..msg)
end

function org_error(msg)
    error('Organizer: '..msg)
end


_static = {
    valid_commands = {
        get=get,
        g=get,
        tidy=tidy,
        t=tidy,
        organize=organize,
        o=organize,
        },
    bag_ids = {
        inventory=0,
        safe=1,
        storage=2,
        temporary=3,
        locker=4,
        satchel=5,
        sack=6,
        case=7,
        wardrobe=8,
        },
    }