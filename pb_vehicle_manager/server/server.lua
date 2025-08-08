local ESX = exports['es_extended']:getSharedObject()

-- ==== PERMS CALLBACK ====
lib.callback.register('pb_veh:isAllowed', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    local group = xPlayer.getGroup()
    for _, g in ipairs(Config.AllowedGroups) do
        if g == group then return true end
    end
    return false
end)

-- ==== ID HELPERS ====
local function getIds(src)
    local ids = GetPlayerIdentifiers(src)
    local out = { discord = 'N/A', steam = 'N/A', license = 'N/A' }
    for _, id in ipairs(ids) do
        if id:sub(1,8) == 'discord:' then
            out.discord = id:sub(9)
        elseif id:sub(1,6) == 'steam:' then
            out.steam = id:sub(7)
        elseif id:sub(1,8) == 'license:' then
            out.license = id:sub(9)
        end
    end
    return out
end

local function normalizePlate(p)
    if not p then return '' end
    p = (ESX and ESX.Math and ESX.Math.Trim and ESX.Math.Trim(p)) or p:gsub('^%s+',''):gsub('%s+$','')
    p = p:upper()
    return p
end

local function isPlateAllowed(plate)
    if not plate or plate == '' then return false, 'Prázdná SPZ.' end
    if #plate > (Config.PlateMaxLength or 8) then
        return false, ('Maximální délka SPZ je %s znaků.'):format(Config.PlateMaxLength or 8)
    end
    local ok = plate:match(Config.PlateAllowedPattern or '^[A-Z0-9 ]+$')
    if not ok then
        return false, 'SPZ obsahuje nepovolené znaky.'
    end
    local low = plate:lower()
    if Config.PlateBlacklist then
        for _, bad in ipairs(Config.PlateBlacklist) do
            if bad ~= '' and low:find(bad:lower(), 1, true) then
                return false, 'SPZ obsahuje zakázaný výraz.'
            end
        end
    end
    return true
end

local function renameVehicleStashes(oldPlate, newPlate)
    if Config.InventorySystem ~= 'ox_inventory' then return end

    local tbl = Config.OxInventoryTable or 'ox_inventory'
    local names = {
        { old = ('glovebox:%s'):format(oldPlate), new = ('glovebox:%s'):format(newPlate) },
        { old = ('trunk:%s'):format(oldPlate),    new = ('trunk:%s'):format(newPlate)    },
    }

    for _, n in ipairs(names) do
        local ok, err = pcall(function()
            exports.oxmysql:executeSync(('UPDATE `%s` SET `name` = ? WHERE `name` = ?'):format(tbl), { n.new, n.old })
        end)
        if not ok then
            print(('[pb_veh] WARN: rename stash %s -> %s selhalo (%s)'):format(n.old, n.new, tostring(err)))
        end
    end
end

-- ==== DISCORD LOGS ====
local function sendDiscordEmbed(embed, action)
    local webhook = Config.DiscordWebhook
    if action == 'delete' and Config.DiscordWebhookDelete and Config.DiscordWebhookDelete ~= '' then
        webhook = Config.DiscordWebhookDelete
    elseif action == 'edit' and Config.DiscordWebhookEdit and Config.DiscordWebhookEdit ~= '' then
        webhook = Config.DiscordWebhookEdit
    end
    if not webhook or webhook == '' then return end

    local payload = { username = 'Vehicle Manager', embeds = {embed} }
    PerformHttpRequest(webhook, function() end, 'POST', json.encode(payload), {['Content-Type']='application/json'})
end

local function fmtUserBlock(title, name, src, ids)
    local lines = {
        ('**Jméno:** %s'):format(name or 'Unknown'),
        ('**Server ID:** %s'):format(src or 'N/A'),
        ('**Discord:** %s'):format(ids.discord ~= 'N/A' and ('<@%s> (`%s`)'):format(ids.discord, ids.discord) or 'N/A'),
        ('**Steam:** `%s`'):format(ids.steam),
        ('**License:** `%s`'):format(ids.license)
    }
    return { name = title, value = table.concat(lines, '\n'), inline = true }
