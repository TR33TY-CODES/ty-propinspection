/**
 * Standalone NUI controller for ty-propinspection.
 *
 * Lua sends presentation data through FiveM's SendNUIMessage wrapper.
 * The UI never requests NUI focus and never sends callbacks back to Lua, so it
 * cannot capture gameplay input or interfere with the inspection controls.
 */

// FiveM CEF transparency hardening. Browser/theme defaults must never paint the
// fullscreen NUI document with an opaque background while the resource is idle.
document.documentElement.style.background = 'transparent';
document.documentElement.style.backgroundColor = 'rgba(0, 0, 0, 0)';
document.body.style.background = 'transparent';
document.body.style.backgroundColor = 'rgba(0, 0, 0, 0)';

const app = document.getElementById('inspection-app');
const storyContent = document.getElementById('story-content');
const storyEyebrow = document.getElementById('story-eyebrow');
const labelElement = document.getElementById('prop-label');
const descriptionElement = document.getElementById('prop-description');
const counterElement = document.getElementById('prop-counter');
const switchPrompt = document.getElementById('switch-prompt');
const hotspot = document.getElementById('hotspot');
const hotspotLabel = document.getElementById('hotspot-label');
const hotspotText = document.getElementById('hotspot-text');

const interactPrompt = document.getElementById('interact-prompt');
const interactEyebrow = document.getElementById('interact-eyebrow');
const interactPrefix = document.getElementById('interact-prefix');
const interactMessage = document.getElementById('interact-message');

const debugTool = document.getElementById('debug-tool');
const debugToolEyebrow = document.getElementById('debug-tool-eyebrow');
const debugOutputModeLabel = document.getElementById('debug-output-mode-label');
const debugToolLocation = document.getElementById('debug-tool-location');
const debugToolMode = document.getElementById('debug-tool-mode');
const debugHotspotPreview = document.getElementById('debug-hotspot-preview');
const debugPreviewLabel = document.getElementById('debug-preview-label');
const debugPreviewStatus = document.getElementById('debug-preview-status');
const debugToolRotation = document.getElementById('debug-tool-rotation');
const debugToolDistance = document.getElementById('debug-tool-distance');
const debugToolTolerance = document.getElementById('debug-tool-tolerance');
const debugToolMin = document.getElementById('debug-tool-min');
const debugToolDefault = document.getElementById('debug-tool-default');
const debugToolMax = document.getElementById('debug-tool-max');
const debugToolNotice = document.getElementById('debug-tool-notice');
const debugZoomMinCard = document.getElementById('debug-zoom-min-card');
const debugZoomDefaultCard = document.getElementById('debug-zoom-default-card');
const debugZoomMaxCard = document.getElementById('debug-zoom-max-card');

const debugRotationLabel = document.getElementById('debug-rotation-label');
const debugDistanceLabel = document.getElementById('debug-distance-label');
const debugToleranceLabel = document.getElementById('debug-tolerance-label');
const debugSavedZoomLabel = document.getElementById('debug-saved-zoom-label');
const debugMinLabel = document.getElementById('debug-min-label');
const debugDefaultLabel = document.getElementById('debug-default-label');
const debugMaxLabel = document.getElementById('debug-max-label');
const debugMouseKey = document.getElementById('debug-mouse-key');
const debugControlRotate = document.getElementById('debug-control-rotate');
const debugControlZoom = document.getElementById('debug-control-zoom');
const debugControlFineZoom = document.getElementById('debug-control-fine-zoom');
const debugControlTolerance = document.getElementById('debug-control-tolerance');
const debugControlRoll = document.getElementById('debug-control-roll');
const debugControlSetHotspot = document.getElementById('debug-control-set-hotspot');
const debugControlClearHotspot = document.getElementById('debug-control-clear-hotspot');
const debugControlPrint = document.getElementById('debug-control-print');

const controlMouseKey = document.getElementById('control-mouse-key');
const controlRotateLabel = document.getElementById('control-rotate-label');
const controlZoomLabel = document.getElementById('control-zoom-label');
const controlResetLabel = document.getElementById('control-reset-label');
const controlSwitchLabel = document.getElementById('control-switch-label');
const controlCloseLabel = document.getElementById('control-close-label');

let closeTimer = null;
let swapTimer = null;
let interactCloseTimer = null;
let debugNoticeTimer = null;

