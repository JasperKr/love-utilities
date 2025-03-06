local defaultIncludePaths = {}    -- add your directories with shaders here (used for including files)
local defaultShaderPaths = { "" } -- add your directories with shaders here (used for loading files)

local clear = require("table.clear")

local colors = {
    ["red"] = "\27[31m",
    ["green"] = "\27[32m",
    ["yellow"] = "\27[33m",
    ["blue"] = "\27[34m",
    ["magenta"] = "\27[35m",
    ["cyan"] = "\27[36m",
    ["white"] = "\27[37m",
    ["reset"] = "\27[0m"
}

local function coloredString(str, color)
    return colors[color] .. str .. colors["reset"]
end

function addDefaultIncludePath(path)
    table.insert(defaultIncludePaths, path)
end

local function lines(str)
    ---@type integer|nil
    local pos = 1;
    return function()
        if not pos then return nil end
        local p1, p2 = string.find(str, "\n", pos, true)
        local line
        if p1 then
            line = str:sub(pos, p1 - 1)
            pos = p2 + 1
        else
            line = str:sub(pos)
            pos = nil
        end
        return line
    end
end

local function addLineToPreviousIncludes(t, lines)
    for i, v in ipairs(t) do
        v[2] = v[2] + lines
        v[3] = v[3] + lines
        addLineToPreviousIncludes(v[4], lines)
    end
end

local cachedShaders = {}

local function loadShaderFile(shaderCode, fileName, depth, enableCache, compileVariables)
    if depth > 20 then
        error("shader: [ " ..
            fileName .. " ] compilation failed\n" .. "too many includes, did you write a recursive include?", 2)
    end

    if fileName and not string.match(fileName, ".glsl") then
        fileName = fileName .. ".glsl"
    end

    if cachedShaders[fileName] and enableCache then
        return
            cachedShaders[fileName].file,
            cachedShaders[fileName].data,
            cachedShaders[fileName].totalLines
    end

    local found = false
    local iterator

    local name = ""
    local finalLines = {}

    if not shaderCode then
        -- shader provided as filename

        -- check if the file exists in any of the default include paths
        for i = 0, #defaultIncludePaths do
            local tempName

            -- if i == 0, then start at the root directory
            if i == 0 then
                tempName = fileName
            else
                tempName = defaultIncludePaths[i] .. fileName
            end


            if love.filesystem.getInfo(tempName) ~= nil then
                local success, tempIterator = pcall(love.filesystem.lines, tempName)
                if not success then
                    print("couldn't find shader file under: " .. tempName)
                end
                if found then
                    error("shader: [ " ..
                        tempName ..
                        " ] compilation failed\n" ..
                        "double include or two shaders with the same name under a different default filepath: " ..
                        fileName,
                        2)
                end
                name = tempName
                iterator = tempIterator
                found = true
            end
        end
    else
        -- shader provided as string

        iterator = lines(shaderCode)
        name = fileName
        found = true
    end

    local shaderData = { name, 1, 1, {} } -- {name, startLine, endLine, {includedFiles}}
    local lineIndex = 0
    local words = {}

    -- if the shader file was not found, return an error
    if not found then
        print("couldn't find shader file: [ " .. name .. " ] compilation failed")
        table.insert(finalLines, "couldn't find shader file: [ " .. name .. " ] compilation failed")
        goto continue
    end


    for line in iterator do
        clear(words)
        for word in string.gmatch(line, "%S+") do
            table.insert(words, word)
        end

        if words[1] == "#include" then
            local includeFileName = string.match(words[2], '[^"]+')
            local shaderLines, includedFileData, lineAmount = loadShaderFile(nil, includeFileName, depth + 1, enableCache,
                compileVariables)
            -- lines, data about the included file {name, startLine, endLine, {includedFiles}} within the included file,
            -- amount of lines in the included file(s)
            table.insert(finalLines, shaderLines)

            local includedShaders = shaderData[4] -- get included files table

            -- check for double includes

            for i, v in ipairs(includedShaders) do
                if v[1] == includeFileName then
                    error("shader: [ " .. name .. " ] compilation failed\n" .. "double include: " .. includeFileName, 2)
                end
            end

            -- add included file data to the current file data
            table.insert(includedShaders, includedFileData) -- add included file data to the current file data

            -- add the current line index to the included file data
            addLineToPreviousIncludes({ includedFileData }, lineIndex) -- add the current line index to the included file data

            lineIndex = lineIndex + lineAmount
            -- increase line index by the amount of lines in the included file
        elseif words[1] == "#defineExtern" then
            -- command is wrapped in a string so we can use spaces, so only use stuff after the first " and before the last "
            local afterFirstQuote = line:sub(line:find('"', nil, true) + 1)

            local lastWordIndex = afterFirstQuote:find('"', nil, true) - 1
            local key = afterFirstQuote:sub(1, lastWordIndex)

            local defaultValue = afterFirstQuote:sub(lastWordIndex + 3)
            -- remove spaces
            defaultValue = defaultValue:gsub("%s+", "")

            local variableName = words[2]

            assert(variableName)

            local value = compileVariables[key]

            if value == nil and defaultValue ~= "" then
                value = defaultValue
            end

            if value == nil then
                value = defaultShaderCompileVariables[key]
            end

            assert(value, "Shader compilation failed due to const define variable [ " .. key .. " ]")

            local newLine = "#define " .. variableName .. " " .. value

            table.insert(finalLines, newLine)
        elseif words[1] == "#defineExternIf" then
            -- command is wrapped in a string so we can use spaces, so only use stuff after the first " and before the last "
            local afterFirstQuote = line:sub(line:find('"', nil, true) + 1)
            local command = afterFirstQuote:sub(1, afterFirstQuote:find('"', nil, true) - 1)

            local name = words[2]
            local ret, err = loadstring("return " .. command)
            if not ret then
                error("Shader compilation failed due to const define variable [ " .. name .. " ].\nError: " .. err)
            end
            assert(name)
            local returned = ret()
            if returned then
                local newLine = "#define " .. name .. " 1"
                table.insert(finalLines, newLine)
            end
        else
            table.insert(finalLines, line)
        end
        lineIndex = lineIndex + 1
    end
    ::continue::

    shaderData[3] = lineIndex

    table.insert(finalLines, "")
    local finalFile = table.concat(finalLines, "\n")

    if depth ~= 0 then
        -- don't cache the main shader file
        cachedShaders[fileName] = {
            file = finalFile,
            data = shaderData,
            totalLines = lineIndex
        }
    end

    return finalFile, shaderData, lineIndex
