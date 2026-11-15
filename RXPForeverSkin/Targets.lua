-- Targets: RestedXP's "Active Targets" frame (the NPCs and mobs of the
-- current step), docked as a row at the bottom of the Current Steps frame,
-- under a divider and a gold heading, its buttons in action button art.
--
-- The buttons are secure action buttons, so the frame is protected in
-- combat. Out of combat it is anchored to the steps and follows them; when
-- combat starts it is pinned where it is, so the steps (which RestedXP moves
-- whenever a step changes) never have a protected frame anchored to them.
local _, ns = ...

-- Space between the last step and the targets row (the divider sits in
-- the middle), in the steps frame's units.
local TARGET_GAP = 8
-- The heading starts where the step titles do.
local HEADING_X = 7
local HEADING_PADDING = 8

-- RestedXP's layout of its frame, in its own units: buttons 25px, 6px in
-- from the left; the first enemy row starts 12px below the top, friendly
-- rows end 6px above the bottom.
local BUTTON_SIZE, BUTTON_INSET, ENEMY_TOP, FRIENDLY_BOTTOM = 25, 6, 12, 6
-- RestedXP's grid: 4 buttons a row, 27px apart. Friendly rows grow upward.
local BUTTONS_PER_ROW, BUTTON_SPACING = 4, 2

-- ActionButtonTemplate's frame art is 46x45 around a 45x45 icon.
local BORDER_WIDTH_RATIO = 46 / 45

-- How far the docked targets reach below the steps (0: none showing), in
-- the steps frame's units. Measured out of combat; the steps' frame is sized
-- from it, never from where the buttons are, so a stray move of RestedXP's
-- frame can't stretch it.
local extent = 0
local layoutQueued = false
-- Set while we place the frame, to tell our moves from anyone else's.
local placing = false
-- Reused for every layout, so updates don't leave tables behind.
local enemies, friendlies = {}, {}

local function TargetFrame()
	return _G.RXPTargetFrame
end

-- ---------------------------------------------------------------- buttons
-- RestedXP's own highlight, created inline with no key: find it by layer.
local function FindHighlight(button)
	for _, region in ipairs({button:GetRegions()}) do
		if region:GetObjectType() == "Texture" and region:GetDrawLayer() == "HIGHLIGHT" then
			return region
		end
	end
end

-- Same art as the Zygor skin's action bar: slot background, round-cornered
-- mask on the icon, the frame on top and Blizzard's mouseover.
local function StyleButton(button)
	if button.RFSBorder then return end
	local w, h = button:GetSize()

	button.RFSSlot = button:CreateTexture(nil, "BACKGROUND", nil, -1)
	button.RFSSlot:SetAtlas("UI-HUD-ActionBar-IconFrame-Background")
	button.RFSSlot:SetAllPoints()

	button.RFSMask = button:CreateMaskTexture()
	button.RFSMask:SetAtlas("UI-HUD-ActionBar-IconFrame-Mask", false, nil, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	button.RFSMask:SetAllPoints()
	button.icon:AddMaskTexture(button.RFSMask)

	button.RFSBorder = button:CreateTexture(nil, "OVERLAY")
	button.RFSBorder:SetAtlas("UI-HUD-ActionBar-IconFrame")
	button.RFSBorder:SetPoint("TOPLEFT")
	button.RFSBorder:SetSize(w * BORDER_WIDTH_RATIO, h)

	local highlight = FindHighlight(button)
	if highlight then
		highlight:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
		highlight:SetBlendMode("BLEND")
		highlight:ClearAllPoints()
		highlight:SetPoint("TOPLEFT")
		highlight:SetSize(w * BORDER_WIDTH_RATIO, h)
	end
end

-- ---------------------------------------------------------------- docking
-- How far below the steps the targets row reaches (0 when none show).
function ns:GetTargetsExtent()
	return ns:IsActive() and extent or 0
end

-- Extra room the steps need above the window for the targets row.
function ns:TargetsRoomAbove()
	local steps = ns.RXPFrame.CurrentStepFrame
	return steps.anchor == "TOP" and ns:GetTargetsExtent() or 0
end

-- The heading and divider live on the steps' frame (Steps.lua's chrome).
local function GetDockArt(chrome)
	if not chrome.RFSTargetsHeading then
		chrome.RFSTargetsHeading = chrome:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		chrome.RFSTargetsDivider = chrome:CreateTexture(nil, "ARTWORK")
		chrome.RFSTargetsDivider:SetAtlas(ns.ART.DIVIDER)
		chrome.RFSTargetsDivider:SetHeight(3)
	end
	return chrome.RFSTargetsHeading, chrome.RFSTargetsDivider
end

