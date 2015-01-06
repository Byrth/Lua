-- Copyright (c) 2014, Byrth
-- All rights reserved.

-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:

    -- * Redistributions of source code must retain the above copyright
      -- notice, this list of conditions and the following disclaimer.
    -- * Redistributions in binary form must reproduce the above copyright
      -- notice, this list of conditions and the following disclaimer in the
      -- documentation and/or other materials provided with the distribution.
    -- * Neither the name of DressUp nor the
      -- names of its contributors may be used to endorse or promote products
      -- derived from this software without specific prior written permission.

-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL Cairthenn BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require 'actions'
res = require 'resources'
bit = require 'bit'
require 'pack'
require 'tables'
texts = require 'texts'
config = require 'config'

--Default settings file:
default_settings = {
    text_box_settings = {
        pos = {
            x = 0,
            y = 0,
        },
        bg = {
            alpha = 255,
            red = 0,
            green = 0,
            blue = 0,
            visible = true
        },
        flags = {
            right = false,
            bottom = false,
            bold = false,
            italic = false
        },
        padding = 0,
        text = {
            size = 12,
            font = 'Consolas',
            fonts = {},
            alpha = 255,
            red = 255,
            green = 255,
            blue = 255
        }
    },
    options = {
        message_printing = false,
    },
}


mob_table = T(windower.ffxi.get_mob_array())

settings = config.load('data\\settings.xml',default_settings)
--config.register(settings,initialize)

box = texts.new('${current_string}',settings.text_box_settings,settings)
box.current_string = ''
box:show()

function listener(act)
    local action = ActionPacket.new(act)
    local targ = action:get_targets()()
    local info = targ:get_actions()():get_basic_info()
    if info and info.conclusion and info.resource and info.conclusion.objects[1] == 'daze' and info.resource =='job_abilities' then
        local name = res.job_abilities[info.spell_id].name
        if not targ.id then for i,v in pairs(targ) do print(i,v) end end
        local targ_tab = windower.ffxi.get_mob_by_id(targ.id)
        local index = targ_tab.index
        
        local duration = 30
        local duration_bonus = 0
        local player = windower.ffxi.get_player()
        if player.main_job == 'DNC' and player.job_points then
            duration_bonus = player.job_points.dnc.step_duration
        end
        
        duration = duration + duration_bonus
        
        if not mob_table[index] then mob_table:append(targ_tab) end
        if not mob_table[index][name] then mob_table[index][name] = {potency = 0,ts = os.clock()} end
        if mob_table[index][name].potency == 0 then
            -- If the monster does not currently have that step, add an extra 30 seconds for the initial boost
            duration = duration + 30
        end
        mob_table[index][name].potency = info.param
        mob_table[index][name].ts = math.min(math.max(mob_table[index][name].ts,os.clock()) + duration, os.clock() + 120 + duration_bonus)
    end
end

dazes = {
    [386]="Quickstep",
    [387]="Quickstep",
    [388]="Quickstep",
    [389]="Quickstep",
    [390]="Quickstep",
    [391]="Box Step",
    [392]="Box Step",
    [393]="Box Step",
    [394]="Box Step",
    [395]="Box Step",
    [396]="Stutter Step",
    [397]="Stutter Step",
    [398]="Stutter Step",
    [399]="Stutter Step",
    [400]="Stutter Step",
    [448]="Feather Step",
    [449]="Feather Step",
    [450]="Feather Step",
    [451]="Feather Step",
    [452]="Feather Step"}

