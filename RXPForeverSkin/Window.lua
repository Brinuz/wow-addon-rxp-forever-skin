-- Window: RestedXP's guide window (title, step list, footer) inside a
-- Blizzard window. RestedXP's banner, logo and borders are hidden; its own
-- frames keep every click and drag.
local _, ns = ...

local ART = ns.ART

-- Blizzard's art for the parts RestedXP draws with its own textures. Its
-- resize grip is already Blizzard's (the chat window's), so it stays.
local SETTINGS_ATLAS = "questlog-icon-setting"   -- UIPanelIconDropdownButtonTemplate

-- RestedXP's list scrolls with an old UIPanelScrollBarTemplate slider; it
-- gets MinimalScrollBar's art (the professions recipe list's scroll bar).
local SCROLL_WIDTH = 8
local SCROLL_THUMB_HEIGHT = 20
local SCROLL_STEPPER = {
	{key = "ScrollUpButton", arrow = "minimal-scrollbar-arrow-top"},
	{key = "ScrollDownButton", arrow = "minimal-scrollbar-arrow-bottom"},
}

-- RestedXP's guide name is "Guide\nSubgroup", for its two-line banner. The
-- title strip has room for one line.
local function TitleFromGuideName(text)
	if not text or (issecretvalue and issecretvalue(text)) then return ns.L.WELCOME_TITLE end
	return (text:gsub("\n", " - "))
end

local function UpdateTitle()
	local frame = ns.RXPFrame
	local chrome = frame.BottomFrame.RFSChrome
	if chrome then
		chrome.TitleContainer.TitleText:SetText(TitleFromGuideName(frame.GuideName.text:GetText()))
	end
end

-- The window frame spans RestedXP's guide name (now the title strip) down
-- to the bottom of the window. Parented to the step list, which RestedXP's
-- V2 interface hides, so the chrome goes away with it.
-- RestedXP has no close button; it hides from its minimap button or with
-- "/rxp hide", which also turns off its "shown" setting (hiding the frame
-- directly would only last until its next update). Run that command.
local function HideGuide()
	local rxpCommand = SlashCmdList.ACECONSOLE_RXP
	if rxpCommand then
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
		rxpCommand("hide")
	end
end

local function StyleCloseButton(chrome)
	if chrome.RFSClose then return end
	-- Its OnLoad places it on the corner; scaled with the thinner frame art,
	-- its offsets scale too, so it stays there.
	local close = CreateFrame("Button", nil, chrome, "UIPanelCloseButtonDefaultAnchors")
	close:SetScale(ns.BORDER_SCALE)
	-- Above the guide name, which takes the title strip's clicks.
	close:SetFrameLevel(ns.RXPFrame.GuideName:GetFrameLevel() + 5)
	close:SetScript("OnClick", HideGuide)
	chrome.RFSClose = close
end

local function StyleChrome()
	local frame = ns.RXPFrame
	local guideName, bottom = frame.GuideName, frame.BottomFrame
	local chrome = ns:GetChrome(bottom)
	chrome:ClearAllPoints()
	chrome:SetPoint("TOPLEFT", guideName, "TOPLEFT")
	chrome:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
	chrome:Show()
	StyleCloseButton(chrome)

	-- RestedXP's 35px banner sits over the list's top edge; make it the
	-- title strip above the list instead. Its mouse handlers (drag, right
	-- click menu) stay as they are.
	guideName:SetHeight(ns.TITLE_HEIGHT)
	guideName:ClearAllPoints()
	guideName:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT", -3, 0)
	guideName:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT", 3, 0)
	UpdateTitle()
end

-- The step to return to: the first one RestedXP has active, skipping
-- sticky steps (they stay active from earlier in the guide).
local function CurrentStepIndex()
	local fallback
	for _, row in ipairs(ns.RXPFrame.ScrollChild.framePool) do
		local step = row.step
		if step and step.active then
			if not step.sticky then return step.index end
			fallback = fallback or step.index
		end
	end
	return fallback
end

-- Scrolls the list to the current step, as RestedXP does when a step
-- changes. Same art and size as the chat window's "scroll to bottom".
local function StyleJumpButton(footer)
	if footer.RFSJump then return end
	local jump = CreateFrame("Button", nil, footer)
	jump:SetSize(17, 15)
	jump:SetPoint("RIGHT", footer.icon, "LEFT", -4, 0)
	jump:SetNormalAtlas("minimal-scrollbar-arrow-returntobottom")
	jump:SetPushedAtlas("minimal-scrollbar-arrow-returntobottom-down")
	jump:SetHighlightAtlas("minimal-scrollbar-arrow-returntobottom-over")
	jump:SetScript("OnClick", function()
		local index = CurrentStepIndex()
		if index then
			ns.RXPFrame.BottomFrame:StepScroll(index)
		end
	end)
	jump:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip_SetTitle(GameTooltip, ns.L.JUMP_TO_CURRENT)
		GameTooltip:Show()
	end)
	jump:SetScript("OnLeave", GameTooltip_Hide)
	footer.RFSJump = jump
