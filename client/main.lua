local RESOURCE_NAME = GetCurrentResourceName()

-- Local-only entity registries. Nothing in this resource is networked.
local worldProps = {}
local debugBlips = {}
local session = nil

-- Tracks the custom nearby interaction NUI so messages are only sent on state changes.
local interactUiVisible = false
local interactUiSignature = nil
local interactUiBlockedUntil = 0

-- A short post-inspection lock prevents keys that closed/switched the inspect
-- workspace from leaking into normal gameplay on the very next frame.
local controlReleaseLockToken = 0

-- Forward declarations used by exports/events and the inspection thread.
local startInspection
local stopInspection

-- ---------------------------------------------------------------------------
-- Localization
-- ---------------------------------------------------------------------------

-- Locale lookup is centralized in `locales.lua`. The helper is loaded after all
-- language files and therefore never caches an English fallback before the
-- selected locale has registered itself.
local nuiLocaleSent = false

---Returns a localized string through the shared L() helper, then optionally
---applies legacy string.format placeholders (`%s`, `%d`, ...).
---@param path string
---@param ... any
---@return string
local function translate(path, ...)
    local value = type(L) == 'function' and L(path) or path

    if type(value) ~= 'string' then
        value = tostring(value)
    end

    if select('#', ...) == 0 then return value end

    local ok, formatted = pcall(string.format, value, ...)
    return ok and formatted or value
end

---Sends the active, fully merged locale table to the NUI.
---`locales.lua` already merges the selected language over English, so the UI
---receives one complete table instead of racing against partially loaded files.
---@param force? boolean
local function sendLocaleToNui(force)
    if nuiLocaleSent and force ~= true then return end

    local localeTable = type(GetLocaleTable) == 'function' and GetLocaleTable() or {}
    local localeCode = type(GetLocaleCode) == 'function' and GetLocaleCode() or 'en'

    SendNUIMessage({
        action = 'setLocale',
        code = localeCode,
        strings = localeTable.nui or {},
        fallback = ((type(GetFallbackLocaleTable) == 'function' and GetFallbackLocaleTable()) or {}).nui or {}
    })

    nuiLocaleSent = true
end

-- The CEF page can load after early client messages. The page therefore sends a
-- one-time `ready` callback and receives the locale again after its JS listener
-- is guaranteed to exist. This prevents the UI from silently staying English.
RegisterNUICallback('ready', function(_, cb)
    nuiLocaleSent = false
    sendLocaleToNui(true)
    cb({ ok = true })
end)

-- Send once more after startup as a second safety net for slow CEF initialization.
-- Debug output also shows exactly which locale the client resolved.
CreateThread(function()
    Wait(750)
    nuiLocaleSent = false
    sendLocaleToNui(true)

    if Config.Debug then
        local available = type(GetAvailableLocaleCodes) == 'function'
            and table.concat(GetAvailableLocaleCodes(), ', ')
            or 'unknown'

        print(('[%s] Locale requested: %s | active: %s | loaded: %s'):format(
            RESOURCE_NAME,
            tostring(Config.Locale),
            type(GetLocaleCode) == 'function' and GetLocaleCode() or 'en',
            available
        ))
    end
end)

-- ---------------------------------------------------------------------------
-- Generic helpers
-- ---------------------------------------------------------------------------

---Prints a formatted debug line only when Config.Debug is enabled.
---@param message string
---@param ... any
local function debugPrint(message, ...)
    if not Config.Debug then return end

    local ok, formatted = pcall(string.format, message, ...)
    print(('[%s] %s'):format(RESOURCE_NAME, ok and formatted or message))
end

---Runs one optional HUD callback without allowing a third-party integration
---error to break the inspection lifecycle.
---@param callbackName 'Enable'|'Disable'
---@return boolean success
local function runHudCallback(callbackName)
    local hud = Config.Hud or {}
    if hud.enabled == false then return false end

    local callback = hud[callbackName]
    if type(callback) ~= 'function' then return false end

    local success, err = pcall(callback)
    if not success then
        debugPrint('Config.Hud.%s failed: %s', tostring(callbackName), tostring(err))
    end

    return success
end

---Applies or restores the optional external HUD integration once per session.
---@param activeSession table
---@param hidden boolean
local function setInspectionHudHidden(activeSession, hidden)
    if not activeSession then return end

    if hidden then
        if activeSession.hudVisibilityChanged then return end
        if (Config.Hud or {}).enabled == false then return end

        activeSession.hudVisibilityChanged = true
        runHudCallback('Disable')
        return
    end

    if not activeSession.hudVisibilityChanged then return end
    activeSession.hudVisibilityChanged = false
    runHudCallback('Enable')
end

---Clamps a number to an inclusive range.
---@param value number
---@param minimum number
---@param maximum number
---@return number
local function clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

---Linear interpolation between two scalar values.
---@param from number
---@param to number
---@param alpha number
---@return number
local function lerp(from, to, alpha)
    return from + (to - from) * alpha
end

---Converts a desired response speed into a frame-rate independent Lerp alpha.
---Formula: alpha = 1 - e^(-speed * deltaTime)
---This means the motion feels nearly identical at 30, 60, 144 or more FPS.
---@param speed number
---@param deltaTime number
---@return number
local function expLerpAlpha(speed, deltaTime)
    return 1.0 - math.exp(-math.max(speed, 0.0) * math.max(deltaTime, 0.0))
end

---Frame-rate independent scalar interpolation.
---@param from number
---@param to number
---@param speed number
---@param deltaTime number
---@return number
local function expLerp(from, to, speed, deltaTime)
    return lerp(from, to, expLerpAlpha(speed, deltaTime))
end

---Normalizes an angle to the [-180, 180) range.
---@param angle number
---@return number
local function normalizeAngle(angle)
    return (angle + 180.0) % 360.0 - 180.0
end

---Returns the shortest signed angular delta from one angle to another.
---@param from number
---@param to number
---@return number
local function shortestAngleDelta(from, to)
    return normalizeAngle(to - from)
end

---Returns the numerically closest equivalent representation of a target angle.
---Example: current 725° and target 0° becomes 720° instead of rotating back 725°.
---@param reference number
---@param target number
---@return number
local function nearestEquivalentAngle(reference, target)
    return reference + shortestAngleDelta(reference, target)
end

---Smoothstep easing for the switch-out animation.
---@param t number
---@return number
local function smoothstep(t)
    t = clamp(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)
end

---Returns a GTA/FiveM model hash from either a string or numeric hash.
---@param model string|number
---@return number
local function getModelHash(model)
    if type(model) == 'number' then return model end
    return joaat(model)
end

---Requests a model with a finite timeout so a bad config can never hang forever.
---@param model string|number
---@param timeoutMs? number
---@return boolean loaded
---@return number hash
local function requestModel(model, timeoutMs)
    local hash = getModelHash(model)
    timeoutMs = timeoutMs or 5000

    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        debugPrint('Invalid model: %s', tostring(model))
        return false, hash
    end

    RequestModel(hash)

    local deadline = GetGameTimer() + timeoutMs
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do
        Wait(0)
        RequestModel(hash)
    end

    if not HasModelLoaded(hash) then
        debugPrint('Timed out while loading model: %s', tostring(model))
        return false, hash
    end

    return true, hash
end

---Requests an animation dictionary with a finite timeout.
---@param dictionary string
---@param timeoutMs? number
---@return boolean
local function requestAnimDict(dictionary, timeoutMs)
    timeoutMs = timeoutMs or 5000
    RequestAnimDict(dictionary)

    local deadline = GetGameTimer() + timeoutMs
    while not HasAnimDictLoaded(dictionary) and GetGameTimer() < deadline do
        Wait(0)
        RequestAnimDict(dictionary)
    end

    return HasAnimDictLoaded(dictionary)
end

---Deletes a local entity safely and clears its mission ownership.
---@param entity number|nil
local function deleteLocalEntity(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
end

---Plays one configured native frontend sound.
---@param sound table|nil
local function playConfiguredSound(sound)
    if Config.EnableSounds == false then return end
    if not sound or not sound.name or not sound.set then return end
    PlaySoundFrontend(-1, sound.name, sound.set, true)
end

---Copies a vector-like rotation into a mutable Lua table.
---@param rotation vector3|table|nil
---@return table
local function copyRotation(rotation)
    rotation = rotation or vec3(0.0, 0.0, 0.0)
    return {
        x = rotation.x or 0.0,
        y = rotation.y or 0.0,
        z = rotation.z or 0.0
    }
end

---Normalizes a vector. Returns a zero vector for extremely small magnitudes.
---@param value vector3
---@return vector3
local function normalizeVector(value)
    local length = #(value)
    if length <= 0.000001 then return vec3(0.0, 0.0, 0.0) end
    return value / length
end

---3D cross product.
---@param a vector3
---@param b vector3
---@return vector3
local function cross(a, b)
    return vec3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    )
end

---Converts a camera rotation (degrees) into a normalized forward direction.
---@param rotation vector3|table
---@return vector3
local function rotationToDirection(rotation)
    local pitch = math.rad(rotation.x)
    local yaw = math.rad(rotation.z)
    local cosPitch = math.abs(math.cos(pitch))

    return normalizeVector(vec3(
        -math.sin(yaw) * cosPitch,
        math.cos(yaw) * cosPitch,
        math.sin(pitch)
    ))
end

---Builds forward/right/up basis vectors from a camera rotation.
---@param rotation vector3|table
---@return vector3 forward
---@return vector3 right
---@return vector3 up
local function cameraBasis(rotation)
    local forward = rotationToDirection(rotation)
    local worldUp = vec3(0.0, 0.0, 1.0)
    local right = normalizeVector(cross(forward, worldUp))

    -- Looking almost perfectly vertical makes the cross product unstable.
    if #(right) <= 0.000001 then
        right = vec3(1.0, 0.0, 0.0)
    end

    local up = normalizeVector(cross(right, forward))
    return forward, right, up
end

---Composes local inspect rotation with the complete camera rotation.
---Unlike the old yaw-only approach, pitch and roll are included too, so the
---same configured default side stays facing the player while looking up/down.
---The local values remain unwrapped; unlimited rotations can continue past 360°.
---@param localRotation vector3|table
---@param cameraRotation vector3|table
---@return table
local function composeCameraRelativeRotation(localRotation, cameraRotation)
    return {
        x = (cameraRotation.x or 0.0) + (localRotation.x or 0.0),
        y = (cameraRotation.y or 0.0) + (localRotation.y or 0.0),
        z = (cameraRotation.z or 0.0) + (localRotation.z or 0.0)
    }
end

