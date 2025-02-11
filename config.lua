Config = {}

-- Kassa locaties voor verschillende restaurants
Config.Registers = {
    -- Burger Shot kassa's
    {
        id = "burgershot_register_1",
        coords = vec3(494.09671020508, -905.86566162109, 24.984365463257),
        business = "burgershot"
    },
    {
        id = "burgershot_register_2", 
        coords = vec3(-1194.8, -893.7, 13.9),
        business = "burgershot"
    }
}

-- Debug mode
Config.Debug = true             -- Enable/disable debug features

Receive = {
    close = "resource:close",
    visible = "resource:visible"
}