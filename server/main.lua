-- Cache veelgebruikte natives
local GetPlayerPed = GetPlayerPed
local GetEntityCoords = GetEntityCoords
local PlayerPedId = PlayerPedId

-- Gebruik lokale variabelen voor betere performance
local activeRegisters = {}
local activeTransactions = {}
local cachedPlayerData = {}
local zones = {}
local activeZones = {}

-- Sla orders op in een table
local activeOrders = {}
local lastOrderId = 0


-- Helper function to check if player has required job
local function hasRequiredJob(playerId, register)
    local player = exports.qbx_core:GetPlayer(playerId)
    if not player then return false end

    local playerJob = player.PlayerData.job
    local requiredJob = register.job

    return playerJob.name == requiredJob.name 
        and playerJob.grade.level >= requiredJob.minimumGrade 
        and playerJob.onduty
end

RegisterNetEvent('crp-restaurants:getNearbyPlayers', function()
    local source = source
    local sourcePed = GetPlayerPed(source)
    local sourceCoords = GetEntityCoords(sourcePed)
    local nearbyPlayers = {}
    
    -- Gebruik lib.getNearbyPlayers om spelers binnen 3.0 units te vinden
    local players = lib.getNearbyPlayers(sourceCoords, 6.0)
    
    for _, playerData in pairs(players) do
        if playerData.id ~= source then -- Skip de source speler
            local targetPlayer = exports['qbx_core']:GetPlayer(playerData.id)
            if targetPlayer then
                table.insert(nearbyPlayers, {
                    id = playerData.id,
                    name = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname
                })
            end
        end
    end
    
    print('[DEBUG] Spelers in de buurt gevonden:', json.encode(nearbyPlayers))
    TriggerClientEvent('crp-restaurants:nearbyPlayersResponse', source, nearbyPlayers)
end)

RegisterNetEvent('crp-restaurants:requestPayment', function(data)
    local source = source
    local targetPlayer = tonumber(data.playerId)
    
    -- Basic validation
    if not targetPlayer or not data.total or type(data.total) ~= "number" or data.total <= 0 then
        return lib.notify(source, {
            title = 'Kassa',
            description = 'Ongeldige betaalgegevens',
            type = 'error'
        })
    end
    
    local sourcePed = GetPlayerPed(source)


    
    -- Forward the payment request to the target player
    TriggerClientEvent('crp-restaurants:showPaymentConfirmation', targetPlayer, {
        total = data.total,
        businessName = data.businessName,
        paymentMethod = data.paymentMethod,
        sourcePlayer = source,
        items = data.items
    })
end)

RegisterNetEvent('crp-restaurants:paymentResponse', function(data)
    local src = source
    local targetPlayer = tonumber(data.sourcePlayer)

    if not src or not targetPlayer then 
        print('[ERROR] Invalid source or target player')
        return lib.notify(src, {
            title = 'Kassa',
            description = 'Ongeldige speler ID',
            type = 'error'
        })
    end

    local response = {
        success = data.accepted,
        message = data.accepted and "Betaling geaccepteerd" or "Betaling geweigerd"
    }

    print('[DEBUG] Betalingsreactie verzonden:', json.encode(response))
    -- Stuur response terug naar de initiator (klant) en naar de doelspeler (business)
    TriggerClientEvent('crp-restaurants:paymentProcessed', targetPlayer, response)

    -- Als de betaling is geaccepteerd, maak direct een nieuwe order aan
    if data.accepted then
        local businessName = data.businessName:lower()
        
        -- Voeg order toe aan activeOrders
        local order = {
            id = lastOrderId + 1,
            items = data.items,
            total = data.total,
            timestamp = os.date(),
            sourcePlayer = tostring(src),
            paymentMethod = data.paymentMethod,
            businessName = businessName,
            status = 'pending'
        }
        lastOrderId = lastOrderId + 1
        
        activeOrders[order.id] = order
        
        -- Stuur naar alle medewerkers
        local players = GetPlayers()
        for _, playerId in ipairs(players) do
            local targetPlayer = exports['qbx_core']:GetPlayer(tonumber(playerId))
            if targetPlayer and targetPlayer.PlayerData.job.name == businessName then
                TriggerClientEvent('crp-restaurants:newOrderNotification', tonumber(playerId), order)
            end
        end
    end
end)

-- Modify the existing register check function
local function IsPlayerNearRegister(playerId, registerId)
    if not activeRegisters[registerId] then return false end
    
    local register = Config.Registers[registerId]
    if not register then return false end

    -- Add job check
    if not hasRequiredJob(playerId, register) then
        return false
    end

    return true
end

-- Vervang de huidige zone setup (regels 95-112) met:
for _, register in pairs(Config.Registers) do
    zones[register.id] = lib.zones.sphere({
        coords = register.coords,
        radius = 3.0,
        debug = Config.Debug,
        inside = function(source)
            print('[DEBUG] Speler', source, 'in zone', register.id)
            if not activeZones[register.id] then
                activeZones[register.id] = {}
            end
            activeZones[register.id][source] = true
        end,
        onExit = function(source)
            print('[DEBUG] Speler', source, 'verlaat zone', register.id)
            if activeZones[register.id] then
                activeZones[register.id][source] = nil
            end
        end
    })
end

-- Cleanup oude transacties elke 5 minuten
CreateThread(function()
    while true do
        local currentTime = os.time()
        for transactionId, transaction in pairs(activeTransactions) do
            if currentTime - transaction.timestamp > 300 then
                activeTransactions[transactionId] = nil
            end
        end
        Wait(300000) -- 5 minuten
    end
end)