end

local function findErrorFile(t, line)
    for _, v in ipairs(t) do
        if line >= v[2] and line <= v[3] then
            local fileName, startLine, endLine, included = findErrorFile(v[4], line)
            if fileName then
                return fileName, startLine, endLine, included
            end
            return v[1], v[2], v[3], v[4]
        end
    end
end

local function findErrorLine(err, includedFiles, shaderCode, name, errorPos)
    local i = 0
    local prevLine = ""
    local errorLine = ""
    if errorPos == -1 then error("shader: " .. name .. "\n" .. err, 2) end
    -- find the line before the error line and the error line
    for line in lines(shaderCode) do
        i = i + 1
        if i == errorPos - 1 then
            prevLine = line
        end
        if i == errorPos then
            errorLine = line
            break
        end
    end

    local fileName, startLine, endLine, included = findErrorFile({ includedFiles }, errorPos)
    -- subtract all included files from the errorPos that are before the errorPos in the file

    -- catch #ifdef / #endif's that weren't closed, the error won't be on any lines in any file
    if not included then
        error("shader: [ " .. name .. " ] compilation failed\n" .. "couldn't find error in file" .. "\n" ..
            err, 3)
    end

    local newErrorPos = errorPos
    for i, v in ipairs(included) do
        if v[3] < errorPos then
            newErrorPos = newErrorPos - (v[3] - v[2]) - 1
        end
    end
    errorPos = newErrorPos - startLine + 1
    return errorPos, prevLine, errorLine, fileName
end

defaultShaderCompileVariables = {}

function setDefaultShaderCompileVariable(key, value)
    defaultShaderCompileVariables[key] = value
end

errorOnShaderFailure = true

