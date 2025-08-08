Config = {}

-- Kdo smí používat menu (ESX group). Přidej/odeber dle potřeby.
Config.AllowedGroups = { 'admin', 'owner' }

-- Discord webhook pro logy (ponech prázdné pro vypnutí)
Config.DiscordWebhook = 'YOURWEBHOOK'
Config.DiscordWebhookDelete = 'YOURWEBHOOK'
Config.DiscordWebhookEdit = 'YOURWEBHOOK'

-- Název příkazu, který otevře menu
Config.Command = 'vehmenu'
Config.CommandDelete = 'vehdel'
Config.CommandPlate = 'vehplate'

-- Validace SPZ
Config.PlateMaxLength = 8                -- klasika GTA 8 znaků
Config.PlateAllowedPattern = '^[A-Z0-9 %-%_]+$'  -- povolíme A-Z, 0-9, mezera, -, _
Config.PlateBlacklist = {
    -- Anglické vulgarismy
    'fuck', 'shit', 'bitch', 'cunt', 'asshole', 'motherfucker', 'fucker', 'whore', 'slut', 'cock', 'dick',
    'pussy', 'nigger','negr', 'neger','negger','neggr','n1gger', 'nigga', 'retard', 'faggot', 'fag', 'gaylord', 'tranny', 'cum', 'jizz',
    'bollocks', 'wanker', 'tosser', 'prick', 'arse', 'blowjob', 'handjob', 'anal', 'vagina', 'penis',
    'masturbate', 'masturbation', 'rapist', 'rape', 'pedophile', 'pedo', 'childmolester', 'incest', 'beastiality',

    -- Česká sprostá a urážlivá slova
    'kurva', 'píča', 'piča', 'čurák', 'curak', 'kokot', 'zmrd', 'zmrde', 'sráč', 'srac', 'prdel', 'hovno',
    'debile', 'debil', 'kripl', 'buzna', 'buzerant', 'šuk', 'suk', 'šukat', 'sukat', 'mrdat', 'mrdka', 'jebat',
    'jeb', 'mrd', 'šoust', 'soustat', 'šoustat', 'šoustač', 'soustač',

    -- Rasismus / etnické urážky
    'hitler', 'nazi', 'kkk', 'heil', 'gasjews', 'jewkiller', 'jewhater', 'islamhater', 'muslimhater',
    'terrorist', 'isis', 'taliban', 'whitepower', 'white power', 'blacksout', 'killblacks', 'killjews',

    -- Politicky citlivé / extremistické
    'putin', 'stalin', 'lenin', 'trump2024', 'maga', 'fuckbiden', 'killtrump', 'killbiden',

    -- Náboženské urážky
    'f**kjesus', 'godhater', 'allahhater', 'f**kmohammed', 'jesushater',

    -- Sexuální obsah
    '69', 'xxx', 'porn', 'porno', 'sex', 'sexy', 'orgy', 'orgasm', 'fetish', 'bdsm', 'gangbang', 'blowjob',
    'handjob', 'deepthroat', 'milf', 'teen', 'incest', 'hentai', 'cumshot', 'facial', 'analsex', 'rimjob',
    'fisting',

    -- Ostatní urážky / toxické fráze
    'loser', 'noob', 'idiot', 'kys', 'kill yourself', 'die', 'suicide', 'hang yourself',

    -- Obecné nebezpečné fráze
    'kill', 'murder', 'bomb', 'terror', 'terrorist', 'execute', 'gun', 'shoot', 'sniper'
}



-- Migrace inventáře (ox_inventory)
-- Pokud máš jiný název tabulky, změň zde:
Config.InventorySystem = 'ox_inventory'
Config.OxInventoryTable = 'ox_inventory' -- v novějších verzích je to často 'ox_inventory'



-- Zprávy (CZ)
Config.Locale = {
    no_perm = 'Nemáš oprávnění k použití této funkce.',
    not_in_vehicle = 'Musíš sedět ve vozidle.',
    open_menu = 'Otevřít Vehicle Manager',
    personal = 'Přidat do osobní garáže',
    society = 'Přidat do frakční (society) garáže',
    enter_target = 'Zadej ID hráče, kterému to připíšeme',
    enter_society = 'Zadej society (např. police, ambulance)',
    enter_label = 'Zadej název vozidla do firemní garáže',
    sent = 'Hotovo, vozidlo bylo zapsáno.',
    invalid_id = 'Neplatné ID hráče.',
    player_offline = 'Cílový hráč není online.',
    db_error = 'Chyba ukládání do databáze.',
    cancelled = 'Akce zrušena.',
}

Config.VehicleTypeMap = {
    default = 'car',
    [8]  = 'car',      -- Motorcycles
    [14] = 'boat',      -- Boats
    [15] = 'air',      -- Helicopters
    [16] = 'air',     -- Planes
}
