fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Petrino + CHATGPT'
description 'Správce vozidel pro ESX s ox_lib UI: přidávání do osobní/frakční garáže, mazání a změna SPZ (s blacklistem) včetně Discord logů a zachování inventáře (trunk/glovebox). Podporuje oddělené webhooky pro přidávání a mazání, oprávnění podle ESX group a validační pravidla pro SPZ.'
version '1.2.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config/config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}
