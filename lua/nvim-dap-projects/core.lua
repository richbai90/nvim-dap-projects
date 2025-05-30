local config_module = require("nvim-dap-projects.config")
local logger = config_module.logger() -- Assumes this returns the new logger instance
local M = {}

--- Searches for and applies a project-local DAP configuration.
function M.search_project_config()
    local current_config = config_module.get()
    -- This first log message was already in the new style in your provided snippet
    logger:debug("Beginning search for project DAP configuration.") -- Corrected spelling

    local dap_ok, dap = pcall(require, "dap")
    if not dap_ok then
        logger:error("nvim-dap could not be required. Ensure it is loaded.") -- Changed
        return
    end

    local project_config_filepath = ""
    for _, path_pattern in ipairs(current_config.config_paths) do
        logger:trace("Checking path:", path_pattern) -- Changed
        local stat = vim.loop.fs_stat(path_pattern)
        if stat and stat.type == "file" then
            project_config_filepath = path_pattern
            logger:debug("Found project config file at:", project_config_filepath) -- Changed
            break
        end
    end

    if project_config_filepath == "" then
        logger:info("No project-specific DAP configuration file found in search paths.") -- Changed
        return
    end

    logger:info("Loading project DAP configuration from:", project_config_filepath) -- Changed

    local loaded_ok, project_dap_settings = pcall(dofile, project_config_filepath)

    if not loaded_ok or type(project_dap_settings) ~= "table" then
        logger:error( -- Changed
            "Failed to load or parse project DAP configuration from:",
            project_config_filepath,
            "Error:",
            project_dap_settings -- The logger will use vim.inspect() on this
        )
        return
    end

    logger:debug("Project DAP settings loaded successfully from file.") -- Changed

    -- Apply adapters
    if project_dap_settings.adapters and type(project_dap_settings.adapters) == "table" then
        if current_config.merge_configs then
            logger:debug("Merging project DAP adapters into global adapters.") -- Changed
            dap.adapters = vim.tbl_deep_extend("force", dap.adapters or {}, project_dap_settings.adapters)
        else
            logger:debug("Overwriting global DAP adapters with project adapters.") -- Changed
            dap.adapters = project_dap_settings.adapters
        end
    elseif not current_config.merge_configs then
        logger:debug("Overwrite mode: No adapters in project config; clearing global DAP adapters.") -- Changed
        dap.adapters = {}
    end

    -- Apply configurations
    if project_dap_settings.configurations and type(project_dap_settings.configurations) == "table" then
        if current_config.merge_configs then
            logger:debug("Merging project DAP configurations into global configurations.") -- Changed
            for lang, project_lang_configs in pairs(project_dap_settings.configurations) do
                if type(project_lang_configs) == "table" then
                    if dap.configurations[lang] == nil or type(dap.configurations[lang]) ~= "table" then
                        dap.configurations[lang] = {}
                    end
                    for _, p_conf in ipairs(project_lang_configs) do
                        table.insert(dap.configurations[lang], p_conf)
                    end
                    logger:trace("Merged configurations for language:", lang) -- Changed
                end
            end
        else
            logger:debug("Overwriting global DAP configurations with project configurations.") -- Changed
            dap.configurations = project_dap_settings.configurations
        end
    elseif not current_config.merge_configs then
        logger:debug("Overwrite mode: No configurations in project config; clearing global DAP configurations.") -- Changed
        dap.configurations = {}
    end

    logger:info( -- Changed
        "DAP settings updated from project configuration. Merge mode:",
        current_config.merge_configs -- The logger will use vim.inspect() on this
    )
end

return M