local function Shown(buttons, into)
	wipe(into)
	for _, button in ipairs(buttons) do
		if button:IsShown() then into[#into + 1] = button end
	end
	return into
end

-- RestedXP puts friendly targets on their own row under the enemies.
-- Continue the enemies' last row with them instead, when they fit in one
-- row (more would grow upward, into the enemies). Returns the lowest button.
local function JoinRows(frame)
	Shown(frame.enemyTargetButtons, enemies)
	Shown(frame.friendlyTargetButtons, friendlies)
	if #enemies == 0 then return friendlies[1] end
	if #friendlies > 0 and #friendlies <= BUTTONS_PER_ROW then
		local first = friendlies[1]
		first:ClearAllPoints()
		first:SetPoint("LEFT", enemies[#enemies], "RIGHT", BUTTON_SPACING, 0)
		return enemies[#enemies]
	end
	return friendlies[1] or enemies[#enemies]
end

-- Where the first row of buttons is centered, from the frame's top.
local function FirstRowCenter(frame)
	local enemy = frame.enemyTargetButtons[1]
	if enemy and enemy:IsShown() then
		return ENEMY_TOP + BUTTON_SIZE / 2
	end
	return frame:GetHeight() - FRIENDLY_BOTTOM - BUTTON_SIZE / 2
end

-- Runs out of combat only; PLAYER_REGEN_ENABLED catches up afterwards.
function ns:LayoutTargets()
	local frame = TargetFrame()
	if not (frame and ns:IsActive()) or InCombatLockdown() then return end
	local steps = ns.RXPFrame.CurrentStepFrame
	local chrome = ns:GetChrome(steps, ns.L.ACTIVE_TITLE)
	local heading, divider = GetDockArt(chrome)

	-- RestedXP's box and title go; the heading replaces the title, and the
	-- frame no longer drags on its own: it moves with the steps.
	ns:ClearBackdrop(frame)
	ns:ClearBackdrop(frame.title)
	frame.title.text:SetAlpha(0)
	frame.title:EnableMouse(false)
	frame:EnableMouse(false)
	for _, button in ipairs(frame.enemyTargetButtons) do StyleButton(button) end
	for _, button in ipairs(frame.friendlyTargetButtons) do StyleButton(button) end

	-- RestedXP scales the targets on their own; convert to the steps' units.
	local ratio = frame:GetEffectiveScale() / steps:GetEffectiveScale()
	local newExtent = 0

	if frame:IsShown() then
		local buttonsLeft = HEADING_X + heading:GetUnboundedStringWidth() + HEADING_PADDING
		placing = true
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", steps, "BOTTOMLEFT", buttonsLeft / ratio - BUTTON_INSET, -TARGET_GAP / ratio)
		placing = false
		local lowest = JoinRows(frame)
		local top, bottom = frame:GetTop(), lowest and lowest:GetBottom()
		if top and bottom then
			newExtent = TARGET_GAP + (top - bottom) * ratio
		end
	end

	-- Only with a button showing: RestedXP may leave the frame up while it
	-- has no targets.
	local shown = newExtent > 0
	heading:SetShown(shown)
	divider:SetShown(shown)
	if shown then
		heading:SetText(frame.title.text:GetText())
		heading:ClearAllPoints()
		heading:SetPoint("LEFT", steps, "BOTTOMLEFT", HEADING_X, -(TARGET_GAP + FirstRowCenter(frame) * ratio))
		divider:ClearAllPoints()
		divider:SetPoint("TOPLEFT", steps, "BOTTOMLEFT", 0, -TARGET_GAP / 2 + 1)
		divider:SetPoint("TOPRIGHT", steps, "BOTTOMRIGHT", 0, -TARGET_GAP / 2 + 1)
	end

	-- Above the window the steps grow upward from it: when the row's height
	-- changes, have RestedXP place them again (the SetPoint hook in Steps.lua
	-- adds the room).
	if math.abs(newExtent - extent) > 0.5 then
		extent = newExtent
		if ns.RXPFrame.SetStepFrameAnchor and steps:GetTop() then
			ns.RXPFrame.SetStepFrameAnchor()
		end
	end
	ns:AnchorStepsChrome()
end

-- RestedXP places its buttons right after resizing the frame, so a layout
-- from its SetHeight would be undone; run it on the next frame instead.
local function RunQueuedLayout()
	layoutQueued = false
	ns:LayoutTargets()
end

local function QueueLayout()
	if layoutQueued then return end
	layoutQueued = true
	C_Timer.After(0, RunQueuedLayout)
end

-- Unpin from the steps before combat locks the frame down (protected
-- frames can still be moved while this event runs).
ns:On("PLAYER_REGEN_DISABLED", function()
	local frame = TargetFrame()
	if not (frame and ns:IsActive()) then return end
	local left, top = frame:GetLeft(), frame:GetTop()
	if left and top then
		placing = true
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
		placing = false
	end
end)

ns:On("PLAYER_REGEN_ENABLED", function()
	ns:LayoutTargets()
end)

function ns:StyleTargets()
	ns:LayoutTargets()
end

function ns:HookTargets()
	local frame = TargetFrame()
	if not frame then return end
	-- RestedXP re-applies its backdrop and title box here (theme changes),
	-- and resizes the frame after every update of the buttons, which is when
	-- new buttons appear. It shows and hides the frame as targets come and go.
	hooksecurefunc(frame, "UpdateVisuals", function() ns:LayoutTargets() end)
	hooksecurefunc(frame, "SetHeight", QueueLayout)
	-- Anyone else placing the frame (RestedXP restoring its saved position):
	-- dock it again.
	hooksecurefunc(frame, "SetPoint", function()
		if not placing then QueueLayout() end
	end)
	frame:HookScript("OnShow", function() ns:LayoutTargets() end)
	frame:HookScript("OnHide", function() ns:LayoutTargets() end)
end
