-- Arrow: RestedXP's waypoint arrow in Blizzard gold, and the text under it
-- in Blizzard's fonts. The arrow keeps RestedXP's own image: Blizzard's
-- arrow art (the navigation and minimap arrows) is too small an image to
-- draw at this size. The text gains the step's main line, between the step
-- title and the distance, so the arrow alone tells what to do there.
local _, ns = ...


-- Long lines wrap under the arrow instead of running across the screen.
local TEXT_WIDTH = 240
local TEXT_GAP = 4

-- RestedXP's arrow text: a title line, then the distance.
local ARROW_TEXT = "^(.-)\n%((%d+)yd%)$"

local function ArrowFrame()
	return _G.RXPG_ARROW
end

-- The first line of the step as drawn in the Current Steps window: RestedXP
-- has filled in its colors and NPC names there already.
local function MainLine(step)
	if not step then return end
	for _, stepFrame in ipairs(ns.RXPFrame.CurrentStepFrame.framePool) do
		if stepFrame.step == step and stepFrame:IsShown() then
			for _, element in ipairs(stepFrame.elements) do
				local text = element:IsShown() and element:GetAlpha() > 0 and element.text:GetText()
				if text and text:find("%S") then
					return text
				end
			end
		end
	end
end

-- SuperTrackedFrame's GetDistanceString (a local there).
local function DistanceString(distance)
	distance = tonumber(distance) or 0
	return distance < 1000 and tostring(distance) or AbbreviateNumbers(distance)
end

-- Title in gold, the step's line in white (with its own colored names), the
-- distance in gold, in Blizzard's words ("120 yds"). RestedXP sets the text
-- whenever the distance changes, every frame while moving: the title and
-- step lines are built once per step, only the distance is new each time.
local GOLD = NORMAL_FONT_COLOR:GenerateHexColorMarkup()
local lastTitle, lastLine, head

local function FormatText(title, line, distance)
	if title ~= lastTitle or line ~= lastLine then
		lastTitle, lastLine = title, line
		head = GOLD .. title .. "|r\n" .. (line and line .. "\n" or "")
	end
	return head .. GOLD .. IN_GAME_NAVIGATION_RANGE:format(DistanceString(distance)) .. "|r"
end

-- Under the arrow, where RestedXP puts it. The arrow itself turns gold:
-- grayed first, so the tint comes out the same whatever its theme color.
local function Layout(arrowFrame)
	arrowFrame.texture:SetDesaturated(true)
	arrowFrame.texture:SetVertexColor(NORMAL_FONT_COLOR:GetRGB())

	local text = arrowFrame.text
	text:ClearAllPoints()
	text:SetPoint("TOP", arrowFrame, "BOTTOM", 0, -TEXT_GAP)
	text:SetWidth(TEXT_WIDTH)
	text:SetFontObject(GameFontHighlight)
	text:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
end

function ns:StyleArrow()
	local arrowFrame = ArrowFrame()
	if arrowFrame and ns:IsActive() then
		Layout(arrowFrame)
	end
end

function ns:HookArrow()
	local arrowFrame = ArrowFrame()
	if not (arrowFrame and arrowFrame.text and arrowFrame.texture) then return end

	-- RestedXP sets its theme texture and font again here.
	hooksecurefunc(arrowFrame, "UpdateVisuals", function() ns:StyleArrow() end)

	local adding = false
	hooksecurefunc(arrowFrame.text, "SetText", function(fontString, text)
		if adding or not ns:IsActive() or type(text) ~= "string" then return end
		local title, distance = text:match(ARROW_TEXT)
		if not title then return end
		adding = true
		fontString:SetText(FormatText(title, MainLine(arrowFrame.element and arrowFrame.element.step), distance))
		adding = false
	end)
	ns:StyleArrow()
end
