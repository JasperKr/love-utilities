local instancedDrawer = require("drawInstanced")

function love.load()
    local circleVertices = {
        { 0, 0, 0.5, 0.5 },
    }
    for angle = 0, math.pi * 2 + math.pi / 16, math.pi / 16 do
        table.insert(circleVertices,
            { math.cos(angle) * 5, math.sin(angle) * 5, 0.5 + math.cos(angle) / 2, 0.5 + math.sin(angle) / 2 })
    end
    local sphereMesh = love.graphics.newMesh({
        { name = "VertexPosition", format = "floatvec2" },
        { name = "VertexTexCoord", format = "floatvec2" },
    }, circleVertices, "fan", "static")

    local instancedDrawShader = love.graphics.newShader("Examples/instancedDrawShader.glsl")

    PointDrawer = instancedDrawer(
        100,
        instancedDrawShader,
        { 0, 0, 1, 1, 1 },
        {
            { name = "InstancePosition", format = "floatvec2" },
            { name = "InstanceColor",    format = "floatvec3" }
        },
        sphereMesh
    )

    Points = {}

    for i = 1, 10000 do
        table.insert(Points,
            {
                x = love.math.random(0, love.graphics.getWidth()),
                y = love.math.random(0, love.graphics.getHeight()),
                r = love.math.random(0, 255) / 255,
                g = love.math.random(0, 255) / 255,
                b = love.math.random(0, 255) / 255,
                velocityX = math.random(-100, 100),
                velocityY = math.random(-100, 100)
            })
    end
end

function love.draw()
    -- add the points to the instanced drawer and update their position
    for i, point in ipairs(Points) do
        PointDrawer:addInstance({ point.x, point.y, point.r, point.g, point.b })

        point.x = point.x + point.velocityX * love.timer.getDelta()
        point.y = point.y + point.velocityY * love.timer.getDelta()

        if point.x < 0 then
            point.velocityX = math.abs(point.velocityX)
        end

        if point.x > love.graphics.getWidth() then
            point.velocityX = -math.abs(point.velocityX)
        end

        if point.y < 0 then
            point.velocityY = math.abs(point.velocityY)
        end

        if point.y > love.graphics.getHeight() then
            point.velocityY = -math.abs(point.velocityY)
        end
    end

    local instanceAmount = PointDrawer.instanceAmount

    local timingBeforeDraw = love.timer.getTime()

    PointDrawer:draw(true, true)

    local timingAfterDraw = love.timer.getTime()

    -- draw a black square in the top left corner so the text is readable
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, 0, 150, 80)
    love.graphics.setColor(1, 1, 1)

    love.graphics.print("FPS: " .. love.timer.getFPS())
    love.graphics.print("instances: " .. instanceAmount, 0, 20)
    love.graphics.print("buffer size: " .. PointDrawer.instanceBufferSize, 0, 40)
    love.graphics.print(
        "draw time (cpu): " .. math.floor((timingAfterDraw - timingBeforeDraw) * 10000 + 0.5) * 0.1 .. "ms", 0,
        60)
end
