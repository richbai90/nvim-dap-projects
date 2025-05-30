-- lua/nvim-dap-projects/core.lua
local config_module = require("nvim-dap-projects.config")
local logger = require("nvim-dap-projects.log")

local M = {}

--- Searches for and applies a project-local DAP configuration.
function M.search_project_config() --
    local current_config = config_module.get()
    logger.log(vim.log.levels.DEBUG, "Starting search for project DAP configuration.") --

    local dap_ok, dap = pcall(require, "dap") --
    if not dap_ok then
        logger.log(vim.log.levels.ERROR, "nvim-dap could not be required. Ensure it is loaded.") --
        return
    end

    local project_config_filepath = ""
    for _, path_pattern in ipairs(current_config.config_paths) do --
        logger.log(vim.log.levels.TRACE, "Checking path: %s", path_pattern) --
        local stat = vim.loop.fs_stat(path_pattern) --
        if stat and stat.type == "file" then --
            project_config_filepath = path_pattern --
            logger.log(vim.log.levels.DEBUG, "Found project config file at: %s", project_config_filepath) --
            break
        end
    end

    if project_config_filepath == "" then
        logger.log(vim.log.levels.INFO, "No project-specific DAP configuration file found in search paths.") --
        return
    end

    logger.log(vim.log.levels.INFO, "Loading project DAP configuration from: %s", project_config_filepath) --

    local loaded_ok, project_dap_settings = pcall(dofile, project_config_filepath) --

    if not loaded_ok or type(project_dap_settings) ~= "table" then --
        logger.log(
            vim.log.levels.ERROR,
            "Failed to load or parse project DAP configuration from %s. Error: %s",
            project_config_filepath,
            tostring(project_dap_settings)
        ) --
        return
    end

    logger.log(vim.log.levels.DEBUG, "Project DAP settings loaded successfully from file.") --

    -- Apply adapters
    if project_dap_settings.adapters and type(project_dap_settings.adapters) == "table" then --
        if current_config.merge_configs then --
            logger.log(vim.log.levels.DEBUG, "Merging project DAP adapters into global adapters.") --
            dap.adapters = vim.tbl_deep_extend("force", dap.adapters or {}, project_dap_settings.adapters) --
        else
            logger.log(vim.log.levels.DEBUG, "Overwriting global DAP adapters with project adapters.") --
            dap.adapters = project_dap_settings.adapters --
        end
    elseif not current_config.merge_configs then --
        logger.log(vim.log.levels.DEBUG, "Overwrite mode: No adapters in project config; clearing global DAP adapters.") --
        dap.adapters = {} --
    end

    -- Apply configurations
    if project_dap_settings.configurations and type(project_dap_settings.configurations) == "table" then --
        if current_config.merge_configs then --
            logger.log(vim.log.levels.DEBUG, "Merging project DAP configurations into global configurations.") --
            for lang, project_lang_configs in pairs(project_dap_settings.configurations) do --
                if type(project_lang_configs) == "table" then --
                    if dap.configurations[lang] == nil or type(dap.configurations[lang]) ~= "table" then --
                        dap.configurations[lang] = {} --
                    end
                    for _, p_conf in ipairs(project_lang_configs) do --
                        table.insert(dap.configurations[lang], p_conf) --
                    end
                    logger.log(vim.log.levels.TRACE, "Merged configurations for language '%s'.", lang) --
                end
            end
        else
            logger.log(vim.log.levels.DEBUG, "Overwriting global DAP configurations with project configurations.") --
            dap.configurations = project_dap_settings.configurations --
        end
    elseif not current_config.merge_configs then --
        logger.log(
            vim.log.levels.DEBUG,
            "Overwrite mode: No configurations in project config; clearing global DAP configurations."
        ) --
        dap.configurations = {} --
    end

    logger.log(
        vim.log.levels.INFO,
        "DAP settings updated from project configuration. Merge mode: %s",
        tostring(current_config.merge_configs)
    ) --
end

return M