end

local function fmtVehicleBlock(propsOrRow, vtype, plateOverride)
    local plate = plateOverride or propsOrRow.plate
    local model, label
    if propsOrRow.vehicle then
        local ok, data = pcall(json.decode, propsOrRow.vehicle)
        if ok and data then
            model = data.model
            label = data.customLabel
        end
    elseif propsOrRow.model or propsOrRow.customLabel then
        model = propsOrRow.model
        label = propsOrRow.customLabel
    elseif type(propsOrRow) == 'table' then
        model = propsOrRow.model
        label = propsOrRow.customLabel
        plate = propsOrRow.plate or plate
    end

    local lines = {
        ('**SPZ:** `%s`'):format(plate or 'N/A'),
        ('**Model:** `%s`'):format(model or 'unknown'),
        ('**Typ:** `%s`'):format(vtype or 'car')
    }
    if label then table.insert(lines, ('**Název:** %s'):format(label)) end
    return { name = 'Vozidlo', value = table.concat(lines, '\n'), inline = true }
end

local function baseEmbed(title, color)
    return { title = title or 'Vehicle Log', color = color or 5793266, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
             footer = { text = os.date('%d.%m.%Y %H:%M:%S') } }
end

local function ensureAllowed(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local group = xPlayer.getGroup()
    for _, g in ipairs(Config.AllowedGroups) do
        if g == group then return true end
    end
    return false
end

-- ======= PŘIDÁVÁNÍ – OSOBNÍ =======
RegisterNetEvent('pb_veh:addPersonalVehicle', function(targetId, vehicleProps, vtype)
    local src = source
    if not ensureAllowed(src) then TriggerClientEvent('pb_veh:notify', src, 'error', Config.Locale.no_perm); return end

    local xTarget = ESX.GetPlayerFromId(tonumber(targetId) or -1)
    if not xTarget then TriggerClientEvent('pb_veh:notify', src, 'error', Config.Locale.player_offline); return end

    local plate = vehicleProps and vehicleProps.plate or nil
    if not plate or plate == '' then TriggerClientEvent('pb_veh:notify', src, 'error', 'Neplatná SPZ.'); return end

    local vehJson = json.encode(vehicleProps)
    local vtypeDb = vtype or 'car'

    exports.oxmysql:insert(
        'INSERT INTO owned_vehicles (owner, plate, vehicle, type) VALUES (?, ?, ?, ?)',
        { xTarget.identifier, plate, vehJson, vtypeDb },
        function(insertId)
            if not insertId then TriggerClientEvent('pb_veh:notify', src, 'error', Config.Locale.db_error); return end

            TriggerClientEvent('pb_veh:notify', src, 'success', Config.Locale.sent)
            TriggerClientEvent('pb_veh:notify', xTarget.source, 'success', ('Do garáže ti bylo přidáno vozidlo [%s].'):format(plate))

            local adminIds, targetIds = getIds(src), getIds(xTarget.source)
            local embed = baseEmbed('🚗 Přidáno osobní vozidlo', 3447003)
            embed.fields = {
                fmtUserBlock('👮 Admin', GetPlayerName(src), src, adminIds),
                fmtUserBlock('🎯 Cíl (hráč)', GetPlayerName(xTarget.source), xTarget.source, targetIds),
                fmtVehicleBlock(vehicleProps, vtypeDb, plate),
                { name='Databáze', value=('**Owner Ident:** `%s`\n**Tabulka:** `owned_vehicles`'):format(xTarget.identifier), inline=false }
            }
            sendDiscordEmbed(embed, 'add')
        end
    )
end)

-- ======= PŘIDÁVÁNÍ – SOCIETY =======
RegisterNetEvent('pb_veh:addSocietyVehicle', function(society, label, vehicleProps, vtype)
    local src = source
    if not ensureAllowed(src) then TriggerClientEvent('pb_veh:notify', src, 'error', Config.Locale.no_perm); return end
    society = tostring(society or ''):gsub('%s+',''); if society == '' then TriggerClientEvent('pb_veh:notify', src, 'error', 'Neplatná society.'); return end

    local plate = vehicleProps and vehicleProps.plate or nil
    if not plate or plate == '' then TriggerClientEvent('pb_veh:notify', src, 'error', 'Neplatná SPZ.'); return end

    vehicleProps = vehicleProps or {}; vehicleProps.customLabel = label
    local vehJson = json.encode(vehicleProps)
    local vtypeDb = vtype or 'car'

    exports.oxmysql:insert(
        'INSERT INTO owned_vehicles (owner, plate, vehicle, type, job, stored) VALUES (NULL, ?, ?, ?, ?, ?)',
        { plate, vehJson, vtypeDb, society, 1 },
        function(insertId)
            if not insertId then TriggerClientEvent('pb_veh:notify', src, 'error', Config.Locale.db_error); return end
            TriggerClientEvent('pb_veh:notify', src, 'success', Config.Locale.sent)

            local adminIds = getIds(src)
            local embed = baseEmbed('🏢 Přidáno frakční vozidlo', 65309)
            embed.fields = {
                fmtUserBlock('👮 Admin', GetPlayerName(src), src, adminIds),
                { name='🏷️ Society', value=('**Název:** `%s`\n**Label:** %s'):format(society, label or 'neuvedeno'), inline=true },
                fmtVehicleBlock(vehicleProps, vtypeDb, plate),
                { name='Databáze', value=('**Job:** `%s`\n**Tabulka:** `owned_vehicles`'):format(society), inline=false }
            }
            sendDiscordEmbed(embed, 'add')
        end
    )
end)

-- ======= CALLBACKY LISTŮ PRO MAZÁNÍ =======
lib.callback.register('pb_veh:getPlayerVehicles', function(source, targetId)
    if not ensureAllowed(source) then return {} end
    local xTarget = ESX.GetPlayerFromId(tonumber(targetId) or -1)
    if not xTarget then return {} end

    local rows = exports.oxmysql:executeSync('SELECT plate, vehicle FROM owned_vehicles WHERE owner = ? ORDER BY plate ASC', { xTarget.identifier }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local ok, data = pcall(json.decode, r.vehicle or '{}')
        local label = ok and data and (data.customLabel or ('Model '..tostring(data.model))) or nil
        table.insert(out, {
            plate = r.plate,
            model = ok and data and data.model or nil,
            label = label,
            desc = ok and data and (data.name or '') or ''
        })
    end
    return out
end)

lib.callback.register('pb_veh:getSocietyVehicles', function(source, society)
    if not ensureAllowed(source) then return {} end
    society = tostring(society or ''):gsub('%s+','')
    if society == '' then return {} end

    local rows = exports.oxmysql:executeSync(
        'SELECT plate, vehicle FROM owned_vehicles WHERE job = ? AND (owner IS NULL OR owner = "") ORDER BY plate ASC',
        { society }
    ) or {}

    local out = {}
    for _, r in ipairs(rows) do
        local ok, data = pcall(json.decode, r.vehicle or '{}')
        local label = ok and data and (data.customLabel or ('Model '..tostring(data.model))) or nil
        table.insert(out, {
            plate = r.plate,
            model = ok and data and data.model or nil,
            label = label,
            desc = ok and data and (data.name or '') or ''
        })
    end
    return out
end)

-- ======= MAZÁNÍ – OSOBNÍ =======
RegisterNetEvent('pb_veh:deletePersonalVehicle', function(targetId, plate)
    local src = source
    if not ensureAllowed(src) then
        TriggerClientEvent('pb_veh:notify', src, 'error', Config.Locale.no_perm)
        return
    end

    local xTarget = ESX.GetPlayerFromId(tonumber(targetId) or -1)
    if not xTarget then
        TriggerClientEvent('pb_veh:notify', src, 'error', Config.Locale.player_offline)
        return
    end

    local rows = exports.oxmysql:executeSync(
        'SELECT plate, vehicle, type FROM owned_vehicles WHERE owner = ? AND plate = ? LIMIT 1',
        { xTarget.identifier, plate }
    )
    if not rows or not rows[1] then
        TriggerClientEvent('pb_veh:notify', src, 'error', 'Vozidlo nenalezeno.')
        return
    end

    local ok, data = pcall(json.decode, rows[1].vehicle or '{}')
    local vtype = rows[1].type or 'car'

    exports.oxmysql:execute(
        'DELETE FROM owned_vehicles WHERE owner = ? AND plate = ?',
        { xTarget.identifier, plate },
        function(_affected)
            -- Ověření smazání SELECTem (nezávislé na návratové hodnotě execute)
            local stillThere = exports.oxmysql:executeSync(
                'SELECT 1 FROM owned_vehicles WHERE owner = ? AND plate = ? LIMIT 1',
                { xTarget.identifier, plate }
            )

            if stillThere and stillThere[1] then
                TriggerClientEvent('pb_veh:notify', src, 'error', Config.Locale.db_error)
                return
            end

            -- Notifikace
            TriggerClientEvent('pb_veh:notify', src, 'success',
                ('Smazáno vozidlo [%s] hráči ID %s.'):format(plate, xTarget.source))
            if xTarget.source then
                TriggerClientEvent('pb_veh:notify', xTarget.source, 'inform',
                    ('Vozidlo [%s] bylo odstraněno z tvojí garáže.'):format(plate))
            end

            -- Log
            local adminIds, targetIds = getIds(src), getIds(xTarget.source or src)
            local embed = baseEmbed('🗑️ Smazáno osobní vozidlo', 15158332)
            embed.fields = {
                fmtUserBlock('👮 Admin', GetPlayerName(src), src, adminIds),
                fmtUserBlock('🎯 Cíl (hráč)', GetPlayerName(xTarget.source), xTarget.source, targetIds),
                fmtVehicleBlock({
                    plate = plate,
                    model = (pcall(function() return (json.decode(rows[1].vehicle or '{}') or {}).model end)) and (json.decode(rows[1].vehicle or '{}') or {}).model or data and data.model or nil,
                    customLabel = data and data.customLabel or nil
                }, vtype, plate),
                {
                    name = 'Databáze',
                    value = ('**Owner Ident:** `%s`\n**Akce:** DELETE\n**Tabulka:** `owned_vehicles`')
                        :format(xTarget.identifier),
                    inline = false
                }
            }
            sendDiscordEmbed(embed, 'delete')
        end
    )
end)

-- ======= MAZÁNÍ – SOCIETY =======
RegisterNetEvent('pb_veh:deleteSocietyVehicle', function(society, plate)
    local src = source
    if not ensureAllowed(src) then
        TriggerClientEvent('pb_veh:notify', src, 'error', Config.Locale.no_perm)
        return
    end

    society = tostring(society or ''):gsub('%s+','')
    if society == '' then
        TriggerClientEvent('pb_veh:notify', src, 'error', 'Neplatná society.')
        return
    end

    local rows = exports.oxmysql:executeSync(
        'SELECT plate, vehicle, type FROM owned_vehicles WHERE job = ? AND (owner IS NULL OR owner = "") AND plate = ? LIMIT 1',
        { society, plate }
    )
    if not rows or not rows[1] then
        TriggerClientEvent('pb_veh:notify', src, 'error', 'Vozidlo nenalezeno.')
        return
    end

    local ok, data = pcall(json.decode, rows[1].vehicle or '{}')
    local vtype = rows[1].type or 'car'

    exports.oxmysql:execute(
        'DELETE FROM owned_vehicles WHERE job = ? AND (owner IS NULL OR owner = "") AND plate = ?',
        { society, plate },
        function(_affected)
            local stillThere = exports.oxmysql:executeSync(
                'SELECT 1 FROM owned_vehicles WHERE job = ? AND (owner IS NULL OR owner = "") AND plate = ? LIMIT 1',
                { society, plate }
            )

            if stillThere and stillThere[1] then
                TriggerClientEvent('pb_veh:notify', src, 'error', Config.Locale.db_error)
                return
            end

            -- Notifikace
            TriggerClientEvent('pb_veh:notify', src, 'success',
                ('Smazáno firemní vozidlo [%s] ze society %s.'):format(plate, society))

            -- Log
            local adminIds = getIds(src)
            local embed = baseEmbed('🗑️ Smazáno frakční vozidlo', 15158332)
            embed.fields = {
                fmtUserBlock('👮 Admin', GetPlayerName(src), src, adminIds),
                { name = '🏷️ Society', value = ('**Název:** `%s`'):format(society), inline = true },
                fmtVehicleBlock({
                    plate = plate,
                    model = data and data.model or nil,
                    customLabel = data and data.customLabel or nil
                }, vtype, plate),
                {
                    name = 'Databáze',
                    value = ('**Job:** `%s`\n**Akce:** DELETE\n**Tabulka:** `owned_vehicles`')
                        :format(society),
                    inline = false
                }
            }
            sendDiscordEmbed(embed, 'delete')
        end
    )
end)

-- ======= SPZ - OSOBNÍ =======
RegisterNetEvent('pb_veh:changePlatePersonal', function(targetId, oldPlate, newPlateRaw)
    local src = source
    if not ensureAllowed(src) then
        TriggerClientEvent('pb_veh:notify', src, 'error', Config.Locale.no_perm)
        return
    end

    local xTarget = ESX.GetPlayerFromId(tonumber(targetId) or -1)
    if not xTarget then
        TriggerClientEvent('pb_veh:notify', src, 'error', Config.Locale.player_offline)
        return
    end

    local oldP = normalizePlate(oldPlate)
    local newP = normalizePlate(newPlateRaw)
    local ok, reason = isPlateAllowed(newP)
    if not ok then
        TriggerClientEvent('pb_veh:notify', src, 'error', reason)
        return
    end

    local rows = exports.oxmysql:executeSync(
        'SELECT plate, vehicle, type FROM owned_vehicles WHERE owner = ? AND plate = ? LIMIT 1',
        { xTarget.identifier, oldP }
    )
    if not rows or not rows[1] then
        TriggerClientEvent('pb_veh:notify', src, 'error', 'Vozidlo nenalezeno.')
        return
    end

    local dup = exports.oxmysql:executeSync(
        'SELECT 1 FROM owned_vehicles WHERE plate = ? LIMIT 1',
        { newP }
    )
    if dup and dup[1] then
        TriggerClientEvent('pb_veh:notify', src, 'error', 'Tato SPZ už existuje.')
        return
    end

    local vtype = rows[1].type or 'car'
    local okj, data = pcall(json.decode, rows[1].vehicle or '{}')
    if okj and data then data.plate = newP end
    local vehJson = json.encode(data or { plate = newP })

    exports.oxmysql:execute('UPDATE owned_vehicles SET plate = ?, vehicle = ? WHERE owner = ? AND plate = ?',
        { newP, vehJson, xTarget.identifier, oldP },
        function(_aff)
            local check = exports.oxmysql:executeSync(
                'SELECT 1 FROM owned_vehicles WHERE owner = ? AND plate = ? LIMIT 1',
                { xTarget.identifier, newP }
            )
            if not check or not check[1] then
                TriggerClientEvent('pb_veh:notify', src, 'error', Config.Locale.db_error)
                return
            end

            renameVehicleStashes(oldP, newP)

            TriggerClientEvent('pb_veh:notify', src, 'success',
                ('SPZ změněna: [%s] → [%s] hráči ID %s.'):format(oldP, newP, xTarget.source))
            TriggerClientEvent('pb_veh:notify', xTarget.source, 'inform',
                ('U vozidla byla změněna SPZ: [%s] → [%s].'):format(oldP, newP))

            local adminIds, targetIds = getIds(src), getIds(xTarget.source or src)
            local embed = baseEmbed('📝 Změněna SPZ (osobní)', 15844367)
            embed.fields = {
                fmtUserBlock('👮 Admin', GetPlayerName(src), src, adminIds),
                fmtUserBlock('🎯 Cíl (hráč)', GetPlayerName(xTarget.source), xTarget.source, targetIds),
                {
                    name = 'SPZ',
                    value = ('**Původní:** `%s`\n**Nová:** `%s`'):format(oldP, newP),
                    inline = true
                },
                fmtVehicleBlock({ plate = newP, model = okj and data and data.model or nil, customLabel = okj and data and data.customLabel or nil }, vtype, newP),
                { name='Databáze', value=('**Owner Ident:** `%s`\n**Akce:** UPDATE\n**Tabulka:** `owned_vehicles`'):format(xTarget.identifier), inline=false }
            }
            sendDiscordEmbed(embed, 'edit')
        end
    )
end)

-- ======= SPZ - FRAKČNÍ =======
RegisterNetEvent('pb_veh:changePlateSociety', function(societyRaw, oldPlate, newPlateRaw)
    local src = source
    if not ensureAllowed(src) then
        TriggerClientEvent('pb_veh:notify', src, 'error', Config.Locale.no_perm)
        return
    end

    local society = tostring(societyRaw or ''):gsub('%s+','')
    if society == '' then
        TriggerClientEvent('pb_veh:notify', src, 'error', 'Neplatná society.')
        return
    end

    local oldP = normalizePlate(oldPlate)
    local newP = normalizePlate(newPlateRaw)
    local ok, reason = isPlateAllowed(newP)
    if not ok then
        TriggerClientEvent('pb_veh:notify', src, 'error', reason)
        return
    end

    local rows = exports.oxmysql:executeSync(
        'SELECT plate, vehicle, type FROM owned_vehicles WHERE job = ? AND (owner IS NULL OR owner = "") AND plate = ? LIMIT 1',
        { society, oldP }
    )
    if not rows or not rows[1] then
        TriggerClientEvent('pb_veh:notify', src, 'error', 'Vozidlo nenalezeno.')
        return
    end

    local dup = exports.oxmysql:executeSync(
        'SELECT 1 FROM owned_vehicles WHERE plate = ? LIMIT 1',
        { newP }
    )
    if dup and dup[1] then
        TriggerClientEvent('pb_veh:notify', src, 'error', 'Tato SPZ už existuje.')
        return
    end

    local vtype = rows[1].type or 'car'
    local okj, data = pcall(json.decode, rows[1].vehicle or '{}')
    if okj and data then data.plate = newP end
    local vehJson = json.encode(data or { plate = newP })

    exports.oxmysql:execute(
        'UPDATE owned_vehicles SET plate = ?, vehicle = ? WHERE job = ? AND (owner IS NULL OR owner = "") AND plate = ?',
        { newP, vehJson, society, oldP },
        function(_aff)
            local check = exports.oxmysql:executeSync(
                'SELECT 1 FROM owned_vehicles WHERE job = ? AND (owner IS NULL OR owner = "") AND plate = ? LIMIT 1',
                { society, newP }
            )
            if not check or not check[1] then
                TriggerClientEvent('pb_veh:notify', src, 'error', Config.Locale.db_error)
                return
            end

            renameVehicleStashes(oldP, newP)

            TriggerClientEvent('pb_veh:notify', src, 'success',
                ('SPZ změněna: [%s] → [%s] (society %s).'):format(oldP, newP, society))

            local adminIds = getIds(src)
            local embed = baseEmbed('📝 Změněna SPZ (frakční)', 15844367)
            embed.fields = {
                fmtUserBlock('👮 Admin', GetPlayerName(src), src, adminIds),
                { name='🏷️ Society', value=('**Název:** `%s`'):format(society), inline=true },
                {
                    name = 'SPZ',
                    value = ('**Původní:** `%s`\n**Nová:** `%s`'):format(oldP, newP),
                    inline = true
                },
                fmtVehicleBlock({ plate = newP, model = okj and data and data.model or nil, customLabel = okj and data and data.customLabel or nil }, vtype, newP),
                { name='Databáze', value=('**Job:** `%s`\n**Akce:** UPDATE\n**Tabulka:** `owned_vehicles`'):format(society), inline=false }
            }
            sendDiscordEmbed(embed, 'edit')
        end
    )
end)