---Returns mouse-axis multipliers for inspect rotation.
---
---Supported forms:
---  Config.InvertMouse = false            -> normal X and Y
---  Config.InvertMouse = true             -> invert X and Y
---  Config.InvertMouse = { x = true, y = false } -> invert only one axis
---@return number horizontalSign
---@return number verticalSign
local function getMouseAxisSigns()
    local setting = Config.InvertMouse

    if type(setting) == 'table' then
        return setting.x == true and -1.0 or 1.0,
            setting.y == true and -1.0 or 1.0
    end

    if setting == true then
        return -1.0, -1.0
    end

    return 1.0, 1.0
end

---Returns the active mouse-rotation limits for a prop.
---
---Natural object-viewer controls use local Z for horizontal yaw and local X for
---vertical pitch. `minY/maxY` remain accepted as a backwards-compatible
---fallback for older configs that used Y as the horizontal axis.
---@param prop table
---@return table|nil
local function getRotationLimits(prop)
    -- Per-prop `false` always means fully unrestricted rotation.
    if prop.rotationLimits == false then return nil end

    local limits = prop.rotationLimits

    -- When the prop has no override, use the global setting. A global `false`
    -- is intentionally preserved instead of falling through to a default table;
    -- this allows continuous rotation beyond ±180 degrees with no hard stop.
    if limits == nil then
        limits = (Config.Motion or {}).rotationLimits
    end

    if limits == false or type(limits) ~= 'table' then return nil end

    return {
        minX = tonumber(limits.minX) or -180.0,
        maxX = tonumber(limits.maxX) or 180.0,
        minZ = tonumber(limits.minZ) or tonumber(limits.minY) or -180.0,
        maxZ = tonumber(limits.maxZ) or tonumber(limits.maxY) or 180.0
    }
end

---Returns a wrapped inspect-prop index.
---@param currentIndex number
---@param direction number
---@param total number
---@return number
local function wrappedIndex(currentIndex, direction, total)
    return ((currentIndex - 1 + direction) % total) + 1
end

-- ---------------------------------------------------------------------------
-- NUI helpers
-- ---------------------------------------------------------------------------

---Shows the story-game inspection overlay.
---@param prop table
---@param index number
---@param total number
local function openNui(prop, index, total)
    local ui = Config.UI or {}
    local background = ui.inspectBackground or {}
    local clearRadius = clamp(tonumber(background.clearRadius) or 32.0, 0.0, 95.0)
    local fullDarkRadius = clamp(tonumber(background.fullDarkRadius) or 78.0, clearRadius + 1.0, 100.0)

    -- Force a fresh locale payload immediately before opening. This makes
    -- Config.Locale changes deterministic even after CEF/resource restarts.
    sendLocaleToNui(true)
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'open',
        label = prop.label or translate('nui.unknownObject'),
        description = prop.description or '',
        index = index,
        total = total,
        canSwitch = total > 1,
        dimEnabled = background.enabled ~= false,
        dimOpacity = clamp(tonumber(background.opacity) or 0.18, 0.0, 1.0),
        dimProtectProp = background.protectProp ~= false,
        dimClearRadius = clearRadius,
        dimFullDarkRadius = fullDarkRadius
    })
end

---Updates title/description when the active inspect prop changes.
---@param prop table
---@param index number
---@param total number
local function updateNuiProp(prop, index, total)
    SendNUIMessage({
        action = 'propChanged',
        label = prop.label or translate('nui.unknownObject'),
        description = prop.description or '',
        index = index,
        total = total,
        canSwitch = total > 1
    })
end

---Shows or hides the hotspot indicator and sub-description.
---@param visible boolean
---@param text? string
local function updateNuiHotspot(visible, text)
    SendNUIMessage({
        action = 'hotspot',
        visible = visible,
        text = text or ''
    })
end

---Closes the overlay with either its normal fade or an immediate hard reset.
---@param immediate boolean
local function closeNui(immediate)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = immediate and 'forceClose' or 'close' })
end

---Shows or updates the development-only Prop Inspect Tool readout.
---The values are the same local inspect-space values that belong in config.lua.
---@param activeSession table
---@param notice? string
local function updateDebugToolNui(activeSession, notice)
    if not activeSession.isDebugTool or not activeSession.debugTool then return end

    sendLocaleToNui()

    local tool = activeSession.debugTool

    -- The setup panel shows target values rather than the visibly interpolated
    -- values. This makes the readout and the 1/2/3 save keys react immediately
    -- even while the prop is still smoothly catching up through Lerp.
    local rotation = activeSession.targetRotation
        or activeSession.currentRotation
        or { x = 0.0, y = 0.0, z = 0.0 }
    local distance = activeSession.targetDistance or activeSession.currentDistance or 0.0
    local minDistance = tonumber(tool.minDistance) or 0.0
    local defaultDistance = tonumber(tool.defaultDistance) or 0.0
    local maxDistance = tonumber(tool.maxDistance) or 0.0

    SendNUIMessage({
        action = 'debugToolUpdate',
        visible = true,
        spotIndex = activeSession.spotIndex,
        propIndex = activeSession.propIndex,
        propTotal = #activeSession.spot.inspectProps,
        mode = tool.mode or 'default',
        rotation = {
            x = rotation.x or 0.0,
            y = rotation.y or 0.0,
            z = rotation.z or 0.0
        },
        distance = distance,
        minDistance = minDistance,
        defaultDistance = defaultDistance,
        maxDistance = maxDistance,
        zoomValid = minDistance <= defaultDistance and defaultDistance <= maxDistance,
        lastSaved = tool.lastSaved,
        tolerance = tool.tolerance or 15.0,
        previewSet = tool.previewHotspot ~= nil,
        previewMatched = tool.previewMatched == true,
        notice = notice
    })
end

---Immediately hides the development-only authoring panel.
local function hideDebugToolNui()
    SendNUIMessage({ action = 'debugToolHide' })
end

---Returns the configured nearby interaction UI mode.
---@return string
local function getInteractUiMode()
    return string.lower(tostring(Config.InteractUI or 'native'))
end

---Shows or updates the custom script interaction prompt.
---A signature cache prevents sending the same NUI message every frame.
---@param label string
---@param locked boolean
local function showScriptInteract(label, locked)
    if getInteractUiMode() ~= 'script' then return end

    local signature = ('%s|%s'):format(label, locked and '1' or '0')
    if interactUiVisible and interactUiSignature == signature then return end

    -- The interaction prompt is another independent NUI entry point. Send the
    -- selected locale again only when the prompt state actually changes.
    sendLocaleToNui(true)

    interactUiVisible = true
    interactUiSignature = signature

    SendNUIMessage({
        action = 'showInteract',
        label = label,
        locked = locked == true
    })
end

---Hides the custom script interaction prompt.
---@param immediate? boolean
local function hideScriptInteract(immediate)
    if not interactUiVisible and immediate ~= true then return end

    interactUiVisible = false
    interactUiSignature = nil

    SendNUIMessage({
        action = immediate == true and 'forceHideInteract' or 'hideInteract'
    })
end

-- ---------------------------------------------------------------------------
-- World-prop streaming
-- ---------------------------------------------------------------------------

---Sets the local world prop visible/collidable or hidden for inspection.
---@param spotIndex number
---@param hidden boolean
local function setWorldPropHidden(spotIndex, hidden)
    local entity = worldProps[spotIndex]
    if not entity or not DoesEntityExist(entity) then return end

    SetEntityVisible(entity, not hidden, false)
    SetEntityCollision(entity, not hidden, not hidden)
    SetEntityAlpha(entity, hidden and 0 or 255, false)
end

---Spawns one configured world prop as a frozen local-only object.
---@param spotIndex number
---@param spot table
local function spawnWorldProp(spotIndex, spot)
    if not spot.worldProp then return end
    if worldProps[spotIndex] and DoesEntityExist(worldProps[spotIndex]) then return end

    local definition = spot.worldProp
    local loaded, hash = requestModel(definition.model, 5000)
    if not loaded then return end

    local coords = definition.coords or spot.coords
    local entity = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)

    if entity == 0 or not DoesEntityExist(entity) then
        debugPrint('Failed to create world prop for spot %s.', tostring(spotIndex))
        SetModelAsNoLongerNeeded(hash)
        return
    end

    SetEntityAsMissionEntity(entity, true, true)
    SetEntityHeading(entity, definition.heading or 0.0)
    FreezeEntityPosition(entity, true)
    SetEntityCanBeDamaged(entity, false)

    worldProps[spotIndex] = entity

    -- If this spot is currently being inspected, a freshly streamed prop must
    -- immediately inherit the hidden state instead of flashing for one frame.
    if session and session.active and session.spotIndex == spotIndex then
        setWorldPropHidden(spotIndex, true)
    end

    SetModelAsNoLongerNeeded(hash)
    debugPrint('Streamed world prop for spot %s.', tostring(spotIndex))
end

---Deletes one streamed world prop.
---@param spotIndex number
local function deleteWorldProp(spotIndex)
    deleteLocalEntity(worldProps[spotIndex])
    worldProps[spotIndex] = nil
end

---Deletes every local world prop owned by this resource.
local function deleteAllWorldProps()
    for spotIndex in pairs(worldProps) do
        deleteWorldProp(spotIndex)
    end
end

-- ---------------------------------------------------------------------------
-- Raycast safety
-- ---------------------------------------------------------------------------

---Calculates the maximum safe prop distance before a wall/geometry hit.
---The ray starts at the fixed camera and ends at the configured maxDistance.
---@param camCoord vector3
---@param camRotation vector3|table
---@param prop table
---@param ignoredEntity number
---@param distanceOverride? table Optional `{ minDistance, maxDistance }` for the authoring tool.
---@return number|nil safeMaxDistance
local function calculateSafeMaxDistance(camCoord, camRotation, prop, ignoredEntity, distanceOverride)
    distanceOverride = distanceOverride or {}
    local minDistance = tonumber(distanceOverride.minDistance) or tonumber(prop.minDistance) or 0.35
    local maxDistance = math.max(
        tonumber(distanceOverride.maxDistance) or tonumber(prop.maxDistance) or minDistance,
        minDistance
    )
    local forward = rotationToDirection(camRotation)
    local destination = camCoord + forward * maxDistance

    local handle = StartShapeTestLosProbe(
        camCoord.x, camCoord.y, camCoord.z,
        destination.x, destination.y, destination.z,
        Config.Camera.raycastFlags or 511,
        ignoredEntity,
        7
    )

    local status = 1
    local hit = false
    local endCoords = destination
    local deadline = GetGameTimer() + (Config.Camera.raycastTimeoutMs or 750)

    -- Async shape tests return status 1 while pending and status 2 when done.
    -- A timeout prevents a native edge case from blocking the inspection forever.
    while status == 1 and GetGameTimer() < deadline do
        Wait(0)
        status, hit, endCoords = GetShapeTestResult(handle)
    end

    if status ~= 2 then
        debugPrint('Raycast did not complete; refusing to spawn the inspect prop for safety.')
        return nil
    end

    if not hit then return maxDistance end

    local hitDistance = #(endCoords - camCoord)
    local safeDistance = hitDistance - (Config.Camera.raycastPadding or 0.12)

    if safeDistance < minDistance then
        debugPrint(
            'Inspection blocked by nearby geometry (safe %.2f < minimum %.2f).',
            safeDistance,
            minDistance
        )
        return nil
    end

    return math.min(safeDistance, maxDistance)