-- Voeg deze events toe
RegisterNetEvent('crp-restaurants:playerEnteredRegister', function(registerId)
    local source = source
    if not activeRegisters[registerId] then
        activeRegisters[registerId] = {}
    end
    activeRegisters[registerId][source] = true
    print('[DEBUG] Speler', source, 'gebruikt kassa', registerId)
end)

RegisterNetEvent('crp-restaurants:playerExitedRegister', function(registerId)
    local source = source
    if activeRegisters[registerId] then
        activeRegisters[registerId][source] = nil
        print('[DEBUG] Speler', source, 'stopt met kassa', registerId)
    end
end)

-- Event om het geld van een speler op te halen
RegisterNetEvent('crp-restaurants:getMoney')
AddEventHandler('crp-restaurants:getMoney', function(data)
    local source = source
    local moneyType = data.moneyType -- 'cash' of 'bank'
    
    -- Haal de speler op via QBX
    local Player = exports['qbx_core']:GetPlayer(source)
    if not Player then return end
    
    -- Haal het geld op van de speler
    local balance = Player.Functions.GetMoney(moneyType)
    
    -- Stuur het bedrag terug naar de client
    TriggerClientEvent('crp-restaurants:moneyResponse', source, balance)
end)

-- Event handler voor nieuwe orders
RegisterNetEvent('crp-restaurants:paymentConfirmed', function(orderData)
    local src = source
    local businessName = orderData.businessName:lower()
    
    -- Voeg order toe aan activeOrders
    local order = {
        id = lastOrderId + 1,
        items = orderData.items,
        total = orderData.total,
        timestamp = os.date(),
        sourcePlayer = tostring(src),
        paymentMethod = orderData.paymentMethod,
        businessName = businessName,
        status = 'pending'
    }
    lastOrderId = lastOrderId + 1
    
    activeOrders[order.id] = order
    
    -- Stuur naar alle medewerkers
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local targetPlayer = exports['qbx_core']:GetPlayer(tonumber(playerId))
        if targetPlayer and targetPlayer.PlayerData.job.name == businessName then
            TriggerClientEvent('crp-restaurants:newOrderNotification', tonumber(playerId), order)
        end
    end
end)

-- Event handler voor order status updates
RegisterNetEvent('crp-restaurants:updateOrderStatus', function(orderId, newStatus)
    local src = source
    local Player = exports['qbx_core']:GetPlayer(src)
    if not Player then return end
    
    local order = activeOrders[orderId]
    if not order then return end
    
    -- Check of speler bij het juiste bedrijf werkt
    if Player.PlayerData.job.name ~= order.businessName then 
        return lib.notify(src, {
            title = 'Bestellingen',
            description = 'Je hebt geen toegang tot deze bestelling',
            type = 'error'
        })
    end
    
    -- Update status
    order.status = newStatus
    activeOrders[orderId] = order
    
    -- Stuur update naar alle medewerkers
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local targetPlayer = exports['qbx_core']:GetPlayer(tonumber(playerId))
        if targetPlayer and targetPlayer.PlayerData.job.name == order.businessName then
            TriggerClientEvent('crp-restaurants:orderStatusUpdated', tonumber(playerId), orderId, newStatus)
        end
    end
end)

-- Event voor het ophalen van actieve orders bij het openen van de UI
RegisterNetEvent('crp-restaurants:getActiveOrders', function()
    local src = source
    local Player = exports['qbx_core']:GetPlayer(src)
    if not Player then return end
    
    local playerOrders = {}
    for id, order in pairs(activeOrders) do
        if order.businessName == Player.PlayerData.job.name then
            playerOrders[#playerOrders + 1] = order
        end
    end
    
    TriggerClientEvent('crp-restaurants:activeOrdersResponse', src, playerOrders)
end)

-- Helper function to check if player works at business (implement your own logic)
function IsPlayerWorkingAt(playerId, businessName)
    -- Implement your own logic here to check if player works at the business
    -- This is just an example
    local Player = exports['qbx_core']:GetPlayer(playerId)
    if Player then
        local job = Player.PlayerData.job
        return job.name == businessName:lower()
    end
    return false
end

lib.addCommand('testorder', {
    help = 'Maak een test bestelling',
    restricted = 'group.admin'
}, function(source, args)
    local Player = exports['qbx_core']:GetPlayer(source)
    if not Player then return end

    -- Maak een test order met producten uit de config
    local testOrder = {
        id = os.time(),
        items = {
            {
                product = {
                    id = "burger_bleeder",
                    name = "Bleeder",
                    price = 5.99
                },
                quantity = 2
            },
            {
                product = {
                    id = "drink_cola",
                    name = "eCola",
                    price = 2.49
                },
                quantity = 1
            }
        },
        total = 14.47,
        timestamp = os.date(),
        sourcePlayer = tostring(source),
        paymentMethod = "bank",
        businessName = "burgershot"
    }

    -- Stuur de order notificatie naar alle burgershot medewerkers
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local targetPlayer = exports['qbx_core']:GetPlayer(tonumber(playerId))
        if targetPlayer and targetPlayer.PlayerData.job.name == "burgershot" then
            TriggerClientEvent('crp-restaurants:newOrderNotification', tonumber(playerId), testOrder)
        end
    end

    -- Bevestig aan de speler
    lib.notify(source, {
        title = 'Test Bestelling',
        description = 'Test bestelling aangemaakt',
        type = 'success'
    })
end) 