-- ~/.config/nvim/lua/nvim-dap-projects.lua (or wherever you keep it)
local M = {}

-- Default configuration values
local defaults = {
	-- Paths to search for the project-local DAP configuration file, in order.
	config_paths = { "./.nvim/nvim-dap.lua", "./.nvim-dap/nvim-dap.lua", "./.nvim-dap.lua" },
	-- Behavior when a project configuration is found:
	-- false: Overwrite global DAP adapters and configurations with project-specific ones.
	-- true: Merge project-specific adapters and configurations into global ones.
	merge_configs = false,
	-- Logging level for this plugin's operations.
	-- Can be vim.log.levels.TRACE, DEBUG, INFO, WARN, ERROR or their string equivalents.
	log_level = vim.log.levels.INFO,
	-- Optional file path to write logs to.
	log_file = nil, -- Example: vim.fn.stdpath('state') .. '/nvim-dap-projects.log'
}

-- Holds the active configuration (defaults merged with user options)
local config = vim.deepcopy(defaults)

--- Logger utility for internal plugin messages.
-- @param level (number|string) vim.log.levels or string equivalent.
-- @param ... (varargs) Values to format into the log message.
local function log(level, ...)
	local msg_level = type(level) == "string" and vim.log.levels[string.upper(level)] or level
	if not msg_level then
		msg_level = vim.log.levels.INFO
	end -- Fallback

	local do_notify = msg_level >= config.log_level
	local do_log_to_file = config.log_file and msg_level >= config.log_level

	if not do_notify and not do_log_to_file then
		return -- No logging action needed for this level
	end

	local msg = string.format(...)

	if do_notify then
		vim.notify(("[nvim-dap-projects] [%s] %s"):format(vim.log.level_str(msg_level):upper(), msg), msg_level)
	end

	if do_log_to_file then
		local f = io.open(config.log_file, "a")
		if f then
			f:write(
				string.format("%s [%s] %s\n", os.date("%Y-%m-%d %H:%M:%S"), vim.log.level_str(msg_level):upper(), msg)
			)
			f:close()
		elseif do_notify then -- Avoid duplicate error if already notified about something else
		-- Only notify about file error if we were supposed to log this message to file
		-- and notifications for this level are enabled.
		else
			-- If notifications are off for this level, but file logging (which was on) failed.
			vim.notify(
				("[nvim-dap-projects] Error: Could not write to log file %s for message: %s"):format(
					config.log_file,
					msg
				),
				vim.log.levels.ERROR
			)
		end
	end
end

--- Configures the nvim-dap-projects module.
-- This should be called once, typically in your Neovim configuration.
-- @param user_opts (table, optional) User-defined options to override defaults.
function M.setup(user_opts)
	user_opts = user_opts or {}
	config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), user_opts)

	-- Validate and normalize log_level
	if type(config.log_level) == "string" then
		config.log_level = vim.log.levels[string.upper(config.log_level)] or defaults.log_level
	end
	if type(config.log_level) ~= "number" then -- Final fallback
		config.log_level = defaults.log_level
	end

	log(
		vim.log.levels.INFO,
		"Configuration updated. Merge mode: %s. Log level: %s. Log file: %s",
		tostring(config.merge_configs),
		vim.log.level_str(config.log_level):upper(),
		config.log_file or "none"
	)
end

