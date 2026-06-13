local INTERNAL = "eDP-1"

local function lid_closed()
	local f = io.open("/proc/acpi/button/lid/LID0/state", "r")
	if not f then
		return false
	end
	local state = f:read("*a")
	f:close()
	return state:find("closed") ~= nil
end

local function has_external()
	for _, m in ipairs(hl.get_monitors()) do
		if m.name ~= INTERNAL then
			return true
		end
	end
	return false
end

local function internal_active()
	return hl.get_monitor(INTERNAL) ~= nil
end

local function disable_internal()
	hl.monitor({ output = INTERNAL, disabled = true })
end

local function enable_internal()
	hl.monitor({ output = INTERNAL, disabled = false, mode = "preferred", position = "auto", scale = 2.0 })
end

-- After the monitor set changes, outputs are repositioned/rescaled, so reload
-- the shell. A single resume fires several monitor events (removed at suspend,
-- added at resume) and the lid handlers can pile on too, so debounce: each call
-- bumps a generation token and, after a short settle delay, only the latest
-- call actually reloads. One reload per burst instead of two or three.
local reload_gen = 0
local function reload_shell()
	reload_gen = reload_gen + 1
	local gen = reload_gen
	hl.exec_cmd(string.format(
		"bash -c 'echo %d > /tmp/fenriz-reload-gen; sleep 1; "
		.. "[ \"$(cat /tmp/fenriz-reload-gen 2>/dev/null)\" = \"%d\" ] "
		.. "&& qs ipc call shell reload'",
		gen, gen))
end

local function sync()
	if lid_closed() and has_external() then
		if internal_active() then
			disable_internal()
		end
	else
		if not internal_active() then
			enable_internal()
		end
	end
end

-- Lid close
hl.bind("switch:on:Lid Switch", function()
	if has_external() then
		disable_internal()
		reload_shell()
	else
		hl.exec_cmd("systemctl suspend")
	end
end, { locked = true })

-- Lid open
hl.bind("switch:off:Lid Switch", function()
	if not internal_active() then
		enable_internal()
		reload_shell()
	end
end, { locked = true })

-- Monitor hotplug: closed-lid docking
hl.on("monitor.added", function(m)
	if lid_closed() then
		disable_internal()
	end
	reload_shell()
end)

-- Undocking with lid closed: re-enable internal
hl.on("monitor.removed", function(m)
	if lid_closed() and not has_external() then
		enable_internal()
	end
	reload_shell()
end)

-- Sync on startup and every config reload
hl.on("hyprland.start", sync)
hl.on("config.reloaded", sync)
