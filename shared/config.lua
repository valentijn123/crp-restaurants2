Config = {}

-- Kassa locaties voor verschillende restaurants
Config.Registers = {
    -- Burger Shot kassa's
    {
        id = "burgershot_register_1",
        coords = vec3(494.09671020508, -905.86566162109, 24.984365463257),
        business = "burgershot",
        job = {
            name = "burgershot",
            minimumGrade = 0,  -- Minimum grade level required
        },
        categories = {
            { id = 'burgers', name = 'Burgers' },
            { id = 'drinks', name = 'Dranken' },
            { id = 'sides', name = 'Sides' },
            { id = 'desserts', name = 'Desserts' }
        },
        products = {
            {
                id = "phone",
                name = "Bleeder",
                price = 5.99,
                category = "burgers",
            },
            {
                id = "tablet",
                name = "eCola",
                price = 2.49,
                category = "drinks",
            }
        }
    },
    {
        id = "burgershot_register_2",
        coords = vec3(-1194.8, -893.7, 13.9),
        business = "burgershot",
        job = {
            name = "burgershot",
            minimumGrade = 0,
        },
        categories = {
            { id = 'burgers', name = 'Burgers' },
            { id = 'drinks', name = 'Dranken' }
        },
        products = {
            {
                id = "burger_bleeder",
                name = "Bleeder",
                price = 5.99,
                category = "burgers",
            }
        }
    }
}

-- Order receiver locaties
Config.OrderReceivers = {
    ['burgershot'] = {
        coords = vec3(494.1116027832, -922.52484130859, 25.401685714722),
        label = "Bestellingen Bekijken",
        job = {
            name = "burgershot",
            minimumGrade = 0
        }
    }
} 

-- Debug mode
Config.Debug = true             -- Enable/disable debug features

