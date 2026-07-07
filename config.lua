Config = {}

-- ==========================================================================
-- GENERAL
-- ==========================================================================

Config.Locale = 'en' -- en, de, pl, tr, ru, es, fr
Config.Debug = false
Config.EnableDOF = true
Config.InvertMouse = false -- true = invert both axes; table = per-axis control
Config.EnableSounds = true
Config.InteractUI = 'script' -- 'script' or 'native'

-- ==========================================================================
-- HUD
-- ==========================================================================

Config.Hud = {
    enabled = true,
    hideNativeHud = true,

    Disable = function()
        if GetResourceState('qb-hud') ~= 'started' then return end

        local success = pcall(function()
            exports['qb-hud']:SetHudState(false)
        end)

        if not success then
            TriggerEvent('qb-hud:client:SetHudState', false)
        end
    end,

    Enable = function()
        if GetResourceState('qb-hud') ~= 'started' then return end

        local success = pcall(function()
            exports['qb-hud']:SetHudState(true)
        end)

        if not success then
            TriggerEvent('qb-hud:client:SetHudState', true)
        end
    end
}

-- ==========================================================================
-- UI
-- ==========================================================================

Config.UI = {
    inspectBackground = {
        enabled = true,
        opacity = 0.90,
        protectProp = true,
        clearRadius = 32.0,
        fullDarkRadius = 78.0
    }
}

-- ==========================================================================
-- WORLD STREAMING & DEBUG
-- ==========================================================================

Config.WorldPropStreamDistance = 90.0
Config.WorldPropDespawnDistance = 110.0
Config.DebugDrawDistance = 40.0

Config.DebugBlip = {
    sprite = 280,
    color = 1,
    scale = 1.0,
    flashes = true
}

-- ==========================================================================
-- PROP SETUP TOOL
-- ==========================================================================

-- Temporary development tool. Disable before releasing the resource publicly.
-- /propinspect, /propinspect [spotId] [propIndex], /propinspect close
Config.PropInspectTool = {
    enabled = true,
    command = 'propinspect',
    zoomMin = 0.15,
    zoomMax = 4.0,
    zoomStep = 0.10,
    fineZoomStep = 0.01,
    defaultTolerance = 15.0,
    toleranceStep = 1.0,
    rollSpeed = 90.0,
    updateIntervalMs = 50
}

-- ==========================================================================
-- CONTROLS
-- ==========================================================================

Config.Controls = {
    interact = 38,
    rotateHold = 24,
    mouseX = 1,
    mouseY = 2,
    zoomIn = 15,
    zoomOut = 14,
    reset = 45,
    previous = 34,
    next = 35,
    arrowLeft = 174,
    arrowRight = 175,
    closeBack = 177,
    closePause = 200,
    closeFrontend = 202,

    debugMode = 74,
    debugSetHotspot = 47,
    debugClearHotspot = 73,
    debugPrint = 191,
    debugSetMin = 157,
    debugSetDefault = 158,
    debugSetMax = 160,
    debugToleranceUp = 172,
    debugToleranceDown = 173,
    debugRollLeft = 44,
    debugRollRight = 38,
    debugFineZoom = 21
}

-- ==========================================================================
-- MOTION & SWITCHING
-- ==========================================================================

Config.Motion = {
    mouseSensitivity = 150.0,
    rotationLerpSpeed = 13.0,
    zoomLerpSpeed = 10.0,
    zoomStep = 0.16,

    -- false = unlimited rotation. See DOCS.md for global and per-prop limits.
    rotationLimits = false,

    switchOffset = 0.48,
    switchOutDuration = 0.18,
    switchInDuration = 0.52,
    bounceDamping = 7.5,
    bounceFrequency = 12.0
}

-- ==========================================================================
-- CAMERA & LIGHT
-- ==========================================================================

Config.Camera = {
    transitionInMs = 450,
    transitionOutMs = 350,
    fovOffset = -2.0,
    raycastPadding = 0.12,
    raycastFlags = 511,
    raycastTimeoutMs = 750,

    breathing = {
        enabled = true,
        positionAmplitude = 0.0045,
        rotationAmplitude = 0.085,
        speed = 0.72
    },

    dof = {
        nearDof = 0.18,
        farDof = 2.8,
        strength = 0.72
    }
}

Config.CameraLight = {
    enabled = true,
    color = { r = 255, g = 242, b = 220 },
    range = 3.0,
    intensity = 1.35,
    forwardOffset = 0.12
}

-- ==========================================================================
-- SOUNDS
-- ==========================================================================

Config.Sounds = {
    open = { name = 'SELECT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    close = { name = 'BACK', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    switch = { name = 'NAV_LEFT_RIGHT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    reset = { name = 'WAYPOINT_SET', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    hotspot = { name = 'PICK_UP', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' }
}

-- ==========================================================================
-- INSPECTION SPOTS
-- ==========================================================================

Config.Spots = {
    [1] = {
        coords = vector3(155.36, -1039.94, 29.28),
        radius = 2.0,
        isLocked = false,

        worldProp = {
            model = 'prop_amb_phone',
            coords = vector3(155.36, -1039.94, 28.28),
            heading = 45.0
        },

        playerAnim = {
            dict = 'cellphone@',
            name = 'cellphone_text_read_base',
            flag = 49,
            attachProp = {
                model = 'prop_phone_ing_02',
                bone = 28422,
                offset = vector3(0.0, 0.0, 0.0),
                rotation = vector3(10.0, 0.0, 0.0)
            }
        },

        inspectProps = {
            {
                model = 'prop_phone_ing_02',
                label = 'Old Smartphone',
                description = 'A damaged smartphone. The display is cracked, but strange scratches cover the back...',
                defaultRotation = vector3(0.0, 0.0, 0.0),
                defaultDistance = 0.40,
                minDistance = 0.25,
                maxDistance = 0.55,
                inertia = 0.15,

                hotspots = {
                    {
                        matchMode = 'view', -- 'view' or 'exact'
                        targetRotation = vector3(6.54, 0.00, 173.51),
                        tolerance = 60.0,
                        subDescription = "INFO: You discovered an engraved serial number on the back: 'X-992-B'."
                    }
                }
            }
        }
    },

    [2] = {
        coords = vector3(154.07, -1048.76, 29.24),
        radius = 2.0,
        isLocked = false,
        worldProp = false,

        playerAnim = {
            dict = 'amb@world_human_gardener_plant@male@base',
            name = 'base',
            flag = 1
        },

        inspectProps = {
            {
                model = 'p_cs_polaroid_s',
                label = 'Polaroid of a Man',
                description = 'A Polaroid photograph showing an unknown man. The image is clear and well preserved, with every detail still easy to see.',
                defaultRotation = vector3(90.0, 0.0, 0.0),
                defaultDistance = 0.45,
                minDistance = 0.25,
                maxDistance = 0.60,
                inertia = 0.20,
                hotspots = {
                    {
                        matchMode = 'view', -- 'view' or 'exact'
                        targetRotation = vector3(124.18, 0.00, 179.28),
                        tolerance = 40.0,
                        subDescription = "A short handwritten message is written on the back of the photograph: DON’T TRUST HIM."
                    }
                }                    
            },
            {
                model = 'v_ret_ta_camera',
                label = 'Old Camera',
                description = 'An older digital camera. It is not the latest model, but it appears to still be functional.',
                defaultRotation = vector3(0.0, 0.0, 0.0),
                defaultDistance = 0.55,
                minDistance = 0.35,
                maxDistance = 0.65,
                inertia = 0.10,
                hotspots = {}
            }
        }
    }
}
