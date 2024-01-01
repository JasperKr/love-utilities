local function lines(str)
    local pos = 1;
    return function()
        if not pos then return nil end
        local p1, p2 = string.find(str, "\r?\n", pos)
        local line
        if p1 then
            line = str:sub(pos, p1 - 1)
            pos = p2 + 1
        else
            line = str:sub(pos)
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
local function loadShaderFile(name, depth)
    if depth > 20 then
        error("shader: [ " ..
            name .. " ] compilation failed\n" .. "too many includes, did you make a recursive include?")
    end

    local finalFile = ""
    local shaderData = { name, 1, 1, {} } -- {name, startLine, endLine, {includedFiles}}
    local lineIndex = 0
    for line in love.filesystem.lines(name) do
        local words = {}
        for word in line:gmatch "([^%s]+)" do
            table.insert(words, word)
        end
        if words[1] == "#include" then
            local fileName = string.gsub(string.gsub(words[2], [["]], ""), [[']], "")
            local shaderLines, includedFileData, lineAmount = loadShaderFile(fileName, depth + 1)
            -- lines, data about the included file {name, startLine, endLine, {includedFiles}} within the included file, amount of lines in the included file(s)
            finalFile = finalFile .. shaderLines .. "\n"

            local includedShaders = shaderData[4] -- get included files table

            -- check for double includes

            for i, v in ipairs(includedShaders) do
                if v[1] == fileName then
                    error("shader: [ " .. name .. " ] compilation failed\n" .. "double include: " .. fileName)
                end
            end

            -- add included file data to the current file data
            table.insert(includedShaders, includedFileData) -- add included file data to the current file data

            -- add the current line index to the included file data
            addLineToPreviousIncludes({ includedFileData }, lineIndex) -- add the current line index to the included file data

            lineIndex = lineIndex + lineAmount
            -- increase line index by the amount of lines in the included file
        else
            finalFile = finalFile .. line .. "\n"
        end
        lineIndex = lineIndex + 1
    end

    shaderData[3] = lineIndex

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

return function(name, options)
    local shaderFile, includedFiles, totalLines = loadShaderFile(name, 0)

    local ran, shader = pcall(love.graphics.newShader, shaderFile, options)
    if not ran then
        local i = 0
        local errorPos = 0
        for line in lines(shader) do
            i = i + 1
            if i == 2 then
                local words = {}
                for word in line:gmatch "([^%s]+)" do
                    table.insert(words, word)
                end
                local pos = words[2]:gsub(":", "")
                errorPos = tonumber(pos) or -1
                break
            end
        end
        local prevLine = ""
        local errorLine = ""
        i = 0
        -- find the line before the error line and the error line
        for line in lines(shaderFile) do
            i = i + 1
            if i == errorPos - 1 then
                prevLine = line
            end
            if i == errorPos then
                errorLine = line
                break
            end
        end

        local errorInIncludedFileName = name

        -- find the file that the error is in
        local fileName, startLine, endLine, included = findErrorFile({ includedFiles }, errorPos)
        -- subtract all included files from the errorPos that are before the errorPos in the file

        -- catch #ifdef / #endif's that weren't closed, the error won't be on any lines in any file
        if not included then
            error("shader: [ " .. name .. " ] compilation failed\n" .. "couldn't find error in file" .. "\n" ..
                shader)
        end
        
        local newErrorPos = errorPos
        for i, v in ipairs(included) do
            if v[3] < errorPos then
                newErrorPos = newErrorPos - (v[3] - v[2]) - 1
            end
        end
        errorPos = newErrorPos - startLine + 1

        errorInIncludedFileName = fileName

        local errorName = name

        if errorInIncludedFileName ~= name then
            errorName = '"' .. errorInIncludedFileName .. '" Included in: "' .. name .. '"'
        end

        error("shader: [ " .. errorName .. " ] compilation failed\n" ..
            "previous line, " .. (errorPos - 1) .. ": " .. prevLine .. "\n" ..
            "error line, " .. errorPos .. ": " .. errorLine .. "\n" .. "\n" ..
            shader)
    else
        return shader
    end
end