local function preprocessShader(name, options, compileVariables, esValidation)
    local providedFilename = string.sub(name, -5) == ".glsl"

    options = options or {}

    do
        if not love.filesystem.getInfo(name) and providedFilename then
            for i = 1, #defaultShaderPaths do
                if love.filesystem.getInfo(defaultShaderPaths[i] .. name) then
                    name = defaultShaderPaths[i] .. name
                    break
                end
            end
        end
    end

    local shaderCode, includedFiles, totalLines

    if providedFilename then
        shaderCode, includedFiles, totalLines = loadShaderFile(nil, name, 0, options.cache ~= false,
            compileVariables)
    else
        shaderCode, includedFiles, totalLines = loadShaderFile(name, options.debugname, 0, options.cache ~= false,
            compileVariables)
    end

    if DebugMode then
        local status, warning = love.graphics.validateShader(esValidation, shaderCode)
        if not status then
            -- if the shader failed to compile, get error info

            -- create shader file, without file caches, since that messes up the error line
            if providedFilename then
                shaderCode, includedFiles, totalLines = loadShaderFile(nil, name, 0, false, compileVariables)
            else
                shaderCode, includedFiles, totalLines = loadShaderFile(name, options.debugname, 0, false,
                    compileVariables)
            end

            status, warning = love.graphics.validateShader(esValidation, shaderCode)

            -- replace empty new lines in "warning"

            warning = warning:gsub("\n\n", "\n")
            if warning:sub(-1) == "\n" then
                warning = warning:sub(1, -2)
            end

            if not providedFilename then
                if ErrorOnShaderFailure then
                    error("[NoTraceback]\nShader: " .. coloredString('"' .. "src/" .. name, "green") .. "\n" ..
                        warning, 2)
                else
                    print("\nShader: src/" .. name .. "\n" .. warning, 2)
                end
            end

            -- error in the combined shader file
            local globalErrorPos = 0
            local i = 0
            for line in lines(warning) do
                i = i + 1

                -- the error line occurs on the 3rd line of the warning
                if i == 3 then
                    local words = {}
                    for word in line:gmatch "([^%s]+)" do
                        table.insert(words, word)
                    end
                    local pos = words[2]:gsub(":", "")
                    globalErrorPos = tonumber(pos) or -1
                    break
                end
            end

            -- get the file and the error line relative to the file
            local errorPos, prevLine, errorLine, fileName = findErrorLine(warning, includedFiles,
                shaderCode, name, globalErrorPos)

            local errorName = name

            if fileName ~= name then
                errorName = fileName
            end

            if ErrorOnShaderFailure then
                error("[NoTraceback]\nShader: " .. coloredString('"' .. "src/" .. errorName .. ":" ..
                        errorPos, "green") .. "\n\n" .. (fileName ~= name and ("Included in " .. name .. "\n") or "") ..
                    coloredString("previous line, " .. (errorPos - 1) .. ": " .. prevLine .. "\n" ..
                        "error line, " .. errorPos .. ": " .. errorLine, "cyan") .. "\n" ..
                    warning, 2)
            else
                print("\nShader: src/" .. errorName .. ":" ..
                    errorPos .. "\n\n" .. (fileName ~= name and ("Included in " .. name .. "\n") or "") ..
                    "previous line, " .. (errorPos - 1) .. ": " .. prevLine .. "\n" ..
                    "error line, " .. errorPos .. ": " .. errorLine .. "\n" ..
                    warning, 2)
            end
        end
    end

    return shaderCode
end

local finalName = {}
--- Gets the name of a file from a filepath
---@param path string
---@return string
local function getNameFromFilepath(path)
    clear(finalName)

    local name = path:match("^.+[\\/]([^/]+)$") or path

    local previousWasUpper = false

    for i = 1, #name do
        local char = name:sub(i, i)
        if char == "." then
            break
        end

        if char:upper() == char and tonumber(char) == nil then
            if not previousWasUpper then
                table.insert(finalName, " ")
                previousWasUpper = true -- make sure we don't add multiple spaces for stuff like GTAO or SSAO, but do add them for stuff like SSAOBlur
            end
        else
            previousWasUpper = false
        end

        if i == 1 then
            char = char:upper()
        end

        table.insert(finalName, char)
    end

    return table.concat(finalName)
end

--- Creates a new shader object from a file or a string.
---@param name string filepath or string of the shader
---@param options? {[1]: string?, debugname: string?, cache:boolean, id?:string, validateES?: boolean}|string options for the shader or the debugname
---@return love.Shader
local function newShader(name, options, isComputeShader)
    local t = type(options)

    local isPath = name:sub(-5) == ".glsl" or name:sub(-3) == ".fs" or name:sub(-3) == ".vs" or name:sub(-3) == ".cs"

    if t == "nil" then
        options = { debugname = isPath and getNameFromFilepath(name) or nil }
    elseif t == "string" then
        options = { debugname = options }
    elseif t == "table" then
        if not options.debugname then
            options.debugname = options[1] or (isPath and getNameFromFilepath(name) or nil)
        end
    else
        error("Invalid options type: " .. t)
    end

    local esValidation = not isComputeShader

    if options.validateES ~= nil then
        esValidation = options.validateES
    end

    local shaderCode = preprocessShader(name, options, options, esValidation)

    local shader, success

    if isComputeShader then
        success, shader = pcall(love.graphics.newComputeShader, shaderCode, options)
    else
        success, shader = pcall(love.graphics.newShader, shaderCode, options)
    end

    if (not success or not shader) and ErrorOnShaderFailure then
        error("Shader: " .. name .. "\n" .. shader, 2)
    elseif not success then
        print("Shader: " .. name .. "\n" .. shader)
    end

    return shader
end

return {
    newShader = function(name, options)
        return newShader(name, options, false)
    end,

    newComputeShader = function(name, options)
        return newShader(name, options, true)
    end
}
