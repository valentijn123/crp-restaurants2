-- Register NUI callback types
RegisterNuiCallbackType('closeOrderReceiver')

-- Gebruik interact voor de interactie punten
CreateThread(function()
    for business, data in pairs(Config.OrderReceivers) do
        interact.addCoords({
            id = 'order_receiver_'..business,
            coords = {
                data.coords
            },
            options = {
                {
                    label = data.label,
                    icon = "clipboard-list",
                    groups = {
                        [data.job.name] = data.job.minimumGrade
                    },
                    onSelect = function()
                        if QBX.PlayerData.job.onduty then
                            TriggerEvent('crp-restaurants:openOrderReceiver')
                        else
                            lib.notify({
                                title = 'Bestellingen',
                                description = 'Je moet in dienst zijn',
                                type = 'error'
                            })
                        end
                    end
                }
            },
            renderDistance = 10.0,
            activeDistance = 2.0,
            cooldown = 1000
        })
    end
end)

RegisterNetEvent('crp-restaurants:openOrderReceiver', function()
    TriggerServerEvent('crp-restaurants:getActiveOrders')
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'resource:showOrderReceiver',
        data = {
            show = true
        }
    })
end)
-- NUI Callback voor het sluiten van de OrderReceiver
RegisterNUICallback('closeOrderReceiver', function(_, cb)
    SetNuiFocus(false, false)
    cb({})
end)

RegisterNetEvent('crp-restaurants:activeOrdersResponse', function(orders)
    SendNUIMessage({
        action = 'resource:activeOrdersResponse',
        data = orders
    })
end)


RegisterNetEvent('crp-restaurants:orderStatusUpdated', function(orderId, status)
    SendNUIMessage({
        action = 'resource:orderStatusUpdated',
        data = {
            orderId = orderId,
            status = status
        }
    })
end) 