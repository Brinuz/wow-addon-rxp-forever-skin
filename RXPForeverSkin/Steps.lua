-- Steps: the guide's step list as professions recipe list rows, and the
-- active steps (below or above the window, plus floating tips) in their own
-- Blizzard frame, with gold step titles and Blizzard check boxes.
local _, ns = ...

local ART = ns.ART

-- ChatConfigCheckButtonTemplate's own textures, which RestedXP replaces.
local CHECK_ART = "Interface\\Buttons\\UI-CheckBox-"

-- How far the active steps' frame reaches past the steps (the sides only for
-- a floating tip). At the top: the title strip, plus RestedXP's step title
-- badge, which it draws 5px above the step.
local MARGIN_SIDE, MARGIN_TOP, MARGIN_BOTTOM = 3, ns.TITLE_HEIGHT + 7, 6

-- Room between the window and the active steps' frame, so the two metal
-- edges don't overlap. Below the window the step frame's top margin counts.
local GAP_BELOW, GAP_ABOVE = MARGIN_TOP + 2, MARGIN_BOTTOM + 2

-- Room between the steps' text and the frame's metal sides. The frame stays
-- as wide as the window; the steps are pulled in from both sides.
local PADDING_SIDE = 8

local function Surround(chrome, frame)
	chrome:ClearAllPoints()
	chrome:SetPoint("TOPLEFT", frame, "TOPLEFT", -MARGIN_SIDE, MARGIN_TOP)
	chrome:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", MARGIN_SIDE, -MARGIN_BOTTOM)
end

-- ---------------------------------------------------------------- step list
-- RestedXP stacks the rows 3px apart; spread them out, with the divider in
-- the middle of the gap, like Zygor's separators between steps.
local RXP_ROW_GAP = 3
local ROW_GAP = 15
local DIVIDER_HEIGHT = 3

-- Finished steps: the objective tracker's check where the step number was,
-- gray text without RestedXP's colors, and faded further than RestedXP's 0.5.
local DONE_CHECK = "ui-questtracker-tracker-check"
local DONE_ALPHA = 0.4

-- RestedXP's own current step (addon.GetGuideProgress, which is private):
-- the guide's saved progress, else the character's current step.
local function CurrentStep(guide)
	if not RXPCData then return 1 end
	local progress = guide and guide.key and RXPCData.guideProgress and RXPCData.guideProgress[guide.key]
	return tonumber(progress and progress.step) or tonumber(RXPCData.currentStep) or 1
end

-- The rule RestedXP uses to fade a row in BottomFrame.UpdateFrame.
local function IsDone(row)
	local step = row.step
	if not step or step.active then return false end
	local skipped = RXPCData and RXPCData.stepSkip and RXPCData.stepSkip[step.index]
	return step.completed or (not step.sticky and CurrentStep(row.guide) > step.index) or skipped and true or false
end

local function StripColors(text)
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function CreateRowArt(row)
	row.RFSSelected = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	row.RFSSelected:SetAtlas(ART.SELECTED)
	row.RFSSelected:SetAllPoints()
	-- Like the recipe list's HighlightOverlay: half alpha, shown on mouseover.
	-- The rows take the mouse (RestedXP's OnEnter), so HIGHLIGHT shows.
	row.RFSHover = row:CreateTexture(nil, "HIGHLIGHT")
	row.RFSHover:SetAtlas(ART.HOVER)
	row.RFSHover:SetAlpha(0.5)
	row.RFSHover:SetAllPoints()
	-- Centered in the gap under the row (SpaceRow).
	local offset = -math.floor((ROW_GAP - DIVIDER_HEIGHT) / 2)
	row.RFSDivider = row:CreateTexture(nil, "ARTWORK")
	row.RFSDivider:SetAtlas(ART.DIVIDER)
	row.RFSDivider:SetHeight(DIVIDER_HEIGHT)
	row.RFSDivider:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, offset)
	row.RFSDivider:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, offset)
	if row.number then
		row.RFSCheck = row:CreateTexture(nil, "OVERLAY")
		row.RFSCheck:SetAtlas(DONE_CHECK)
		row.RFSCheck:SetSize(14, 14)
		row.RFSCheck:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	end
end

-- RestedXP sets the text and alpha on every UpdateFrame; this runs after it.
local function StyleDone(row, done)
	if done then
		row:SetAlpha(DONE_ALPHA)
		row.text:SetTextColor(GRAY_FONT_COLOR:GetRGB())
		-- RestedXP sets its colored text again on every refresh of the row;
		-- remember the last plain version instead of stripping it each time.
		local text = row.text:GetText()
		if text and text ~= row.RFSPlain then
			if text ~= row.RFSColored then
				row.RFSColored, row.RFSPlain = text, StripColors(text)
			end
			row.text:SetText(row.RFSPlain)
		end
	else
		row.text:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
	end
	if row.number then
		row.number.text:SetShown(not done)
		row.RFSCheck:SetShown(done)
	end
end

-- RestedXP anchors each row under the previous one when a guide loads:
-- 3px below it, or overlapping by 1px for a step it never shows. Widen the
-- gap above shown rows. The list's scroll height follows the rows, and
-- RestedXP scrolls to a step by its share of that height, so both still fit.
local function SpaceRow(row, shown)
	local point, relativeTo, relativePoint, x, y = row:GetPoint(1)
	if not (point == "TOPLEFT" and relativePoint == "BOTTOMLEFT") then return end
	local gap = shown and ROW_GAP or RXP_ROW_GAP
	if y ~= -RXP_ROW_GAP and y ~= -ROW_GAP or y == -gap then return end
	row:SetPoint("TOPLEFT", relativeTo, "BOTTOMLEFT", x, -gap)
	row:SetPoint("TOPRIGHT", relativeTo, "BOTTOMRIGHT", x, -gap)
