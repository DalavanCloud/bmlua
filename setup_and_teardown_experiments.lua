#!/usr/bin/env lua

require("io")
require("uci")

require('bmlua.set')
local set = bmlua.set
require('bmlua.opkg')
local opkg = bmlua.opkg

local UPDATER_CONFIG = "bismark-updater"
local EXPERIMENTS_CONFIG = "bismark-experiments"
local CONFIG_PATH = "/tmp/etc_config"

local get_managed_repositories = function(cursor)
    local repositories = set.Set()
    local updater_config = cursor:get_all(UPDATER_CONFIG)
    if updater_config ~= nil then
        for _, section in pairs(updater_config) do
            if section[".type"] == "repositories" and section.name ~= nil then
                repositories:update(set.from_array(section.name))
            end
        end
    end
    return repositories
end

local get_packages_in_repositories = function(repositories)
    local packages = set.Set()
    for repository in repositories:iter() do
        packages:update(opkg.read_package_list(repository))
    end
    return packages
end

local load_experiments = function(cursor, candidate_packages)
    local experiments_config = cursor:get_all(EXPERIMENTS_CONFIG)
    if experiments_config == nil then return nil end

    local installed_packages = set.Set()
    for _, section in pairs(experiments_config) do
        if section[".type"] == "experiment"
                and section.installed == '1'
                and section.package ~= nil then
            installed_packages:update(set.from_array(section.package))
        end
    end
    return installed_packages:intersection(candidate_packages)
end

function main(arg)
    cursor = uci.cursor(CONFIG_PATH)

    all_repositories = opkg.get_package_lists()
    managed_repositories = get_managed_repositories(cursor)
    unmanaged_repositories = all_repositories:difference(managed_repositories)

    unmanaged_packages = get_packages_in_repositories(unmanaged_repositories)
    managed_packages = get_packages_in_repositories(managed_repositories)
    if managed_packages:intersection(unmanaged_packages):length() > 0 then
        print("Managed and unmanaged repositories must be disjoint!")
        return 1
    end

    should_install = load_experiments(cursor, managed_packages)
    currently_installed = opkg.list_installed():intersection(managed_packages)
    for package_name in should_install:difference(currently_installed):iter() do
        opkg.install(package_name)
    end
    for package_name in currently_installed:difference(should_install):iter() do
        opkg.remove(package_name)
    end
end

return main(arg)
