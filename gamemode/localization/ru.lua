BW.Lang["ru"] = {
	Weapons = {
		["hands"] = "Руки"
	},
	Notify = {
		Info = "Информация",
		Warn = "Предупреждение",
		Error = "Ошибка",
		Success = "Успех",
		Hint = "Совет",
	},
	Team = {
		NoTeam = "Гражданский",
		TeamDisbanded = "Ваша команда была распущена!",
		TeamCreate = "Команда '%s' была успешно создана!",
		TeamWrongPass = "Вы указали неверный пароль!",
		TeamKick = "Вы были выгнаны из команды!",
		TeamLeave = "Вы покинули свою команду!",
		AlreadyInTeam = "Вы уже состоите в команде!",
		LeaveFirst = "Сначала покиньте текущую команду!",
		Full = "Команда переполнена!",
		TeamJoin = "Вы успешно зашли в команду: %s!",
		KickSuccess = "Игрок %s был исключен из команды.",
		KickFailed = "Не удалось исключить игрока!",

		MenuTitle = "Команды",
		MenuTeamTab = "Список команд",
		MenuControlTab = "Управление",
		MenuControlNewTeamTitle = "Создание новой команды",
		MenuControlInputName = "Название команды",
		MenuControlInputPass = "Пароль (оставьте пустым для открытой)",
		MenuControlInputColor = "Цвет команды:",
		MenuControlCreateBtn = "Создать команду",
		MenuControlWarnBlankName = "Введите название команды!",
		MenuControlInTeamTitle = "Вы состоите в команде",
		MenuControlLeaveBtn = "Покинуть команду",

		MenuControlDisbandBtn = "Распустить команду",
		MenuControlDisbandTitle = "Ликвидация команды",
		MenuControlDisbandText = "Вы уверены, что хотите распустить команду? Это действие необратимо.",
		MenuControlDisbandYes = "Да",
		MenuControlDisbandNo = "Нет",

		MenuBrowseNoTeamPlayers = "В команде нет игроков",

		MenuBrowseLeaveBtn = "Покинуть",
		MenuBrowseLeaveTitle = "Выход из команды",
		MenuBrowseLeaveText = "Вы уверены, что хотите выйти из команды?",
		MenuBrowseLeaveYes = "Да",
		MenuBrowseLeaveNo = "Нет",

		MenuBrowseDisbandBtn = "Распустить",
		MenuBrowseDisbandTitle = "Ликвидация команды",
		MenuBrowseDisbandText = "Вы уверены, что хотите распустить команду? Это действие необратимо.",
		MenuBrowseDisbandYes = "Да",
		MenuBrowseDisbandNo = "Нет",

		MenuBrowseJoinBtn = "Войти",
		MenuBrowseJoinTitle = "Вход в команду",
		MenuBrowseJoinText = "Введите пароль команды:",
		MenuBrowseJoinYes = "ОК",
		MenuBrowseJoinNo = "Отмена",

		MenuBrowseKickBtn = "Выгнать",
		MenuBrowseKickTitle = "Выгнать игрока",
		MenuBrowseKickText = "Вы уверены, что хотите исключить %s из команды?",
		MenuBrowseKickYes = "Да",
		MenuBrowseKickNo = "Нет",
	},
	Scoreboard = {
		Nick = "Игрок",
		Team = "Команда",
		Kills = "Убийства",
		Deaths = "Смерти",
		Reputation = "Репутация",
		Ping = "Пинг",
	},
	SpawnMenu = {
		PropsTabName = "Пропы",
		ShopTabName = "Магазин",
		LimitProp = "Вы достигли лимита пропов!",
		BlockProp = "Этот предмет запрещен для спавна!",
		CommandDisabled = "Команда %s отключена на сервере!"
	},
	PropsCategory = {
        ["building_blocks"]         = "Строительные блоки",
        ["doors_and_windows"]       = "Двери и Окна",
        ["defense_and_barricades"]   = "Защита и Баррикады",
        ["interior_and_environment"] = "Интерьер и Окружение",
    },
	Buddies = {
		CatName = "Друзья",
		NoPlayers = "На сервере нет других игроков!",
		RemoveFriend = "Удалить",
		AddFriend = "Доверять",
	},
	HUD = {
		OwnerUnknown = "Неизвестно",
		OwnerLabel = "Владелец",
	},
	ShopCategory = {
        ["cat_1"]       = "Денежные принтеры",
    },
    ShopItems = {
        ["money_printer_1"] = "Начальный принтер",
    },
	Command = {
		NoPermission = "У вас нет прав для использования этой команды.",
		DropMoney = {
			Hint = "Использование: /dropmoney [сумма]",
			NoMoney = "У вас недостаточно денег!",
			Success = "Вы выбросили %s%s!",
		},
		Drop = {
			Error = "Вы не можете выбросить это оружие!",
			Success = "Вы выбросили %s!",
		},
	},
	Entity = {
		Money = "Вы подобрали %s%s!"
	},
	Advert = {
		JoinText = "<color=95,250,95>[BaseWars]</color> <color=255,165,0>Игрок</color> <color=0,255,255>%s</color> <color=255,165,0>подключился к серверу! (SteamID:</color> <color=0,255,255>%s</color><color=255,165,0>, Последний визит:</color> <color=0,255,255>%s</color><color=255,165,0>)</color>",
		LeaveText = "<color=95,250,95>[BaseWars]</color> <color=255,165,0>Игрок</color> <color=0,255,255>%s</color> <color=255,165,0>вышел с сервера! (SteamID:</color> <color=0,255,255>%s</color><color=255,165,0>)</color>",
	},
	Chat = {
		TeamText = "КОМАНДА",
		DeadText = "УМЕР",
	},
	Shop = {
		Price = "Цена:",
		Free = "Бесплатно",
		Level = "Требуемый уровень: ",
		Max = "Максимально: ",
		SpawnError = "Ошибка сервера: неверна конфигурация объекта!",
		VIP = "★ ТОЛЬКО ДЛЯ VIP ★",
		VIPAlert = "Этот предмет доступен только для VIP!",
		LvlAlert = "Недостаточный уровень!",
		MaxLimitAlert = "Вы достигли макс. количества! (Макс.: %s)",
		MoneyAlert = "Недостаточно средств!",
		BoughtSuccess = "Вы успешно купили:",
	},
	WeaponSelectorTitle = "Арсенал",
	PayDay = "Зарплата! Вы получили %s%s!",
	MoneyDropOnDeath = "Упс... Вы потеряли %s%s!"
}