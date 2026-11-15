-- Core: the shared table, saved settings, event routing, the hooks into
-- RestedXP's guide window, and the slash command.
local addonName, ns = ...

ns.TITLE = "RestedXP Forever Skin"
ns.SLASH = "/rfs"

-- RestedXP's guide window (its legacy, "v1" window). RestedXP keeps its
-- addon table private; this frame and the functions stored on it are what
-- other addons can reach. A hard dependency in the .toc, so it is here.
ns.RXPFrame = RXPFrame

ns.L = {
	WELCOME_TITLE = "RestedXP Guides",
	ACTIVE_TITLE = "Current Steps",
	TIP_TITLE = "Tip",
	JUMP_TO_CURRENT = "Go to the current step",
	ENABLED = "Blizzard style",
	ENABLED_TOOLTIP = "Draw the RestedXP guide window with Blizzard's window frame, fonts and colors.",
	ENABLED_ON = "Blizzard style on.",
	ENABLED_OFF = "Blizzard style off.",
	RELOAD = "RestedXP's own look comes back after reloading the interface.",
	NO_RXP = "RestedXP's guide window was not found; nothing to restyle.",
}

local DEFAULTS = {
	enabled = true,
}

-- ---------------------------------------------------------------- events
-- Files subscribe with ns:On(event, fn); one frame dispatches them all.
local handlers = {}
local eventFrame = CreateFrame("Frame")

function ns:On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		eventFrame:RegisterEvent(event)
	end
	table.insert(handlers[event], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	for _, fn in ipairs(handlers[event]) do
		fn(...)
	end
end)

function ns:Print(msg)
	print(NORMAL_FONT_COLOR:WrapTextInColorCode(ns.TITLE .. ":") .. " " .. msg)
end

-- Every restyle keys off this. RestedXP only sets its own art when a guide
-- or theme loads, so turning the skin off asks for a reload instead of
-- undoing each change (see the popup below).
function ns:IsActive()
	return ns.db ~= nil and ns.db.enabled
end

-- ---------------------------------------------------------------- hooks
local hooked = false

-- Restyle everything that exists now; the hooks keep it styled afterwards.
function ns:StyleAll()
	if not ns:IsActive() then return end
	ns:StyleWindow()
	ns:StyleScrollBar()
	ns:StyleRows()
	ns:StyleActiveSteps()
	ns:StyleTargets()
	ns:StyleArrow()
	-- RestedXP usually placed the active steps before our hooks existed; let
	-- it place them again, so the SetPoint hook adds the gap. It measures the
	-- frame against the screen, so only once the frame is laid out.
	local frame = ns.RXPFrame
	if frame.SetStepFrameAnchor and frame.CurrentStepFrame:GetTop() then
		frame.SetStepFrameAnchor()
	end
end

local function InstallHooks()
	if hooked then return end
	hooked = true
	local frame = ns.RXPFrame
	-- RestedXP calls all of these through the frame tables (RXPFrame.X(),
	-- BottomFrame.UpdateFrame()), so hooking the table fields reaches them.
	hooksecurefunc(frame, "UpdateVisuals", function() ns:StyleWindow() end)
	hooksecurefunc(frame, "UpdateScrollBar", function() ns:StyleScrollBar() end)
	hooksecurefunc(frame.BottomFrame, "UpdateFrame", function(...) ns:StyleRows(...) end)
	hooksecurefunc(frame.CurrentStepFrame, "UpdateText", function() ns:StyleActiveSteps() end)
	ns:HookWindow()
	ns:HookActiveSteps()
	ns:HookTargets()
	ns:HookArrow()
	ns:StyleAll()
end

-- Saved variables exist only from ADDON_LOADED on. Fill missing defaults.
ns:On("ADDON_LOADED", function(name)
	if name ~= addonName then return end
	RXPForeverSkinDB = RXPForeverSkinDB or {}
	for k, v in pairs(DEFAULTS) do
		if RXPForeverSkinDB[k] == nil then
			RXPForeverSkinDB[k] = v
		end
	end
	ns.db = RXPForeverSkinDB

	local frame = ns.RXPFrame
	if not (frame and frame.BottomFrame and frame.CurrentStepFrame and frame.UpdateVisuals) then
		ns:Print(ns.L.NO_RXP)
		return
	end
	InstallHooks()
end)

