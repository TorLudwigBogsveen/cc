
peripheral.call("left", "pushItems", "right", 1)

function run()
    while true do
        moveItems()
    end
end

function moveItems()
    local items = peripheral.call("left", "list")
    for slot, item in pairs(items) do
        local items_remaining = true
        if depositItem(item, slot, "left", "right") == 0 then
            items_remaining = false
        end
    end
end

function depositItem(item, slot, source, destination)
    local n_inserted_items = peripheral.call(source, "pushItems", destination, slot)
    return item.count - n_inserted_items
end
