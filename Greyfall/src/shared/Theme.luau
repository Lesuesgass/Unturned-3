-- Visual style for every interface element. Muted, low-saturation colours and one plain font.

local C = Color3.fromRGB
local FAMILY = "rbxasset://fonts/families/SourceSansPro.json"

return {
	Font = Font.new(FAMILY, Enum.FontWeight.Regular),
	FontMedium = Font.new(FAMILY, Enum.FontWeight.SemiBold),
	FontBold = Font.new(FAMILY, Enum.FontWeight.Bold),
	-- Fixed-width digits for numbers that change in place (stats, ammo, weight, clock).
	FontNumbers = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium),

	Panel = C(18, 19, 17),
	PanelTransparency = 0.2,
	PanelLight = C(34, 36, 32),
	PanelHover = C(48, 50, 44),
	Line = C(72, 74, 66),
	Text = C(214, 212, 200),
	TextDim = C(140, 140, 128),
	Accent = C(158, 150, 112),
	Danger = C(176, 70, 60),
	DangerText = C(193, 109, 101), -- Danger lightened so small text stays readable (4.5:1)

	Health = C(156, 62, 54),
	Food = C(168, 132, 78),
	Water = C(78, 118, 140),
	Stamina = C(186, 184, 170),
	Immunity = C(112, 138, 74),
	Oxygen = C(120, 160, 175),

	-- Type scale (about 1.25 between steps).
	CaptionTextSize = 12,
	SmallTextSize = 14,
	TextSize = 16,
	TitleTextSize = 20,
	DisplayTextSize = 30,
	HeroTextSize = 44,

	-- Touch-friendly height for every button and list row.
	ControlHeight = 44,
}
