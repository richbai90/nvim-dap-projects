-- lua/nvim-dap-projects/config.lua
local logger_module = require("nvim-dap-projects.log") -- We'll define this next
local logger

local M = {}

local defaults = {
    config_paths = { "./.nvim/nvim-dap.lua", "./.nvim-dap/nvim-dap.lua", "./.nvim-dap.lua" }, --
    merge_configs = false, --
    log_level = 'INFO',
    log_file = nil, --
}

local active_config = vim.deepcopy(defaults)

--- Sets up and updates the plugin's configuration.
-- @param user_opts (table, optional) User-defined options to override defaults.
function M.setup(user_opts)
    user_opts = user_opts or {}
    active_config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), user_opts) --
    logger = logger_module.create_logger(active_config.log_file)
    logger:set_level(active_config.log_level)
    
    -- Validate and normalize log_level
    if type(active_config.log_level) == "string" then --
        active_config.log_level = vim.log.levels[string.upper(active_config.log_level)] or defaults.log_level --
    end
    if type(active_config.log_level) ~= "number" then -- Final fallback --
        active_config.log_level = defaults.log_level --
    end

    -- Log the updated configuration using the logger module
    logger:info("setup complete:", user_opts)
end

--- Returns the current active configuration.
-- @return (table) The active configuration table.
function M.get()
    return active_config
end

function M.logger()
  return logger
end

return M
