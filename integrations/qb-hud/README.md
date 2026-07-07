# Stock qb-hud visibility bridge

`ty-propinspection` already contains generic HUD callbacks in `Config.Hud`.
The current stock `qb-hud` main branch has no public hide/show API, so a one-time
bridge is required if you use the untouched upstream resource.

The bridge keeps the change small and does not affect normal qb-hud behavior.

## 1. Add one state variable

Open:

```text
qb-hud/client.lua
```

Near the other top-level local state variables, add:

```lua
local externalHudVisible = true
```

## 2. Add the visibility API

Place this block anywhere after the local variables and before the main HUD
update loop:

```lua
local function SetExternalHudState(visible)
    externalHudVisible = visible == true

    if not externalHudVisible then
        SendNUIMessage({ action = 'hudtick', show = false })
        SendNUIMessage({ action = 'car', show = false })
    end
end

RegisterNetEvent('qb-hud:client:SetHudState', SetExternalHudState)
exports('SetHudState', SetExternalHudState)
```

## 3. Change one line in the HUD update loop

Find this line inside the main HUD update thread:

```lua
local show = true
```

Replace it with:

```lua
local show = externalHudVisible
```

That is all the Prop Inspection resource needs. The included default callbacks
will automatically call:

```lua
exports['qb-hud']:SetHudState(false)
```

when inspection starts, and:

```lua
exports['qb-hud']:SetHudState(true)
```

when inspection ends.

## Important

After editing qb-hud, restart both resources:

```text
restart qb-hud
restart ty-propinspection
```

The Prop Inspection resource also calls `HideHudAndRadarThisFrame()` while the
inspection is active, so GTA's native HUD and radar are hidden independently of
qb-hud.
