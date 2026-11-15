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
local function StyleChrome()
	local frame = ns.RXPFrame
	local guideName, bottom = frame.GuideName, frame.BottomFrame
	local chrome = ns:GetChrome(bottom)
	chrome:ClearAllPoints()
	chrome:SetPoint("TOPLEFT", guideName, "TOPLEFT")
	chrome:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
	chrome:Show()

	-- RestedXP's 35px banner sits over the list's top edge; make it the
	-- title strip above the list instead. Its mouse handlers (drag, right
	-- click menu) stay as they are.
	guideName:SetHeight(ns.TITLE_HEIGHT)
	guideName:ClearAllPoints()
	guideName:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT", -3, 0)
	guideName:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT", 3, 0)
	UpdateTitle()
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