end

local function StyleFooter()
	local footer = ns.RXPFrame.Footer
	ns:ClearBackdrop(footer)
	footer.bg:Hide()
	footer.text:SetTextColor(GRAY_FONT_COLOR:GetRGB())

	local cog = footer.cog
	cog:SetSize(15, 16)
	cog:SetNormalAtlas(SETTINGS_ATLAS)
	cog:SetHighlightAtlas(SETTINGS_ATLAS, "ADD")
	cog:GetHighlightTexture():SetAlpha(0.4)

	StyleJumpButton(footer)

	if not footer.RFSDivider then
		footer.RFSDivider = footer:CreateTexture(nil, "ARTWORK")
		footer.RFSDivider:SetAtlas(ART.DIVIDER)
		footer.RFSDivider:SetHeight(3)
		footer.RFSDivider:SetPoint("TOPLEFT", 2, 1)
		footer.RFSDivider:SetPoint("TOPRIGHT", -2, 1)
	end
end

function ns:StyleWindow()
	if not ns:IsActive() then return end
	local frame = ns.RXPFrame
	local guideName = frame.GuideName

	ns:ClearBackdrop(frame.BottomFrame)
	ns:ClearBackdrop(guideName)
	guideName.bg:Hide()
	guideName.icon:Hide()
	guideName.classIcon:Hide()
	-- Shown in the title strip instead (UpdateTitle).
	guideName.text:SetAlpha(0)

	StyleChrome()
	StyleFooter()
end

function ns:StyleScrollBar()
	if not ns:IsActive() then return end
	local bar = ns.RXPFrame.ScrollFrame.ScrollBar

	-- Steppers: MinimalScrollBar's Back/Forward arrows, 17x11.
	for _, stepper in ipairs(SCROLL_STEPPER) do
		local button = bar[stepper.key]
		button:SetSize(17, 11)
		button.Normal:SetAtlas(stepper.arrow)
		button.Pushed:SetAtlas(stepper.arrow .. "-down")
		button.Disabled:SetAtlas(stepper.arrow)
		button.Disabled:SetAlpha(0.5)
		button.Highlight:SetAtlas(stepper.arrow .. "-over")
		button.Highlight:SetBlendMode("BLEND")
	end

	-- Track behind the slider, in three pieces like MinimalScrollBar's.
	if not bar.RFSTrack then
		local track = {}
		track.Begin = bar:CreateTexture(nil, "BACKGROUND")
		track.Begin:SetAtlas("minimal-scrollbar-track-top", true)
		track.Begin:SetPoint("TOP")
		track.End = bar:CreateTexture(nil, "BACKGROUND")
		track.End:SetAtlas("minimal-scrollbar-track-bottom", true)
		track.End:SetPoint("BOTTOM")
		track.Middle = bar:CreateTexture(nil, "BACKGROUND")
		track.Middle:SetAtlas("!minimal-scrollbar-track-middle", true)
		track.Middle:SetPoint("TOPLEFT", track.Begin, "BOTTOMLEFT")
		track.Middle:SetPoint("BOTTOMRIGHT", track.End, "TOPRIGHT")
		bar.RFSTrack = track
	end

	-- The slider's thumb is a single texture: the thumb's middle piece, with
	-- its top and bottom caps attached to it.
	local thumb = bar:GetThumbTexture()
	thumb:SetAtlas("minimal-scrollbar-small-thumb-middle")
	thumb:SetSize(SCROLL_WIDTH, SCROLL_THUMB_HEIGHT)
	if not bar.RFSThumbCaps then
		local top = bar:CreateTexture(nil, "ARTWORK")
		top:SetAtlas("minimal-scrollbar-small-thumb-top", true)
		top:SetPoint("BOTTOM", thumb, "TOP")
		local bottom = bar:CreateTexture(nil, "ARTWORK")
		bottom:SetAtlas("minimal-scrollbar-small-thumb-bottom", true)
		bottom:SetPoint("TOP", thumb, "BOTTOM")
		bar.RFSThumbCaps = {top, bottom}
	end
end

function ns:HookWindow()
	-- RestedXP sets the guide name on this font string whenever a guide loads.
	hooksecurefunc(ns.RXPFrame.GuideName.text, "SetText", function()
		if ns:IsActive() then UpdateTitle() end
	end)
end
