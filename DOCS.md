# Prop Inspection System — Documentation

This document is the complete configuration and development guide for `ty-propinspection`.

## Table of Contents

1. Installation
2. Resource Structure
3. Quick Start
4. General Configuration
5. Localization
6. Interaction UI
7. HUD Integration
8. Inspection Background
9. World Prop Streaming
10. Motion, Lerp and Inertia
11. Rotation and Rotation Limits
12. Camera, DOF and Light
13. Sound Feedback
14. Creating Inspection Spots
15. Player Animations and Attached Hand Props
16. Inspect Prop Settings
17. Multiple Props and Switching
18. Hotspots
19. Prop Setup Tool (`/propinspect`)
20. Debug Mode and Blips
21. Exports and Client Events
22. Cleanup and Safety
23. Performance Notes
24. Troubleshooting

---

# 1. Installation

1. Copy the folder `ty-propinspection` into your server resources directory.
2. Add the resource to `server.cfg`:

```cfg
ensure ty-propinspection
```

3. Restart the server or run:

```text
restart ty-propinspection
```

The script is standalone. No framework is required.

The resource uses `fxmanifest.lua` to load files in this order:

```text
config.lua
locales.lua
client/main.lua
```

The order is important because `Config.Locale` must exist before the locale helper starts, and the locale helper must exist before the client sends text to the NUI.

---

# 2. Resource Structure

```text
ty-propinspection/
├── fxmanifest.lua
├── config.lua
├── locales.lua
├── README.md
├── DOCS.md
├── client/
│   └── main.lua
├── html/
│   ├── index.html
│   ├── style.css
│   └── app.js
└── integrations/
    └── qb-hud/
        └── README.md
```

The NUI does not use `backdrop-filter` or `-webkit-backdrop-filter`. These properties are intentionally avoided because they can create black compositor boxes in FiveM CEF.

---

# 3. Quick Start

The minimum useful spot looks like this:

```lua
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

        inspectProps = {
            {
                model = 'prop_phone_ing_02',
                label = 'Old Smartphone',
                description = 'A damaged smartphone with strange scratches on the back.',
                defaultRotation = vector3(0.0, 0.0, 0.0),
                defaultDistance = 0.40,
                minDistance = 0.25,
                maxDistance = 0.55,
                inertia = 0.15,
                hotspots = {}
            }
        }
    }
}
```

The player walks into `radius`, sees the configured interaction prompt, presses `E`, and enters the inspection workspace.

---

# 4. General Configuration

```lua
Config.Locale = 'en'
Config.Debug = true
Config.EnableDOF = true
Config.InvertMouse = false
Config.EnableSounds = true
Config.InteractUI = 'script'
```

## `Config.Locale`

Selects the built-in system language.

Included values:

```text
en  English
de  German
pl  Polish
tr  Turkish
ru  Russian
es  Spanish
fr  French
```

Region values are normalized where possible:

```lua
Config.Locale = 'de-DE'
```

resolves to:

```text
de
```

## `Config.Debug`

When enabled:

- development diagnostics are printed to F8;
- spot markers and debug lines are drawn nearby;
- map blips are created for every configured spot.

Disable it for production:

```lua
Config.Debug = false
```

## `Config.EnableDOF`

Enables cinematic depth of field during inspection.

```lua
Config.EnableDOF = true
```

## `Config.InvertMouse`

Controls mouse rotation inversion.

```lua
Config.InvertMouse = false
```

Normal mouse rotation.

```lua
Config.InvertMouse = true
```

Inverts both horizontal and vertical prop rotation. This makes the difference immediately visible when dragging left/right or up/down.

You can also configure each axis separately:

```lua
Config.InvertMouse = {
    x = true,  -- invert left/right rotation
    y = false  -- keep up/down rotation normal
}
```

Or only invert vertical rotation:

```lua
Config.InvertMouse = {
    x = false,
    y = true
}
```

## `Config.EnableSounds`

Master switch for all built-in native GTA feedback sounds.

```lua
Config.EnableSounds = false
```

This disables open, close, switch, reset and hotspot sounds.

## `Config.InteractUI`

Available modes:

```lua
Config.InteractUI = 'script'
```

Uses the custom NUI prompt.

```lua
Config.InteractUI = 'native'
```