end

-- ---------------------------------------------------------------------------
-- Player animation and attached hand prop
-- ---------------------------------------------------------------------------

---Starts the optional player animation and creates the optional hand prop.
---@param activeSession table
local function startPlayerPresentation(activeSession)
    local animation = activeSession.spot.playerAnim
    if not animation then return end

    local ped = activeSession.ped

    if animation.dict and animation.name then
        if requestAnimDict(animation.dict, 5000) then
            TaskPlayAnim(
                ped,
                animation.dict,
                animation.name,
                4.0,
                -4.0,
                -1,
                animation.flag or 49,
                0.0,
                false,
                false,
                false
            )
            activeSession.animationStarted = true
        else
            debugPrint('Animation dictionary failed to load: %s', tostring(animation.dict))
        end
    end

    local attached = animation.attachProp
    if not attached then return end

    local loaded, hash = requestModel(attached.model, 5000)
    if not loaded then return end

    local pedCoords = GetEntityCoords(ped)
    local entity = CreateObjectNoOffset(hash, pedCoords.x, pedCoords.y, pedCoords.z, false, false, false)

    if entity ~= 0 and DoesEntityExist(entity) then
        local offset = attached.offset or vec3(0.0, 0.0, 0.0)
        local rotation = attached.rotation or vec3(0.0, 0.0, 0.0)
        local boneIndex = GetPedBoneIndex(ped, attached.bone or 18905)

        SetEntityAsMissionEntity(entity, true, true)
        SetEntityCollision(entity, false, false)

        AttachEntityToEntity(
            entity,
            ped,
            boneIndex,
            offset.x, offset.y, offset.z,
            rotation.x, rotation.y, rotation.z,
            true,
            true,
            false,
            true,
            1,
            true
        )

        activeSession.handProp = entity
    end

    SetModelAsNoLongerNeeded(hash)
end

---Stops the optional player animation and deletes its separate attached prop.
---@param activeSession table
local function stopPlayerPresentation(activeSession)
    deleteLocalEntity(activeSession.handProp)
    activeSession.handProp = nil

    local animation = activeSession.spot.playerAnim
    if activeSession.animationStarted and animation and DoesEntityExist(activeSession.ped) then
        StopAnimTask(activeSession.ped, animation.dict, animation.name, 2.0)
    end
end

-- ---------------------------------------------------------------------------
-- Inspect prop creation and state
-- ---------------------------------------------------------------------------

---Creates the current inspect prop in front of the scripted camera.
---@param activeSession table
---@param prop table
---@return boolean
local function spawnInspectProp(activeSession, prop)
    local loaded, hash = requestModel(prop.model, 5000)
    if not loaded then return false end

    local forward, right = cameraBasis(activeSession.renderCamRot or activeSession.baseCamRot)
    local spawnPosition = (activeSession.renderCamCoord or activeSession.baseCamCoord)
        + forward * activeSession.currentDistance
        + right * (activeSession.switchOffset or 0.0)

    local entity = CreateObjectNoOffset(
        hash,
        spawnPosition.x,
        spawnPosition.y,
        spawnPosition.z,
        false,
        false,
        false
    )

    if entity == 0 or not DoesEntityExist(entity) then
        debugPrint('Failed to create inspect prop: %s', tostring(prop.model))
        SetModelAsNoLongerNeeded(hash)
        return false
    end

    SetEntityAsMissionEntity(entity, true, true)
    FreezeEntityPosition(entity, true)
    SetEntityCollision(entity, false, false)
    SetEntityCanBeDamaged(entity, false)
    SetEntityAlpha(entity, math.floor(activeSession.propAlpha or 255), false)

    activeSession.inspectProp = entity
    activeSession.inspectModelHash = hash

    SetModelAsNoLongerNeeded(hash)
    return true
end

---Resets motion state to a prop's configured defaults.
---@param activeSession table
---@param prop table
---@param safeMaxDistance number
local function resetMotionStateForProp(activeSession, prop, safeMaxDistance)
    local defaultRotation = copyRotation(prop.defaultRotation)
    local configuredMinDistance = tonumber(prop.minDistance) or 0.35
    local minDistance = math.min(configuredMinDistance, safeMaxDistance)
    local maxDistance = math.max(
        math.min(tonumber(prop.maxDistance) or minDistance, safeMaxDistance),
        minDistance
    )
    local defaultDistance = clamp(tonumber(prop.defaultDistance) or minDistance, minDistance, maxDistance)

    activeSession.safeMaxDistance = maxDistance
    activeSession.currentDistance = defaultDistance
    activeSession.targetDistance = defaultDistance
    activeSession.currentRotation = copyRotation(defaultRotation)
    activeSession.targetRotation = copyRotation(defaultRotation)
    activeSession.activeHotspotKey = nil

    updateNuiHotspot(false)
end

---Resets the development tool's captured zoom values for the active prop.
---The current prop config is copied so the user can adjust only the values they need.
---@param activeSession table
local function resetDebugToolStateForProp(activeSession)
    if not activeSession.isDebugTool then return end

    local prop = activeSession.propDefinition
    local toolConfig = Config.PropInspectTool or {}
    local minDistance = tonumber(prop.minDistance) or 0.35
    local maxDistance = math.min(tonumber(prop.maxDistance) or minDistance, activeSession.safeMaxDistance)
    local defaultDistance = clamp(tonumber(prop.defaultDistance) or minDistance, minDistance, maxDistance)

    activeSession.debugTool = activeSession.debugTool or {}
    activeSession.debugTool.mode = 'default'
    activeSession.debugTool.minDistance = minDistance
    activeSession.debugTool.defaultDistance = defaultDistance
    activeSession.debugTool.maxDistance = maxDistance
    activeSession.debugTool.lastSaved = nil
    activeSession.debugTool.tolerance = tonumber(activeSession.debugTool.tolerance)
        or tonumber(toolConfig.defaultTolerance)
        or 15.0

    -- A preview hotspot belongs to one specific prop. Clear it when the tool
    -- switches props so an old rotation can never be tested against a new model.
    activeSession.debugTool.previewHotspot = nil
    activeSession.debugTool.previewHotspotView = nil
    activeSession.debugTool.previewMatched = false
    activeSession.debugTool.previewWasMatched = false
    activeSession.debugTool.nextUiUpdate = 0
end

---Normalizes hotspot rotation matching mode.
---`view` compares the visible side of the prop and ignores twist around the
---camera-to-prop axis. `exact` keeps the legacy X/Y/Z Euler comparison.
---@param mode any
---@return string
local function normalizeHotspotMatchMode(mode)
    return string.lower(tostring(mode or 'view')) == 'exact' and 'exact' or 'view'
end

---Returns the direction from the prop toward the camera in the prop's LOCAL
---coordinate space. This is the key to twist-independent hotspot matching:
---rolling the prop upside down around the viewing axis does not change which
---local side points at the camera, so the same hotspot remains discoverable.
---@param activeSession table
---@return vector3|nil
local function getPropViewSignature(activeSession)
    local entity = activeSession.inspectProp
    if not entity or not DoesEntityExist(entity) then return nil end

    local cameraCoord = activeSession.renderCamCoord or activeSession.baseCamCoord
    local localCamera = GetOffsetFromEntityGivenWorldCoords(
        entity,
        cameraCoord.x,
        cameraCoord.y,
        cameraCoord.z
    )

    local signature = normalizeVector(vec3(localCamera.x, localCamera.y, localCamera.z))
    if #(signature) <= 0.000001 then return nil end
    return signature
end

---Builds a twist-independent view signature for one configured target rotation.
---The inspect entity is temporarily rotated before the first visible frame, the
---camera direction is converted into prop-local space, then the original entity
---rotation is restored immediately.
---@param activeSession table
---@param targetRotation vector3|table
---@return vector3|nil
local function captureTargetViewSignature(activeSession, targetRotation)
    local entity = activeSession.inspectProp
    if not entity or not DoesEntityExist(entity) then return nil end

    local originalRotation = GetEntityRotation(entity, 2)
    local cameraRotation = activeSession.renderCamRot or activeSession.baseCamRot
    local target = copyRotation(targetRotation)
    local worldRotation = composeCameraRelativeRotation(target, cameraRotation)

    SetEntityRotation(
        entity,
        worldRotation.x,
        worldRotation.y,
        worldRotation.z,
        2,
        true
    )

    local signature = getPropViewSignature(activeSession)

    SetEntityRotation(
        entity,
        originalRotation.x,
        originalRotation.y,
        originalRotation.z,
        2,
        true
    )

    return signature
end

---Prepares per-session hotspot matching data for the active inspect prop.
---Configured tables are never mutated; all derived values live in session state.
---@param activeSession table
local function prepareHotspotRuntime(activeSession)
    activeSession.hotspotRuntime = {}

    local hotspots = (activeSession.propDefinition and activeSession.propDefinition.hotspots) or {}
    for hotspotIndex, hotspot in ipairs(hotspots) do
        local runtime = {
            matchMode = normalizeHotspotMatchMode(hotspot.matchMode)
        }

        if runtime.matchMode == 'view' then
            if hotspot.targetView then
                runtime.targetView = normalizeVector(vec3(
                    hotspot.targetView.x or 0.0,
                    hotspot.targetView.y or 0.0,
                    hotspot.targetView.z or 0.0
                ))
            elseif hotspot.targetRotation then
                runtime.targetView = captureTargetViewSignature(activeSession, hotspot.targetRotation)
            end
        end

        activeSession.hotspotRuntime[hotspotIndex] = runtime
    end
end

---Activates and spawns an inspect prop by array index.
---@param activeSession table
---@param index number
---@return boolean
local function activateInspectProp(activeSession, index)
    local prop = activeSession.spot.inspectProps[index]
    if not prop then return false end

    local distanceOverride = nil
    if activeSession.isDebugTool then
        local toolConfig = Config.PropInspectTool or {}
        distanceOverride = {
            minDistance = tonumber(toolConfig.zoomMin) or 0.15,
            maxDistance = tonumber(toolConfig.zoomMax) or 4.0
        }
    end

    local safeMaxDistance = calculateSafeMaxDistance(
        activeSession.baseCamCoord,
        activeSession.baseCamRot,
        prop,
        activeSession.ped,
        distanceOverride
    )

    if not safeMaxDistance then return false end

    activeSession.propIndex = index
    activeSession.propDefinition = prop
    resetMotionStateForProp(activeSession, prop, safeMaxDistance)
    resetDebugToolStateForProp(activeSession)

    if not spawnInspectProp(activeSession, prop) then
        return false
    end

    prepareHotspotRuntime(activeSession)
    return true
