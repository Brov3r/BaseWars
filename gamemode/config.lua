BW.Config = {
	Colors = {
        -- === Base ===
        White           = Color(255, 255, 255, 255),
        Black           = Color(0, 0, 0, 255),
        
        LightRed        = Color(254, 110, 99),
        Red             = Color(244, 67, 54, 255),
        Pink            = Color(233, 30, 99, 255),
        Purple          = Color(156, 39, 176, 255),
        Blue            = Color(33, 150, 243, 255),
        Cyan            = Color(0, 188, 212, 255),
        Teal            = Color(0, 150, 136, 255),
        LightGreen      = Color(109, 221, 112),
        Green           = Color(76, 175, 80, 255),
        Yellow          = Color(255, 235, 59, 255),
        Orange          = Color(255, 152, 0, 255),
        Amber           = Color(255, 193, 7, 255),
        Brown           = Color(121, 85, 72, 255),
        Grey            = Color(158, 158, 158, 255),

        -- === Gray ===
        Gray10          = Color(10, 10, 10, 255),
        Gray20          = Color(20, 20, 20, 255),
        DarkGray30      = Color(30, 30, 30, 255),
        DarkGray35      = Color(35, 35, 40, 255),
        Gray40          = Color(40, 40, 40, 255),
        DarkGray45      = Color(45, 45, 50, 255),
        Gray50          = Color(50, 50, 50, 255),
        DarkGray        = Color(60, 60, 60, 255),
        Gray80          = Color(80, 80, 80, 255),
        Gray100         = Color(100, 100, 100, 255),
        Gray128         = Color(128, 128, 128, 255),
        Gray150         = Color(150, 150, 150, 255),
        Silver          = Color(192, 192, 192, 255),
        LightGray       = Color(200, 200, 200, 255),
        Gray220         = Color(220, 220, 220, 255),
        Gray240         = Color(240, 240, 240, 255),

        -- === Status ===
        Info            = Color(100, 180, 255, 255),
        Warn            = Color(255, 200, 50, 255),
        Error           = Color(255, 100, 100, 255),
        Success         = Color(100, 255, 100, 255),

        -- === Shop UI / SpawnMenu ===
        Transparent     = Color(0, 0, 0, 0),
        TextShade       = Color(0, 0, 0, 200),
        VipGold         = Color(255, 215, 0, 120),
        ShopCheap       = Color(0, 90, 200, 180),
        ShopAvailable   = Color(90, 200, 0, 180),
        ShopLocked      = Color(90, 90, 90, 180),
        ShopNoMoney     = Color(200, 0, 20, 180),
    },
	HUD = {
        Dimensions = {
            Avatar       	= 100,
			AvatarExpWidth	= 10,
			AvatarPadding	= 10,
            HealthBarH   	= 15,
            HealthBarW   	= 200,
            ArmorBarH    	= 8,
            ArmorBarW    	= 200,
        },
        Margin              = 10,
        AvatarCornerOffset  = 20,
        AnimTime            = 0.2,
    },
    Team = {
        MaxPlayers = 5,
    },
	Notify = {
		MaxNotification 	= 5,
		Spacing 			= 10,
		SlideSpeed 			= 8,
	},
	Motion = {
		EnableBHop	        = true,
        WalkSpeed           = 125,
        RunSpeed            = 250,
        JumpPower           = 200
    },
	AllowedTools = {
        ["weld"]        = true,
        ["button"]      = true,
        ["lamp"]        = true,
        ["nocollide"]   = true,
        ["camera"]      = true,
        ["colour"]      = true,
        ["material"]    = true,
        ["remover"]     = true
    },
	PlayerLoadout = {
        "weapon_physcannon",
        "gmod_tool",
        "hands",
        "weapon_physgun",
        "gmod_camera"
    },
	NameTag = {
        MaxDist   = 800,
        FadeDist  = 50,
        FadeSpeed = 12,
        Scale     = 0.18,
    },
	Fog = {
		Enabled     = true,
		Mode        = MATERIAL_FOG_LINEAR,
		Start       = 1500,
		["End"]     = 3000,
		MaxDensity  = 1,
		Color       = Color(191, 191, 191),
	},
	Props = {
        ["building_blocks"] = {
            {hp = 200, "models/props_phx/construct/metal_plate1.mdl"},
            {hp = 350, "models/props_phx/construct/metal_plate1x2.mdl"},
            {hp = 600, "models/props_phx/construct/metal_plate2x2.mdl"},
            {hp = 1200, "models/props_phx/construct/metal_plate4x4.mdl"},
            {hp = 400, "models/props_phx/construct/metal_tube.mdl"},
            {hp = 750, "models/props_phx/construct/metal_tubex2.mdl"},
            {hp = 500, "models/props_phx/construct/metal_plate_curve180.mdl"},
            {hp = 800, "models/props_phx/construct/metal_plate_curve360.mdl"},
            {hp = 1000, "models/props_phx/construct/metal_dome360.mdl"},

            {hp = 60, "models/props_phx/construct/plastic/plastic_panel1x1.mdl"},
            {hp = 100, "models/props_phx/construct/plastic/plastic_panel1x2.mdl"},
            {hp = 180, "models/props_phx/construct/plastic/plastic_panel2x2.mdl"},
            {hp = 400, "models/props_phx/construct/plastic/plastic_panel4x4.mdl"},
            
            {hp = 50, "models/hunter/blocks/cube025x025x025.mdl"},
            {hp = 200, "models/hunter/blocks/cube025x150x025.mdl"},
            {hp = 450, "models/hunter/blocks/cube025x4x025.mdl"},
            {hp = 850, "models/hunter/blocks/cube025x8x025.mdl"},
            {hp = 300, "models/hunter/blocks/cube075x075x075.mdl"},
            {hp = 600, "models/hunter/blocks/cube1x150x1.mdl"},
            
            {hp = 700, "models/mechanics/solid_steel/i_beam_4.mdl"},
            {hp = 550, "models/mechanics/solid_steel/steel_beam45_3.mdl"},
            {hp = 1000, "models/mechanics/solid_steel/steel_beam45_8.mdl"},
            {hp = 900, "models/mechanics/solid_steel/step_beam_32.mdl"},
            {hp = 800, "models/mechanics/solid_steel/sheetmetal_box90_4.mdl"}
        },

        ["doors_and_windows"] = {
            {hp = 500, "models/props_borealis/borealis_door001a.mdl"},          
            {hp = 700, "models/props_wasteland/prison_celldoor001b.mdl"},       
            {hp = 400, "models/props_doors/door03_slotted_left.mdl"},           
            {hp = 150, "models/props_c17/door01_left.mdl"},                     
            {hp = 250, "models/props_c17/door02_double.mdl"},                   
            {hp = 1500, "models/props_lab/blastdoor001a.mdl"},                  
            {hp = 1500, "models/props_lab/blastdoor001b.mdl"},                  
            {hp = 120, "models/props_interiors/VendingMachineSoda01a_door.mdl"},
            
            {hp = 30, "models/props_phx/construct/windows/window1x1.mdl"},
            {hp = 45, "models/props_phx/construct/windows/window1x2.mdl"},
            {hp = 75, "models/props_phx/construct/windows/window2x2.mdl"},
            {hp = 150, "models/props_phx/construct/windows/window4x4.mdl"}
        },

        ["defense_and_barricades"] = {
            {hp = 1500, "models/props_c17/concrete_barrier001a.mdl"},           
            {hp = 250, "models/props_c17/fence01a.mdl"},                        
            {hp = 250, "models/props_c17/fence01b.mdl"},
            {hp = 300, "models/props_c17/fence03a.mdl"},
            {hp = 900, "models/props_combine/combine_barricade_short02a.mdl"},  
            {hp = 100, "models/props_borealis/bluebarrel001.mdl"},              
            {hp = 180, "models/props_c17/oildrum001.mdl"},                      
            {hp = 40, "models/props_c17/oildrum001_explosive.mdl"}              
        },

        ["interior_and_environment"] = {
            {hp = 150, "models/props_c17/bench01a.mdl"},                        
            {hp = 40, "models/nova/chair_plastic01.mdl"},                       
            {hp = 70, "models/nova/chair_wood01.mdl"},                          
            {hp = 250, "models/props_c17/FurnitureCouch001a.mdl"},              
            {hp = 250, "models/props_c17/FurnitureCouch002a.mdl"},             
            {hp = 300, "models/props_c17/display_cooler01a.mdl"},               
            {hp = 350, "models/props_c17/FurnitureWashingmachine001a.mdl"},     
            {hp = 350, "models/props_c17/furnitureStove001a.mdl"},              
            {hp = 600, "models/props_interiors/VendingMachineSoda01a.mdl"},     
            {hp = 450, "models/props_wasteland/controlroom_storagecloset001a.md"},
            {hp = 300, "models/props_wasteland/kitchen_counter001a.mdl"},       
            {hp = 600, "models/props_c17/FurnitureBathtub001a.mdl"},           
            {hp = 600, "models/props_interiors/BathTub01a.mdl"},                
            {hp = 50, "models/props_junk/PlasticCrate01a.mdl"},                 
            {hp = 1100, "models/props_junk/TrashDumpster01a.mdl"},              
            {hp = 500, "models/props_borealis/mooring_cleat01.mdl"},            
            {hp = 400, "models/props_c17/gravestone003a.mdl"},                  
            {hp = 350, "models/props_c17/gravestone_coffinpiece001a.mdl"}       
        }
    },
    Shop = {
        ["cat_1"] = {
            ["money_printer_1"] = {
                ent = "item_healthkit",
                model = "models/props_interiors/VendingMachineSoda01a.mdl",
                price = 1000,
                lvl = 1,
                max = 2,
                vip = false,
            },
        }
    },
	PlayerGroups = {
        ["superadmin"] = {
            PayDayMultiplier = 3.0,
            DropMoneyMultiplier = 0.025,
			PrefixText = "Owner",
			PrefixIcon = "icon16/shield.png",
            Privilege = true
        },
        ["admin"] = {
            PayDayMultiplier = 2.5,
            DropMoneyMultiplier = 0.03,
			PrefixText = "Admin",
			PrefixIcon = "icon16/ruby.png",
        },
        ["vip"] = {
            PayDayMultiplier = 2.0,
            DropMoneyMultiplier = 0.05,
			PrefixText = "VIP",
			PrefixIcon = "icon16/star.png",
            Privilege = true,
        },
        ["user"] = {
            PayDayMultiplier = 1.0,
        },
    },
	Economy = {
		Currency 				    = "$",
		StartMoney 				    = 5000,
		PayDayInterval    		    = 300,
		PayDayDefaultMin  		    = 500,
		PayDayDefaultMax  		    = 800,
		PayDayDefaultMultiplier     = 1,
        SafeMoneyAmountOnDeath      = 5000,
        DropMoneyMultiplierDefault  = 0.1
	},
}