windower.register_event('incoming chunk',function(id,org,modi,is_inj,is_blk)
    if not is_inj and id == 0x00E and bit.band(org:byte(0x0B),0x04) == 4 then
        -- Real NPC Update packet, HP update bit
        local index = org:unpack('H',0x09)
        if not mob_table[index] then mob_table[index] = windower.ffxi.get_mob_by_index(index) end
        -- mob_table[index] can still be nil if that particular 0x00E was the one that initialized a mob in the mob array
        if mob_table[index] and org:byte(0x1F) > mob_table[index].hpp+9 then
            -- Mob has regenned by >10% or died and respawned
            -- This will fail in the case of a player dying or
            -- something with the monster at >91% HP.
            mob_table['Box Step'] = {potency = 0,ts = os.clock()}
            mob_table['Stutter Step'] = {potency = 0,ts = os.clock()}
            mob_table['Feather Step'] = {potency = 0,ts = os.clock()}
            mob_table['Quickstep'] = {potency = 0,ts = os.clock()}
        end
    elseif not is_inj and id == 0x29 then
        local am = {}
        am.actor_id = org:unpack("I",0x05)
        am.target_id = org:unpack("I",0x09)
        am.param_1 = org:unpack("I",0x0D)
        am.param_2 = org:unpack("H",0x11)%2^9 -- First 7 bits
        am.param_3 = math.floor(org:unpack("I",0x11)/2^5) -- Rest
        am.actor_index = org:unpack("H",0x15)
        am.target_index = org:unpack("H",0x17)
        am.message_id = org:unpack("H",0x19)%2^15 -- Cut off the most significant bit
        if not mob_table[am.target_index] then mob_table[am.target_index] = windower.ffxi.get_mob_by_index(am.target_index) end
        if am.message_id == 206 and dazes[am.param_1] then -- Wears off message
            mob_table[am.target_index][dazes[am.param_1]] = {potency = 0,ts = os.clock()}
        end
    end
end)

function make_step_string(name,index)
    if mob_table[index] and mob_table[index][name] and mob_table[index][name].potency > 0 then
        local tdiff = mob_table[index][name].ts - os.clock()
        if tdiff > 0 then
            local r,g,b = 255,math.floor(255*math.min(tdiff,15)/15),math.floor(255*math.min(tdiff,30)/30)
            local padded_name = pad(12,name)
            local padded_potency = pad(2,tostring(mob_table[index][name].potency))
            local str_time = string.format('%.1f',tdiff)
            local padded_time = pad(5,str_time)
            return '\\cs('..r..','..g..','..b..')'..padded_name..' lv.'..padded_potency..' '..padded_time..'\\cr\n'
        else return '' end
    end
    return ''
end

function pad(num,name)
    local str = ''
    name = name and tostring(name) or ''
    for i=1,(num-string.len(name)) do
        str = str..' '
    end
    return str..name
end

function update_box()
    local info = windower.ffxi.get_info()
    if not info.logged_in or info.chat_open or not windower.ffxi.get_player() or not windower.ffxi.get_player().in_combat then
        box.current_string = ''
        return
    end
    local targ = windower.ffxi.get_mob_by_target('st') or windower.ffxi.get_mob_by_target('t')
    if targ and targ.is_npc then
        local str = make_step_string('Box Step',targ.index)..make_step_string('Quickstep',targ.index)..make_step_string('Feather Step',targ.index)..make_step_string('Stutter Step',targ.index)
        local name = targ.name
        if string.len(name) > 17 then
            name = name:sub(1,16)..'.'
        end
        box.current_string =  'Dazes: '..pad(17,name)..'\n'..(string.len(str) > 0 and str or pad(12,'None active')..pad(12))
    else
        box.current_string = 'Dazes: '..pad(17,'Invalid target')
    end
end

windower.register_event('zone change',function()
    mob_table = {}
end)

windower.register_event('addon command',function(...)
    local commands = {...}
    local first_cmd = table.remove(commands,1)
    if approved_commands[first_cmd] then
        local tab = {}
        for i,v in pairs(commands) do
            tab[i] = tonumber(v) or v
        end
        texts[first_cmd](box,unpack(tab))
        settings.text_box_settings = box._settings
        config.save(settings)
    elseif first_cmd == 'reload' then
        windower.send_command('lua r pointwatch')
    elseif first_cmd == 'unload' then
        windower.send_command('lua u pointwatch')
    elseif first_cmd == 'eval' then
        assert(loadstring(table.concat(commands, ' ')))()
    end
end)

windower.register_event('prerender',update_box)

ActionPacket.open_listener(listener)