end

-- ---------------------------------------------------------------------------
-- Camera animation and rendering
-- ---------------------------------------------------------------------------

---Applies subtle sinusoidal camera movement and stores the current camera basis.
---This is the cinematic "AnimateCamOp" layer requested for organic breathing.
---@param activeSession table
---@param gameTimeSeconds number
local function animateCamOp(activeSession, gameTimeSeconds)
    local breathing = Config.Camera.breathing or {}
    local baseCoord = activeSession.baseCamCoord
    local baseRotation = activeSession.baseCamRot
    local camCoord = baseCoord
    local camRotation = vec3(baseRotation.x, baseRotation.y, baseRotation.z)

    if breathing.enabled then
        local speed = breathing.speed or 0.72
        local positionAmplitude = breathing.positionAmplitude or 0.0045
        local rotationAmplitude = breathing.rotationAmplitude or 0.085
        local phase = gameTimeSeconds * speed * math.pi * 2.0

        local _, right, up = cameraBasis(baseRotation)
        local horizontal = math.sin(phase * 0.53) * positionAmplitude
        local vertical = math.sin(phase) * positionAmplitude

        camCoord = baseCoord + right * horizontal + up * vertical
        camRotation = vec3(
            baseRotation.x + math.sin(phase * 0.81) * rotationAmplitude,
            baseRotation.y,
            baseRotation.z + math.cos(phase * 0.47) * rotationAmplitude * 0.55
        )
    end

    activeSession.renderCamCoord = camCoord
    activeSession.renderCamRot = camRotation

    SetCamCoord(activeSession.cam, camCoord.x, camCoord.y, camCoord.z)
    SetCamRot(activeSession.cam, camRotation.x, camRotation.y, camRotation.z, 2)
end

---Applies the configured DOF and local camera light for the current frame.
---@param activeSession table
local function drawInspectionEffects(activeSession)
    if Config.EnableDOF then
        -- SET_USE_HI_DOF is a per-frame native; the other DOF values are set at start.
        SetUseHiDof()
    end

    local light = Config.CameraLight
    if not light or not light.enabled then return end

    local forward = rotationToDirection(activeSession.renderCamRot)
    local lightPosition = activeSession.renderCamCoord + forward * (light.forwardOffset or 0.12)
    local color = light.color or { r = 255, g = 242, b = 220 }

    DrawLightWithRange(
        lightPosition.x,
        lightPosition.y,
        lightPosition.z,
        color.r or 255,
        color.g or 255,
        color.b or 255,
        light.range or 3.0,
        light.intensity or 1.35
    )
end

-- ---------------------------------------------------------------------------
-- Input, inertia and switch animation
-- ---------------------------------------------------------------------------

---Returns a clean angle for copy-ready config output.
---The special case keeps positive 180 as 180 instead of displaying -180.
---@param angle number
---@return number
local function configDisplayAngle(angle)
    local normalized = normalizeAngle(angle)
    if math.abs(normalized + 180.0) < 0.005 and angle > 0.0 then
        return 180.0
    end
    return normalized
end

---Prints the current authoring-tool values in ready-to-paste Lua syntax.
---@param activeSession table
local function printDebugToolValues(activeSession)
    local tool = activeSession.debugTool
    if not tool then return end

    -- Hotspot export uses the saved preview rotation, not the prop's current
    -- rotation. This guarantees that the exact value tested in preview mode is
    -- the same value copied into config.lua.
    local rotation
    if tool.mode == 'hotspot' then
        if not tool.previewHotspot then
            updateDebugToolNui(activeSession, translate('debugTool.hotspotSetFirst'))
            return
        end

        rotation = tool.previewHotspot
    else
        -- Default rotation export uses the exact authored target value. The
        -- visible prop may still be catching up because rendering remains smooth.
        rotation = activeSession.targetRotation or activeSession.currentRotation
    end

    local x = configDisplayAngle(rotation.x or 0.0)
    local y = configDisplayAngle(rotation.y or 0.0)
    local z = configDisplayAngle(rotation.z or 0.0)

    local modeLabel = tool.mode == 'hotspot'
        and translate('nui.debug.hotspot')
        or translate('nui.debug.standard')

    print(('^5[%s] %s^7 %s %d | %s %d | %s'):format(
        RESOURCE_NAME,
        translate('nui.debug.developmentTool'),
        translate('nui.debug.spot'),
        activeSession.spotIndex,
        translate('nui.debug.prop'),
        activeSession.propIndex,
        modeLabel
    ))

    if tool.mode == 'hotspot' then
        print('hotspots = {')
        print('    {')
        print("        matchMode = 'view',")
        print(('        targetRotation = vector3(%.2f, %.2f, %.2f),'):format(x, y, z))
        print(('        tolerance = %.1f,'):format(tool.tolerance or 15.0))
        print(("        subDescription = '%s',"):format(translate('debugTool.placeholderSubDescription')))
        print('    }')
        print('}')
    else
        print(('defaultRotation = vector3(%.2f, %.2f, %.2f),'):format(x, y, z))
        print(('defaultDistance = %.2f,'):format(tool.defaultDistance or activeSession.currentDistance or 1.0))
        print(('minDistance = %.2f,'):format(tool.minDistance or 0.5))
        print(('maxDistance = %.2f,'):format(tool.maxDistance or 2.0))
    end

    local minDistance = tonumber(tool.minDistance) or 0.0
    local defaultDistance = tonumber(tool.defaultDistance) or 0.0
    local maxDistance = tonumber(tool.maxDistance) or 0.0
    local zoomValid = minDistance <= defaultDistance and defaultDistance <= maxDistance

    print(('^5[%s]^7 %s'):format(RESOURCE_NAME, translate('debugTool.valuesPrintedConsole')))

    if not zoomValid then
        print(('^3[%s] %s^7'):format(RESOURCE_NAME, translate('debugTool.invalidZoomOrder')))
        updateDebugToolNui(activeSession, translate('debugTool.invalidZoomOrder'))
    else
        updateDebugToolNui(activeSession, translate('debugTool.valuesPrinted'))
    end
end

---Handles the extra development-tool keys while normal inspect controls remain active.
---@param activeSession table
---@param deltaTime number
local function handleDebugToolControls(activeSession, deltaTime)
    if not activeSession.isDebugTool or not activeSession.debugTool then return end
    if activeSession.switchState then return end

    local controls = Config.Controls
    local tool = activeSession.debugTool
    local currentDistance = activeSession.targetDistance or activeSession.currentDistance or 1.0
    local toolConfig = Config.PropInspectTool or {}

    -- Mouse input already controls yaw (Z) and pitch (X). Q/E therefore edits
    -- the remaining roll axis (Y), which makes all three rotation values easy
    -- to author without fighting the normal left/right mouse movement.
    local rollSpeed = math.max(
        tonumber(toolConfig.rollSpeed) or tonumber(toolConfig.zRotationSpeed) or 90.0,
        1.0
    )
    if IsDisabledControlPressed(0, controls.debugRollLeft) then
        activeSession.targetRotation.y = activeSession.targetRotation.y - rollSpeed * deltaTime
    elseif IsDisabledControlPressed(0, controls.debugRollRight) then
        activeSession.targetRotation.y = activeSession.targetRotation.y + rollSpeed * deltaTime
    end

    if IsDisabledControlJustPressed(0, controls.debugMode) then
        tool.mode = tool.mode == 'hotspot' and 'default' or 'hotspot'

        -- Preview detection is paused in DEFAULT mode so standard-rotation
        -- authoring stays visually clean. The saved preview remains available
        -- and resumes automatically when HOTSPOT mode is selected again.
        if tool.mode ~= 'hotspot' then
            tool.previewMatched = false
            tool.previewWasMatched = false
            activeSession.activeHotspotKey = nil
            updateNuiHotspot(false)
        end

        updateDebugToolNui(
            activeSession,
            tool.mode == 'hotspot' and translate('debugTool.modeHotspot') or translate('debugTool.modeDefault')
        )
    end

    -- G captures the exact current target rotation as a temporary hotspot and
    -- immediately enters HOTSPOT mode. The player can now rotate away and back
    -- to verify the real tolerance/detection behavior before copying any values.
    if IsDisabledControlJustPressed(0, controls.debugSetHotspot) then
        -- Capture what is visibly on screen right now. Matching the target to
        -- the same value also stops any remaining inertia so the saved hotspot
        -- cannot drift a few degrees after the button is pressed.
        local capturedRotation = copyRotation(activeSession.currentRotation or activeSession.targetRotation)
        activeSession.targetRotation = copyRotation(capturedRotation)
        tool.previewHotspot = capturedRotation
        tool.previewHotspotView = getPropViewSignature(activeSession)
        tool.previewMatched = false
        tool.previewWasMatched = false
        tool.mode = 'hotspot'
        activeSession.activeHotspotKey = nil
        updateNuiHotspot(false)
        updateDebugToolNui(activeSession, translate('debugTool.hotspotSet'))
    end

    -- X removes only the temporary preview. No configured hotspot data is ever
    -- modified by the tool, so preview testing is completely non-destructive.
    if IsDisabledControlJustPressed(0, controls.debugClearHotspot) then
        tool.previewHotspot = nil
        tool.previewHotspotView = nil
        tool.previewMatched = false
        tool.previewWasMatched = false
        activeSession.activeHotspotKey = nil
        updateNuiHotspot(false)
        updateDebugToolNui(activeSession, translate('debugTool.hotspotCleared'))
    end

    -- Every save key changes exactly one value. Older versions automatically
    -- adjusted the other two values to keep them ordered, which made 1/2/3 look
    -- as if they all saved the same zoom. Validation now happens separately.
    if IsDisabledControlJustPressed(0, controls.debugSetMin) then
        tool.minDistance = currentDistance
        tool.lastSaved = 'min'
        updateDebugToolNui(activeSession, translate('debugTool.minSet'))
    end

    if IsDisabledControlJustPressed(0, controls.debugSetDefault) then
        tool.defaultDistance = currentDistance
        tool.lastSaved = 'default'
        updateDebugToolNui(activeSession, translate('debugTool.defaultSet'))
    end

    if IsDisabledControlJustPressed(0, controls.debugSetMax) then
        tool.maxDistance = currentDistance
        tool.lastSaved = 'max'
        updateDebugToolNui(activeSession, translate('debugTool.maxSet'))
    end

    local toleranceStep = math.max(tonumber(toolConfig.toleranceStep) or 1.0, 0.1)

    if IsDisabledControlJustPressed(0, controls.debugToleranceUp) then
        tool.tolerance = clamp((tool.tolerance or 15.0) + toleranceStep, 0.1, 180.0)
        updateDebugToolNui(activeSession, translate('debugTool.toleranceIncreased'))
    elseif IsDisabledControlJustPressed(0, controls.debugToleranceDown) then
        tool.tolerance = clamp((tool.tolerance or 15.0) - toleranceStep, 0.1, 180.0)
        updateDebugToolNui(activeSession, translate('debugTool.toleranceDecreased'))
    end

    if IsDisabledControlJustPressed(0, controls.debugPrint) then
        printDebugToolValues(activeSession)
    end