/**
 * Built-in emergency fallback used only if Lua has not sent a locale yet.
 * The normal source of truth is `locales.lua`.
 */
const defaultLocale = {
    unknownObject: 'Unknown Object',
    inspection: 'INSPECTION',
    detailDiscovered: 'DETAIL DISCOVERED',
    interaction: 'INTERACTION',
    notAvailable: 'NOT AVAILABLE',
    press: 'Press',
    locked: 'LOCKED',
    inspectMessage: 'to inspect %s.',
    lockedMessage: '%s cannot be inspected right now.',
    controls: {
        mouse: 'MOUSE',
        rotate: 'Hold & Rotate',
        zoom: 'Zoom',
        reset: 'Reset',
        switch: 'Switch',
        close: 'Close'
    },
    debug: {
        developmentTool: 'PROP SETUP TOOL',
        outputMode: 'COPY VALUES AS',
        standard: 'DEFAULT',
        hotspot: 'HOTSPOT',
        rotation: 'ROTATION',
        distance: 'CURRENT ZOOM',
        tolerance: 'HOTSPOT TOLERANCE',
        savedZoom: 'SAVED ZOOM VALUES',
        min: 'MIN',
        default: 'START',
        max: 'MAX',
        rotate: 'Rotate',
        zoom: 'Zoom',
        fineZoom: 'Fine Zoom',
        roll: 'Roll / Tilt',
        printF8: 'Print Config to F8',
        preview: 'HOTSPOT PREVIEW',
        previewNotSet: 'NOT SET',
        previewSearching: 'NOT FOUND',
        previewFound: 'FOUND',
        setHotspot: 'Set Hotspot',
        clearHotspot: 'Clear Preview',
        spot: 'SPOT',
        prop: 'PROP'
    }
};

let locale = deepMerge({}, defaultLocale);

/**
 * Returns whether a value is a plain object suitable for recursive merging.
 *
 * @param {unknown} value Candidate value.
 * @returns {boolean}
 */
function isPlainObject(value) {
    return value !== null && typeof value === 'object' && !Array.isArray(value);
}

/**
 * Recursively merges locale objects without mutating the source tables.
 * Later arguments override earlier values while missing keys remain available.
 *
 * @param {object} base Base object.
 * @param {object} override Override object.
 * @returns {object} Merged object.
 */
function deepMerge(base, override) {
    const result = { ...(isPlainObject(base) ? base : {}) };

    if (!isPlainObject(override)) return result;

    for (const [key, value] of Object.entries(override)) {
        if (isPlainObject(value)) {
            result[key] = deepMerge(result[key], value);
        } else {
            result[key] = value;
        }
    }

    return result;
}

/**
 * Replaces `%s` placeholders in a localized string from left to right.
 *
 * @param {unknown} template Localized format string.
 * @param {...unknown} values Replacement values.
 * @returns {string}
 */
function formatLocale(template, ...values) {
    let output = String(template ?? '');

    for (const value of values) {
        output = output.replace('%s', String(value ?? ''));
    }

    return output;
}

/**
 * Restricts a numeric value to an inclusive range.
 *
 * @param {unknown} value Candidate numeric value.
 * @param {number} minimum Inclusive minimum.
 * @param {number} maximum Inclusive maximum.
 * @param {number} fallback Value used when conversion fails.
 * @returns {number}
 */
function clampNumber(value, minimum, maximum, fallback) {
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) return fallback;
    return Math.min(maximum, Math.max(minimum, numeric));
}

/** Restricts a numeric value to the 0..1 range. */
function clamp01(value, fallback = 0) {
    return clampNumber(value, 0, 1, fallback);
}

/**
 * Pads a positive index for the cinematic "01 / 03" counter style.
 *
 * @param {number} value Numeric index or total.
 * @returns {string}
 */
function formatCounterValue(value) {
    const safeValue = Number.isFinite(Number(value)) ? Math.max(0, Number(value)) : 0;
    return String(safeValue).padStart(2, '0');
}

/**
 * Applies all static labels from the active locale to the DOM.
 */