Uses native GTA/FiveM help text.

---

# 5. Localization

All built-in languages and locale functions are stored in one file:

```text
locales.lua
```

The locale registry is private to that file so another global `Locales` table cannot overwrite it.

The public helper functions are:

```lua
L(key)
GetLocaleCode()
GetLocaleTable()
GetFallbackLocaleTable()
GetAvailableLocaleCodes()
```

Example:

```lua
Config.Locale = 'de'
```

With `Config.Debug = true`, F8 prints a diagnostic line similar to:

```text
[ty-propinspection] Locale requested: de | active: de | loaded: de, en, es, fr, pl, ru, tr
```

If the line says `active: en`, verify that you replaced the complete resource folder and are not running an older duplicate copy.

## Story content is not translated automatically

These values belong to your own story content:

```lua
label = 'Old Smartphone'
description = 'A damaged smartphone...'
subDescription = 'A serial number was found...'
```

`Config.Locale` translates built-in interface text such as:

- Inspection
- Detail Discovered
- Press E
- Rotate
- Zoom
- Reset
- Switch
- Close
- Prop Setup Tool

To localize story content, create separate spot configurations or implement your own content lookup.

---

# 6. Interaction UI

Custom UI:

```lua
Config.InteractUI = 'script'
```

Native help text:

```lua
Config.InteractUI = 'native'
```

The custom prompt automatically uses the first inspect prop label:

```text
Press [E] to inspect Old Smartphone.
```

Locked spots display a disabled state and cannot be opened:

```lua
isLocked = true
```

---

# 7. HUD Integration

```lua
Config.Hud = {
    enabled = true,
    hideNativeHud = true,

    Disable = function()
        -- Hide your external HUD here.
    end,

    Enable = function()
        -- Restore your external HUD here.
    end
}
```

## `enabled`

Controls only the custom `Enable` and `Disable` callbacks.

```lua
enabled = false
```

No external HUD callbacks are called.

## `hideNativeHud`

Hides the built-in GTA HUD and radar while inspecting.

```lua
hideNativeHud = true
```

## qb-hud example

The default config tries:

```lua
exports['qb-hud']:SetHudState(false)
```

and falls back to:

```lua
TriggerEvent('qb-hud:client:SetHudState', false)
```

See:

```text
integrations/qb-hud/README.md
```

for versions of `qb-hud` that do not provide a public visibility API.

---

# 8. Inspection Background

```lua
Config.UI = {
    inspectBackground = {
        enabled = true,
        opacity = 0.90,
        protectProp = true,
        clearRadius = 32.0,
        fullDarkRadius = 78.0
    }
}
```

## `enabled`

Enables the cinematic darkening effect.

## `opacity`

Controls the maximum darkness outside the protected center area.

```text
0.00 = no darkening
0.50 = medium darkening
0.90 = very dark
1.00 = fully black
```

## `protectProp`

When enabled, the center of the screen remains transparent so the NUI dark layer does not visibly darken the inspect prop.

```lua
protectProp = true
```

## `clearRadius`

Size of the completely transparent center area.

Increase it for large props:

```lua
clearRadius = 42.0
```

## `fullDarkRadius`

Controls where the vignette reaches full configured opacity.

A larger distance creates a softer transition:

```lua
fullDarkRadius = 85.0
```

---

# 9. World Prop Streaming

```lua
Config.WorldPropStreamDistance = 90.0
Config.WorldPropDespawnDistance = 110.0
```

The visible world prop is local and distance streamed.

Behavior:

1. Player enters stream distance.
2. The configured world prop is created locally.
3. Player starts inspection.
4. That world prop is hidden for the local player.
5. The inspect prop is created in the camera workspace.
6. Inspection closes.
7. The inspect prop is deleted and the world prop becomes visible again.
8. Player leaves despawn distance.
9. The local world prop is deleted.

The larger despawn distance creates hysteresis and prevents rapid spawn/delete loops near the streaming boundary.

---

# 10. Motion, Lerp and Inertia

```lua
Config.Motion = {
    mouseSensitivity = 150.0,
    rotationLerpSpeed = 13.0,
    zoomLerpSpeed = 10.0,
    zoomStep = 0.16,
    rotationLimits = false
}
```