end

---Starts the old-prop-out/new-prop-in transition.
---@param activeSession table
---@param direction number -1 for previous, +1 for next
local function beginPropSwitch(activeSession, direction)
    local total = #activeSession.spot.inspectProps
    if total <= 1 or activeSession.switchState then return end

    local nextIndex = wrappedIndex(activeSession.propIndex, direction, total)
    local nextDefinition = activeSession.spot.inspectProps[nextIndex]

    -- Start loading the next model during the outgoing animation.
    RequestModel(getModelHash(nextDefinition.model))

    activeSession.switchState = {
        phase = 'out',
        direction = direction,
        nextIndex = nextIndex,
        elapsed = 0.0
    }

    activeSession.activeHotspotKey = nil
    updateNuiHotspot(false)
    playConfiguredSound(Config.Sounds.switch)
end

---Advances the lateral fade and damped bounce transition.
---@param activeSession table
---@param deltaTime number
---@return boolean success
local function updatePropSwitch(activeSession, deltaTime)
    local switch = activeSession.switchState
    if not switch then
        activeSession.switchOffset = 0.0
        activeSession.propAlpha = 255
        return true
    end

    local motion = Config.Motion

    if switch.phase == 'out' then
        switch.elapsed = switch.elapsed + deltaTime
        local duration = math.max(motion.switchOutDuration or 0.18, 0.01)
        local progress = clamp(switch.elapsed / duration, 0.0, 1.0)
        local eased = smoothstep(progress)

        activeSession.switchOffset = switch.direction * (motion.switchOffset or 0.48) * eased
        activeSession.propAlpha = math.floor(255.0 * (1.0 - progress))

        if progress >= 1.0 then
            deleteLocalEntity(activeSession.inspectProp)
            activeSession.inspectProp = nil

            if not activateInspectProp(activeSession, switch.nextIndex) then
                debugPrint('Could not activate inspect prop index %s.', tostring(switch.nextIndex))
                return false
            end

            updateNuiProp(
                activeSession.propDefinition,
                activeSession.propIndex,
                #activeSession.spot.inspectProps
            )

            if activeSession.isDebugTool then
                updateDebugToolNui(activeSession, translate('debugTool.propChanged'))
            end

            switch.phase = 'in'
            switch.elapsed = 0.0
            activeSession.switchOffset = -switch.direction * (motion.switchOffset or 0.48)
            activeSession.propAlpha = 0
        end

        return true
    end

    -- Incoming movement uses a damped cosine. The exponential envelope quickly
    -- kills the oscillation while the cosine creates a subtle spring/bounce.
    switch.elapsed = switch.elapsed + deltaTime
    local duration = math.max(motion.switchInDuration or 0.52, 0.01)
    local progress = clamp(switch.elapsed / duration, 0.0, 1.0)
    local damping = motion.bounceDamping or 7.5
    local frequency = motion.bounceFrequency or 12.0
    local envelope = math.exp(-damping * progress)
    local oscillation = math.cos(frequency * progress)

    activeSession.switchOffset = -switch.direction
        * (motion.switchOffset or 0.48)
        * envelope
        * oscillation
    activeSession.propAlpha = math.floor(255.0 * clamp(progress * 1.8, 0.0, 1.0))

    if progress >= 1.0 then
        activeSession.switchOffset = 0.0
        activeSession.propAlpha = 255
        activeSession.switchState = nil
    end

    return true
end

-- ---------------------------------------------------------------------------
-- Inspection input lock
-- ---------------------------------------------------------------------------

-- Explicit controls are kept here even though DisableAllControlActions is also
-- called. The redundancy is intentional: some gameplay/frontend actions are
-- evaluated in different control groups, and explicit blocking prevents ESC,
-- WASD or A/D from leaking through on heavily customized FiveM clients.
local INSPECTION_BLOCKED_CONTROLS = {
    -- Movement / locomotion.
    21, 22, 30, 31, 32, 33, 34, 35, 36,
    218, 219, 232, 233, 234, 235,
    266, 267, 268, 269,

    -- Combat / weapon actions.
    24, 25, 37, 45, 140, 141, 142, 143, 257, 263, 264,

    -- Pause / back / frontend actions.
    177, 194, 199, 200, 202
}

---Blocks gameplay and frontend controls for the current frame while keeping
---them readable through IsDisabledControl... / GetDisabledControlNormal.
local function blockInspectionControlsThisFrame()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)

    for _, control in ipairs(INSPECTION_BLOCKED_CONTROLS) do
        DisableControlAction(0, control, true)
        DisableControlAction(1, control, true)
        DisableControlAction(2, control, true)
    end

    -- FiveM/Cfx explicitly exposes this native for suppressing the frontend in
    -- the current frame. It prevents ESC from opening the pause/map screen.
    DisableFrontendThisFrame()
    SetPauseMenuActive(false)
    DisablePlayerFiring(PlayerId(), true)
end

---Returns true while any inspection key that could affect normal gameplay is
---still physically held down after leaving the workspace.
---@return boolean
local function isInspectionKeyStillHeld()
    local controls = Config.Controls

    return IsDisabledControlPressed(0, controls.closeBack)
        or IsDisabledControlPressed(0, controls.closePause)
        or IsDisabledControlPressed(0, controls.closeFrontend)
        or IsDisabledControlPressed(0, controls.previous)
        or IsDisabledControlPressed(0, controls.next)
        or IsDisabledControlPressed(0, controls.arrowLeft)
        or IsDisabledControlPressed(0, controls.arrowRight)
        or IsDisabledControlPressed(0, 30)
        or IsDisabledControlPressed(0, 31)
        or IsDisabledControlPressed(0, 32)
        or IsDisabledControlPressed(0, 33)
end

---Temporarily suppresses only inspection-related keys after closing. The lock
---ends as soon as the user releases them, with a hard timeout as a safety net.
local function suppressInspectionKeyCarryover()
    controlReleaseLockToken = controlReleaseLockToken + 1
    local token = controlReleaseLockToken

    CreateThread(function()
        local deadline = GetGameTimer() + 1000

        repeat
            Wait(0)

            -- Do not call DisableAllControlActions here: normal gameplay should
            -- immediately resume for unrelated controls after the inspect closes.
            for _, control in ipairs(INSPECTION_BLOCKED_CONTROLS) do
                DisableControlAction(0, control, true)
                DisableControlAction(1, control, true)
                DisableControlAction(2, control, true)
            end

            DisableFrontendThisFrame()
            SetPauseMenuActive(false)
        until token ~= controlReleaseLockToken
            or GetGameTimer() >= deadline
            or not isInspectionKeyStillHeld()
    end)
end

---Processes only the controls that belong to the inspection workspace.
---@param activeSession table
---@param deltaTime number
---@return boolean shouldClose
local function handleInspectionControls(activeSession, deltaTime)
    local controls = Config.Controls

    -- The inspection workspace blocks gameplay every frame. Disabled-control
    -- queries below still read the keys that belong to this workspace.
    blockInspectionControlsThisFrame()

    if IsDisabledControlJustPressed(0, controls.closeBack)
        or IsDisabledControlJustPressed(0, controls.closePause)
        or IsDisabledControlJustPressed(0, controls.closeFrontend) then
        return true
    end

    handleDebugToolControls(activeSession, deltaTime)

    if not activeSession.switchState then
        if IsDisabledControlJustPressed(0, controls.previous)
            or IsDisabledControlJustPressed(0, controls.arrowLeft) then
            beginPropSwitch(activeSession, -1)
        elseif IsDisabledControlJustPressed(0, controls.next)
            or IsDisabledControlJustPressed(0, controls.arrowRight) then
            beginPropSwitch(activeSession, 1)
        end
    end

    local prop = activeSession.propDefinition
    if not prop then return false end

    local minDistance
    local maxDistance

    if activeSession.isDebugTool then
        local toolConfig = Config.PropInspectTool or {}
        minDistance = math.max(tonumber(toolConfig.zoomMin) or 0.15, 0.05)
        maxDistance = math.min(
            math.max(tonumber(toolConfig.zoomMax) or 4.0, minDistance),
            activeSession.safeMaxDistance
        )
    else
        minDistance = tonumber(prop.minDistance) or 0.35
        maxDistance = math.min(tonumber(prop.maxDistance) or minDistance, activeSession.safeMaxDistance)
    end

    local zoomStep = Config.Motion.zoomStep or 0.16
    if activeSession.isDebugTool then
        local toolConfig = Config.PropInspectTool or {}
        local fineZoom = IsDisabledControlPressed(0, controls.debugFineZoom)
        zoomStep = fineZoom
            and math.max(tonumber(toolConfig.fineZoomStep) or 0.01, 0.001)
            or math.max(tonumber(toolConfig.zoomStep) or 0.10, 0.001)
    end

    if IsDisabledControlJustPressed(0, controls.zoomIn) then
        activeSession.targetDistance = clamp(
            activeSession.targetDistance - zoomStep,
            minDistance,
            maxDistance
        )
    elseif IsDisabledControlJustPressed(0, controls.zoomOut) then
        activeSession.targetDistance = clamp(
            activeSession.targetDistance + zoomStep,
            minDistance,
            maxDistance
        )
    end

    if IsDisabledControlJustPressed(0, controls.reset) then
        local defaultRotation = copyRotation(prop.defaultRotation)
        activeSession.targetRotation = {
            x = nearestEquivalentAngle(activeSession.currentRotation.x, defaultRotation.x),
            y = nearestEquivalentAngle(activeSession.currentRotation.y, defaultRotation.y),
            z = nearestEquivalentAngle(activeSession.currentRotation.z, defaultRotation.z)
        }
        activeSession.targetDistance = clamp(
            tonumber(prop.defaultDistance) or minDistance,
            minDistance,
            maxDistance
        )
        playConfiguredSound(Config.Sounds.reset)
    end

    -- Rotation happens only while Left Mouse is held. Mouse input changes a
    -- target rotation; the visible prop follows it through the inertia Lerp.
    if not activeSession.switchState and IsDisabledControlPressed(0, controls.rotateHold) then
        local mouseX = GetDisabledControlNormal(0, controls.mouseX)
        local mouseY = GetDisabledControlNormal(0, controls.mouseY)
        local inertia = clamp(tonumber(prop.inertia) or 0.0, 0.0, 0.95)
        local inputWeight = 1.0 - inertia * 0.45
        local frameScale = clamp(deltaTime * 60.0, 0.0, 3.0)
        local sensitivity = (Config.Motion.mouseSensitivity or 150.0) * inputWeight * frameScale
        local horizontalSign, verticalSign = getMouseAxisSigns()
        local limits = nil
        if not activeSession.isDebugTool then
            limits = getRotationLimits(prop)
        end

        -- Natural object-viewer mapping:
        --   mouse left/right -> yaw around local Z
        --   mouse up/down    -> pitch around local X
        --
        -- Horizontal input is inverted so the prop follows the direction in
        -- which the player drags it, like grabbing a physical object.
        local nextZ = activeSession.targetRotation.z - mouseX * sensitivity * horizontalSign
        local nextX = activeSession.targetRotation.x - mouseY * sensitivity * verticalSign

        if limits then
            activeSession.targetRotation.z = clamp(nextZ, limits.minZ, limits.maxZ)
            activeSession.targetRotation.x = clamp(nextX, limits.minX, limits.maxX)
        else
            -- The authoring tool intentionally stays unrestricted so unusual
            -- objects and exact backside rotations can always be reached.
            activeSession.targetRotation.z = nextZ
            activeSession.targetRotation.x = nextX
        end
    end

    return false
