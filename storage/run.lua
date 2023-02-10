require("storage")

addInputChest("minecraft:chest_19")

loadChestData("chest_data")
--initChestsWithFilterType(FilterType.ModID)

while true do
    depostitInputs()
    saveChestData("chest_data")
    print("ticked")
end
