-- this implementation's limitation is needing to set the fill the data every frame, which is not efficient
-- i can implement it otherwise but it's more convienient to use this way

local instancedDrawFunctions = {}
local instancedDrawMetatable = {
    __index = instancedDrawFunctions
}

--- create an instanced drawer
---@param bufferSize integer the initial size of the instance buffer and the increment size
---@param shader love.Shader the shader to use for drawing
---@param defaultData table the data to fill the buffer with
---@param vertexformat table the vertex format to use for the mesh (position, color, etc)
---@param instancedMesh love.Mesh the mesh to draw instanced
---@return table
local function newInstancedDrawer(bufferSize, shader, defaultData, vertexformat, instancedMesh)
    local creationBuffer = {}

    for i = 1, bufferSize do
        creationBuffer[i] = { unpack(defaultData) } -- make sure we don't reference the same table
    end

    local self = {
        instanceAmount = 0,
        instanceBufferSize = bufferSize,
        instanceBufferIncrement = bufferSize,
        inverseInstanceBufferIncrement = 1 / bufferSize,
        instanceData = {},
        instanceShader = shader,
        instanceDefaultData = defaultData,
        meshData = love.graphics.newMesh(vertexformat, creationBuffer, "points", "dynamic"),
        vertexformat = vertexformat,
        instancedMesh = instancedMesh
    }

    for i, format in ipairs(vertexformat) do
        instancedMesh:attachAttribute(format.name, self.meshData, "perinstance")
    end

    return setmetatable(self, instancedDrawMetatable)
end

function instancedDrawFunctions:draw(useShader, resetShader)
    local amount = self.instanceAmount
    local changedBuffer = false

    if useShader then
        love.graphics.setShader(self.instanceShader)
    end

    -- if the amount of instances is greater than the buffer size, increase the buffer size
    while math.ceil(amount * self.inverseInstanceBufferIncrement) * self.instanceBufferIncrement > self.instanceBufferSize do
        local startingBufferSize = self.instanceBufferSize

        -- increase the buffer size by the increment
        self.instanceBufferSize = self.instanceBufferSize + self.instanceBufferIncrement

        -- fill the buffer with new data
        for i = startingBufferSize, self.instanceBufferSize do
            self.instanceData[i] = { unpack(self.instanceDefaultData) }
        end

        changedBuffer = true
    end

    if changedBuffer then
        self.meshData = love.graphics.newMesh(self.vertexformat, self.instanceData, "points", "stream")
        for i, format in ipairs(self.vertexformat) do
            self.instancedMesh:attachAttribute(format.name, self.meshData, "perinstance")
        end
    else
        self.meshData:setVertices(self.instanceData)
    end
    love.graphics.drawInstanced(self.instancedMesh, self.instanceAmount)

    self:clearInstances()

    if useShader and resetShader then
        love.graphics.setShader()
    end
end

function instancedDrawFunctions:addInstance(data)
    self.instanceAmount = self.instanceAmount + 1
    self.instanceData[self.instanceAmount] = data
end

function instancedDrawFunctions:clearInstances()
    self.instanceAmount = 0
    --table.clear(self.instanceData) -- no need to clear the table, just reset the amount and only draw the amount of instances
end

return newInstancedDrawer