end

---Updates current rotation and zoom using frame-rate independent interpolation.
---@param activeSession table
---@param deltaTime number
local function updateInterpolatedMotion(activeSession, deltaTime)
    local prop = activeSession.propDefinition
    local inertia = clamp(tonumber(prop.inertia) or 0.0, 0.0, 0.95)

    -- Higher inertia reduces response speed. The target remains where input left
    -- it, so the visible prop continues catching up after the mouse is released.
    local inertiaResponse = math.max(0.16, 1.0 - inertia * 0.82)
    local rotationSpeed = (Config.Motion.rotationLerpSpeed or 13.0) * inertiaResponse

    -- X/Y stay unwrapped during interpolation. This is important at the exact
    -- ±180° back-facing position: shortest-angle interpolation would otherwise
    -- normalize 180° to -180° and can feel like an artificial stop or snap.
    activeSession.currentRotation.x = expLerp(
        activeSession.currentRotation.x,
        activeSession.targetRotation.x,
        rotationSpeed,
        deltaTime
    )
    activeSession.currentRotation.y = expLerp(
        activeSession.currentRotation.y,
        activeSession.targetRotation.y,
        rotationSpeed,
        deltaTime
    )
    activeSession.currentRotation.z = expLerp(
        activeSession.currentRotation.z,
        activeSession.targetRotation.z,
        rotationSpeed,
        deltaTime
    )

    activeSession.currentDistance = expLerp(
        activeSession.currentDistance,
        activeSession.targetDistance,
        Config.Motion.zoomLerpSpeed or 10.0,
        deltaTime
    )
end

---Converts the configured/local inspect rotation into a camera-relative world rotation.
---
---`defaultRotation` and all mouse input are intentionally stored in local inspect
---space. At render time it is composed with the complete camera rotation.
---This fixes both the front/back heading bug and the up/down pitch mismatch.
---
---The prop therefore keeps the same visual default orientation in front of
---the camera regardless of horizontal heading or vertical look angle.
---@param activeSession table
---@return table rotation
local function getCameraRelativePropRotation(activeSession)
    local localRotation = activeSession.currentRotation
    local cameraRotation = activeSession.renderCamRot or activeSession.baseCamRot
    return composeCameraRelativeRotation(localRotation, cameraRotation)
end

---Moves/rotates the local inspect prop from the current interpolated state.
---@param activeSession table
local function applyInspectPropTransform(activeSession)
    local entity = activeSession.inspectProp
    if not entity or not DoesEntityExist(entity) then return end

    local forward, right = cameraBasis(activeSession.renderCamRot)
    local position = activeSession.renderCamCoord
        + forward * activeSession.currentDistance
        + right * (activeSession.switchOffset or 0.0)

    -- Keep all configured rotations camera-relative. This makes the first visible
    -- side deterministic even if the player starts the inspection facing away.
    local worldRotation = getCameraRelativePropRotation(activeSession)

    SetEntityCoordsNoOffset(entity, position.x, position.y, position.z, false, false, false)
    SetEntityRotation(
        entity,
        worldRotation.x,
        worldRotation.y,
        worldRotation.z,
        2,
        true
    )
    SetEntityAlpha(entity, clamp(math.floor(activeSession.propAlpha or 255), 0, 255), false)
end

-- ---------------------------------------------------------------------------
-- Hotspot detection
-- ---------------------------------------------------------------------------

---Calculates the angle in degrees between two normalized vectors.
---@param a vector3
---@param b vector3
---@return number
local function vectorAngle(a, b)
    local dot = clamp(a.x * b.x + a.y * b.y + a.z * b.z, -1.0, 1.0)
    return math.deg(math.acos(dot))
end

---Evaluates one hotspot and returns whether it matches plus a selection score.
---Offset hotspots use a camera cone. Rotation hotspots support two modes:
---  view  = same visible prop side, ignoring upside-down twist around the view axis
---  exact = legacy wrapped X/Y/Z Euler comparison
---@param activeSession table
---@param hotspot table
---@param runtime? table Precomputed per-session hotspot data.
---@return boolean matched
---@return number score
local function evaluateHotspot(activeSession, hotspot, runtime)
    local hasRule = false
    local matched = true
    local score = 0.0
    local tolerance = math.max(tonumber(hotspot.tolerance) or 10.0, 0.1)

    if hotspot.offset then
        hasRule = true
        local entity = activeSession.inspectProp
        local worldPoint = GetOffsetFromEntityInWorldCoords(
            entity,
            hotspot.offset.x,
            hotspot.offset.y,
            hotspot.offset.z
        )
        local toHotspot = normalizeVector(worldPoint - activeSession.renderCamCoord)
        local cameraForward = rotationToDirection(activeSession.renderCamRot)
        local angle = vectorAngle(cameraForward, toHotspot)

        matched = matched and angle <= tolerance
        score = math.max(score, angle)
    end

    if hotspot.targetRotation or hotspot.targetView then
        hasRule = true

        local matchMode = (runtime and runtime.matchMode)
            or normalizeHotspotMatchMode(hotspot.matchMode)

        if matchMode == 'view' then
            local targetView = runtime and runtime.targetView or nil

            if not targetView and hotspot.targetView then
                targetView = normalizeVector(vec3(
                    hotspot.targetView.x or 0.0,
                    hotspot.targetView.y or 0.0,
                    hotspot.targetView.z or 0.0
                ))
            end

            local currentView = getPropViewSignature(activeSession)
            if targetView and currentView then
                -- Comparing prop-local camera directions detects the visible side
                -- without caring about twist around that direction. A phone can
                -- therefore be upside down and still reveal its back hotspot.
                local viewAngle = vectorAngle(currentView, targetView)
                matched = matched and viewAngle <= tolerance
                score = math.max(score, viewAngle)
            else
                matched = false
                score = math.max(score, 180.0)
            end
        else
            local target = hotspot.targetRotation
            if not target then
                matched = false
                score = math.max(score, 180.0)
            else
                local dx = math.abs(shortestAngleDelta(activeSession.currentRotation.x, target.x))
                local dy = math.abs(shortestAngleDelta(activeSession.currentRotation.y, target.y))
                local dz = math.abs(shortestAngleDelta(activeSession.currentRotation.z, target.z))
                local angularDistance = math.sqrt(dx * dx + dy * dy + dz * dz)

                matched = matched and angularDistance <= tolerance
                score = math.max(score, angularDistance)
            end
        end
    end

    return hasRule and matched, score
end

---Finds the best matching hotspot and updates NUI only when it changes.
---@param activeSession table
local function updateHotspots(activeSession)
    if activeSession.switchState
        or not activeSession.inspectProp
        or not DoesEntityExist(activeSession.inspectProp) then
        if activeSession.activeHotspotKey then
            activeSession.activeHotspotKey = nil
            updateNuiHotspot(false)
        end

        if activeSession.isDebugTool and activeSession.debugTool then
            activeSession.debugTool.previewMatched = false
            activeSession.debugTool.previewWasMatched = false
        end
        return
    end

    -- Development preview path ------------------------------------------------
    -- The setup tool intentionally ignores configured hotspots. G saves one
    -- temporary rotation, then this exact same detection formula is evaluated
    -- live while the user rotates away and back. This makes the preview a real
    -- test of the production hotspot behavior instead of a cosmetic mockup.
    if activeSession.isDebugTool then
        local tool = activeSession.debugTool
        local previewRotation = tool
            and tool.mode == 'hotspot'
            and tool.previewHotspot
            or nil
        local previewView = tool
            and tool.mode == 'hotspot'
            and tool.previewHotspotView
            or nil

        if not previewRotation or not previewView then
            if tool then
                tool.previewMatched = false
                tool.previewWasMatched = false
            end

            if activeSession.activeHotspotKey then
                activeSession.activeHotspotKey = nil
                updateNuiHotspot(false)
            end
            return
        end

        local matched = evaluateHotspot(activeSession, {
            matchMode = 'view',
            targetRotation = previewRotation,
            targetView = previewView,
            tolerance = tool.tolerance or 15.0
        })

        local previewKey = matched and 'debug-preview' or nil
        local changed = previewKey ~= activeSession.activeHotspotKey

        tool.previewMatched = matched

        if changed then
            activeSession.activeHotspotKey = previewKey

            if matched then
                updateNuiHotspot(true, translate('debugTool.previewSubDescription'))
            else
                updateNuiHotspot(false)
            end
        end

        -- In preview mode the discovery sound plays each time the user leaves
        -- the valid angle and successfully finds it again. This makes testing
        -- tolerance boundaries much easier than a one-time discovery flag.
        if matched and not tool.previewWasMatched then
            playConfiguredSound(Config.Sounds.hotspot)
        end

        tool.previewWasMatched = matched
        return
    end

    -- Normal gameplay hotspot path -------------------------------------------
    local hotspots = activeSession.propDefinition.hotspots or {}
    local bestIndex = nil
    local bestScore = math.huge

    for hotspotIndex, hotspot in ipairs(hotspots) do
        local runtime = activeSession.hotspotRuntime and activeSession.hotspotRuntime[hotspotIndex] or nil
        local matched, score = evaluateHotspot(activeSession, hotspot, runtime)
        if matched and score < bestScore then
            bestIndex = hotspotIndex
            bestScore = score
        end
    end

    local key = bestIndex and ('%d:%d'):format(activeSession.propIndex, bestIndex) or nil
    if key == activeSession.activeHotspotKey then return end

    activeSession.activeHotspotKey = key

    if not bestIndex then
        updateNuiHotspot(false)
        return
    end

    local hotspot = hotspots[bestIndex]
    updateNuiHotspot(true, hotspot.subDescription or '')

    if not activeSession.discoveredHotspots[key] then
        activeSession.discoveredHotspots[key] = true
        playConfiguredSound(Config.Sounds.hotspot)
    end
