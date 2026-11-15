-- Chrome: the Blizzard window frame, and the list art shared by the window
-- and the step frames.
local _, ns = ...

ns.ART = {
	DIVIDER = "RecipeList-Divider",
	SELECTED = "Professions_Recipe_Active",
	HOVER = "Professions_Recipe_Hover",
}

-- Blizzard's title strip is 21px; the background starts below it.
ns.TITLE_HEIGHT = 22

-- A Blizzard window behind `parent`, stored as parent.RFSChrome. Anchoring
-- is left to the caller: the art often has to reach past the frame's edges,
-- and the content has to start below the title strip.
function ns:GetChrome(parent, title)
	if not parent.RFSChrome then
		local chrome = CreateFrame("Frame", nil, parent, "RXPForeverSkinChromeTemplate")
		-- Same call ProfessionsMixin:OverrideArt makes for the Professions window.
		SetTextureWithAddressModeOptions(chrome.Bg, "Profession-Background-Overview")
		chrome.TitleContainer:SetFrameLevel(chrome:GetFrameLevel() + 10)
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
