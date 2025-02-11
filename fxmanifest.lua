fx_version 'cerulean'

game "gta5"

author "Valentijn"
version '1.0.0'
description 'Restaurant Script.'

lua54 'yes'

-- ui_page 'build/index.html'
ui_page 'http://localhost:3000/' --voor development

shared_script {
    '@ox_lib/init.lua',
    'shared/**'
}

server_script {
    'server/**'
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    '@sleepless_interact/init.lua',
    'client/events.lua',
    'client/ui.lua',
    'client/client.lua',
    'client/**',
}

files {
    'build/**',
}
