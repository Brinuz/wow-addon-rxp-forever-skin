-- Targets: RestedXP's "Active Targets" frame (the NPCs and mobs of the
-- current step) and its "Active Items" frame (the items the step uses),
-- docked side by side at the bottom of the Current Steps frame, under a
-- divider, each behind a gold heading, their buttons in action button art.
--
-- The buttons are secure action buttons, so the frames are protected in
-- combat. Out of combat they are anchored to the steps and follow them; when
-- combat starts they are pinned where they are, so the steps (which RestedXP
-- moves whenever a step changes) never have a protected frame anchored to
-- them.
local _, ns = ...

-- Space between the last step and the rows (the divider sits in the
-- middle), in the steps frame's units.
local TARGET_GAP = 8
-- The targets' heading starts where the step titles do; each column's
-- buttons start after its heading.
local HEADING_X = 7
local HEADING_PADDING = 8

-- RestedXP's layout of its frames, in their own units: buttons 25px; target
-- buttons 6px in from the left, the first enemy row 12px below the top,
-- friendly rows end 6px above the bottom; item buttons 4px in from the
-- left and 2px up from the bottom.
local BUTTON_SIZE, BUTTON_INSET, ENEMY_TOP, FRIENDLY_BOTTOM = 25, 6, 12, 6
local ITEM_INSET, ITEM_BOTTOM = 4, 2
-- RestedXP's grid: 4 buttons a row, 27px apart. Friendly rows grow upward.
local BUTTONS_PER_ROW, BUTTON_SPACING = 4, 2

-- ActionButtonTemplate's frame art is 46x45 around a 45x45 icon.
local BORDER_WIDTH_RATIO = 46 / 45

-- How far the docked rows reach below the steps (0: none showing), in the
-- steps frame's units. Measured out of combat; the steps' frame is sized
-- from it, never from where the buttons are, so a stray move of RestedXP's
-- frames can't stretch it.
local extent = 0
local layoutQueued = false
-- Set while we place a frame, to tell our moves from anyone else's.
local placing = false
-- Reused for every layout, so updates don't leave tables behind.
local enemies, friendlies, items = {}, {}, {}

local function TargetFrame()
	return _G.RXPTargetFrame
end

local function ItemFrame()
	return _G.RXPItemFrame
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
	if button.RFSBorder or not button.icon then return end
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

-- RestedXP's box and title go; our heading replaces the title, and the
-- frame no longer drags on its own: it moves with the steps.
local function StripFrame(frame, buttonLists)
	ns:ClearBackdrop(frame)
	ns:ClearBackdrop(frame.title)
	frame.title.text:SetAlpha(0)
	frame.title:EnableMouse(false)
	frame:EnableMouse(false)
	for _, buttons in ipairs(buttonLists) do
		for _, button in ipairs(buttons) do StyleButton(button) end
	end
end

-- ---------------------------------------------------------------- docking
-- How far below the steps the docked rows reach (0 when none show).
function ns:GetTargetsExtent()
	return ns:IsActive() and extent or 0
end

-- Extra room the steps need above the window for the docked rows.
function ns:TargetsRoomAbove()
	local steps = ns.RXPFrame.CurrentStepFrame
	return steps.anchor == "TOP" and ns:GetTargetsExtent() or 0
end

-- The headings and divider live on the steps' frame (Steps.lua's chrome).
local function GetDockArt(chrome)
	if not chrome.RFSTargetsHeading then
		chrome.RFSTargetsHeading = chrome:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		chrome.RFSItemsHeading = chrome:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		chrome.RFSTargetsDivider = chrome:CreateTexture(nil, "ARTWORK")
		chrome.RFSTargetsDivider:SetAtlas(ns.ART.DIVIDER)
		chrome.RFSTargetsDivider:SetHeight(3)
	end
	return chrome.RFSTargetsHeading, chrome.RFSItemsHeading, chrome.RFSTargetsDivider
end

local function Shown(buttons, into)
	wipe(into)
	for _, button in ipairs(buttons or {}) do
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

-- Where the first row of target buttons is centered, from the frame's top.
local function FirstRowCenter(frame)
	local enemy = frame.enemyTargetButtons[1]
	if enemy and enemy:IsShown() then
		return ENEMY_TOP + BUTTON_SIZE / 2
	end
	return frame:GetHeight() - FRIENDLY_BOTTOM - BUTTON_SIZE / 2
