-- Items

local Items = {}
local items = {}
local bags = {}
local item_tab = {}

local function validate_bag(bag_table)
    if (bag_table.access == 'Everywhere' or (bag_table.access == 'Mog House' and windower.ffxi.get_info().mog_house)) and
        windower.ffxi.get_bag_info(bag_table.id) then
        return true
    end
    return false
end

local function validate_id(id)
    return (id and id ~= 0 and id ~= 0xFFFF) -- Not empty or gil
end

function Items.new(loc_items,bool)
    loc_items = loc_items or windower.ffxi.get_items()
    new_instance = setmetatable({}, {__index = function (t, k) if rawget(t,k) then return rawget(t,k) else return rawget(items,k) end end})
    for bag_id,bag_table in pairs(res.bags) do
        if (bool or validate_bag(bag_table)) and (loc_items[bag_id] or loc_items[bag_table.english:lower()]) then
            local cur_inv = new_instance:new(bag_id)
            for inventory_index,item_table in pairs(loc_items[bag_id] or loc_items[bag_table.english:lower()]) do
                if type(item_table) == 'table' and validate_id(item_table.id) then
                    cur_inv:new(item_table.id,item_table.count,item_table.extdata,inventory_index)
                end
            end
        end
    end
    return new_instance
end

function items:new(key)
    local new_instance = setmetatable({_parent = self,_info={n=0,bag_id=key}}, {__index = function (t, k) if rawget(t,k) then return rawget(t,k) else return rawget(bags,k) end end})
    self[key] = new_instance
    return new_instance
end

function items:find(item)
    for bag_id,bag_table in pairs(res.bags) do
        if self[bag_id] and self[bag_id]:contains(item) then
            return bag_id, self[bag_id]:contains(item)
        end
    end
    return false
end

function items:route(start_bag,start_ind,end_bag)
    local failure = false
    local initial_ind = start_ind
    if start_bag ~= 0 and self[0]._info.n < 80 then
        start_ind = self[start_bag][start_ind]:move(0)
    elseif start_bag ~= 0 and self[0]._info.n >= 80 then
        failure = true
        org_warning('Cannot move more than 80 items into inventory')
    end
        
    if start_ind and end_bag ~= 0 and self[end_bag]._info.n < 80 then
        self[0][start_ind]:move(end_bag)
    elseif not start_ind then
        failure = true
        org_warning('Initial movement of the route failed. ('..tostring(start_bag)..' '..tostring(initial_ind)..' '..tostring(start_ind)..' '..tostring(end_bag)..')')
    elseif self[end_bag]._info.n >= 80 then
        failure = true
        org_warning('Cannot move more than 80 items into that inventory ('..end_bag..')')
    end
    return not failure
end

function items:it()
    local i = 0
    return function ()
        while i < 9 do
            i = i + 1
            if self[i%9] then return i%9, self[i%9] end
        end
    end
end

function bags:new(id,count,extdata,index)
    if self._info.n >= 80 then org_warning('Attempting to add another item to a bag with 80 items') return end
    if index and table.with(self,'index',index) then org_warning('Cannot assign the same index twice') return end
    self._info.n = self._info.n + 1
    index = index or self:first_empty()
    self[index] = setmetatable({_parent=self,id=id,count=count,extdata=extdata,index=index,annihilated = false,
        name=res.items[id][_global.language]:lower(),log_name=res.items[id][_global.language..'_log']:lower()},
        {__index = function (t, k) 
            if not t or not k then print('table index is nil error',t,k) end
            if rawget(t,k) then
                return rawget(t,k)
            else
                return rawget(item_tab,k)
            end
        end})
    return index
end

function bags:it()
    local i = 0
    return function ()
        while i < 80 do
            i = i + 1
            if self[i] then return i, self[i] end
        end
    end
end

function bags:first_empty()
    for i=1,80 do
        if not self[i] then return i end
    end
end

function bags:remove(index)
    if not rawget(self,index) then org_warning('Attempting to remove an index that does not exist') return end
    self._info.n = self._info.n - 1
    rawset(self,index,nil)
end

function bags:contains(item,bool)
    bool = bool or false -- Default to only looking at unannihilated items
    for i,v in pairs(self) do
        if (not v.annihilated or bool) and v.id == item.id and v.count >= item.count and v.extdata == item.extdata then
            -- May have to do a higher level comparison here for extdata.
            -- If someone exports an enchanted item when the timer is
            -- counting down then this function will return false for it.
            return i
        end
    end
    return false
end

function item_tab:move(dest_bag,count)
    if not dest_bag then org_warning('Destination bag is invalid.') return false end
    count = count or self.count
    local parent = self._parent
    local targ_inv = parent._parent[dest_bag]
    if not self.annihilated and targ_inv._info.n < 80 and (targ_inv._info.bag_id == 0 or parent._info.bag_id == 0) then
        item_tab:free()
        windower.packets.inject_outgoing(0x29,string.char(0x29,6,0,0)..'I':pack(count)..string.char(parent._info.bag_id,dest_bag,self.index,0x52))
        local new_index = targ_inv:new(self.id, count, self.extdata)
        print(parent._info.bag_id,dest_bag,self.index,new_index)
        parent:remove(self.index)
        return new_index
    elseif targ_inv._info.n >= 80 then
        org_warning('Cannot move the item. Target inventory is full ('..dest_bag..')')
    elseif (targ_inv._info.bag_id ~= 0 and parent._info.bag_id ~= 0) then
        org_warning('Cannot move the item. Attempting to move from a non-inventory to a non-inventory bag ('..parent._info.bag_id..' '..dest_bag..')')
    elseif self.annihilated then
        org_warning('Cannot move the item. It has already been annihilated.')
    end
    return false
end

function item_tab:put_away(usable_bags)
    local current_items = self._parent._parent
    usable_bags = usable_bags or {1,4,2,5,6,7}
    local bag_free
    for _,v in ipairs(usable_bags) do
        if current_items[v]._info.n < 80 then
            bag_free = v
            break
        end
    end
    if bag_free then
        self:move(bag_free,self.count)
    end
end

function item_tab:free()
    if item_tab.status == 5 then
        local eq = windower.ffxi.get_items().equipment
        for _,v in pairs(res.slots) do
            local ind_name = v.english:lower():gsub(' ','_')
            local bag_name = ind_name..'_bag'
            local ind, bag = eq[ind_name],eq[bag_name]
            if item_tab.index == ind and item_tab._parent._info.bag_id == bag then
                windower.packets.inject_outgoing(0x50,string.char(0x50,0x04,0,0,0,v.id,0,0))
                break
            end
        end
    end
    return true
end

function item_tab:annihilate()
    rawset(self,'annihilated',true)
end

return Items