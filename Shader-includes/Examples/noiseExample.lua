local includeShaders = require "includeShaders"

local shader
function love.load()
    -- This will load the shader from the Examples folder
    shader = includeShaders("Examples/noiseExample.glsl")
end

function love.draw()
    shader:send("time", love.timer.getTime() / 5.0)

    love.graphics.setShader(shader)
    -- This will draw a rectangle that fills the screen
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
end
