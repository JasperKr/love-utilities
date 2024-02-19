# Shaders-include
a copy of my game engine's shader include system

Allows for including other shaders using the following syntax, both are valid: 
```
#include "filename"
#include filename
```
Shows the error on the line in the actual included file.

# Instanced-drawing
a copy of my game engine's instanced drawing system

Allows for easily drawing meshes instanced using love's drawInstanced function:

Create a drawer object: 
local newDrawer = require("drawInstanced")

local drawerObject = newDrawer(100, -- default buffer size  
    shader, -- the shader to use when drawing  
    defaultData, -- the data to fill the vertices with when creating a new buffer  
    vertexFormat, -- the format to instance the mesh with, might contain something like: position, color, etc  
    instancedMesh -- the mesh to draw  
)

in your love.draw:

when you want to draw an instance of that object, use addInstance:

drawerObject:addInstance(vertices)

then when you're done with adding the instances and want to present it on screen, use:

in most cases you want to set useShader, resetShader to true or nil. however,  
if you want to draw multiple instanced objects using the same shader in a row  
you don't need to set and reset it every time. Or if you want to draw the objects  
multiple times, you can set clear instances to false and it won't reset the index  
(if you don't reset it every frame it will just keep increasing which is really bad)  

drawerObject:draw(useShader, resetShader, clearInstances)