function applyStaticLocale() {
    storyEyebrow.textContent = locale.inspection;
    hotspotLabel.textContent = locale.detailDiscovered;

    debugToolEyebrow.textContent = locale.debug.developmentTool;
    debugOutputModeLabel.textContent = locale.debug.outputMode;
    debugRotationLabel.textContent = locale.debug.rotation;
    debugDistanceLabel.textContent = locale.debug.distance;
    debugToleranceLabel.textContent = locale.debug.tolerance;
    debugSavedZoomLabel.textContent = locale.debug.savedZoom;
    debugMinLabel.textContent = locale.debug.min;
    debugDefaultLabel.textContent = locale.debug.default;
    debugMaxLabel.textContent = locale.debug.max;
    debugMouseKey.textContent = locale.controls.mouse;
    debugControlRotate.textContent = locale.debug.rotate;
    debugControlZoom.textContent = locale.debug.zoom;
    debugControlFineZoom.textContent = locale.debug.fineZoom;
    debugControlTolerance.textContent = locale.debug.tolerance;
    debugControlRoll.textContent = locale.debug.roll;
    debugPreviewLabel.textContent = locale.debug.preview;
    debugControlSetHotspot.textContent = locale.debug.setHotspot;
    debugControlClearHotspot.textContent = locale.debug.clearHotspot;
    debugControlPrint.textContent = locale.debug.printF8;

    controlMouseKey.textContent = locale.controls.mouse;
    controlRotateLabel.textContent = locale.controls.rotate;
    controlZoomLabel.textContent = locale.controls.zoom;
    controlResetLabel.textContent = locale.controls.reset;
    controlSwitchLabel.textContent = locale.controls.switch;
    controlCloseLabel.textContent = locale.controls.close;
}

/**
 * Activates a locale payload sent by Lua.
 * The selected locale is merged over English, then over the JS emergency
 * fallback, so incomplete custom locales remain safe.
 *
 * @param {object} data Message payload received from Lua.
 */
function applyLocalePayload(data) {
    const englishFallback = deepMerge(defaultLocale, data.fallback ?? {});
    locale = deepMerge(englishFallback, data.strings ?? {});
    document.documentElement.lang = String(data.code ?? 'en');
    applyStaticLocale();
}

/**
 * Updates the visible prop title, description and position counter.
 * textContent is used intentionally so config text can never inject HTML.
 *
 * @param {object} data Message payload received from Lua.
 */
function applyPropContent(data) {
    labelElement.textContent = data.label ?? locale.unknownObject;
    descriptionElement.textContent = data.description ?? '';
    counterElement.textContent = `${formatCounterValue(data.index)} / ${formatCounterValue(data.total)}`;
    switchPrompt.classList.toggle('is-hidden', data.canSwitch !== true);
}

/**
 * Configures the inspection background.
 *
 * When prop protection is enabled, the NUI does not place the dark layer over
 * the center of the screen. Instead, a radial focus window stays transparent
 * around the inspect prop while the surrounding world is darkened.
 *
 * @param {object} data Message payload received from Lua.
 */
function applyInspectionBackground(data) {
    const dimOpacity = data.dimEnabled === false ? 0 : clamp01(data.dimOpacity, 0.18);
    const clearRadius = clampNumber(data.dimClearRadius, 0, 95, 32);
    const fullDarkRadius = clampNumber(data.dimFullDarkRadius, clearRadius + 1, 100, 78);
    const protectProp = data.dimEnabled !== false && data.dimProtectProp !== false;

    app.style.setProperty('--inspection-dim-opacity', String(dimOpacity));
    app.style.setProperty('--inspection-clear-radius', `${clearRadius}%`);
    app.style.setProperty('--inspection-full-dark-radius', `${fullDarkRadius}%`);
    app.classList.toggle('is-prop-protected', protectProp);
}

/** Fully opens the interface and restarts its CSS entrance animation. */
function openInterface(data) {
    window.clearTimeout(closeTimer);
    window.clearTimeout(swapTimer);

    applyInspectionBackground(data);
    document.body.classList.add('nui-active');

    applyPropContent(data);
    hideHotspot();

    app.classList.remove('is-closing');
    app.setAttribute('aria-hidden', 'false');

    // Two animation frames guarantee that the hidden state is committed first,
    // so reopening quickly still plays the full entrance transition.
    requestAnimationFrame(() => {
        requestAnimationFrame(() => app.classList.add('is-visible'));
    });
}

