local pretty = require "cc.pretty"
local modem = peripheral.wrap("top") or error("No modem attached", 0)

function findChests()
    local chests = modem.getNamesRemote()
    return chests
end

local chest_names = findChests()

local storage_chests = {}
local input_chests = {} 

FilterType = {None = -1, Item = 0, Items = 1,  ModID = 2}

local filter_mode = FilterType.None

function sortStorageChests() 
    for _, chest in pairs(storage_chests) do 
        sortChest(chest)
    end
end

function sortChest(chest)
    if chest.filter.type == FilterType.None then
        depositItems(chest.name)
    elseif chest.filter.type == FilterType.Item then
        local items = modem.callRemote(chest.name, "list")
        for slot, item in pairs(items) do
            if item.name ~= chest.filter.item then
                depositItem(item, slot, chest.name)
            end
        end
    elseif chest.filter.type == FilterType.Items then
        local items = modem.callRemote(chest.name, "list")
        for slot, item in pairs(items) do
            local correct = false
            for j in pairs(chest.filter.items) do
                if chest.filter.items[j] == item.name then
                    correct = true
                end
            end
            if not correct then
                depositItem(item, slot, chest.name)
            end
        end
    elseif chest.filter.type == FilterType.ModID then
        local items = modem.callRemote(chest.name, "list")
        for slot, item in pairs(items) do
            if chest.filter.modid ~= getItemModID(item.name) then
                depositItem(item, slot, chest.name)
            end
        end
    end
end

function saveChestData(file_name)
    local data = {filter_type = filter_mode, storage_chests = storage_chests}
    --print (textutils.serialise(data))
    io.output(file_name)
    io.write(textutils.serialise(data, { allow_repetitions = true }))
    io.close()
end

function loadChestData(file_name)
    io.input(file_name)
    local data = io.read("a")
    local data = textutils.unserialise(data)
    filter_mode = data.filter_type
    storage_chests = data.storage_chests
end

function addInputChest(chest_name) 
    table.insert(input_chests, chest_name)
end

function isInputChest(chest_name)
    for i, name in pairs(input_chests) do
        if name == chest_name then
            return true
        end
    end
    return false
end

function initChestsWithFilterType(filter_type)
    filter_mode = filter_type
    for i, chest_name in pairs(chest_names) do
        if isInputChest(chest_name) == false then
            local items = getChestItemTypes(chest_name)
            local filter = nil
            if #items == 0 then
                filter = createFilter(FilterType.None)
            else
                filter = createFilter(filter_type)
                if filter.type == FilterType.Item then
                    filter.item = items[1]
                elseif filter.type == FilterType.Items then
                    table.insert(filter.items, items[1])
                elseif filter.type == FilterType.ModID then
                    filter.modid = getItemModID(items[1])
                end
            end
            table.insert(storage_chests, createStorageChest(filter, chest_name))
        end
    end
end

function getItemModID(item_name)
    local index = string.find(item_name, ":")
    if index == nil then
        print("ERROR IN getItemModID, could not get item modID")
    end

    return string.sub(item_name, 1, index-1)
end

function set_add(set, item)
    for k, v in pairs(set) do
        if v == item then
            return
        end
    end
    table.insert(set, item)
end

function getChestItemTypes(chest_name)
    local types = {}
    print(chest_name)
    local items = modem.callRemote(chest_name, "list")
    for _slot, item in pairs(items) do
        set_add(types, item.name)
    end
    return types
end

function isChestFull(chest_name) 
    local items = modem.callRemote(chest_name, "list")
    for slot, item in pairs(items) do
        if item.count < modem.callRemote(chest_name, "getItemLimit", slot) then
            return false
        end
    end
    if #items < modem.callRemote(chest_name, "size") then
        return false
    end
    return true
end

function isChestEmpty(chest_name) 
    local items = modem.callRemote(chest_name, "list")
    if #items == 0 then
        return true
    end
    return false
end

function createFilter(type)
    if type == FilterType.None then
        return {type = type}
    end
    if type == FilterType.Item then
        return {type = type, item = nil}
    end
    if type == FilterType.Items then
        return {type = type, items = nil}
    end
    if type == FilterType.ModID then
        return {type = type, modid =  nil}
    end
end

function countItemsInChest(chest_name)
    local item_counts = {}
    local items = modem.callRemote(chest_name, "list")
    for slot, item in pairs(items) do
        item_counts[item.name] = item_counts[item.name] + 1
    end
    return item_counts
end

function countItemInChest(chest_name, item_name)
    local item_count = 0
    local items = modem.callRemote(chest_name, "list")
    for slot, item in pairs(items) do
        if item.name == item_name then
            item_count = item_count + 1
        end
    end
    return item_count
end

function createStorageChest(filter, chest_name) 
    local chest = {filter = filter, empty = isChestEmpty(chest_name), full = isChestFull(chest_name), item_counts = {}, name = chest_name}
    return chest
end

function depostitInputs()
    for _, input_chest in pairs(input_chests) do
        depositItems(input_chest)
    end
end

function depositItems(source)
    local items = modem.callRemote(source, "list")
    for slot, item in pairs(items) do
        depositItem(item, slot, source)
    end
end

function depositItem(item, slot, source)
    local items_remaining = true
    local chests = getChestsWithItemFilter(item.name)
    for i in pairs(chests) do
        local chest = chests[i]
        if chest ~= nil then--and chest.full == false then
            if moveItem(item, slot, source, chest.name) == 0 then
                items_remaining = false
            end
        end
    end
    if items_remaining == true then
        local chest = getEmptyChest()
        if chest == nil then
            print("ERROR NO MORE SPACE")
        else
            local filter = createFilter(filter_mode)
            if filter.type == FilterType.Item then
                filter.item = item.name
            elseif filter.type == FilterType.Items then
                table.insert(filter.items, item.name)
            elseif filter.type == FilterType.ModID then
                filter.modid = getItemModID(item.name)
            end

            if #chests > 0 then
                filter = chests[1].filter --TODO copy filter
            end
            if chest.filter.type == FilterType.None then
                chest.filter = filter
            end
            moveItem(item, slot, source, chest.name)
        end
    end
end

function moveItem(item, slot, source, destination)
    local n_inserted_items = modem.callRemote(source, "pushItems", destination, slot)
    return item.count - n_inserted_items
end

function getEmptyChest()
    for i in pairs(storage_chests) do
        local items = modem.callRemote(storage_chests[i].name, "list")
        if #items == 0 then
            return storage_chests[i]
        end
    end
    return nil
end

function getChestsWithItemFilter(item_name)
    local chests = {}
    for i, chest in pairs(storage_chests) do
        if chest.filter.type == FilterType.Item then
            if chest.filter.item == item_name then
                table.insert(chests, chest)
            end
        elseif chest.filter.type == FilterType.Items then
            for j in pairs(chest.filter.items) do
                if chest.filter.items[j] == item_name then
                    table.insert(chests, chest)
                end
            end
        elseif chest.filter.type == FilterType.ModID then
            if chest.filter.modid == getItemModID(item_name) then
                table.insert(chests, chest)
            end
        end
    end
    return chests
end

function getChestWithItem(item_name)
    for i in pairs(storage_chests) do
        if chestHasItem(storage_chests[i].name, item_name) then
            return storage_chests[i]
        end
    end
    return nil
end

function chestHasItem(chest_name, item_name)
    local items = modem.callRemote(chest_name, "list")
    for slot, item in pairs(items) do
        if item.name == item_name then
            return true
        end
    end
    return false
end
