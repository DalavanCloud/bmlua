module(..., package.seeall);

require('os')
require('io')
require('bmlua.path')
require('bmlua.set')
local set = bmlua.set
require('bmlua.str')

------------------------------------------------------------------------------
-- LOCAL (PRIVATE) CONSTANTS
------------------------------------------------------------------------------

-- from http://www.php.net/manual/en/function.escapeshellcmd.php
local BAD_SHELL_CHARS = '[#&;`|%*%?~<>^%(%)%[%]%{%}%$%\\\010\255\'\"]'
local DRY_RUN_ARG = '--noaction'
local TMPFS_ARG = '-d ram'
local OPKG_CMD = '/bin/opkg'
local NEVER_REMOVE = {'libc', 'uclibcxx'}
local OPKG_CONF_FILENAME = "/etc/opkg.conf"

------------------------------------------------------------------------------
-- LOCAL (PRIVATE) FUNCTIONS
------------------------------------------------------------------------------

local shell_escape = function (s)
    return string.gsub(s, '(' .. BAD_SHELL_CHARS .. ')', '\\%1')
end

local opkg_build_cmd = function (cmd, args, dry_run)
    local cmdparts = {}
    cmdparts[#cmdparts + 1] = OPKG_CMD
    if dry_run then
        cmdparts[#cmdparts + 1] = DRY_RUN_ARG
    end
    cmdparts[#cmdparts + 1] = cmd
    cmdparts[#cmdparts + 1] = args
    local cmdstr = shell_escape(table.concat(cmdparts, ' '))
    return cmdstr
end

local opkg_cmd_status = function (cmd, args, dry_run)
    local retval = nil
    local cmdstr = opkg_build_cmd(cmd, args, dry_run) .. ' > /dev/null 2>&1'
    retval = os.execute(cmdstr)
    if dry_run then
        print(string.format("os.execute(%q) = %d", cmdstr, retval))
    end
    return retval
end

local opkg_cmd_stdout = function (cmd, args, dry_run)
    local stdout = {}
    local cmdstr = opkg_build_cmd(cmd, args, dry_run) .. ' 2> /dev/null'
    f = io.popen(cmdstr)
    for line in f:lines() do
        stdout[#stdout + 1] = line
    end
    if dry_run then
        print(string.format("io.popen(%q) = {", cmdstr))
        for k,v in pairs(stdout) do
            print('    "' .. v .. '",')
        end
        print('}')
    end
    return stdout
end

------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
------------------------------------------------------------------------------

function depends_on(pkg)
    local deps = nil
    local out = opkg_cmd_stdout('whatdepends', pkg)
    if #out >= 3 then
        deps = {}
        for i=4,#out do
            deps[#deps + 1] = bmlua.str.strip(out[i])
        end
    end
    return deps
end

function info(pkg)
    local status = {available = false}
    local out = opkg_cmd_stdout('info', pkg)
    if #out > 0 then
        status.available = true
        status.depends = {}
        for k,v in pairs(out) do
            if v:match("^Status: ") then
                status.installed = ((v:match('%s+installed%s+') ~= nil) or
                                    (v:match('%s+installed$') ~= nil))
            elseif v:match("^Version: ") then
                status.version = v:match('^Version: ([^%s]+)')
            elseif v:match("^Installed%-Time: ") then
                status.installed_time = v:match('^Installed%-Time: ([^%s]+)')
            elseif v:match("^Depends: ") then
                local depstr = v:sub(9)
                status.depends = bmlua.str.split(depstr, ', ', false)
            end
        end
    end
    return status
end

function install(pkg, dry_run)
    local deps = info(pkg).depends
    assert(deps ~= nil)
    for k,v in pairs(deps) do
        install(v, dry_run)
    end
    local cmd = '--nodeps ' .. pkg
    if pkg:match('-tmpfs$') then
        cmd = TMPFS_ARG .. ' ' .. cmd
    end
    assert(opkg_cmd_status('install', cmd, dry_run) == 0)
    -- TODO better error handling than this assertion approach?
end

function remove(pkg, dry_run)
    for k,v in pairs(NEVER_REMOVE) do
        assert(v ~= pkg)
    end
    local cmd = '--force-depends ' .. pkg
    assert(opkg_cmd_status('remove', cmd, dry_run) == 0)
    -- TODO check for "No packages removed."
end

function list_installed(dry_run)
    installed_packages = set.Set()
    for _, line in pairs(opkg_cmd_stdout("list-installed", "", dry_run)) do
        result = line:match("^(%S+) -")
        if result ~= nil then
            installed_packages:add(result)
        end
    end
    return installed_packages
end

local get_package_list_directory = function()
    local list_directory = nil
    local handle = io.open(OPKG_CONF_FILENAME, "r")
    if handle ~= nil then
        for line in handle:lines() do
            directory = line:match("^lists_dir%s+%S+%s+(%S+)$")
            if directory ~= nil then
                list_directory = directory
            end
        end
        handle:close()
    end
    return list_directory
end
local package_list_directory = get_package_list_directory()

function get_package_lists()
    local lists = set.Set()
    local handle = io.open(OPKG_CONF_FILENAME, "r")
    if handle ~= nil then
        for line in handle:lines() do
            local name = line:match("^src/gz (%S+) ")
            if name ~= nil then
                lists:add(name)
            end
        end
    end
    return lists
end

function read_package_list(name)
    local packages = set.Set()
    local path = bmlua.path.join(package_list_directory, name)
    local handle = io.open(path, "r")
    if handle ~= nil then
        for line in handle:lines() do
            name = line:match("^Package: (%S+)")
            if name ~= nil then packages:add(name) end
        end
        handle:close()
    end
    return packages
end

