fx_version 'cerulean'
game 'gta5'

name 'ty-propinspection'
author 'Treety'
description 'Standalone AAA-style prop inspection system with streamed world props, hotspots, inertia, cinematic camera, localized NUI, full camera-relative orientation and authoring tool.'
version '1.0.15'

ui_page 'html/index.html'

-- Explicit client order is important for localization:
-- Config.Locale must exist before locales.lua, and L()/GetLocaleTable() must
-- exist before client/main.lua starts sending NUI messages.
client_scripts {
    'config.lua',
    'locales.lua',
    'client/main.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}
