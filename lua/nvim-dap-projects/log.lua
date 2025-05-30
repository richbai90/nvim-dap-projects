-- lua/nvim-dap-projects/log.lua
local M = {}

-- Forward declaration for config to avoid cyclic dependency if config also logs early
local get_config

--- Logger utility for internal plugin messages.
-- @param level (number|string) vim.log.levels or string equivalent.
-- @param ... (varargs) Values to format into the log message.
function M.log(level, ...)
    -- Lazily require config or ensure it's set up
    if not get_config then
        get_config = require("nvim-dap-projects.config").get
    end
    local current_config = get_config()

    local msg_level = type(level) == "string" and vim.log.levels[string.upper(level)] or level --
    if not msg_level then
        msg_level = vim.log.levels.INFO -- Fallback --
    end

    local do_notify = msg_level >= current_config.log_level --
    local do_log_to_file = current_config.log_file and msg_level >= current_config.log_level --

    if not do_notify and not do_log_to_file then
        return -- No logging action needed for this level --
    end

    local msg = string.format(...) --

    if do_notify then
        vim.notify(("[nvim-dap-projects] [%s] %s"):format(vim.log.level_str(msg_level):upper(), msg), msg_level) --
    end

    if do_log_to_file then --
        local f = io.open(current_config.log_file, "a") --
        if f then
            f:write(
                string.format("%s [%s] %s\n", os.date("%Y-%m-%d %H:%M:%S"), vim.log.level_str(msg_level):upper(), msg) --
            )
            f:close() --
        elseif do_notify then
            -- Avoid duplicate error notification logic from original file for brevity here,
            -- but it can be reinstated if desired.
        else
             vim.notify( --
                 ("[nvim-dap-projects] Error: Could not write to log file %s for message: %s"):format(
                     current_config.log_file,
                     msg
                 ),
                 vim.log.levels.ERROR
             )
        end
    end
end

return M