## Frame-independent interpolation

The client uses exponential interpolation:

```text
alpha = 1 - e^(-speed × deltaTime)
```

The helper functions are in `client/main.lua`:

```lua
expLerpAlpha()
expLerp()
```

This keeps motion visually consistent across different frame rates.

## `mouseSensitivity`

Controls how strongly mouse input changes target rotation.

Higher:

```lua
mouseSensitivity = 200.0
```

Lower:

```lua
mouseSensitivity = 100.0
```

## `rotationLerpSpeed`

Controls how quickly the visible prop catches its target rotation.

Higher values feel faster and tighter:

```lua
rotationLerpSpeed = 18.0
```

Lower values feel softer:

```lua
rotationLerpSpeed = 8.0
```

## `zoomLerpSpeed`

Controls how quickly the visible prop catches the target zoom distance.

## `zoomStep`

Controls normal mouse-wheel zoom increments during regular inspection.

## `inertia`

Every inspect prop has its own inertia value:

```lua
inertia = 0.15
```

Inertia affects rotation response and follow-through.

Recommended examples:

```text
0.05  Very light object; fast response
0.15  Small phone or tool
0.35  Documents or medium object
0.60  Heavy object; slow response
0.90  Very heavy, strongly delayed response
```

Example light object:

```lua
inertia = 0.10
```

Example heavy object:

```lua
inertia = 0.70
```

The value does not simulate full rigid-body physics. It changes how strongly the interpolated rotation lags behind the mouse target.

---

# 11. Rotation and Rotation Limits

The default configuration has no rotation limit:

```lua
Config.Motion.rotationLimits = false
```

The prop can continue rotating beyond:

```text
180°
360°
720°
-360°
```

The internal local inspect rotation stays unwrapped, so continuous rotation does not hit a hard stop.

## Camera-relative default rotation

`defaultRotation` is local to the inspect camera:

```lua
defaultRotation = vector3(0.0, 0.0, 0.0)
```

The complete camera rotation is applied, including:

- horizontal heading;
- vertical look pitch;
- camera roll when present.

Therefore the same configured side remains presented even if the player starts inspection while looking:

- north or south;
- toward or away from the world prop;
- upward;
- downward.

## Global rotation limit

Replace `false` with a table:

```lua
Config.Motion.rotationLimits = {
    minX = -80.0,
    maxX = 80.0,
    minZ = -120.0,
    maxZ = 120.0
}
```

The natural viewer controls use:

```text
X = vertical pitch
Z = horizontal turn
```

## Per-prop rotation limit

A prop can override the global setting:

```lua
{
    model = 'prop_phone_ing_02',

    rotationLimits = {
        minX = -60.0,
        maxX = 60.0,
        minZ = -150.0,
        maxZ = 150.0
    },

    -- Other prop settings...
}
```

## Disable limits for one prop

Even when a global limit exists:

```lua
rotationLimits = false
```

makes that individual prop unlimited.

## Use the global setting for one prop

Omit `rotationLimits` completely:

```lua
{
    model = 'prop_phone_ing_02',
    -- no rotationLimits field
}
```

---

# 12. Camera, DOF and Light

```lua
Config.Camera = {
    transitionInMs = 450,
    transitionOutMs = 350,
    fovOffset = -2.0,
    raycastPadding = 0.12,
    raycastFlags = 511,
    raycastTimeoutMs = 750
}
```

## Camera transitions

```lua
transitionInMs = 450
transitionOutMs = 350
```

Control the scripted camera blend times.

## Anti-clipping raycast

Before the inspect prop is created, the script checks the camera-to-prop path.

```lua
raycastPadding = 0.12
```

keeps the prop slightly in front of a detected obstruction.

## Camera breathing

```lua
breathing = {
    enabled = true,
    positionAmplitude = 0.0045,
    rotationAmplitude = 0.085,
    speed = 0.72
}
```

Keep the values subtle. Large values make the inspection camera visibly float.

## DOF

```lua
dof = {
    nearDof = 0.18,
    farDof = 2.8,
    strength = 0.72
}
```

Used only when:

```lua
Config.EnableDOF = true
```

## Camera light

