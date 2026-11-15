-- Chrome: the Blizzard window frame, and the list art shared by the window
-- and the step frames.
local _, ns = ...

ns.ART = {
	DIVIDER = "RecipeList-Divider",
	SELECTED = "Professions_Recipe_Active",
	HOVER = "Professions_Recipe_Hover",
}

-- The metal frame art is drawn at this size: thinner edges, corners and
-- title bar than Blizzard's own windows, the windows themselves unchanged.
local BORDER_SCALE = 0.85
ns.BORDER_SCALE = BORDER_SCALE

-- Blizzard's title strip is 21px (the background starts below it) and the
-- background sits 2px inside the edges, both at full size.
local TITLE_STRIP, BG_INSET, TITLE_TEXT_Y = 21, 2, -5

ns.TITLE_HEIGHT = 22

-- The window frame's corners need about 118px of height at full size; a
-- shorter window gets its top and bottom corners overlapping.
ns.MIN_CHROME_HEIGHT = math.ceil(118 * BORDER_SCALE)

-- A Blizzard window behind `parent`, stored as parent.RFSChrome. Anchoring
-- is left to the caller: the art often has to reach past the frame's edges,
-- and the content has to start below the title strip.
function ns:GetChrome(parent, title)
	if not parent.RFSChrome then
		local chrome = CreateFrame("Frame", nil, parent, "RXPForeverSkinChromeTemplate")
		-- Same call ProfessionsMixin:OverrideArt makes for the Professions window.
		SetTextureWithAddressModeOptions(chrome.Bg, "Profession-Background-Overview")
		chrome.TitleContainer:SetFrameLevel(chrome:GetFrameLevel() + 10)
		-- The nine-slice fills the chrome whatever its scale; its pieces
		-- shrink. Move the background and title in to match.
		chrome.NineSlice:SetScale(BORDER_SCALE)
		chrome.Bg:ClearAllPoints()
		chrome.Bg:SetPoint("TOPLEFT", BG_INSET * BORDER_SCALE, -TITLE_STRIP * BORDER_SCALE)
		chrome.Bg:SetPoint("BOTTOMRIGHT", -BG_INSET * BORDER_SCALE, BG_INSET * BORDER_SCALE)
		chrome.TitleContainer.TitleText:SetPoint("TOP", 0, TITLE_TEXT_Y * BORDER_SCALE)
		chrome.TitleContainer.TitleText:SetText(title)
		parent.RFSChrome = chrome
	end
	return parent.RFSChrome
end

-- RestedXP draws its panels with BackdropTemplate; clearing the backdrop
-- also turns its later SetBackdropColor calls (row hover) into no-ops.
function ns:ClearBackdrop(frame)
	if frame and frame.backdropInfo then
		frame:ClearBackdrop()
	end
end
