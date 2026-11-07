-- Visual style for every interface element. Muted, low-saturation colours and one plain font.

local C = Color3.fromRGB
local FAMILY = "rbxasset://fonts/families/SourceSansPro.json"

return {
	Font = Font.new(FAMILY, Enum.FontWeight.Regular),
	FontMedium = Font.new(FAMILY, Enum.FontWeight.SemiBold),
	FontBold = Font.new(FAMILY, Enum.FontWeight.Bold),

	Panel = C(18, 19, 17),
	PanelTransparency = 0.2,
	PanelLight = C(34, 36, 32),
	PanelHover = C(48, 50, 44),
	Line = C(72, 74, 66),
	Text = C(214, 212, 200),
	TextDim = C(140, 140, 128),
	Accent = C(158, 150, 112),
	Danger = C(176, 70, 60),

	Health = C(156, 62, 54),
	Food = C(168, 132, 78),
	Water = C(78, 118, 140),
	Stamina = C(186, 184, 170),
	Infection = C(112, 138, 74),

	TextSize = 16,
	SmallTextSize = 13,
	TitleTextSize = 20,
}
