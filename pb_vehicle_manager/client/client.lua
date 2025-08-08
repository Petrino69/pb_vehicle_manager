local ESX = exports['es_extended']:getSharedObject()

-- === HELPERY ===
local function getVehicleTypeForDB(vehicle)
    local class = GetVehicleClass(vehicle)
    local t = Config.VehicleTypeMap[class]
    if not t then t = Config.VehicleTypeMap.default or 'car' end
    return t
end

local function isAllowed()
    return lib.callback.await('pb_veh:isAllowed', false)
end

-- === MENU PŘIDÁVÁNÍ ===
local function openAddMenu()
    if not isAllowed() then
        lib.notify({type='error', description=Config.Locale.no_perm}); return
    end
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        lib.notify({type='error', description=Config.Locale.not_in_vehicle}); return
    end

    lib.registerContext({
        id = 'pb_veh_add_main',
        title = Config.Locale.open_menu,
        options = {
            {
                title = Config.Locale.personal,
                icon = 'user',
                onSelect = function()
                    local input = lib.inputDialog(Config.Locale.personal, {
                        { type='number', label=Config.Locale.enter_target, placeholder='např. 12', required=true, min=1 }
                    })
                    if not input then
                        lib.notify({type='inform', description=Config.Locale.cancelled}); return
                    end
                    local targetId = tonumber(input[1])
                    if not targetId or targetId < 1 then
                        lib.notify({type='error', description=Config.Locale.invalid_id}); return
                    end
                    local props = ESX.Game.GetVehicleProperties(veh)
                    local vtype = getVehicleTypeForDB(veh)
                    TriggerServerEvent('pb_veh:addPersonalVehicle', targetId, props, vtype)
                end
            },
            {
                title = Config.Locale.society,
                icon = 'building',
                onSelect = function()
                    local input = lib.inputDialog(Config.Locale.society, {
                        { type='input', label=Config.Locale.enter_society, placeholder='police / ambulance / mechanic', required=true, min=2 },
                        { type='input', label=Config.Locale.enter_label, placeholder='Název ve firemní garáži', required=true, min=2, max=48 },
                    })
                    if not input then
                        lib.notify({type='inform', description=Config.Locale.cancelled}); return
                    end
                    local society = (input[1] or ''):gsub('%s+','')
                    local label = input[2] or ''
                    if society == '' or label == '' then
                        lib.notify({type='error', description='Vyplň prosím všechna pole.'}); return
                    end
                    local props = ESX.Game.GetVehicleProperties(veh)
                    local vtype = getVehicleTypeForDB(veh)
                    props.customLabel = label
                    TriggerServerEvent('pb_veh:addSocietyVehicle', society, label, props, vtype)
                end
            }
        }
    })
    lib.showContext('pb_veh_add_main')
end

-- === MENU MAZÁNÍ  ===
local function openDeleteMenu()
    if not isAllowed() then
        lib.notify({type='error', description=Config.Locale.no_perm}); return
    end

    lib.registerContext({
        id = 'pb_veh_del_main',
        title = 'Smazat vozidlo z garáže',
        options = {
            {
                title = 'Osobní garáž hráče',
                icon = 'user-minus',
                onSelect = function()
                    local input = lib.inputDialog('Osobní garáž', {
                        { type='number', label='Zadej ID hráče', placeholder='např. 12', required=true, min=1 }
                    })
                    if not input then
                        lib.notify({type='inform', description=Config.Locale.cancelled}); return
                    end
                    local targetId = tonumber(input[1])
                    if not targetId or targetId < 1 then
                        lib.notify({type='error', description=Config.Locale.invalid_id}); return
                    end

                    -- Získat list aut hráče
                    local items = lib.callback.await('pb_veh:getPlayerVehicles', false, targetId)
                    if not items or #items == 0 then
                        lib.notify({type='inform', description='Hráč nemá žádná vozidla.'}); return
                    end

                    local opts = {}
                    for _, v in ipairs(items) do
                        local title = ('[%s] %s'):format(v.plate or '???', v.label or (v.model or 'model'))
                        table.insert(opts, {
                            title = title,
                            description = v.desc or '',
                            icon = 'car',
                            onSelect = function()
                                local alert = lib.alertDialog({
                                    header = 'Smazat vozidlo?',
                                    content = ('Chceš smazat vozidlo se SPZ **%s** hráči ID **%s**?\nTato akce je nevratná.'):format(v.plate, targetId),
                                    centered = true,
                                    cancel = true,
                                })
                                if alert == 'confirm' then
                                    TriggerServerEvent('pb_veh:deletePersonalVehicle', targetId, v.plate)
                                else
                                    lib.showContext('pb_veh_del_player_list')
                                end
                            end
                        })
                    end

                    lib.registerContext({
                        id = 'pb_veh_del_player_list',
                        title = ('Vozidla hráče ID %s'):format(targetId),
                        options = opts
                    })
                    lib.showContext('pb_veh_del_player_list')
                end
            },
            {
                title = 'Frakční (society) garáž',
                icon = 'building',
                onSelect = function()
                    local input = lib.inputDialog('Frakční garáž', {
                        { type='input', label='Zadej society (např. police)', placeholder='police', required=true, min=2 }
                    })
                    if not input then
                        lib.notify({type='inform', description=Config.Locale.cancelled}); return
                    end
                    local society = (input[1] or ''):gsub('%s+','')
                    if society == '' then
                        lib.notify({type='error', description='Neplatná society.'}); return
                    end

                    local items = lib.callback.await('pb_veh:getSocietyVehicles', false, society)
                    if not items or #items == 0 then
                        lib.notify({type='inform', description='Tato society nemá žádná vozidla.'}); return
                    end

                    local opts = {}
                    for _, v in ipairs(items) do
                        local title = ('[%s] %s'):format(v.plate or '???', v.label or (v.model or 'model'))
                        table.insert(opts, {
                            title = title,
                            icon = 'car',
                            onSelect = function()
                                local alert = lib.alertDialog({
                                    header = 'Smazat vozidlo?',
                                    content = ('Chceš smazat vozidlo se SPZ **%s** ze society **%s**?\nTato akce je nevratná.'):format(v.plate, society),
                                    centered = true,
                                    cancel = true,
                                })
                                if alert == 'confirm' then
                                    TriggerServerEvent('pb_veh:deleteSocietyVehicle', society, v.plate)
                                else
                                    lib.showContext('pb_veh_del_society_list')
                                end
                            end
                        })
                    end

                    lib.registerContext({
                        id = 'pb_veh_del_society_list',
                        title = ('Vozidla society %s'):format(society),
                        options = opts
                    })
                    lib.showContext('pb_veh_del_society_list')
                end
            }
        }
    })
    lib.showContext('pb_veh_del_main')