end

-- ---------------------------------------------------------------------------
-- Inspection lifecycle
-- ---------------------------------------------------------------------------

---Creates the fixed camera workspace and configures optional DOF.
---@param activeSession table
---@return boolean
local function createInspectionCamera(activeSession)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    if not cam or cam == 0 then return false end

    activeSession.cam = cam

    SetCamCoord(cam, activeSession.baseCamCoord.x, activeSession.baseCamCoord.y, activeSession.baseCamCoord.z)
    SetCamRot(cam, activeSession.baseCamRot.x, activeSession.baseCamRot.y, activeSession.baseCamRot.z, 2)
    SetCamFov(cam, activeSession.baseFov + (Config.Camera.fovOffset or 0.0))

    if Config.EnableDOF then
        local dof = Config.Camera.dof or {}
        SetCamUseShallowDofMode(cam, true)
        SetCamNearDof(cam, dof.nearDof or 0.18)
        SetCamFarDof(cam, dof.farDof or 2.8)
        SetCamDofStrength(cam, dof.strength or 0.72)
    end

    SetCamActive(cam, true)
    RenderScriptCams(true, true, Config.Camera.transitionInMs or 450, true, true)
    return true
end

---The only per-frame camera/input loop. It is created on open and exits on close.
---@param activeSession table
local function runInspectionLoop(activeSession)
    CreateThread(function()
        local lastFrameTime = GetGameTimer()

        while session == activeSession and activeSession.active do
            Wait(0)

            -- GTA's native HUD/radar must be hidden every frame. This is separate
            -- from Config.Hud.Disable(), which is intended for external NUI HUDs.
            if (Config.Hud or {}).hideNativeHud == true then
                HideHudAndRadarThisFrame()
            end

            local now = GetGameTimer()
            local deltaTime = clamp((now - lastFrameTime) / 1000.0, 0.0, 0.05)
            lastFrameTime = now

            if not DoesEntityExist(activeSession.ped) or IsEntityDead(activeSession.ped) then
                stopInspection(false, true)
                deleteAllWorldProps()
                break
            end

            if handleInspectionControls(activeSession, deltaTime) then
                stopInspection(true, false)
                break
            end

            if not updatePropSwitch(activeSession, deltaTime) then
                stopInspection(false, true)
                break
            end

            updateInterpolatedMotion(activeSession, deltaTime)
            animateCamOp(activeSession, now / 1000.0)
            applyInspectPropTransform(activeSession)
            updateHotspots(activeSession)
            drawInspectionEffects(activeSession)

            if activeSession.isDebugTool and activeSession.debugTool then
                local updateInterval = math.max(
                    tonumber((Config.PropInspectTool or {}).updateIntervalMs) or 50,
                    16
                )

                if now >= (activeSession.debugTool.nextUiUpdate or 0) then
                    activeSession.debugTool.nextUiUpdate = now + updateInterval
                    updateDebugToolNui(activeSession)
                end
            end

            -- Prevent GTA's idle cinematic camera while the workspace is active.
            InvalidateIdleCam()
            InvalidateVehicleIdleCam()
        end
    end)
end