/** Starts the smooth outro and hides the DOM after the transition completes. */
function closeInterface() {
    window.clearTimeout(closeTimer);
    window.clearTimeout(swapTimer);

    hideHotspot();
    storyContent.classList.remove('is-switching');
    app.classList.add('is-closing');
    app.classList.remove('is-visible');

    closeTimer = window.setTimeout(() => {
        app.classList.remove('is-closing', 'is-prop-protected');
        app.setAttribute('aria-hidden', 'true');
        document.body.classList.remove('nui-active');
    }, 430);
}

/** Immediately removes the interface without transitions. */
function forceCloseInterface() {
    window.clearTimeout(closeTimer);
    window.clearTimeout(swapTimer);

    app.classList.remove('is-visible', 'is-closing', 'is-prop-protected');
    storyContent.classList.remove('is-switching');
    hotspot.classList.remove('is-visible');
    app.setAttribute('aria-hidden', 'true');
    document.body.classList.remove('nui-active');
}

/** Crossfades story text when A/D changes the inspected prop. */
function transitionPropContent(data) {
    window.clearTimeout(swapTimer);
    storyContent.classList.add('is-switching');
    hideHotspot();

    swapTimer = window.setTimeout(() => {
        applyPropContent(data);
        storyContent.classList.remove('is-switching');
    }, 120);
}

/** Displays a discovered hotspot and its additional story information. */
function showHotspot(text) {
    hotspotText.textContent = text ?? '';
    hotspot.classList.add('is-visible');
}

/** Hides the hotspot indicator and removes its old text. */
function hideHotspot() {
    hotspot.classList.remove('is-visible');
    hotspotText.textContent = '';
}

/**
 * Shows the optional standalone interaction prompt.
 * The prompt never receives NUI focus and cannot steal player input.
 *
 * @param {object} data Message payload received from Lua.
 */
function showInteractPrompt(data) {
    window.clearTimeout(interactCloseTimer);

    const label = String(data.label ?? locale.unknownObject);
    const locked = data.locked === true;

    interactPrompt.classList.toggle('is-locked', locked);
    interactEyebrow.textContent = locked ? locale.notAvailable : locale.interaction;
    interactPrefix.textContent = locked ? locale.locked : locale.press;
    interactMessage.textContent = locked
        ? formatLocale(locale.lockedMessage, label)
        : formatLocale(locale.inspectMessage, label);

    interactPrompt.setAttribute('aria-hidden', 'false');

    requestAnimationFrame(() => {
        requestAnimationFrame(() => interactPrompt.classList.add('is-visible'));
    });
}

/** Smoothly hides the standalone interaction prompt. */
function hideInteractPrompt() {
    window.clearTimeout(interactCloseTimer);
    interactPrompt.classList.remove('is-visible');

    interactCloseTimer = window.setTimeout(() => {
        interactPrompt.setAttribute('aria-hidden', 'true');
    }, 430);
}

/** Immediately clears the interaction prompt during restarts/cleanup. */
function forceHideInteractPrompt() {
    window.clearTimeout(interactCloseTimer);
    interactPrompt.classList.remove('is-visible', 'is-locked');
    interactPrompt.setAttribute('aria-hidden', 'true');
}

/** Safely formats a numeric authoring value. */
function formatDebugNumber(value, digits = 2) {
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) return (0).toFixed(digits);
    return numeric.toFixed(digits);
}

/** Shows a short status message inside the authoring panel. */
function showDebugNotice(text) {
    window.clearTimeout(debugNoticeTimer);

    if (!text) {
        debugToolNotice.classList.remove('is-visible');
        debugToolNotice.textContent = '';
        return;
    }

    debugToolNotice.textContent = text;
    debugToolNotice.classList.add('is-visible');

    debugNoticeTimer = window.setTimeout(() => {
        debugToolNotice.classList.remove('is-visible');
    }, 1500);
}