```lua
Config.CameraLight = {
    enabled = true,
    color = { r = 255, g = 242, b = 220 },
    range = 3.0,
    intensity = 1.35,
    forwardOffset = 0.12
}
```

The light is drawn only while an inspection session is active.

---

# 13. Sound Feedback

```lua
Config.EnableSounds = true
```

Individual sounds:

```lua
Config.Sounds = {
    open = { name = 'SELECT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    close = { name = 'BACK', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    switch = { name = 'NAV_LEFT_RIGHT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    reset = { name = 'WAYPOINT_SET', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    hotspot = { name = 'PICK_UP', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' }
}
```

Set the master switch to `false` to disable all of them without editing the table.

---

# 14. Creating Inspection Spots

A spot contains:

```lua
[1] = {
    coords = vector3(...),
    radius = 2.0,
    isLocked = false,
    worldProp = {...},
    playerAnim = {...},
    inspectProps = {...}
}
```

## `coords`

Interaction center.

## `radius`

Maximum interaction distance.

## `isLocked`

```lua
isLocked = false
```

allows interaction.

```lua
isLocked = true
```

shows the locked state and prevents inspection.

## `worldProp`

```lua
worldProp = {
    model = 'prop_amb_phone',
    coords = vector3(155.36, -1039.94, 28.28),
    heading = 45.0
}
```

This is the object visible in the normal game world.

---

# 15. Player Animations and Attached Hand Props

Optional example:

```lua
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
}
```

## Animation fields

```text
dict   Animation dictionary
name   Animation name
flag   GTA animation flag
```

## Attached prop fields

```text
model      Separate local object model
bone       Ped bone ID
offset     Local position relative to the bone
rotation   Local rotation relative to the bone
```

The attached object is not the inspect prop. It is a separate presentation prop, such as a phone, flashlight, clipboard or magnifying glass.

It is deleted automatically when inspection ends.

---

# 16. Inspect Prop Settings

```lua
{
    model = 'prop_phone_ing_02',
    label = 'Old Smartphone',
    description = 'A damaged smartphone...',
    defaultRotation = vector3(0.0, 0.0, 0.0),
    defaultDistance = 0.40,
    minDistance = 0.25,
    maxDistance = 0.55,
    inertia = 0.15,
    hotspots = {}
}
```

## `model`

The local prop shown in the camera workspace.

## `label`

Large title in the top-left story UI.

## `description`

Main description text.

## `defaultRotation`

Starting orientation in local camera-relative inspect space.

Use `/propinspect` to find it visually.

## `defaultDistance`

Starting camera-to-prop distance.

## `minDistance`

Closest allowed zoom.

## `maxDistance`

Farthest allowed zoom.

Required relationship:

```text
minDistance <= defaultDistance <= maxDistance
```

## `inertia`

Per-prop rotation weight. See the inertia section above.

---

# 17. Multiple Props and Switching

Add more entries to `inspectProps`:

```lua
inspectProps = {
    {
        model = 'prop_cs_documents_01',
        label = 'Documents',
        -- ...
    },
    {
        model = 'prop_phone_ing_02',
        label = 'Phone',
        -- ...
    }
}
```

The player switches with:

```text
A / D
Left Arrow / Right Arrow
```

The switch animation uses:

```lua
switchOffset = 0.48
switchOutDuration = 0.18
switchInDuration = 0.52
bounceDamping = 7.5
bounceFrequency = 12.0
```

---


## Example: Multiple Ground Items Without a World Prop

A spot can exist without a permanently visible world prop:

```lua
worldProp = false
```

The included second example spot uses this for two small discarded items:

```lua
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
            model = 'ng_proc_litter_plasbot1',
            label = 'Old eCola Plastic Bottle'
        },
        {
            model = 'ng_proc_cigpak01c',
            label = 'Empty Redwood Cigarette Pack'
        }
    }
}
```

This is useful for evidence piles, rubbish, small clues or locations where a single permanent world model would not represent all inspectable items.

# 18. Hotspots

Hotspots reveal additional story information when a condition is matched.

Two matching modes are available:

```text
view
exact
```

## `view` mode

Recommended for visible sides of an object:

```lua
{
    matchMode = 'view',
    targetRotation = vector3(6.54, 0.00, 173.51),
    tolerance = 60.0,
    subDescription = "A serial number is engraved on the back."
}
```