---Starts an inspection for one configured spot.
---@param spotIndex number
---@param options? table Development options such as `{ debugTool = true, propIndex = 2 }`.
---@return boolean
startInspection = function(spotIndex, options)
    if session then return false end
    options = options or {}

    -- The nearby prompt must disappear before the cinematic inspection UI opens.
    interactUiBlockedUntil = GetGameTimer() + 700
    hideScriptInteract(false)

    local spot = Config.Spots[spotIndex]
    if not spot then return false end
    if spot.isLocked and options.debugTool ~= true then return false end
    if not spot.inspectProps or #spot.inspectProps == 0 then
        debugPrint('Spot %s has no inspectProps.', tostring(spotIndex))
        return false
    end

    local initialPropIndex = clamp(
        math.floor(tonumber(options.propIndex) or 1),
        1,
        #spot.inspectProps
    )

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then
        return false
    end

    -- Hide before raycasting so the world representation itself cannot block the ray.
    setWorldPropHidden(spotIndex, true)

    local activeSession = {
        active = true,
        isDebugTool = options.debugTool == true,
        spotIndex = spotIndex,
        spot = spot,
        ped = ped,
        playerId = PlayerId(),
        playerControlWasOn = IsPlayerControlOn(PlayerId()),
        pedWasFrozen = IsEntityPositionFrozen(ped),
        baseCamCoord = GetGameplayCamCoord(),
        baseCamRot = GetGameplayCamRot(2),
        baseFov = GetGameplayCamFov(),
        renderCamCoord = GetGameplayCamCoord(),
        renderCamRot = GetGameplayCamRot(2),
        propIndex = initialPropIndex,
        propAlpha = 255,
        switchOffset = 0.0,
        switchState = nil,
        discoveredHotspots = {},
        hudVisibilityChanged = false,
        debugTool = options.debugTool == true and {
            mode = 'default',
            tolerance = tonumber((Config.PropInspectTool or {}).defaultTolerance) or 15.0,
            nextUiUpdate = 0
        } or nil
    }

    -- Establish session ownership early so cleanup can safely unwind any failure.
    session = activeSession

    if not activateInspectProp(activeSession, initialPropIndex) then
        stopInspection(false, true)
        return false
    end

    if not createInspectionCamera(activeSession) then
        stopInspection(false, true)
        return false
    end

    FreezeEntityPosition(ped, true)

    -- FreezeEntityPosition stops translation, but the player's locomotion state
    -- can still visually react to movement keys on some servers. Disabling player
    -- control prevents walk/run-in-place while raw disabled inputs remain readable
    -- by the inspection workspace.
    if activeSession.playerControlWasOn then
        SetPlayerControl(activeSession.playerId, false, 0)
    end

    -- Hide external HUDs once the inspection workspace is fully established.
    -- The matching Enable callback is guaranteed by stopInspection(), including
    -- death, resource stop and all other cleanup paths.
    setInspectionHudHidden(activeSession, true)

    -- The development tool should not start gameplay presentation animations or
    -- attach hand props; it is only for tuning the isolated inspect object.
    if not activeSession.isDebugTool then
        startPlayerPresentation(activeSession)
    end

    openNui(activeSession.propDefinition, initialPropIndex, #spot.inspectProps)

    if activeSession.isDebugTool then
        updateDebugToolNui(activeSession, translate('debugTool.active'))
    else
        hideDebugToolNui()
    end

    playConfiguredSound(Config.Sounds.open)
    runInspectionLoop(activeSession)

    debugPrint(
        'Started %s at spot %s, prop %s.',
        activeSession.isDebugTool and 'Prop Inspect Tool' or 'inspection',
        tostring(spotIndex),
        tostring(initialPropIndex)
    )
    return true
end

---Closes the current inspection and restores every local state change.
---@param playCloseSound boolean
---@param immediate boolean
stopInspection = function(playCloseSound, immediate)
    local activeSession = session
    if not activeSession then
        closeNui(immediate == true)
        return
    end

    -- Keep the nearby interaction prompt hidden until the cinematic outro is done.
    interactUiBlockedUntil = GetGameTimer()
        + (immediate and 0 or ((Config.Camera.transitionOutMs or 350) + 150))

    -- Clear the global owner first; the per-frame thread stops on its next check.
    session = nil
    activeSession.active = false

    if playCloseSound then
        playConfiguredSound(Config.Sounds.close)
    end

    closeNui(immediate == true)
    updateNuiHotspot(false)
    hideDebugToolNui()

    deleteLocalEntity(activeSession.inspectProp)
    activeSession.inspectProp = nil

    stopPlayerPresentation(activeSession)
    setInspectionHudHidden(activeSession, false)

    if activeSession.cam and DoesCamExist(activeSession.cam) then
        SetCamUseShallowDofMode(activeSession.cam, false)
        RenderScriptCams(
            false,
            not immediate,
            immediate and 0 or (Config.Camera.transitionOutMs or 350),
            true,
            true
        )
        DestroyCam(activeSession.cam, false)
    else
        RenderScriptCams(false, false, 0, true, true)
    end

    if DoesEntityExist(activeSession.ped) then
        FreezeEntityPosition(activeSession.ped, activeSession.pedWasFrozen == true)
    end

    -- Restore the player's original control state only if this resource disabled
    -- it. This avoids overriding another resource that already had control locked.
    if activeSession.playerControlWasOn then
        SetPlayerControl(activeSession.playerId or PlayerId(), true, 0)
    end

    -- ESC/A/D/W/S may still be physically held in the close frame. Suppress those
    -- specific keys until release so they cannot open the map or start movement.
    suppressInspectionKeyCarryover()

    setWorldPropHidden(activeSession.spotIndex, false)
    SetNuiFocus(false, false)

    debugPrint(
        'Closed %s at spot %s.',
        activeSession.isDebugTool and 'Prop Inspect Tool' or 'inspection',
        tostring(activeSession.spotIndex)
    )
end

-- ---------------------------------------------------------------------------
-- Interaction prompt and idle-efficient world streaming
-- ---------------------------------------------------------------------------

---Draws a native GTA help prompt for the current frame.
---@param text string
local function showHelpText(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- Low-frequency world streaming. This is intentionally separate from the
-- per-frame inspection loop and sleeps heavily when the player is far away.
CreateThread(function()
    while true do
        local ped = PlayerPedId()

        if not DoesEntityExist(ped) or IsEntityDead(ped) then
            deleteAllWorldProps()
            Wait(1000)
        else
            local playerCoords = GetEntityCoords(ped)
            local nextWait = 1250

            for spotIndex, spot in pairs(Config.Spots) do
                if spot.worldProp then
                    local worldCoords = spot.worldProp.coords or spot.coords
                    local distance = #(playerCoords - worldCoords)
                    local streamDistance = spot.worldProp.streamDistance or Config.WorldPropStreamDistance
                    local despawnDistance = spot.worldProp.despawnDistance or Config.WorldPropDespawnDistance
                    local entity = worldProps[spotIndex]

                    if distance <= streamDistance then
                        nextWait = math.min(nextWait, 500)
                        if not entity or not DoesEntityExist(entity) then
                            spawnWorldProp(spotIndex, spot)
                        end
                    elseif entity and DoesEntityExist(entity) and distance >= despawnDistance then
                        deleteWorldProp(spotIndex)
                    end
                end
            end

            Wait(nextWait)
        end
    end
end)

-- Adaptive interaction thread. It sleeps while far away and only becomes a
-- frame loop when the player is actually inside an interaction radius.
CreateThread(function()
    while true do
        if session then
            hideScriptInteract(false)
            Wait(500)
        elseif GetGameTimer() < interactUiBlockedUntil then
            hideScriptInteract(false)
            Wait(50)
        else
            local ped = PlayerPedId()

            if not DoesEntityExist(ped) or IsEntityDead(ped) then
                hideScriptInteract(false)
                Wait(1000)
            else
                local playerCoords = GetEntityCoords(ped)
                local closestIndex = nil
                local closestDistance = math.huge
                local nearestAnyDistance = math.huge

                for spotIndex, spot in pairs(Config.Spots) do
                    local distance = #(playerCoords - spot.coords)
                    nearestAnyDistance = math.min(nearestAnyDistance, distance)

                    if distance <= (spot.radius or 2.0) and distance < closestDistance then
                        closestIndex = spotIndex
                        closestDistance = distance
                    end
                end

                if closestIndex then
                    local spot = Config.Spots[closestIndex]
                    local firstProp = spot.inspectProps and spot.inspectProps[1]
                    local label = firstProp and firstProp.label or translate('fallback.object')
                    local uiMode = getInteractUiMode()

                    if uiMode == 'script' then
                        showScriptInteract(label, spot.isLocked == true)
                    else
                        -- Ensure a previously visible custom prompt cannot survive a live config reload.
                        hideScriptInteract(false)

                        if spot.isLocked then
                            showHelpText(translate('native.locked', label))
                        else
                            showHelpText(translate('native.inspect', label))
                        end
                    end

                    if not spot.isLocked and IsControlJustPressed(0, Config.Controls.interact) then
                        startInspection(closestIndex)
                    end

                    Wait(0)
                else
                    hideScriptInteract(false)

                    if nearestAnyDistance <= 20.0 then
                        Wait(100)
                    else
                        Wait(750)
                    end
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Debug markers and map blips
-- ---------------------------------------------------------------------------

---Creates one conspicuous debug blip per spot using the first prop label.
local function createDebugBlips()
    if not Config.Debug then return end

    for spotIndex, spot in pairs(Config.Spots) do
        local blip = AddBlipForCoord(spot.coords.x, spot.coords.y, spot.coords.z)
        local firstProp = spot.inspectProps and spot.inspectProps[1]
        local label = firstProp and firstProp.label or translate('fallback.inspectionSpot', spotIndex)

        SetBlipSprite(blip, Config.DebugBlip.sprite or 280)
        SetBlipColour(blip, Config.DebugBlip.color or 1)
        SetBlipScale(blip, Config.DebugBlip.scale or 1.0)
        SetBlipAsShortRange(blip, false)
        SetBlipFlashes(blip, Config.DebugBlip.flashes == true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(label)
        EndTextCommandSetBlipName(blip)

        debugBlips[#debugBlips + 1] = blip
    end
end

---Removes all debug blips owned by the resource.
local function removeDebugBlips()
    for _, blip in ipairs(debugBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    debugBlips = {}
end

if Config.Debug then
    CreateThread(function()
        createDebugBlips()

        while true do
            local ped = PlayerPedId()
            local playerCoords = DoesEntityExist(ped) and GetEntityCoords(ped) or vec3(0.0, 0.0, 0.0)
            local shouldDraw = false

            for _, spot in pairs(Config.Spots) do
                if #(playerCoords - spot.coords) <= Config.DebugDrawDistance then
                    shouldDraw = true
                    break
                end
            end

            if not shouldDraw then
                Wait(500)
            else
                for _, spot in pairs(Config.Spots) do
                    local distance = #(playerCoords - spot.coords)
                    if distance <= Config.DebugDrawDistance then
                        DrawMarker(
                            28,
                            spot.coords.x, spot.coords.y, spot.coords.z + 0.12,
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            0.22, 0.22, 0.22,
                            80, 255, 80, 210,
                            false, true, 2, false, nil, nil, false
                        )

                        if spot.worldProp then
                            local worldCoords = spot.worldProp.coords or spot.coords

                            DrawMarker(
                                28,
                                worldCoords.x, worldCoords.y, worldCoords.z + 0.08,
                                0.0, 0.0, 0.0,
                                0.0, 0.0, 0.0,
                                0.16, 0.16, 0.16,
                                255, 70, 70, 220,
                                false, true, 2, false, nil, nil, false
                            )

                            DrawLine(
                                spot.coords.x, spot.coords.y, spot.coords.z,
                                worldCoords.x, worldCoords.y, worldCoords.z,
                                255, 70, 70, 210
                            )
                        end
                    end
                end

                Wait(0)
            end
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Development-only Prop Inspect Tool command
-- ---------------------------------------------------------------------------

---Finds the closest configured spot to the local player.
---@return number|nil spotIndex
local function findNearestConfiguredSpot()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return nil end

    local playerCoords = GetEntityCoords(ped)
    local nearestIndex = nil
    local nearestDistance = math.huge

    for spotIndex, spot in pairs(Config.Spots) do
        if spot.coords then
            local distance = #(playerCoords - spot.coords)
            if distance < nearestDistance then
                nearestIndex = spotIndex
                nearestDistance = distance
            end
        end
    end

    return nearestIndex
end

---Registers the temporary authoring command when explicitly enabled in config.
---There is intentionally no ACE dependency; server owners should disable the
---tool after setup by setting `Config.PropInspectTool.enabled = false`.
local function registerPropInspectToolCommand()
    local tool = Config.PropInspectTool or {}
    if tool.enabled ~= true then return end

    local commandName = tostring(tool.command or 'propinspect')

    RegisterCommand(commandName, function(_, args)
        local firstArgument = string.lower(tostring(args[1] or ''))

        if firstArgument == 'close' then
            if session and session.isDebugTool then
                stopInspection(true, false)
            else
                print(('^3[%s]^7 %s'):format(RESOURCE_NAME, translate('debugTool.notOpen')))
            end
            return
        end

        if session then
            print(('^1[%s]^7 %s'):format(RESOURCE_NAME, translate('debugTool.closeCurrent', commandName)))
            return
        end

        local spotIndex = tonumber(args[1]) or findNearestConfiguredSpot()
        local propIndex = math.floor(tonumber(args[2]) or 1)
        local spot = spotIndex and Config.Spots[spotIndex] or nil

        if not spot then
            print(('^1[%s]^7 %s'):format(RESOURCE_NAME, translate('debugTool.invalidSpot', commandName)))
            return
        end

        if not spot.inspectProps or not spot.inspectProps[propIndex] then
            print(('^1[%s]^7 %s'):format(RESOURCE_NAME, translate(
                'debugTool.invalidProp',
                tostring(spotIndex),
                commandName,
                tostring(spotIndex)
            )))
            return
        end

        local started = startInspection(spotIndex, {
            debugTool = true,
            propIndex = propIndex
        })

        if started then
            print(('^5[%s] PROP INSPECT TOOL^7 %s'):format(RESOURCE_NAME, translate(
                'debugTool.opened',
                tostring(spotIndex),
                tostring(propIndex)
            )))
            print(('^7%s'):format(translate('debugTool.controls')))
            print(('^3[%s]^7 %s'):format(RESOURCE_NAME, translate('debugTool.disableAfterSetup')))
        end
    end, false)

    print(('^5[%s]^7 %s'):format(RESOURCE_NAME, translate('debugTool.commandEnabled', commandName)))
end

-- ---------------------------------------------------------------------------
-- Validation, exports, events and guaranteed cleanup
-- ---------------------------------------------------------------------------

---Prints configuration problems early instead of failing silently in gameplay.
local function validateConfig()
    local interactMode = getInteractUiMode()
    if interactMode ~= 'script' and interactMode ~= 'native' then
        debugPrint("WARNING: Config.InteractUI must be 'script' or 'native'; current value is '%s'.", interactMode)
    end

    if activeLocaleCode ~= requestedLocaleCode then
        debugPrint("WARNING: Locale '%s' does not exist. Falling back to '%s'.", requestedLocaleCode, activeLocaleCode)
    end

    for spotIndex, spot in pairs(Config.Spots) do
        if not spot.coords then
            debugPrint('WARNING: Spot %s has no coords.', tostring(spotIndex))
        end

        if not spot.inspectProps or #spot.inspectProps == 0 then
            debugPrint('WARNING: Spot %s has no inspectProps.', tostring(spotIndex))
        else
            for propIndex, prop in ipairs(spot.inspectProps) do
                local minDistance = tonumber(prop.minDistance) or 0.0
                local maxDistance = tonumber(prop.maxDistance) or 0.0

                if not prop.model then
                    debugPrint('WARNING: Spot %s prop %s has no model.', tostring(spotIndex), tostring(propIndex))
                end

                if maxDistance < minDistance then
                    debugPrint(
                        'WARNING: Spot %s prop %s maxDistance is below minDistance.',
                        tostring(spotIndex),
                        tostring(propIndex)
                    )
                end
            end
        end
    end
end

CreateThread(function()
    -- Force the fullscreen NUI and any scripted camera into a clean idle state
    -- when the resource starts or restarts. The CSS also hides the entire NUI
    -- document by default, so there is no visible frame before this message.
    SetNuiFocus(false, false)
    closeNui(true)
    hideScriptInteract(true)
    hideDebugToolNui()
    RenderScriptCams(false, false, 0, true, true)

    validateConfig()
    registerPropInspectToolCommand()
    debugPrint('Resource initialized. Camera/input render thread is inactive while idle.')
end)

-- Modular client exports for other standalone resources.
exports('StartInspection', function(spotIndex)
    return startInspection(tonumber(spotIndex))
end)

exports('CloseInspection', function()
    stopInspection(true, false)
end)

exports('IsInspecting', function()
    return session ~= nil
end)

exports('SetSpotLocked', function(spotIndex, locked)
    spotIndex = tonumber(spotIndex)
    if not Config.Spots[spotIndex] then return false end

    Config.Spots[spotIndex].isLocked = locked == true
    return true
end)

-- Equivalent client events for projects that prefer event-based integration.
RegisterNetEvent('ty-propinspection:client:start', function(spotIndex)
    startInspection(tonumber(spotIndex))
end)

RegisterNetEvent('ty-propinspection:client:close', function()
    stopInspection(true, false)
end)

RegisterNetEvent('ty-propinspection:client:setLocked', function(spotIndex, locked)
    spotIndex = tonumber(spotIndex)
    if Config.Spots[spotIndex] then
        Config.Spots[spotIndex].isLocked = locked == true
    end
end)

-- Resource restart/stop cleanup. All entities are local-only, so a full client
-- disconnect also destroys them automatically with the client entity context.
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= RESOURCE_NAME then return end

    stopInspection(false, true)
    deleteAllWorldProps()
    removeDebugBlips()
    closeNui(true)
    hideScriptInteract(true)
    hideDebugToolNui()
    RenderScriptCams(false, false, 0, true, true)
end)
