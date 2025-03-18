---@diagnostic disable: undefined-field
---@class iDIndexedTable<T>: { items: {[integer]: T}, indexTable: { string: integer }, key: (string | integer | number), add: fun(self: iDIndexedTable, v: T), get: fun(self: iDIndexedTable, id: (string | integer | number)): (T?), remove: fun(self: iDIndexedTable, index: number): (T?), removeAsObject: fun(self: iDIndexedTable, v: T): (T?), removeById: fun(self: iDIndexedTable, id: any): (T?), clear: fun(self: iDIndexedTable, ), setKey: fun(self: iDIndexedTable, object: T, key: (string | integer | number)) }
local iDIndexedTableFunctions = {}
local indexedTableMetatable = {
    __index = iDIndexedTableFunctions
}

---Creates a new indexed table
---@generic T
---@param key? string
---@return iDIndexedTable<T>
local function newIdIndexedTable(key)
    local t = {
        indexTable = {},
        items = {},
        key = key or "id",
    }
    setmetatable(t, indexedTableMetatable)
    return t
end

---@class objectIndexedTable<T>: { items: {[integer]: T}, indexTable: { string: integer}, key: (string | integer | number), add: fun(self: objectIndexedTable, v: T), get: fun(self: objectIndexedTable, id: (string | integer | number)): (T?), remove: fun(self: objectIndexedTable, index: number): (T?), removeAsObject: fun(self: objectIndexedTable, v: T): (T?), clear: fun(self: objectIndexedTable, ), setKey: fun(self: objectIndexedTable, object: T, key: (string | integer | number)) }
local objectIndexedTableFunctions = {}

local objectIndexedTableMetatable = {
    __index = objectIndexedTableFunctions
}

---@generic T
---@return objectIndexedTable<T>
local function newObjectIndexedTable()
    return setmetatable({ indexTable = {}, items = {} }, objectIndexedTableMetatable)
end

---@generic T
---@param v T
---@param self iDIndexedTable<T>
function iDIndexedTableFunctions:add(v)
    table.insert(self.items, v)
    self.indexTable[v[self.key]] = #self.items
end

function iDIndexedTableFunctions:get(id)
    return self.items[self.indexTable[id]]
end

---removes something from the table
---@param index number
---@generic T
---@param self iDIndexedTable<T>
function iDIndexedTableFunctions:remove(index)
    -- get the object at the index
    local w = self.items[index]

    -- if the object is the last object in the table, we can just remove it
    if index == #self.items then
        self.indexTable[w[self.key]] = nil
        return table.remove(self.items, index)
    else
        -- get the index and object of the last object in the table
        local lastIndex = #self.items
        local lastObject = self.items[lastIndex]

        -- swap the object at the index with the last object
        self.items[index] = lastObject
        self.indexTable[lastObject[self.key]] = index

        -- remove the last object
        self.indexTable[w[self.key]] = nil
        return table.remove(self.items, #self.items)
    end
end

---@generic T
---@param self iDIndexedTable<T>
function iDIndexedTableFunctions:removeAsObject(v)
    -- if the object is valid and has an id
    if v and v[self.key] then
        local index = self.indexTable[v[self.key]]

        -- if the object is in the table
        if index then
            -- if the object is the last object in the table, we can just remove it
            if index == #self.items then
                self.indexTable[v[self.key]] = nil
                return table.remove(self.items, index)
            else
                -- get the index and object of the last object in the table
                local lastObject = self.items[#self.items]
                self.items[index] = lastObject

                -- if the last object has a valid id, update the index table
                if lastObject then
                    self.indexTable[lastObject[self.key]] = index
                end

                -- remove the object from the index table and the table
                self.indexTable[v[self.key]] = nil
                return table.remove(self.items, #self.items)
            end
        end
    end
end

--- removes an object from the table by id
---@generic T
---@param self iDIndexedTable<T>
---@param id string
---@return any
function iDIndexedTableFunctions:removeById(id)
    -- if the id is valid
    if id then
        return self:remove(self.indexTable[id])
    end
end

function objectIndexedTableFunctions:add(v)
    table.insert(self.items, v)
    self.indexTable[v] = #self.items
end

---removes something from the table
---@param i number
function objectIndexedTableFunctions:remove(i)
    local w = self.items[i]
    if i == #self.items then
        self.indexTable[w] = nil
        return table.remove(self.items, i)
    else
        local lastIndex = #self.items
        local lastObject = self.items[lastIndex]
        self.items[i] = lastObject
        self.indexTable[lastObject] = i
        self.indexTable[w] = nil
        return table.remove(self.items, #self.items)
    end
end

function objectIndexedTableFunctions:removeAsObject(v)
    assert(v, "Object is nil")
    local i = self.indexTable[v]
    if i then
        if i == #self.items then
            self.indexTable[v] = nil
            table.remove(self.items)
        else
            local lastObject = self.items[#self.items]
            self.items[i] = lastObject
            if lastObject then
                self.indexTable[lastObject] = i
            end
            self.indexTable[v] = nil
            table.remove(self.items)
        end

        return true
    end

    return false
end

function objectIndexedTableFunctions:clear()
    table.clear(self.items)
    table.clear(self.indexTable)
end

function iDIndexedTableFunctions:clear()
    table.clear(self.items)
    table.clear(self.indexTable)
end

function objectIndexedTableFunctions:setKey(object, key)
    local index = self.indexTable[object]
    if index then
        self.indexTable[object] = nil
        self.indexTable[key] = index
    end
end

---@generic T
---@param self iDIndexedTable<T>
function iDIndexedTableFunctions:setKey(object, key)
    local index = self.indexTable[object[self.key]]
    if index then
        self.indexTable[object[self.key]] = nil
        self.indexTable[key] = index
    end
end

local function readonlyTable(data)
    return setmetatable({}, {
        __index = data,
        __newindex = function()
            error("Attempt to modify a readonly table", 2)
        end,
    })
end

return {
    newIdIndexedTable = newIdIndexedTable,
    newObjectIndexedTable = newObjectIndexedTable,
    readonlyTable = readonlyTable,
}