end

-- === MENU ZMĚNA SPZ  ===
local function openPlateMenu()
    if not isAllowed() then
        lib.notify({type='error', description=Config.Locale.no_perm}); return
    end

    lib.registerContext({
        id = 'pb_veh_plate_main',
        title = 'Změnit SPZ vozidla',
        options = {
            {
                title = 'Osobní garáž hráče',
                icon = 'keyboard',
                onSelect = function()
                    local input = lib.inputDialog('Osobní garáž - změna SPZ', {
                        { type='number', label='Zadej ID hráče', placeholder='např. 12', required=true, min=1 }
                    })
                    if not input then lib.notify({type='inform', description=Config.Locale.cancelled}); return end
                    local targetId = tonumber(input[1])
                    if not targetId or targetId < 1 then lib.notify({type='error', description=Config.Locale.invalid_id}); return end

                    local items = lib.callback.await('pb_veh:getPlayerVehicles', false, targetId)
                    if not items or #items == 0 then lib.notify({type='inform', description='Hráč nemá žádná vozidla.'}); return end

                    local opts = {}
                    for _, v in ipairs(items) do
                        local title = ('[%s] %s'):format(v.plate or '???', v.label or (v.model or 'model'))
                        table.insert(opts, {
                            title = title,
                            icon = 'car',
                            onSelect = function()
                                local inp = lib.inputDialog(('Nová SPZ pro [%s]'):format(v.plate), {
                                    { type='input', label='Zadej novou SPZ', placeholder='NAPŘ. ABC 1234', required=true, min=1, max=Config.PlateMaxLength }
                                })
                                if not inp then lib.notify({type='inform', description=Config.Locale.cancelled}); return end
                                local newPlate = inp[1] or ''
                                TriggerServerEvent('pb_veh:changePlatePersonal', targetId, v.plate, newPlate)
                            end
                        })
                    end

                    lib.registerContext({
                        id = 'pb_veh_plate_player_list',
                        title = ('Vozidla hráče ID %s (zvol pro změnu SPZ)'):format(targetId),
                        options = opts
                    })
                    lib.showContext('pb_veh_plate_player_list')
                end
            },
            {
                title = 'Frakční (society) garáž',
                icon = 'keyboard',
                onSelect = function()
                    local input = lib.inputDialog('Frakční garáž - změna SPZ', {
                        { type='input', label='Zadej society (např. police)', placeholder='police', required=true, min=2 }
                    })
                    if not input then lib.notify({type='inform', description=Config.Locale.cancelled}); return end
                    local society = (input[1] or ''):gsub('%s+','')
                    if society == '' then lib.notify({type='error', description='Neplatná society.'}); return end

                    local items = lib.callback.await('pb_veh:getSocietyVehicles', false, society)
                    if not items or #items == 0 then lib.notify({type='inform', description='Tato society nemá žádná vozidla.'}); return end

                    local opts = {}
                    for _, v in ipairs(items) do
                        local title = ('[%s] %s'):format(v.plate or '???', v.label or (v.model or 'model'))
                        table.insert(opts, {
                            title = title,
                            icon = 'car',
                            onSelect = function()
                                local inp = lib.inputDialog(('Nová SPZ pro [%s]'):format(v.plate), {
                                    { type='input', label='Zadej novou SPZ', placeholder='NAPŘ. ABC 1234', required=true, min=1, max=Config.PlateMaxLength }
                                })
                                if not inp then lib.notify({type='inform', description=Config.Locale.cancelled}); return end
                                local newPlate = inp[1] or ''
                                TriggerServerEvent('pb_veh:changePlateSociety', society, v.plate, newPlate)
                            end
                        })
                    end

                    lib.registerContext({
                        id = 'pb_veh_plate_society_list',
                        title = ('Vozidla society %s (zvol pro změnu SPZ)'):format(society),
                        options = opts
                    })
                    lib.showContext('pb_veh_plate_society_list')
                end
            }
        }
    })
    lib.showContext('pb_veh_plate_main')
end





-- === PŘÍKAZY ===
RegisterCommand(Config.Command, function() openAddMenu() end, false)         -- přidávání
RegisterCommand(Config.CommandDelete, function() openDeleteMenu() end, false) -- mazání
RegisterCommand(Config.CommandPlate, function() openPlateMenu() end, false) -- Příkaz pro změnu SPZ

RegisterNetEvent('pb_veh:notify', function(kind, msg)
    lib.notify({ type = kind or 'inform', description = msg or '' })
end)
