local tables = require("Tables.tables")

local testTable = tables.newObjectIndexedTable()


local object_1 = { name = "test1" }

testTable:add(object_1)
testTable:add({ name = "test2" })
testTable:add({ name = "test3" })

for i, v in ipairs(testTable.items) do
    print(i, v.name)
end

print("Removing object 1")

testTable:removeAsObject(object_1)

for i, v in ipairs(testTable.items) do
    print(i, v.name)
end

local idTable = tables.newIdIndexedTable()

idTable:add({ name = "test1", id = 1 })
idTable:add({ name = "test2", id = 2 })
idTable:add({ name = "test3", id = 3 })

local object_4 = { name = "test4", id = 4 }
idTable:add(object_4)

print("Printing idTable")

for i, v in ipairs(idTable.items) do
    print(i, v.name)
end

print("Removing object 2")

idTable:removeById(2)

for i, v in ipairs(idTable.items) do
    print(i, v.name)
end

print("Removing object 4")

idTable:removeAsObject(object_4)

for i, v in ipairs(idTable.items) do
    print(i, v.name)
end

local readonlyTable = tables.readonlyTable({ 1, 2, 3, 4, 5 })

for i = 1, 5 do -- #, ipairs, pairs don't work
    print(i, readonlyTable[i])
end

readonlyTable[1] = 10

love.event.quit()
