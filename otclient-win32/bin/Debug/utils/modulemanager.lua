local require = require
local type, pairs, ipairs, setmetatable = type, pairs, ipairs, setmetatable
local str_find = string.find

local SEnv = require("utils.sandboxEnv")
local Module = require("utils.module")

local _M = {
    _modules = {},
    _modules_reloaded = nil
}

function _M.getModule(name)
    return _M._modules[name]
end

function _M.loadModule(name, modulePath)
    local moddef, modmt
    local mod

    if not name and not modulePath then
        return
    elseif not name then
        moddef = require(modulePath .. ".__moddef")
        name = moddef.name
    end

    local mod = _M.getModule(name)
    if not mod then
        modulePath = modulePath or 'modules.' .. name    
        moddef = require(modulePath .. ".__moddef")
        modmt = Module.newmeta(moddef, modulePath)

        -- dependencies module
        if type(modmt._mt_dependencies) == "table" then
            for i, v in ipairs(modmt._mt_dependencies) do
                _M.loadModule(v[1], v[2])
            end
        end

        -- this module
        local modenv
        if modmt._mt_sandboxed then
            mod = SEnv.new()
            SEnv.setGlobalEnvironment(mod)
            require(modmt._mt_classPath)

            -- inject module meta
            for k, v in pairs(modmt) do
                mod[k] = v
            end

            print("Loaded module(sandboxed) '" .. name .. "'")
            _M._modules[name] = mod

 
            --
            mod:_mt_load()
            SEnv.resetGlobalEnvironment()
        else
            mod = require(moddef.classPath)
            if type(mod) == "boolean" then
                mod = {}
            end

            -- inject module meta
            for k, v in pairs(modmt) do
                mod[k] = v
            end

            print("Loaded module '" .. name .. "'")
            _M._modules[name] = mod

            --
            mod:_mt_load()
        end

        -- load later module
        if type(modmt._mt_loadLater) == "table" then
            for i, v in ipairs(modmt._mt_loadLater) do
                _M.loadModule(v[1], v[2])
            end
        end

    end
    return mod
end

function _M.reloadModule(mod)
    _M._modules_reloaded = _M._modules_reloaded or {}

    local modname = mod.m_name
    if not _M._modules_reloaded[modname] then
        -- ensure module name is not "modulemanager“
        local b, e = str_find(modname, "modulemanager")
        if not b then
            mod:unload()

            -- load again
            _M.loadModule(modname, mod.m_modulePath)
        end
    end

    _M._modules_reloaded[modname] = true
end

function _M.reloadModules()
    -- backup modules
    local old_modules = {}
    for k, v in pairs(_M._modules) do
        old_modules[k] = v
    end

    -- reload
    _M._modules_reloaded = {}
    for name, v in pairs(old_modules) do
        _M.reloadModule(v)
    end
    _M._modules_reloaded = nil
end

return _M
