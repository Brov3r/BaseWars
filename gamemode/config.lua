BW.Config = BW.Config or {}

BW.Config = {
    Motion = {
        WalkSpeed   = 125,
        RunSpeed    = 250,
        JumpPower   = 200
    },
	Notify = {
		MaxNotification 	= 5,
		Spacing 			= 10,
		SlideSpeed 			= 8,
	},
    Colors = {
        White         = Color(255, 255, 255),
        Black         = Color(0, 0, 0),
        Red           = Color(255, 50, 50),
        Green         = Color(0, 255, 0),
        Blue          = Color(0, 0, 255),
        Gray          = Color(128, 128, 128),
        LightGray     = Color(200, 200, 200),
        DarkGray      = Color(60, 60, 60),
        DarkGray45    = Color(45, 45, 50, 245),
        DarkGray35    = Color(35, 35, 40, 245),
        DarkGray30    = Color(30, 30, 30),
        BlackAlpha50  = Color(0, 0, 0, 128),
        BlackAlpha150 = Color(0, 0, 0, 150),
        BlackAlpha200 = Color(0, 0, 0, 200),
        WhiteAlpha200 = Color(255, 255, 255, 200),
        Info          = Color(100, 180, 255),
        Warn          = Color(255, 200, 50),
        Error         = Color(255, 100, 100),
        Success       = Color(100, 255, 100),
        Silver        = Color(192, 192, 192),
        Gold          = Color(255, 215, 0),
        Orange        = Color(255, 165, 0),
        Purple        = Color(128, 0, 128),
        Cyan          = Color(0, 255, 255),
        Yellow        = Color(255, 255, 0),
    },
    Scoreboard = {
        Spacing        = 2,
        AvatarSize     = 32,
        AvatarOffsetX  = 42,
        MuteBtnWidth   = 24,
        MuteBtnMargin  = 20,
        PanelWidth     = 840,
        PanelMaxHeight = 600,
        HeaderHeight   = 30,
        RowHeight      = 48,
        LeftMargin     = 20,
    },
    NameTag = {
        MaxDist   = 800,
        FadeDist  = 50,
        FadeSpeed = 12,
        Scale     = 0.18,
    },
    HUD = {
        Dimensions = {
            Avatar       = 78,
            HealthBarH   = 15,
            HealthBarW   = 200,
            ArmorBarH    = 8,
            ArmorBarW    = 200,
        },
        Margin             = 10,
        AvatarCornerOffset = 20,
    },
	AnimTime          = 0.2,
    StartMoney        = 5000,
    PayDayInterval    = 300,
    PayDayDefaultMin  = 500,
    PayDayDefaultMax  = 800,
    PayDayMultiplier  = {
        ["admin"] = 2.5,
        ["vip"]   = 1.7,
        ["user"]  = 1,
    }
}

-- Export
Colors = BW.Config.Colors