end

-- RestedXP sets each row's backdrop when a guide loads, then lays the rows
-- out with UpdateFrame (hooked in Core), so clearing it here sticks.
local function StyleRow(row)
	if not (row and row:IsShown()) then return end
	if not row.RFSSelected then CreateRowArt(row) end
	ns:ClearBackdrop(row)
	local current = row.step and row.step.active and true or false
	row.RFSSelected:SetShown(current)
	if row.number then
		row.number.text:SetTextColor(GRAY_FONT_COLOR:GetRGB())
	end
	-- Alpha 0 is RestedXP hiding the row (a step above your level).
	local shown = row:GetAlpha() > 0
	SpaceRow(row, shown)
	if shown then
		StyleDone(row, IsDone(row))
	end
end

-- Takes UpdateFrame's arguments. RestedXP refreshes single steps many times
-- a second, as UpdateFrame(nil, n) or row:UpdateFrame(); restyle only that
-- row then, and every row when it lays out the whole list.
function ns:StyleRows(caller, stepIndex)
	if not ns:IsActive() then return end
	local rows = ns.RXPFrame.ScrollChild.framePool
	if not caller and stepIndex then
		StyleRow(rows[stepIndex])
	elseif caller and caller.step then
		StyleRow(rows[stepIndex or caller.step.index])
	else
		for _, row in ipairs(rows) do
			StyleRow(row)
		end
	end
end

-- ---------------------------------------------------------------- active steps
local function StyleElement(element)
	local button = element.button
	button:SetNormalTexture(CHECK_ART .. "Up")
	button:SetCheckedTexture(CHECK_ART .. "Check")
	button:SetDisabledCheckedTexture(CHECK_ART .. "Check-Disabled")
	element.text:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
end

local function StyleStepFrame(stepFrame)
	ns:ClearBackdrop(stepFrame)
	local number = stepFrame.number
	if number then
		ns:ClearBackdrop(number)
		-- The step title as a gold heading. RestedXP sized the badge for its
		-- own font and centered the text in it; start it at the left instead.
		-- RestedXP colors it explicitly, which wins over the font's gold.
		number.text:SetFontObject(GameFontNormal)
		number.text:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
		number.text:ClearAllPoints()
		number.text:SetPoint("LEFT", number, "LEFT", 0, 1)
	end
	for _, element in ipairs(stepFrame.elements) do
		StyleElement(element)
	end

	-- A tip floats on its own, away from the other steps: give it a frame.
	local tip = stepFrame.step and stepFrame.step.tip
	if tip then
		local chrome = ns:GetChrome(stepFrame, ns.L.TIP_TITLE)
		Surround(chrome, stepFrame)
		chrome:Show()
	elseif stepFrame.RFSChrome then
		stepFrame.RFSChrome:Hide()
	end
end

-- Whether any step (other than a floating tip) is drawn in the frame.
local function HasVisibleSteps(stepsFrame)
	for _, stepFrame in ipairs(stepsFrame.framePool) do
		if stepFrame:IsShown() and stepFrame:GetAlpha() > 0 and not (stepFrame.step and stepFrame.step.tip) then
			return true
		end
	end
	return false
end

function ns:StyleActiveSteps()
	if not ns:IsActive() then return end
	local stepsFrame = ns.RXPFrame.CurrentStepFrame
	for _, stepFrame in ipairs(stepsFrame.framePool) do
		StyleStepFrame(stepFrame)
	end
	-- Exactly as wide as the window: RestedXP's own inset differs between
	-- placing the steps below the window and above its title strip.
	ns:AnchorStepsChrome()
	ns:LayoutTargets()
end

-- Also called by Targets.lua: with active targets docked under the steps
-- the frame reaches down to them.
function ns:AnchorStepsChrome()
	local stepsFrame = ns.RXPFrame.CurrentStepFrame
	local window = ns.RXPFrame
	local chrome = ns:GetChrome(stepsFrame, ns.L.ACTIVE_TITLE)
	local targets = ns:GetTargetsExtent()
	chrome:ClearAllPoints()
	chrome:SetPoint("TOP", stepsFrame, "TOP", 0, MARGIN_TOP)
	chrome:SetPoint("BOTTOM", stepsFrame, "BOTTOM", 0, -(targets + MARGIN_BOTTOM))
	chrome:SetPoint("LEFT", window, "LEFT")
	chrome:SetPoint("RIGHT", window, "RIGHT")
	chrome:SetShown(targets > 0 or HasVisibleSteps(stepsFrame))
end

-- RestedXP anchors the active steps flush against the window (below it, or
-- above the guide name), from a local function we can't hook. Follow each
-- of its SetPoint calls with the same point moved out by the gap and in by
-- the side padding. Above the window, docked targets need room too.
function ns:HookActiveSteps()
	local stepsFrame = ns.RXPFrame.CurrentStepFrame
	local moving = false
	hooksecurefunc(stepsFrame, "SetPoint", function(self, point, relativeTo, relativePoint, x, y)
		if moving or not ns:IsActive() or type(relativeTo) ~= "table" then return end
		local below = point:find("^TOP") ~= nil
		local dy = below and -GAP_BELOW or GAP_ABOVE + ns:TargetsRoomAbove()
		local dx = point:find("LEFT$") and PADDING_SIDE or point:find("RIGHT$") and -PADDING_SIDE or 0
		moving = true
		self:SetPoint(point, relativeTo, relativePoint, (x or 0) + dx, (y or 0) + dy)
		moving = false
	end)
end