/** Updates the development-only Prop Inspect Tool readout. */
function updateDebugTool(data) {
    if (data.visible !== true) {
        hideDebugTool();
        return;
    }

    const rotation = data.rotation ?? {};
    const isHotspotMode = data.mode === 'hotspot';
    const mode = isHotspotMode ? locale.debug.hotspot : locale.debug.standard;

    debugToolLocation.textContent = `${locale.debug.spot} ${formatCounterValue(data.spotIndex)} · ${locale.debug.prop} ${formatCounterValue(data.propIndex)} / ${formatCounterValue(data.propTotal)}`;
    const previewSet = data.previewSet === true;
    const previewMatched = previewSet && data.previewMatched === true;

    debugToolMode.textContent = mode;
    debugTool.classList.toggle('is-hotspot-mode', isHotspotMode);
    debugTool.classList.toggle('has-hotspot-preview', previewSet);
    debugTool.classList.toggle('is-preview-found', previewMatched);
    debugTool.classList.toggle('is-preview-missing', previewSet && !previewMatched);
    debugTool.classList.toggle('has-invalid-zoom', data.zoomValid === false);

    debugPreviewStatus.textContent = !previewSet
        ? locale.debug.previewNotSet
        : previewMatched
            ? locale.debug.previewFound
            : locale.debug.previewSearching;

    app.classList.add('is-debug-tool');

    debugToolRotation.textContent = `${formatDebugNumber(rotation.x)}, ${formatDebugNumber(rotation.y)}, ${formatDebugNumber(rotation.z)}`;
    debugToolDistance.textContent = formatDebugNumber(data.distance);
    debugToolTolerance.textContent = `${formatDebugNumber(data.tolerance, 1)}°`;
    debugToolMin.textContent = formatDebugNumber(data.minDistance);
    debugToolDefault.textContent = formatDebugNumber(data.defaultDistance);
    debugToolMax.textContent = formatDebugNumber(data.maxDistance);

    const lastSaved = String(data.lastSaved ?? '');
    debugZoomMinCard.classList.toggle('is-last-saved', lastSaved === 'min');
    debugZoomDefaultCard.classList.toggle('is-last-saved', lastSaved === 'default');
    debugZoomMaxCard.classList.toggle('is-last-saved', lastSaved === 'max');

    debugTool.setAttribute('aria-hidden', 'false');
    debugTool.classList.add('is-visible');

    if (data.notice) showDebugNotice(String(data.notice));
}

/** Immediately hides and clears the development tool panel. */
function hideDebugTool() {
    window.clearTimeout(debugNoticeTimer);
    debugTool.classList.remove(
        'is-visible',
        'is-hotspot-mode',
        'has-hotspot-preview',
        'is-preview-found',
        'is-preview-missing',
        'has-invalid-zoom'
    );
    debugPreviewStatus.textContent = locale.debug.previewNotSet;
    debugZoomMinCard.classList.remove('is-last-saved');
    debugZoomDefaultCard.classList.remove('is-last-saved');
    debugZoomMaxCard.classList.remove('is-last-saved');
    app.classList.remove('is-debug-tool');
    debugTool.setAttribute('aria-hidden', 'true');
    debugToolNotice.classList.remove('is-visible');
    debugToolNotice.textContent = '';
}

/** Routes every FiveM NUI message to the matching presentation action. */
window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || typeof data.action !== 'string') return;

    switch (data.action) {
        case 'setLocale':
            applyLocalePayload(data);
            break;

        case 'open':
            openInterface(data);
            break;

        case 'close':
            closeInterface();
            break;

        case 'forceClose':
            forceCloseInterface();
            break;

        case 'propChanged':
            transitionPropContent(data);
            break;

        case 'hotspot':
            if (data.visible === true) {
                showHotspot(data.text);
            } else {
                hideHotspot();
            }
            break;

        case 'showInteract':
            showInteractPrompt(data);
            break;

        case 'hideInteract':
            hideInteractPrompt();
            break;

        case 'forceHideInteract':
            forceHideInteractPrompt();
            break;

        case 'debugToolUpdate':
            updateDebugTool(data);
            break;

        case 'debugToolHide':
            hideDebugTool();
            break;

        default:
            break;
    }
});

// Guaranteed startup state after first load and after resource restarts.
applyStaticLocale();
forceCloseInterface();
forceHideInteractPrompt();
hideDebugTool();

// Tell Lua that the CEF listener is now ready. This prevents an early locale
// message from being lost during resource startup and leaving the UI in English.
fetch(`https://${GetParentResourceName()}/ready`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify({})
}).catch(() => {
    // The built-in English emergency fallback remains usable if CEF is closing.
});
