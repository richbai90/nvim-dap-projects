-- lua/nvim-dap-projects/init.lua
local config_module = require("nvim-dap-projects.config")
local core_module = require("nvim-dap-projects.core")
-- log_module is used internally by config_module and core_module
-- health_module is discovered by Neovim, not directly called via the public API

local M = {}

--- Configures the nvim-dap-projects module.
-- This should be called once, typically in your Neovim configuration.
-- @param user_opts (table, optional) User-defined options to override defaults.
function M.setup(user_opts)
    -- Defer setup if necessary, as discovered in previous troubleshooting
    vim.schedule(function()
        config_module.setup(user_opts)
        -- Any other general plugin initialization that depends on config can go here.
    end)
end

--- Searches for and applies a project-local DAP configuration.
function M.search_project_config()
    -- Defer this call as well if it depends on setup or needs to run slightly later
    vim.schedule(function()
        core_module.search_project_config()
    end)
end

return M