`view` checks which local side of the prop faces the camera.

This means the same physical side can still match when the prop is rolled upside down.

Example:

```text
Back side upright       -> match
Back side upside down   -> match
Front side              -> no match
```

## `exact` mode

Use this when all rotation axes must be near one exact orientation:

```lua
{
    matchMode = 'exact',
    targetRotation = vector3(10.0, 25.0, 170.0),
    tolerance = 12.0,
    subDescription = 'This detail is visible only at a precise angle.'
}
```

## `tolerance`

Tolerance is measured in degrees.

Smaller values require more precision:

```lua
tolerance = 8.0
```

Larger values are easier to trigger:

```lua
tolerance = 45.0
```

For broad phone-back detection, a large value can be appropriate:

```lua
tolerance = 60.0
```

## Offset hotspot

A hotspot can also use a local prop-space offset:

```lua
{
    offset = vector3(0.0, 0.08, 0.02),
    tolerance = 10.0,
    subDescription = 'A small mark is visible here.'
}
```

The offset is converted from prop-local coordinates into world coordinates. The system checks the angle between the camera forward direction and that point.

A hotspot can combine offset and rotation conditions. In that case all configured conditions must match.

---

# 19. Prop Setup Tool (`/propinspect`)

The setup tool is intended for development only.

```lua
Config.PropInspectTool.enabled = true
```

Disable it when setup is finished:

```lua
Config.PropInspectTool.enabled = false
```

No ACE permission is required by design.

## Commands

Open nearest spot, first prop:

```text
/propinspect
```

Open a specific spot and prop:

```text
/propinspect 2 2
```

Close:

```text
/propinspect close
```

## Basic controls

```text
Hold Mouse           Rotate prop
Mouse Wheel          Normal zoom
Shift + Mouse Wheel  Fine zoom
Q / E                Roll / remaining rotation axis
1                    Save current zoom as minDistance
2                    Save current zoom as defaultDistance
3                    Save current zoom as maxDistance
G                    Set temporary hotspot preview
X                    Clear temporary hotspot preview
H                    Switch Default / Hotspot output mode
Arrow Up / Down      Change hotspot tolerance
Enter                Print ready-to-paste config to F8
Esc / Backspace      Close
```

## Finding default rotation

1. Run:

```text
/propinspect 1 1
```

2. Keep the output mode on `DEFAULT`.
3. Rotate the prop until the starting presentation looks correct.
4. Set zoom values with `1`, `2`, and `3`.
5. Press `Enter`.
6. Copy the printed values from F8.

Example output:

```lua
defaultRotation = vector3(0.00, 0.00, 0.00),
defaultDistance = 0.40,
minDistance = 0.25,
maxDistance = 0.55,
```

## Zoom values are independent

Each key changes only one saved value:

```text
1 -> minDistance only
2 -> defaultDistance only
3 -> maxDistance only
```

Changing the current zoom after pressing `1` does not overwrite the saved minimum.

The tool warns about an invalid order but does not silently change the other values.

Valid order:

```text
MIN <= START <= MAX
```

## Fine zoom

Normal wheel step:

```lua
zoomStep = 0.10
```

Fine wheel step while holding Shift:

```lua
fineZoomStep = 0.01
```

Example:

```text
0.40
0.41
0.42
0.43
```

This is useful for small props such as phones, bags and bottles.

## Setting and previewing a hotspot

1. Rotate the prop to the desired visible side.
2. Press `G`.
3. The current view is captured as a temporary hotspot.
4. Rotate away.
5. The preview should show `NOT FOUND`.
6. Rotate back.
7. The preview should show `FOUND` and display the normal hotspot UI.
8. Adjust tolerance with Arrow Up / Down.
9. Press `Enter` to print the tested hotspot config.

`G` freezes the captured target at the exact current orientation, preventing interpolation drift from changing the saved value.

## `view` preview behavior

The preview uses the same production `view` matching logic as the real inspection system.

Therefore:

```text
Same side upright       -> FOUND
Same side upside down   -> FOUND
Different side          -> NOT FOUND
```

## Clear preview

Press:

```text
X
```

This removes only the temporary development preview. It never edits `Config.Spots` automatically.

## Default / Hotspot output mode

Press:

