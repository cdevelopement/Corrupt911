fx_version 'cerulean'
game 'gta5'

author 'Corrupt'
description 'Corrupt 911 with SiriusDuty Integration'
version '2.0.0'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html'
}

dependencies {
    'ox_lib',
    'SiriusDuty'
}