-- RestedXP builds its window on its own initialization, which may come after
-- our ADDON_LOADED; style again once everything is in place.
ns:On("PLAYER_LOGIN", function()
	if hooked then ns:StyleAll() end
end)

-- ---------------------------------------------------------------- on / off
StaticPopupDialogs.RXPFOREVERSKIN_RELOAD = {
	text = ns.L.RELOAD,
	button1 = RELOADUI,
	button2 = CANCEL,
	OnAccept = function() ReloadUI() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

-- Called after ns.db.enabled changed (slash command or settings checkbox).
function ns:Refresh()
	if ns.db.enabled then
		ns:StyleAll()
	else
		StaticPopup_Show("RXPFOREVERSKIN_RELOAD")
	end
end

-- ---------------------------------------------------------------- slash
local function Debug()
	local frame = ns.RXPFrame
	ns:Print("debug")
	print("  enabled:", ns:IsActive(), " hooks:", hooked)
	-- Lua memory climbs between garbage collections; compare a few runs.
	UpdateAddOnMemoryUsage()
	print(("  memory: this addon %.0f KB, RestedXP %.0f KB"):format(GetAddOnMemoryUsage(addonName),
		GetAddOnMemoryUsage("RXPGuides")))
	if not frame then return end
	print(("  window: %dx%d scale %.2f shown %s, legacy list shown: %s"):format(frame:GetWidth(), frame:GetHeight(),
		frame:GetEffectiveScale(), tostring(frame:IsShown()), tostring(frame.BottomFrame:IsShown())))
	local chrome = frame.BottomFrame.RFSChrome
	print("  chrome shown:", chrome and chrome:IsShown() or false, " title:", chrome and chrome.TitleContainer.TitleText:GetText())
	local steps = frame.CurrentStepFrame
	print(("  active steps: %d frames, height %.1f, anchor %s"):format(#steps.framePool, steps:GetHeight(),
		tostring(steps.anchor)))
	print("  list rows:", #frame.ScrollChild.framePool)
	local targets = _G.RXPTargetFrame
	if targets then
		local _, relativeTo = targets:GetPoint(1)
		print(("  targets: %dx%d scale %.2f, shown %s, docked %s"):format(targets:GetWidth(), targets:GetHeight(),
			targets:GetEffectiveScale(), tostring(targets:IsShown()), tostring(relativeTo == frame.CurrentStepFrame)))
	end
	for _, row in ipairs(frame.ScrollChild.framePool) do
		local divider = row.RFSDivider
		if divider and row:IsVisible() then
			local info = C_Texture.GetAtlasInfo(ns.ART.DIVIDER)
			print(("  first divider: visible %s, %dx%d, alpha %.2f, row alpha %.2f, atlas %s"):format(
				tostring(divider:IsVisible()), divider:GetWidth(), divider:GetHeight(), divider:GetAlpha(),
				row:GetEffectiveAlpha(), info and (info.width .. "x" .. info.height) or "missing"))
			break
		end
	end
end

-- Memory after a full garbage collection is what an addon really keeps;
-- the number in memory panels also counts garbage not yet collected.
local function Memory()
	UpdateAddOnMemoryUsage()
	local rxp, own = GetAddOnMemoryUsage("RXPGuides"), GetAddOnMemoryUsage(addonName)
	collectgarbage("collect")
	UpdateAddOnMemoryUsage()
	ns:Print(("memory before / after collection: RestedXP %.1f / %.1f MB, this addon %.0f / %.0f KB"):format(
		rxp / 1024, GetAddOnMemoryUsage("RXPGuides") / 1024, own, GetAddOnMemoryUsage(addonName)))
end

SLASH_RXPFOREVERSKIN1 = ns.SLASH
SlashCmdList.RXPFOREVERSKIN = function(msg)
	msg = strtrim(msg or ""):lower()
	if msg == "debug" then
		Debug()
	elseif msg == "mem" then
		Memory()
	elseif msg == "options" then
		ns:OpenSettings()
	else
		ns.db.enabled = not ns.db.enabled
		ns:Print(ns.db.enabled and ns.L.ENABLED_ON or ns.L.ENABLED_OFF)
		ns:Refresh()
	end
end
