RegisterNUICallback(Receive.close, function(_, cb)
    SendNUIMessage({
        action = Send.visible,
        data = { show = false }
    })
    cb(1)
end)