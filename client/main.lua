-- Fallback: define dummy interact if not already defined to avoid nil error
if not interact then
    interact = {}
    interact.addCoords = function(args)
        print("Dummy interact.addCoords aangeroepen voor kassa:", args.id)
        -- ...existing code or potential direct call for testing...
    end
end

-- Register NUI callback types first
RegisterNuiCallbackType('getMoney')
RegisterNuiCallbackType(Receive.close)
RegisterNuiCallbackType(Receive.checkout)
RegisterNuiCallbackType('paymentConfirmed')

-- Store the current register data
local currentRegister = nil

local isProcessingPayment = false

local function OpenRegister(register)
    print('[DEBUG] Kassa openen:', register.id)
    
    -- Sla de huidige register op
    currentRegister = register
    
    -- Format products to include image paths
    local products = {}
    for _, product in ipairs(register.products) do
        products[#products + 1] = {
            id = product.id,
            name = product.name,
            price = product.price,
            category = product.category,
            image = string.format('nui://ox_inventory/web/images/%s.png', product.id)
        }
    end

    -- Add 'All' category and register-specific categories
    local categories = {{ id = 'all', name = 'Alles' }}
    for _, category in ipairs(register.categories) do
        categories[#categories + 1] = category
    end

    -- Set focus and send data to NUI
    SetNuiFocus(true, true)
    print('[DEBUG] Sending NUI Message with action:', Send.visible)
    SendNUIMessage({
        action = Send.visible,
        data = {
            show = true,
            business = register.business,
            categories = categories,
            products = products
        }
    })
end

local function canInteractWithRegister(register)
    local PlayerData = QBX.PlayerData
    if not PlayerData or not PlayerData.job then return false end

    local playerJob = PlayerData.job
    local requiredJob = register.job

    return playerJob.name == requiredJob.name 
        and playerJob.grade.level >= requiredJob.minimumGrade 
        and playerJob.onduty
end

local function InitializeRegisters()
    for _, register in pairs(Config.Registers) do
        interact.addCoords({
            id = register.id,
            coords = {
                register.coords
            },
            options = {
                {
                    label = "Open Kassa",
                    icon = "cash-register",
                    groups = {
                        [register.job.name] = register.job.minimumGrade
                    },
                    onSelect = function()
                        if QBX.PlayerData.job.onduty then
                            OpenRegister(register)
                        else
                            exports['qbx_core']:Notify('Je moet in dienst zijn', 'error')
                        end
                    end
                }
            },
            renderDistance = 10.0,
            activeDistance = 2.0,
            cooldown = 1000
        })
    end
end

-- Initialize bij resource start
CreateThread(function()
    InitializeRegisters()
end)

-- NUI Callbacks
RegisterNUICallback(Receive.close, function(_, cb)
    currentRegister = nil
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = Send.visible,
        data = { show = false }
    })
    cb({ success = true })
end)

RegisterNUICallback(Receive.checkout, function(data, cb)
    currentRegister = nil
    SetNuiFocus(false, false)
    cb({})
end)

RegisterNUICallback('nui:close', function(data, cb)
    print('[DEBUG] Received direct close event')
    SetNuiFocus(false, false)
    cb({ success = true })
end)

RegisterNUICallback('getNearbyPlayers', function(_, cb)
    TriggerServerEvent('crp-restaurants:getNearbyPlayers')
    cb({})
end)

RegisterNetEvent('crp-restaurants:nearbyPlayersResponse', function(players)
    print('[DEBUG] Client received players:', json.encode(players))
    local message = {
        action = 'resource:nearbyPlayers', -- Make sure this matches your Send.nearbyPlayers value
        data = { 
            players = players 
        }
    }
    print('[DEBUG] Sending NUI message:', json.encode(message))
    SendNUIMessage(message)
end)

RegisterNUICallback('getProducts', function(_, cb)
    if not currentRegister then return cb({}) end
    
    local products = {}
    for _, product in ipairs(currentRegister.products) do
        products[#products + 1] = {
            id = product.id,
            name = product.name,
            price = product.price,
            category = product.category,
            image = string.format('nui://ox_inventory/web/images/%s.png', product.id)
        }
    end
    
    -- Add 'All' category and register-specific categories
    local categories = {{ id = 'all', name = 'Alles' }}
    for _, category in ipairs(currentRegister.categories) do
        categories[#categories + 1] = category
    end
    
    cb({
        products = products,
        categories = categories
    })
end)

RegisterNUICallback('requestPayment', function(data, cb)
    print('[DEBUG] Requesting payment from player:', data.playerId)
    TriggerServerEvent('crp-restaurants:requestPayment', data)
    cb({})
end)

-- Listen for payment requests (as the customer)
RegisterNetEvent('crp-restaurants:showPaymentConfirmation', function(data)
    print('[DEBUG] Betalingsbevestiging UI tonen:', json.encode(data))
    SendNUIMessage({
        action = 'resource:showPaymentConfirmation',
        data = data
    })
    SetNuiFocus(true, true)
end)

-- Handle payment response
RegisterNUICallback('paymentResponse', function(data, cb)
    print('[DEBUG] Betalingsreactie ontvangen:', json.encode(data))
    
    -- Trigger het server event
    TriggerServerEvent('crp-restaurants:paymentResponse', data)
    
    -- Stuur een succesvol object terug
    cb({
        success = true,
        message = "Payment response sent"
    })
end)

RegisterNetEvent('crp-restaurants:paymentProcessed', function(response)
    print('[DEBUG] Betaling verwerkt, wordt naar NUI gestuurd:', json.encode(response))
    SendNUIMessage({
        action = 'resource:paymentProcessed',
        data = response or { success = false, message = "Onbekende fout" }
    })
end)

-- Event handler voor het ontvangen van het saldo van de server
RegisterNetEvent('crp-restaurants:moneyResponse')
AddEventHandler('crp-restaurants:moneyResponse', function(balance)
    SendNUIMessage({
        action = 'moneyResponse',
        data = {
            balance = balance
        }
    })
end)

-- NUI Callback voor getMoney
RegisterNUICallback('getMoney', function(data, cb)
    TriggerServerEvent('crp-restaurants:getMoney', data)
    cb({})
end)

-- Handle new order notifications for staff
RegisterNetEvent('crp-restaurants:newOrderNotification', function(orderData)
    print('[DEBUG] Received order notification:', json.encode(orderData))
    -- Debug print toevoegen om te zien of de job match
    local PlayerData = QBX.PlayerData -- Dit is de correcte manier om PlayerData te krijgen
    if PlayerData then
        print('[DEBUG] Player job:', PlayerData.job.name)
    end
    
    SendNUIMessage({
        action = 'resource:newOrder',
        data = orderData
    })
end)

--[[
RegisterNUICallback('newOrder', function(data, cb)
    print('[DEBUG] New order callback received:', json.encode(data))
    TriggerServerEvent('crp-restaurants:paymentConfirmed', data)
    cb({
        success = true,
        message = "Order sent"
    })
end)
]]--

RegisterNUICallback('paymentConfirmed', function(data, cb)
    print('[DEBUG] Betaling bevestigd callback ontvangen:', json.encode(data))
    TriggerServerEvent('crp-restaurants:paymentConfirmed', data)
    cb({
        success = true,
        message = "Payment confirmed"
    })
end)

RegisterNetEvent('crp-restaurants:getCurrentBusiness')
AddEventHandler('crp-restaurants:getCurrentBusiness', function()
    local Player = QBX.PlayerData
    if Player and Player.job then
        TriggerClientEvent('crp-restaurants:businessResponse', source, {
            business = Player.job.name
        })
    end
end)