--- Searches for and applies a project-local DAP configuration.
-- This function will modify `require('dap').adapters` and `require('dap').configurations`
-- based on the found project file and the configured merge/overwrite strategy.
function M.search_project_config()
	log(vim.log.levels.DEBUG, "Starting search for project DAP configuration.")

	local dap_ok, dap = pcall(require, "dap")
	if not dap_ok then
		log(vim.log.levels.ERROR, "nvim-dap could not be required. Ensure it is loaded.")
		return
	end

	local project_config_filepath = ""
	for _, path_pattern in ipairs(config.config_paths) do
		log(vim.log.levels.TRACE, "Checking path: %s", path_pattern)
		-- vim.loop.fs_stat is more robust than io.open for just checking existence/type
		local stat = vim.loop.fs_stat(path_pattern)
		if stat and stat.type == "file" then
			project_config_filepath = path_pattern
			log(vim.log.levels.DEBUG, "Found project config file at: %s", project_config_filepath)
			break
		end
	end

	if project_config_filepath == "" then
		log(vim.log.levels.INFO, "No project-specific DAP configuration file found in search paths.")
		return
	end

	log(vim.log.levels.INFO, "Loading project DAP configuration from: %s", project_config_filepath)

	-- dofile executes the Lua file and returns the value it returns.
	-- We expect the project config file to return a table.
	local loaded_ok, project_dap_settings = pcall(dofile, project_config_filepath)

	if not loaded_ok or type(project_dap_settings) ~= "table" then
		log(
			vim.log.levels.ERROR,
			"Failed to load or parse project DAP configuration from %s. Error: %s",
			project_config_filepath,
			tostring(project_dap_settings)
		)
		return
	end

	log(vim.log.levels.DEBUG, "Project DAP settings loaded successfully from file.")

	-- Apply adapters
	if project_dap_settings.adapters and type(project_dap_settings.adapters) == "table" then
		if config.merge_configs then
			log(vim.log.levels.DEBUG, "Merging project DAP adapters into global adapters.")
			dap.adapters = vim.tbl_deep_extend("force", dap.adapters or {}, project_dap_settings.adapters)
		else
			log(vim.log.levels.DEBUG, "Overwriting global DAP adapters with project adapters.")
			dap.adapters = project_dap_settings.adapters
		end
	elseif not config.merge_configs then
		log(vim.log.levels.DEBUG, "Overwrite mode: No adapters in project config; clearing global DAP adapters.")
		dap.adapters = {} -- Overwrite global with empty if not merging and project provides none
	end

	-- Apply configurations
	if project_dap_settings.configurations and type(project_dap_settings.configurations) == "table" then
		if config.merge_configs then
			log(vim.log.levels.DEBUG, "Merging project DAP configurations into global configurations.")
			for lang, project_lang_configs in pairs(project_dap_settings.configurations) do
				if type(project_lang_configs) == "table" then -- Should be a list of config objects
					if dap.configurations[lang] == nil or type(dap.configurations[lang]) ~= "table" then
						dap.configurations[lang] = {} -- Initialize if not exists or not a table
					end
					-- Append project configurations to the existing list for the language
					for _, p_conf in ipairs(project_lang_configs) do
						table.insert(dap.configurations[lang], p_conf)
					end
					log(vim.log.levels.TRACE, "Merged configurations for language '%s'.", lang)
				end
			end
		else
			log(vim.log.levels.DEBUG, "Overwriting global DAP configurations with project configurations.")
			dap.configurations = project_dap_settings.configurations
		end
	elseif not config.merge_configs then
		log(
			vim.log.levels.DEBUG,
			"Overwrite mode: No configurations in project config; clearing global DAP configurations."
		)
		dap.configurations = {} -- Overwrite global with empty if not merging and project provides none
	end

	log(
		vim.log.levels.INFO,
		"DAP settings updated from project configuration. Merge mode: %s",
		tostring(config.merge_configs)
	)
end

--- Provides a healthcheck for nvim-dap-projects.
-- Can be used with `:checkhealth nvim-dap-projects` if registered.
function M.healthcheck()
	vim.health.start("nvim-dap-projects")

	local dap_ok, _ = pcall(require, "dap")
	if not dap_ok then
		vim.health.error("nvim-dap is not installed or not found in runtime path (rtp).", {
			"Please install nvim-dap (mfussenegger/nvim-dap).",
			"Ensure it's loaded before nvim-dap-projects operations.",
		})
	else
		vim.health.ok("nvim-dap is accessible.")
	end

	vim.health.info("nvim-dap-projects Settings:")
	vim.health.info(("- Merge project configurations: %s"):format(tostring(config.merge_configs)))
	vim.health.info(("- Log level: %s"):format(vim.log.level_str(config.log_level):upper()))
	vim.health.info(("- Log file: %s"):format(config.log_file or "Not set"))
	vim.health.info(("- Config search paths: %s"):format(table.concat(config.config_paths, ", ")))

	-- Check current project context
	local found_path = nil
	local cwd = vim.fn.getcwd()
	vim.health.info(("Current working directory: %s"):format(cwd))
	for _, p in ipairs(config.config_paths) do
		local full_p = cwd .. "/" .. p -- Simplistic path join, assumes p starts with './'
		if string.sub(p, 1, 2) ~= "./" then
			full_p = p
		end -- If path is absolute or different

		local stat = vim.loop.fs_stat(full_p) -- Check relative to cwd
		if not stat and string.sub(p, 1, 2) == "./" then -- try without prepending cwd if it was already relative
			stat = vim.loop.fs_stat(string.sub(p, 3)) -- for paths like ./.nvim/file.lua
		end
		if not stat then -- also try path as is, if not starting with ./
			stat = vim.loop.fs_stat(p)
		end

		if stat and stat.type == "file" then
			found_path = p -- Use the pattern found
			break
		end
	end

	if found_path then
		vim.health.ok(
			("A potential project DAP config file was found matching pattern: '%s' (relative to CWD or as specified)."):format(
				found_path
			)
		)
		vim.health.info("  This does not guarantee the file is valid or parsable by this plugin.")
	else
		vim.health.warn("No project DAP config file found in the current CWD using configured search paths.")
	end

	if config.log_file then
		local f = io.open(config.log_file, "a")
		if f then
			f:close()
			vim.health.ok(("Log file '%s' appears to be writable."):format(config.log_file))
		else
			vim.health.error(("Log file '%s' is not writable."):format(config.log_file), {
				"Check file permissions and path.",
			})
		end
	end
end

-- Optional: Register healthcheck if you want to use :checkhealth
-- This part would typically go in your plugin's main init.lua or ftplugin if it were a full plugin.
-- For a single file module, you might need to call this registration from your main Neovim config.
-- vim.health.provider.register("nvim-dap-projects", { get = function() M.healthcheck() end })

return M