```text
H
```

to switch between:

```text
DEFAULT
HOTSPOT
```

In `DEFAULT` mode, Enter prints starting rotation and zoom values.

In `HOTSPOT` mode, Enter prints the captured hotspot values.

## Tool configuration

```lua
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
```

`zoomMin` and `zoomMax` are extended development limits. They do not replace the actual prop `minDistance` and `maxDistance` values until you copy the values into the prop configuration.

---

# 20. Debug Mode and Blips

```lua
Config.Debug = true
```

Debug mode enables:

- 3D markers at spots;
- lines around world-prop positions;
- visible map blips;
- F8 diagnostics;
- locale diagnostics.

Blip appearance:

```lua
Config.DebugBlip = {
    sprite = 280,
    color = 1,
    scale = 1.0,
    flashes = true
}
```

The blip name uses the first inspect prop label from the spot.

Disable all debug markers and blips:

```lua
Config.Debug = false
```

---

# 21. Exports and Client Events

## Exports

Start a configured inspection:

```lua
exports['ty-propinspection']:StartInspection(1)
```

Close the active inspection:

```lua
exports['ty-propinspection']:CloseInspection()
```

Check state:

```lua
local inspecting = exports['ty-propinspection']:IsInspecting()
```

Lock or unlock a spot locally:

```lua
exports['ty-propinspection']:SetSpotLocked(1, true)
exports['ty-propinspection']:SetSpotLocked(1, false)
```

## Client events

Start:

```lua
TriggerEvent('ty-propinspection:client:start', 1)
```

Close:

```lua
TriggerEvent('ty-propinspection:client:close')
```

Set locked state:

```lua
TriggerEvent('ty-propinspection:client:setLocked', 1, true)
```

---

# 22. Cleanup and Safety

The script cleans local state when:

- inspection closes normally;
- the player dies;
- the resource stops or restarts;
- the current session fails during setup.

Cleanup includes:

- scripted camera;
- inspect prop;
- attached hand prop;
- streamed local world props when appropriate;
- player animation;
- HUD state;
- NUI state;
- DOF state;
- control state.

The player is frozen during inspection and movement/combat controls are blocked.

`ESC` is consumed by the inspection system, so closing the workspace should not open the pause menu or map.

---

# 23. Performance Notes

The expensive inspection loop exists only while a session is active.

At idle:

- no camera render loop runs;
- no per-frame prop rotation loop runs;
- no per-frame light loop runs;
- no inspection control loop runs.

World props use distance streaming instead of being permanently created for every client everywhere on the map.

The nearby interaction thread dynamically sleeps when the player is far away.

NUI interaction prompts are sent on state changes rather than every frame.

---

# 24. Troubleshooting

## Locale stays English

Set:

```lua
Config.Locale = 'de'
Config.Debug = true
```

Restart the resource and check F8.

Expected:

```text
Locale requested: de | active: de | loaded: de, en, es, fr, pl, ru, tr
```

If `requested` is `de` but `active` is `en`:

1. delete the old resource folder completely;
2. make sure there is only one running copy of `ty-propinspection`;
3. install the complete new folder, including `locales.lua`;
4. restart the resource.

The v1.0.14 locale registry is private inside `locales.lua` and cannot be overwritten through a global `Locales` variable.

## Wrong side when starting inspection

`defaultRotation` is camera-relative. v1.0.14 applies the complete camera rotation, including vertical pitch.

The same default side should remain presented even when starting while looking up or down.

## Black or grey fullscreen overlay while idle

The root NUI document must stay transparent. Do not add a dark background to `html` or `body`.

The cinematic background belongs only to the active `.inspection-app` state.

## Black boxes around prompts

Do not add:

```css
backdrop-filter
```

or:

```css
-webkit-backdrop-filter
```

The included CSS intentionally contains neither property.

## Prop cannot reach the back side

Keep:

```lua
Config.Motion.rotationLimits = false
```

and do not add a per-prop limit.

## Zoom values overwrite each other in the tool

In the current tool they are independent. Make sure you are running the latest resource version.

## Hotspot works upright but not upside down

Use:

```lua
matchMode = 'view'
```

not:

```lua
matchMode = 'exact'
```

`view` matches the visible physical side while ignoring twist around the view axis.
