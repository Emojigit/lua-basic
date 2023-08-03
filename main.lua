local p = {}

local function copytable(t)
    local rt = {}
    for x,y in pairs(t) do
        rt[x] = y
    end
    return rt
end

local function hexgsub(hex)
    local dec = tonumber(hex,16)
    return string.char(dec)
end

local function print_traceback(traceback)
    print("Execution traceback:")
    for i, tbt in ipairs(traceback) do
        local str_cmdline = {}
        for ci, cv in ipairs(tbt.cmdline) do
            str_cmdline[ci] = tostring(cv)
        end
        print(string.format("#%d %d: %s",i,tbt.line,table.concat(str_cmdline," | ")))
        for k,v in pairs(tbt.vars) do
            print(string.format("\t@  $%s = %s (%s)",k,v,type(v)))
        end
        if tbt.rtnval ~= nil then
            print(string.format("\t-> %s (%s)",tostring(tbt.rtnval),type(tbt.rtnval)))
        end
        if tbt.gotoln then
            print(string.format("\t-> GOTO %d",tbt.gotoln))
        end
        if tbt.err then
            print("\t!  ERROR HERE")
        end
    end
end
p.print_traceback = print_traceback

function p.interpepter(code)
    local codes = {}
    local lbls = {}
    for x in string.gmatch(code,"%c*(%C+)%c*") do
        if string.sub(x,1,1) ~= "#" then
            local curr_line = {}
            for y in string.gmatch(x,"(%S+)%s*") do
                y = string.gsub(y,"\\(%x%x)",hexgsub)
                table.insert(curr_line,y)
            end
            local i = #codes + 1
            curr_line[1] = string.upper(curr_line[1])
            codes[i] = curr_line
            if curr_line[1] == "LBL" then
                if not curr_line[2] then
                    print(string.format("HALT: Invalid syntax of LBL on line %d",i))
                    return 127, {}
                elseif lbls[curr_line[2]] then
                    print(string.format("HALT: LBL with repeated names on line %d",i))
                    return 127, {}
                end
                lbls[curr_line[2]] = i
            end
        end
    end

    local vars = {}
    local traceback = {}
    local i = 0
    while i < #codes do
        i = i + 1
        local curr_line = copytable(codes[i])
        local tbt = {
            line = i,
            cmdline = copytable(curr_line),
            vars = {}
        }
        table.insert(traceback,tbt)
        if curr_line[1] == "LBL" or curr_line[1] == "PASS" then
            -- pass
        else
            for ci,v in ipairs(curr_line) do
                if string.sub(v,1,1) == "$" then
                    local varname = string.sub(v,2)
                    if vars[varname] == nil then
                        print(string.format("HALT: Undefined variable name %s on line %d",varname,ci))
                        tbt.err = true
                        print_traceback(traceback)
                        return 127, {traceback = traceback}
                    end
                    curr_line[ci] = vars[varname]
                    tbt.vars[varname] = vars[varname]
                end
            end
            local rtnval = nil
            if curr_line[1] == "ECHO" then
                if not curr_line[2] then
                    curr_line[2] = ""
                end
                print(curr_line[2])
            elseif curr_line[1] == "GOTO" then
                if curr_line[2] == nil then
                    print(string.format("HALT: GOTO Expect one args on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                if not lbls[curr_line[2]] then
                    print(string.format("HALT: No label with the name %s found on line %d",curr_line[2],i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                i = lbls[curr_line[2]]
                tbt.gotoln = i
            elseif curr_line[1] == "IFGOTO" then
                if curr_line[2] == nil or curr_line[3] == nil then
                    print(string.format("HALT: IFGOTO Expect two args on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                if not type(curr_line[2]) == "boolean" then
                    print(string.format("HALT: IFGOTO condition must be boolean on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                if not lbls[curr_line[3]] then
                    print(string.format("HALT: No label with the name %s found on line %d",curr_line[3],i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                if curr_line[2] then
                    i = lbls[curr_line[3]]
                    tbt.gotoln = i
                end
            elseif curr_line[1] == "HALT" then
                if curr_line[2] == nil then
                    print(string.format("HALT: HALT Expect one args on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                local exitcode = tonumber(curr_line[2]) or -1
                if not(exitcode) or exitcode < 0 or exitcode > 127 then
                    print(string.format("HALT: Invalid HALT exit code %d on line %d",exitcode,i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end 
                if curr_line[3] then
                    local rtnt = {}
                    for i,v in ipairs(curr_line) do
                        if i > 2 then
                            table.insert(rtnt,v)
                        end
                    end
                    rtnt.traceback = traceback
                    return exitcode, rtnt
                end
                return exitcode, {traceback=traceback}
            -- Variables
            elseif curr_line[1] == "SETVAL" then
                if curr_line[2] == nil or curr_line[3] == nil then
                    print(string.format("HALT: SETVAL Expect two args on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                if not type(curr_line[2]) == "string" then
                    print(string.format("HALT: SETVAL name must be string on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                vars[curr_line[2]] = curr_line[3]
            elseif curr_line[1] == "GETVAL" then
                if curr_line[2] == nil then
                    print(string.format("HALT: GETVAL Expect one arg on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                if not type(curr_line[2]) == "string" then
                    print(string.format("HALT: GETVAL name must be string on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                rtnval = vars[curr_line[2]]
                if rtnval == nil then
                    print(string.format("HALT: Undefined variable name %s on line %d",curr_line[2],i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
            elseif curr_line[1] == "DELVAL" then
                if curr_line[2] == nil then
                    print(string.format("HALT: DELVAL Expect one arg on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                if not type(curr_line[2]) == "string" then
                    print(string.format("HALT: DELVAL name must be string on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                vars[curr_line[2]] = nil
            elseif curr_line[1] == "EXISTVAL" then
                if curr_line[2] == nil then
                    print(string.format("HALT: DELVAL Expect one arg on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                if not type(curr_line[2]) == "string" then
                    print(string.format("HALT: DELVAL name must be string on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                rtnval = vars[curr_line[2]] and true or false
            -- Types
            elseif curr_line[1] == "GETTYPE" then
                if curr_line[2] == nil then
                    print(string.format("HALT: GETTYPE Expect one arg on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                local t = type(curr_line[2])
                if t == "number" then
                    rtnval = "NUM"
                elseif t == "string" then
                    rtnval = "STR"
                elseif t == "boolean" then
                    rtnval = "BOOL"
                end
            elseif curr_line[1] == "CHGTYPE" then
                if curr_line[2] == nil or curr_line[3] == nil then
                    print(string.format("HALT: CHGTYPE Expect two args on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                local t = string.upper(curr_line[3])
                if t == "NUM" then
                    rtnval = tonumber(curr_line[2])
                elseif t == "STR" then
                    rtnval = tostring(curr_line[2])
                elseif t == "BOOL" then
                    local lower_val = string.lower(curr_line[2])
                    if lower_val == "true" then
                        rtnval = true
                    elseif lower_val == "false" then
                        rtnval = false
                    else
                        rtnval = curr_line[2] and true or false
                    end
                else
                    print(string.format("HALT: Unknown CHGTYPE type %s on line %d",t,i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
            -- Logic Gates
            elseif curr_line[1] == "EQ" then
                if curr_line[2] == nil or curr_line[3] == nil then
                    print(string.format("HALT: EQ Expect two args on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                if curr_line[2] == curr_line[3] then
                    rtnval = true
                else
                    rtnval = false
                end
            elseif curr_line[2] == "NOT" then
                if curr_line[2] == nil then
                    print(string.format("HALT: NOT Expect one arg on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                if type(curr_line[2]) ~= "boolean" then
                    print(string.format("HALT: NOT Expect boolean on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                rtnval = not curr_line[2]
            elseif curr_line[1] == "AND" then
                if curr_line[2] == nil or curr_line[3] == nil then
                    print(string.format("HALT: AND Expect two args on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                if type(curr_line[2]) ~= "boolean" or type(curr_line[3]) ~= "boolean" then
                    print(string.format("HALT: AND Expect booleans on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                rtnval = (curr_line[2] and curr_line[3])
            elseif curr_line[1] == "OR" then
                if curr_line[2] == nil or curr_line[3] == nil then
                    print(string.format("HALT: OR Expect two args on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                if type(curr_line[2]) ~= "boolean" or type(curr_line[3]) ~= "boolean" then
                    print(string.format("HALT: OR Expect booleans on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                rtnval = (curr_line[2] or curr_line[3])
            -- Maths
            elseif curr_line[1] == "ADD" then
                if curr_line[2] == nil or curr_line[3] == nil then
                    print(string.format("HALT: ADD Expect two args on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                local num1, num2 = tonumber(curr_line[2]), tonumber(curr_line[3])
                if not (num1 and num2) then
                    print(string.format("HALT: ADD Expect valid numbers on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                rtnval = num1 + num2
            elseif curr_line[1] == "MULTIPLY" then
                if curr_line[2] == nil or curr_line[3] == nil then
                    print(string.format("HALT: MULTIPLY Expect two args on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                local num1, num2 = tonumber(curr_line[2]), tonumber(curr_line[3])
                if not (num1 and num2) then
                    print(string.format("HALT: MULTIPLY Expect valid numbers on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                rtnval = num1 * num2
            elseif curr_line[1] == "DIVIDE" then
                if curr_line[2] == nil or curr_line[3] == nil then
                    print(string.format("HALT: DIVIDE Expect two args on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                local num1, num2 = tonumber(curr_line[2]), tonumber(curr_line[3])
                if not (num1 and num2) then
                    print(string.format("HALT: DIVIDE Expect valid numbers on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                rtnval = num1 / num2
            -- Strings
            elseif curr_line[1] == "STRSUB" then
                if curr_line[2] == nil or curr_line[3] == nil then
                    print(string.format("HALT: STRSUB Expect two or three args on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                if not type(curr_line[2]) == "string" then
                    print(string.format("HALT: STRSUB string must be string on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                local num1, num2 = tonumber(curr_line[3]), tonumber(curr_line[4])
                if not num1 or (curr_line[4] ~= nil and not num2) then
                    print(string.format("HALT: STRSUB Expect valid numbers on line %d",i))
                    tbt.err = true
                    print_traceback(traceback)
                    return 127, {traceback = traceback}
                end
                rtnval = string.sub(curr_line[2],num1,num2)
            elseif curr_line[1] == "CONCAT" then
                rtnval = ""
                for l,v in ipairs(curr_line) do
                    if l ~= 1 then
                        if not type(v) == "string" then
                            print(string.format("HALT: CONCAT arg %d is not string on line %d",l,i))
                            tbt.err = true
                            print_traceback(traceback)
                            return 127, {traceback = traceback}
                        end
                        rtnval = rtnval .. v
                    end
                end
            -- Unknown command
            else
                print(string.format("HALT: Unknown command %s on line %d",tostring(curr_line[1]),i))
                tbt.err = true
                print_traceback(traceback)
                return 127, {traceback = traceback}
            end
            -- Write rtn val to $OUTPUT
            vars.OUTPUT = rtnval
            tbt.rtnval = rtnval
        end
    end
    -- If not HALT are called
    return 0, {traceback=traceback}
end

function p.fromfile(path)
    local f = io.open(path, "r")
    if not f then error("File " .. path .. " not found.") end
    local code = f:read("*a")
    return p.interpepter(code)
end

return p