end

-- RestedXP may leave a frame up while it has no buttons to show.
local function HasTargets(frame)
	return frame and frame:IsShown() and (#Shown(frame.enemyTargetButtons, enemies) > 0
		or #Shown(frame.friendlyTargetButtons, friendlies) > 0)
end

local function HasItems(frame)
	return frame and frame:IsShown() and #Shown(frame.buttonList, items) > 0
end

-- A column's heading, left of its buttons: `x` from the steps' left, `y`
-- the first row's center, from the steps' bottom.
local function PlaceHeading(heading, steps, text, x, y)
	heading:SetText(text)
	heading:ClearAllPoints()
	heading:SetPoint("LEFT", steps, "BOTTOMLEFT", x, -y)
	heading:Show()
end

-- The buttons' size relative to the steps' text: RestedXP's 25px buttons
-- drawn a fifth larger. Overrides RestedXP's own scale settings for these
-- two frames.
local BUTTON_SCALE = 1.2

-- Sizes `frame` to BUTTON_SCALE of the steps' scale, then puts it so its
-- content starts at `left` and `top` (steps units, from the steps' bottom
-- left), `inset` and `topInset` being where RestedXP draws its first button
-- inside it (its units).
local function PlaceFrame(frame, steps, left, top, inset, topInset)
	local parentScale = frame:GetEffectiveScale() / frame:GetScale()
	placing = true
	frame:SetScale(steps:GetEffectiveScale() * BUTTON_SCALE / parentScale)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", steps, "BOTTOMLEFT", left / BUTTON_SCALE - inset, -top / BUTTON_SCALE + topInset)
	placing = false
end

-- The right edge of the rightmost button, from the steps' left (steps units).
local function RightEdge(steps, buttons)
	local right = 0
	for _, button in ipairs(buttons) do
		local r = button:GetRight()
		if r then
			right = math.max(right, r * button:GetEffectiveScale() / steps:GetEffectiveScale() - steps:GetLeft())
		end
	end
	return right
end

-- Space between the targets' last button and the items column.
local COLUMN_GAP = 16

-- Runs out of combat only; PLAYER_REGEN_ENABLED catches up afterwards.
-- Two columns side by side: targets on the left, items from the middle (or
-- after the targets when they reach past it). Either one alone goes left.
function ns:LayoutTargets()
	if not ns:IsActive() or InCombatLockdown() then return end
	local targetFrame, itemFrame = TargetFrame(), ItemFrame()
	if not (targetFrame or itemFrame) then return end
	local steps = ns.RXPFrame.CurrentStepFrame
	local chrome = ns:GetChrome(steps, ns.L.ACTIVE_TITLE)
	local targetsHeading, itemsHeading, divider = GetDockArt(chrome)

	if targetFrame then
		StripFrame(targetFrame, {targetFrame.enemyTargetButtons, targetFrame.friendlyTargetButtons})
	end
	if itemFrame then
		StripFrame(itemFrame, {itemFrame.buttonList})
	end

	local showTargets, showItems = HasTargets(targetFrame), HasItems(itemFrame)
	targetsHeading:Hide()
	itemsHeading:Hide()

	-- How far down the rows reach, from the steps' bottom.
	local height = 0
	local itemsX = HEADING_X
	if showTargets then
		PlaceHeading(targetsHeading, steps, targetFrame.title.text:GetText(), HEADING_X,
			TARGET_GAP + FirstRowCenter(targetFrame) * BUTTON_SCALE)
		local buttonsLeft = HEADING_X + targetsHeading:GetUnboundedStringWidth() + HEADING_PADDING
		PlaceFrame(targetFrame, steps, buttonsLeft, TARGET_GAP, BUTTON_INSET, 0)
		local lowest = JoinRows(targetFrame)
		local top, bottom = targetFrame:GetTop(), lowest and lowest:GetBottom()
		if top and bottom then
			height = TARGET_GAP + (top - bottom) * BUTTON_SCALE
		end
		if showItems and steps:GetLeft() then
			local targetsRight = math.max(RightEdge(steps, enemies), RightEdge(steps, friendlies))
			itemsX = math.max(steps:GetWidth() / 2, targetsRight + COLUMN_GAP)
		end
	end
	if showItems then
		PlaceHeading(itemsHeading, steps, itemFrame.title.text:GetText(), itemsX,
			TARGET_GAP + BUTTON_SIZE / 2 * BUTTON_SCALE)
		local buttonsLeft = itemsX + itemsHeading:GetUnboundedStringWidth() + HEADING_PADDING
		-- RestedXP lines its item buttons up along the frame's bottom.
		local topInset = itemFrame:GetHeight() - ITEM_BOTTOM - BUTTON_SIZE
		PlaceFrame(itemFrame, steps, buttonsLeft, TARGET_GAP, ITEM_INSET, topInset)
		height = math.max(height, TARGET_GAP + BUTTON_SIZE * BUTTON_SCALE)
	end

	local shown = showTargets or showItems
	divider:SetShown(shown)
	if shown then
		divider:ClearAllPoints()
		divider:SetPoint("TOPLEFT", steps, "BOTTOMLEFT", 0, -TARGET_GAP / 2 + 1)
		divider:SetPoint("TOPRIGHT", steps, "BOTTOMRIGHT", 0, -TARGET_GAP / 2 + 1)
	end

	-- Above the window the steps grow upward from it: when the rows' height
	-- changes, have RestedXP place them again (the SetPoint hook in Steps.lua
	-- adds the room).
	if math.abs(height - extent) > 0.5 then
		extent = height
		if ns.RXPFrame.SetStepFrameAnchor and steps:GetTop() then
			ns.RXPFrame.SetStepFrameAnchor()
		end
	end
	ns:AnchorStepsChrome()
end

-- RestedXP places its buttons right after resizing a frame, so a layout
-- from its SetHeight or SetWidth would be undone; run it on the next frame.
local function RunQueuedLayout()
	layoutQueued = false
	ns:LayoutTargets()
end

local function QueueLayout()
	if layoutQueued then return end
	layoutQueued = true
	C_Timer.After(0, RunQueuedLayout)
end

-- Unpin from the steps before combat locks the frames down (protected
-- frames can still be moved while this event runs).
local function Pin(frame)
	local left, top = frame:GetLeft(), frame:GetTop()
	if left and top then
		placing = true
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
		placing = false
	end
end

ns:On("PLAYER_REGEN_DISABLED", function()
	if not ns:IsActive() then return end
	if TargetFrame() then Pin(TargetFrame()) end
	if ItemFrame() then Pin(ItemFrame()) end
end)

ns:On("PLAYER_REGEN_ENABLED", function()
	ns:LayoutTargets()
end)

function ns:StyleTargets()
	ns:LayoutTargets()
end

-- RestedXP re-applies its backdrop and title box in UpdateVisuals (theme
-- changes), and resizes a frame after every update of its buttons, which is
-- when new buttons appear. It shows and hides the frames as their content
-- comes and goes. Anyone else placing a frame (RestedXP restoring its saved
-- position): dock it again.
local function HookFrame(frame, resize)
	if frame.RFSHooked then return end
	frame.RFSHooked = true
	if frame.UpdateVisuals then
		hooksecurefunc(frame, "UpdateVisuals", function() ns:LayoutTargets() end)
	end
	hooksecurefunc(frame, resize, QueueLayout)
	-- RestedXP applies its own scale setting; ours wins.
	hooksecurefunc(frame, "SetScale", function()
		if not placing then QueueLayout() end
	end)
	hooksecurefunc(frame, "SetPoint", function()
		if not placing then QueueLayout() end
	end)
	frame:HookScript("OnShow", function() ns:LayoutTargets() end)
	frame:HookScript("OnHide", function() ns:LayoutTargets() end)
end

-- The items frame may be created later than the targets frame.
local function HookFrames()
	if TargetFrame() then HookFrame(TargetFrame(), "SetHeight") end
	if ItemFrame() then HookFrame(ItemFrame(), "SetWidth") end
end

function ns:HookTargets()
	HookFrames()
end

ns:On("PLAYER_ENTERING_WORLD", function()
	if ns:IsActive() then
		HookFrames()
		QueueLayout()
	end
end)
