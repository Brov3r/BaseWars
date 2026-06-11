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
	MapZone = {
		DangerZone = "Вы вошли в зараженную зону!"
	},
	SpawnMenu = {
		PropsTabName = "Пропы",
		ShopTabName = "Магазин",
		RulesTabName = "Правила",
		FAQTabName = "FAQ",
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
		WorldText = "Мир"
	},
	ShopCategory = {
        ["cat_1"]       = "Денежные принтеры",
    },
    ShopItems = {
        ["money_printer_1"] = "Начальный принтер",
    },
	Command = {
		NoPermission = "У вас нет прав для использования этой команды.",
		Cooldown = "Подождите %s сек. перед повторным использованием.",
		DropMoney = {
			Hint = "Использование: /dropmoney [сумма]",
			NoMoney = "У вас недостаточно денег!",
			Success = "Вы выбросили %s%s!",
		},
		Report = {
			Hint = "Использование: /report [текст]",
			TooLong = "Ваше сообщение слишком длинное! Не более 500 символов!",
			DbError = "При отправке сообщения произошла ошибка. Попробуйте еще раз позже.",
			Success = "Ваше сообщение было успешно отправлено администраторам!",
			AdminMsg = "<#5FF05F>[REPORT] <#FFA500>Игрок <#00FFFF>%s <#FFA500>(<#00FFFF>%s<#FFA500>) отправил репорт: <#00FFFF>%s",
		},
		Drop = {
			Error = "Вы не можете выбросить это оружие!",
		},
	},
	Entity = {
		Money = "Вы подобрали %s%s!"
	},
	Advert = {
		JoinText = "<#5FF05F>[BaseWars] <#FFA500>Игрок <#00FFFF>%s <#FFA500>подключился к серверу! (SteamID: <#00FFFF>%s<#FFA500>)",
		LeaveText = "<#5FF05F>[BaseWars] <#FFA500>Игрок <#00FFFF>%s <#FFA500>вышел с сервера! (SteamID: <#00FFFF>%s<#FFA500>)",
		DelayMsg = {
			Msg1 = "<#5FF05F>[BaseWars] <#FFA500>Мы делаем сервер лучше каждый день! Есть крутая идея или нашли баг? Расскажите нам через <#00FFFF>/report",
			Msg2 = "<#5FF05F>[BaseWars] <#FFA500>Новичок на проекте? Не теряйся! Изучи FAQ и правила в меню на клавишу <#00FFFF>Q <#FFA500>— так играть будет гораздо приятнее.",
			Msg3 = "<#5FF05F>[BaseWars] <#FFA500>В BaseWars веселее в компании! Зови друзей, объединяйтесь в кланы и захватывайте этот мир вместе.",
		},
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