-- lua/nvim-dap-projects/health.lua
local Health = {}

function Health.check()
    vim.health.start("nvim-dap-projects") --

    local config_module_ok, config_module = pcall(require, "nvim-dap-projects.config")
    if not config_module_ok or not config_module or not config_module.get then
        vim.health.error("nvim-dap-projects.config module or get() function not found.")
        return
    end
    local current_config = config_module.get()

    local dap_ok, _ = pcall(require, "dap") --
    if not dap_ok then
        vim.health.error("nvim-dap is not installed or not found in runtime path (rtp).", { --
            "Please install nvim-dap (mfussenegger/nvim-dap).", --
            "Ensure it's loaded before nvim-dap-projects operations.", --
        })
    else
        vim.health.ok("nvim-dap is accessible.") --
    end

    vim.health.info("nvim-dap-projects Settings:") --
    vim.health.info(("- Merge project configurations: %s"):format(tostring(current_config.merge_configs))) --
    if current_config.log_level and vim.log and vim.log.level_str then
         vim.health.info(("- Log level: %s"):format(vim.log.level_str(current_config.log_level):upper())) --
    else
         vim.health.info(("- Log level: (Could not determine string representation or log_level not set)"))
    end
    vim.health.info(("- Log file: %s"):format(current_config.log_file or "Not set")) --
    vim.health.info(("- Config search paths: %s"):format(table.concat(current_config.config_paths, ", "))) --

    local cwd = vim.fn.getcwd() --
    vim.health.info(("Current working directory: %s"):format(cwd)) --
    local found_path = nil
    -- This path checking logic is simplified from the original.
    -- The original M.healthcheck had more robust path checking for CWD relative paths.
    -- That logic should be fully reinstated here.
    for _, p in ipairs(current_config.config_paths) do --
        local full_p = p -- Placeholder for actual path resolution logic from original M.healthcheck
         if string.sub(p, 1, 2) == "./" then full_p = cwd .. "/" .. string.sub(p,3) end
        local stat = vim.loop.fs_stat(full_p)
        if stat and stat.type == "file" then
            found_path = p
            break
        end
    end

    if found_path then
        vim.health.ok( --
            ("A potential project DAP config file was found matching pattern: '%s' (relative to CWD or as specified)."):format(
                found_path
            )
        )
        vim.health.info("  This does not guarantee the file is valid or parsable by this plugin.") --
    else
        vim.health.warn("No project DAP config file found in the current CWD using configured search paths.") --
    end

    if current_config.log_file then --
        local f = io.open(current_config.log_file, "a") --
        if f then
            f:close() --
            vim.health.ok(("Log file '%s' appears to be writable."):format(current_config.log_file)) --
        else
            vim.health.error(("Log file '%s' is not writable."):format(current_config.log_file), { --
                "Check file permissions and path.", --
            })
        end
    end
end

return Health -- Neovim will look for the check() function in this returned table
