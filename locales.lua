-- ============================================================================
-- Central locale registry and helper
-- ============================================================================
--
-- All built-in languages live in this ONE client file on purpose. Keeping the
-- tables and lookup helper together guarantees deterministic FiveM load order:
--
--   config.lua -> locales.lua -> client/main.lua
--
-- Change `Config.Locale` in config.lua. Supported values: en, de, pl, tr, ru,
-- es and fr. Region codes such as `de-DE` and `pt_BR` are normalized to their
-- base language when a matching locale exists.
--
-- Missing keys fall back to English individually. The entire language never
-- switches back to English just because one translation is missing.

local LocaleData = {}


-- --------------------------------------------------------------------------
-- EN
-- --------------------------------------------------------------------------
LocaleData['en'] = {
    nui = {
        unknownObject = 'Unknown Object',
        inspection = 'INSPECTION',
        detailDiscovered = 'DETAIL DISCOVERED',
        interaction = 'INTERACTION',
        notAvailable = 'NOT AVAILABLE',
        press = 'Press',
        locked = 'LOCKED',
        inspectMessage = 'to inspect %s.',
        lockedMessage = '%s cannot be inspected right now.',

        controls = {
            mouse = 'MOUSE',
            rotate = 'Hold & Rotate',
            zoom = 'Zoom',
            reset = 'Reset',
            switch = 'Switch',
            close = 'Close'
        },

        debug = {
            developmentTool = 'PROP SETUP TOOL',
            outputMode = 'COPY VALUES AS',
            standard = 'DEFAULT',
            hotspot = 'HOTSPOT',
            rotation = 'ROTATION',
            distance = 'CURRENT ZOOM',
            tolerance = 'HOTSPOT TOLERANCE',
            savedZoom = 'SAVED ZOOM VALUES',
            min = 'MIN',
            default = 'START',
            max = 'MAX',
            rotate = 'Rotate',
            zoom = 'Zoom',
            fineZoom = 'Fine Zoom',
            roll = 'Roll / Tilt',
            printF8 = 'Print Config to F8',
            preview = 'HOTSPOT PREVIEW',
            previewNotSet = 'NOT SET',
            previewSearching = 'NOT FOUND',
            previewFound = 'FOUND',
            setHotspot = 'Set Hotspot',
            clearHotspot = 'Clear Preview',
            spot = 'SPOT',
            prop = 'PROP',
        },
    },

    native = {
        inspect = 'Press ~INPUT_CONTEXT~ to inspect ~b~%s~s~.',
        locked = '~r~%s cannot be inspected right now.~s~'
    },

    debugTool = {
        active = 'PROP SETUP TOOL ACTIVE',
        modeHotspot = 'HOTSPOT OUTPUT',
        modeDefault = 'DEFAULT OUTPUT',
        hotspotSet = 'HOTSPOT PREVIEW SET — THE SAME SIDE ALSO MATCHES UPSIDE DOWN',
        hotspotCleared = 'HOTSPOT PREVIEW CLEARED',
        hotspotSetFirst = 'SET A HOTSPOT FIRST WITH G',
        previewSubDescription = 'PREVIEW: Hotspot detection works correctly.',
        propChanged = 'PROP CHANGED',
        minSet = 'MIN ZOOM SAVED',
        defaultSet = 'START ZOOM SAVED',
        maxSet = 'MAX ZOOM SAVED',
        toleranceIncreased = 'TOLERANCE INCREASED',
        toleranceDecreased = 'TOLERANCE DECREASED',
        valuesPrinted = 'CONFIG PRINTED TO F8',
        invalidZoomOrder = 'INVALID ZOOM ORDER: MIN ≤ START ≤ MAX',
        placeholderSubDescription = 'YOUR TEXT HERE',
        valuesPrintedConsole = 'Values printed. Copy them from F8 into config.lua.',
        notOpen = 'The Prop Inspect Tool is not currently open.',
        closeCurrent = 'Close the current inspection before opening /%s.',
        invalidSpot = 'Invalid spot. Usage: /%s [spotId] [propIndex]',
        invalidProp = 'Invalid prop index for spot %s. Usage: /%s %s [propIndex]',
        opened = 'Opened spot %s, prop %s.',
        controls = 'Mouse = rotate | Wheel = zoom | Shift+Wheel = fine zoom | Q/E = roll | 1/2/3 = save Min/Start/Max | G = set hotspot preview | X = clear preview | H = Default/Hotspot | Enter = print config',
        disableAfterSetup = 'Disable Config.PropInspectTool.enabled after setup is finished.',
        commandEnabled = 'Development command enabled: /%s [spotId] [propIndex]',
    },

    fallback = {
        object = 'Object',
        inspectionSpot = 'Inspection Spot %s'
    }
}


-- --------------------------------------------------------------------------
-- DE
-- --------------------------------------------------------------------------
LocaleData['de'] = {
    nui = {
        unknownObject = 'Unbekanntes Objekt',
        inspection = 'UNTERSUCHUNG',
        detailDiscovered = 'DETAIL ENTDECKT',
        interaction = 'INTERAKTION',
        notAvailable = 'NICHT VERFÜGBAR',
        press = 'Drücke',
        locked = 'GESPERRT',
        inspectMessage = 'um %s zu untersuchen.',
        lockedMessage = '%s kann derzeit nicht untersucht werden.',
        controls = {
            mouse = 'MAUS',
            rotate = 'Halten & Rotieren',
            zoom = 'Zoom',
            reset = 'Reset',
            switch = 'Wechseln',
            close = 'Schließen',
        },
        debug = {
            developmentTool = 'PROP-SETUP-TOOL',
            outputMode = 'WERTE KOPIEREN ALS',
            standard = 'STANDARD',
            hotspot = 'HOTSPOT',
            rotation = 'ROTATION',
            distance = 'AKTUELLER ZOOM',
            tolerance = 'HOTSPOT-TOLERANZ',
            savedZoom = 'GESPEICHERTE ZOOM-WERTE',
            min = 'MIN',
            default = 'START',
            max = 'MAX',
            rotate = 'Rotieren',
            zoom = 'Zoom',
            fineZoom = 'Feiner Zoom',
            roll = 'Neigen / Rollen',
            printF8 = 'Config in F8 ausgeben',
            preview = 'HOTSPOT-VORSCHAU',
            previewNotSet = 'NICHT GESETZT',
            previewSearching = 'NICHT GEFUNDEN',
            previewFound = 'GEFUNDEN',
            setHotspot = 'Hotspot setzen',
            clearHotspot = 'Vorschau löschen',
            spot = 'SPOT',
            prop = 'PROP',
        },
    },
    native = {
        inspect = 'Drücke ~INPUT_CONTEXT~, um ~b~%s~s~ zu untersuchen.',
        locked = '~r~%s kann derzeit nicht untersucht werden.~s~',
    },
    debugTool = {
        active = 'PROP-SETUP-TOOL AKTIV',
        modeHotspot = 'HOTSPOT-AUSGABE',
        modeDefault = 'STANDARD-AUSGABE',
        hotspotSet = 'HOTSPOT-VORSCHAU GESETZT — DIESELBE SEITE FUNKTIONIERT AUCH AUF DEM KOPF',
        hotspotCleared = 'HOTSPOT-VORSCHAU GELÖSCHT',
        hotspotSetFirst = 'SETZE ZUERST MIT G EINEN HOTSPOT',
        previewSubDescription = 'VORSCHAU: Die Hotspot-Erkennung funktioniert korrekt.',
        propChanged = 'PROP GEWECHSELT',
        minSet = 'MIN-ZOOM GESPEICHERT',
        defaultSet = 'START-ZOOM GESPEICHERT',
        maxSet = 'MAX-ZOOM GESPEICHERT',
        toleranceIncreased = 'TOLERANZ ERHÖHT',
        toleranceDecreased = 'TOLERANZ VERRINGERT',
        valuesPrinted = 'CONFIG IN F8 AUSGEGEBEN',
        invalidZoomOrder = 'UNGÜLTIGE ZOOM-REIHENFOLGE: MIN ≤ START ≤ MAX',
        placeholderSubDescription = 'DEIN TEXT HIER',
        valuesPrintedConsole = 'Werte ausgegeben. Kopiere sie aus F8 in die config.lua.',
        notOpen = 'Das Prop-Inspect-Tool ist derzeit nicht geöffnet.',
        closeCurrent = 'Schließe die aktuelle Inspektion, bevor du /%s öffnest.',
        invalidSpot = 'Ungültiger Spot. Verwendung: /%s [spotId] [propIndex]',
        invalidProp = 'Ungültiger Prop-Index für Spot %s. Verwendung: /%s %s [propIndex]',
        opened = 'Spot %s, Prop %s geöffnet.',
        controls = 'Maus = rotieren | Mausrad = Zoom | Shift+Mausrad = Feinzoom | Q/E = rollen | 1/2/3 = Min/Start/Max speichern | G = Hotspot-Vorschau setzen | X = Vorschau löschen | H = Standard/Hotspot | Enter = Config ausgeben',
        disableAfterSetup = 'Deaktiviere Config.PropInspectTool.enabled nach Abschluss der Einrichtung.',
        commandEnabled = 'Entwickler-Command aktiviert: /%s [spotId] [propIndex]',
    },

    fallback = {
        object = 'Objekt',
        inspectionSpot = 'Inspektions-Spot %s',
    },
}


-- --------------------------------------------------------------------------
-- PL
-- --------------------------------------------------------------------------
LocaleData['pl'] = {
    nui = {
        unknownObject = 'Nieznany obiekt',
        inspection = 'INSPEKCJA',
        detailDiscovered = 'ODKRYTO SZCZEGÓŁ',
        interaction = 'INTERAKCJA',
        notAvailable = 'NIEDOSTĘPNE',
        press = 'Naciśnij',
        locked = 'ZABLOKOWANE',
        inspectMessage = 'aby zbadać %s.',
        lockedMessage = '%s nie może teraz zostać zbadane.',
        controls = {
            mouse = 'MYSZ',
            rotate = 'Przytrzymaj i obracaj',
            zoom = 'Powiększenie',
            reset = 'Reset',
            switch = 'Zmień',
            close = 'Zamknij',
        },
        debug = {
            developmentTool = 'NARZĘDZIE KONFIGURACJI PROPA',
            outputMode = 'KOPIUJ WARTOŚCI JAKO',
            standard = 'DOMYŚLNE',
            hotspot = 'HOTSPOT',
            rotation = 'OBRÓT',
            distance = 'AKTUALNY ZOOM',
            tolerance = 'TOLERANCJA HOTSPOTU',
            savedZoom = 'ZAPISANE WARTOŚCI ZOOMU',
            min = 'MIN',
            default = 'START',
            max = 'MAX',
            rotate = 'Obracaj',
            zoom = 'Zoom',
            fineZoom = 'Precyzyjny zoom',
            roll = 'Przechył / obrót',
            printF8 = 'Wyświetl config w F8',
            preview = 'PODGLĄD HOTSPOTU',
            previewNotSet = 'NIE USTAWIONO',
            previewSearching = 'NIE ZNALEZIONO',
            previewFound = 'ZNALEZIONO',
            setHotspot = 'Ustaw hotspot',
            clearHotspot = 'Wyczyść podgląd',
            spot = 'SPOT',
            prop = 'PROP',
        },
    },
    native = {
        inspect = 'Naciśnij ~INPUT_CONTEXT~, aby zbadać ~b~%s~s~.',
        locked = '~r~%s nie może teraz zostać zbadane.~s~',
    },
    debugTool = {
        active = 'NARZĘDZIE KONFIGURACJI AKTYWNE',
        modeHotspot = 'WYJŚCIE HOTSPOT',
        modeDefault = 'WYJŚCIE DOMYŚLNE',
        hotspotSet = 'PODGLĄD HOTSPOTU USTAWIONY — TA SAMA STRONA DZIAŁA TEŻ DO GÓRY NOGAMI',
        hotspotCleared = 'PODGLĄD HOTSPOTU WYCZYSZCZONY',
        hotspotSetFirst = 'NAJPIERW USTAW HOTSPOT KLAWISZEM G',
        previewSubDescription = 'PODGLĄD: Wykrywanie hotspotu działa poprawnie.',
        propChanged = 'ZMIENIONO PROP',
        minSet = 'ZAPISANO MIN ZOOM',
        defaultSet = 'ZAPISANO START ZOOM',
        maxSet = 'ZAPISANO MAX ZOOM',
        toleranceIncreased = 'ZWIĘKSZONO TOLERANCJĘ',
        toleranceDecreased = 'ZMNIEJSZONO TOLERANCJĘ',
        valuesPrinted = 'CONFIG WYŚWIETLONY W F8',
        invalidZoomOrder = 'NIEPRAWIDŁOWA KOLEJNOŚĆ ZOOMU: MIN ≤ START ≤ MAX',
        placeholderSubDescription = 'TWÓJ TEKST TUTAJ',
        valuesPrintedConsole = 'Wartości wyświetlono. Skopiuj je z F8 do config.lua.',
        notOpen = 'Narzędzie Prop Inspect nie jest obecnie otwarte.',
        closeCurrent = 'Zamknij bieżącą inspekcję przed otwarciem /%s.',
        invalidSpot = 'Nieprawidłowy spot. Użycie: /%s [spotId] [propIndex]',
        invalidProp = 'Nieprawidłowy indeks prop dla spotu %s. Użycie: /%s %s [propIndex]',
        opened = 'Otwarto spot %s, prop %s.',
        controls = 'Mysz = obrót | Kółko = zoom | Shift+Kółko = precyzyjny zoom | Q/E = przechył | 1/2/3 = zapisz Min/Start/Max | G = ustaw podgląd hotspotu | X = wyczyść podgląd | H = Domyślny/Hotspot | Enter = wypisz config',
        disableAfterSetup = 'Wyłącz Config.PropInspectTool.enabled po zakończeniu konfiguracji.',
        commandEnabled = 'Command deweloperski włączony: /%s [spotId] [propIndex]',
    },

    fallback = {
        object = 'Obiekt',
        inspectionSpot = 'Spot inspekcji %s',
    },
}


-- --------------------------------------------------------------------------
-- TR
-- --------------------------------------------------------------------------
LocaleData['tr'] = {
    nui = {
        unknownObject = 'Bilinmeyen Nesne',
        inspection = 'İNCELEME',
        detailDiscovered = 'DETAY KEŞFEDİLDİ',
        interaction = 'ETKİLEŞİM',
        notAvailable = 'KULLANILAMIYOR',
        press = 'Bas',
        locked = 'KİLİTLİ',
        inspectMessage = '%s nesnesini incelemek için.',
        lockedMessage = '%s şu anda incelenemiyor.',
        controls = {
            mouse = 'FARE',
            rotate = 'Basılı Tut ve Döndür',
            zoom = 'Yakınlaştır',
            reset = 'Sıfırla',
            switch = 'Değiştir',
            close = 'Kapat',
        },
        debug = {
            developmentTool = 'PROP KURULUM ARACI',
            outputMode = 'DEĞERLERİ ŞU OLARAK KOPYALA',
            standard = 'VARSAYILAN',
            hotspot = 'HOTSPOT',
            rotation = 'DÖNÜŞ',
            distance = 'MEVCUT ZOOM',
            tolerance = 'HOTSPOT TOLERANSI',
            savedZoom = 'KAYITLI ZOOM DEĞERLERİ',
            min = 'MİN',
            default = 'BAŞLANGIÇ',
            max = 'MAKS',
            rotate = 'Döndür',
            zoom = 'Zoom',
            fineZoom = 'Hassas Yakınlaştırma',
            roll = 'Eğ / Yuvarla',
            printF8 = 'Configi F8’e yazdır',
            preview = 'HOTSPOT ÖNİZLEME',
            previewNotSet = 'AYARLANMADI',
            previewSearching = 'BULUNAMADI',
            previewFound = 'BULUNDU',
            setHotspot = 'Hotspot Ayarla',
            clearHotspot = 'Önizlemeyi Temizle',
            spot = 'SPOT',
            prop = 'PROP',
        },
    },
    native = {
        inspect = '~b~%s~s~ nesnesini incelemek için ~INPUT_CONTEXT~ tuşuna bas.',
        locked = '~r~%s şu anda incelenemiyor.~s~',
    },
    debugTool = {
        active = 'PROP KURULUM ARACI AKTİF',
        modeHotspot = 'HOTSPOT ÇIKTISI',
        modeDefault = 'VARSAYILAN ÇIKTI',
        hotspotSet = 'HOTSPOT ÖNİZLEMESİ AYARLANDI — AYNI YÜZ TERS ÇEVRİLSE DE EŞLEŞİR',
        hotspotCleared = 'HOTSPOT ÖNİZLEMESİ TEMİZLENDİ',
        hotspotSetFirst = 'ÖNCE G İLE BİR HOTSPOT AYARLA',
        previewSubDescription = 'ÖNİZLEME: Hotspot algılama doğru çalışıyor.',
        propChanged = 'PROP DEĞİŞTİRİLDİ',
        minSet = 'MİN ZOOM KAYDEDİLDİ',
        defaultSet = 'BAŞLANGIÇ ZOOMU KAYDEDİLDİ',
        maxSet = 'MAKS ZOOM KAYDEDİLDİ',
        toleranceIncreased = 'TOLERANS ARTIRILDI',
        toleranceDecreased = 'TOLERANS AZALTILDI',
        valuesPrinted = 'CONFIG F8’E YAZDIRILDI',
        invalidZoomOrder = 'GEÇERSİZ ZOOM SIRASI: MİN ≤ BAŞLANGIÇ ≤ MAKS',
        placeholderSubDescription = 'METNİNİ BURAYA YAZ',
        valuesPrintedConsole = 'Değerler yazdırıldı. F8’den config.lua dosyasına kopyala.',
        notOpen = 'Prop Inspect Aracı şu anda açık değil.',
        closeCurrent = '/%s komutunu açmadan önce mevcut incelemeyi kapat.',
        invalidSpot = 'Geçersiz spot. Kullanım: /%s [spotId] [propIndex]',
        invalidProp = 'Spot %s için geçersiz prop indeksi. Kullanım: /%s %s [propIndex]',
        opened = 'Spot %s, prop %s açıldı.',
        controls = 'Fare = döndür | Tekerlek = zoom | Shift+Tekerlek = hassas zoom | Q/E = eğim | 1/2/3 = Min/Start/Max kaydet | G = hotspot önizlemesi ayarla | X = önizlemeyi temizle | H = Varsayılan/Hotspot | Enter = config yazdır',
        disableAfterSetup = 'Kurulum bittikten sonra Config.PropInspectTool.enabled seçeneğini devre dışı bırak.',
        commandEnabled = 'Geliştirici komutu etkin: /%s [spotId] [propIndex]',
    },

    fallback = {
        object = 'Nesne',
        inspectionSpot = 'İnceleme Spotu %s',
    },
}


-- --------------------------------------------------------------------------
-- RU
-- --------------------------------------------------------------------------
LocaleData['ru'] = {
    nui = {
        unknownObject = 'Неизвестный объект',
        inspection = 'ОСМОТР',
        detailDiscovered = 'ОБНАРУЖЕНА ДЕТАЛЬ',
        interaction = 'ВЗАИМОДЕЙСТВИЕ',
        notAvailable = 'НЕДОСТУПНО',
        press = 'Нажмите',
        locked = 'ЗАБЛОКИРОВАНО',
        inspectMessage = 'чтобы осмотреть %s.',
        lockedMessage = '%s сейчас нельзя осмотреть.',
        controls = {
            mouse = 'МЫШЬ',
            rotate = 'Удерживать и вращать',
            zoom = 'Масштаб',
            reset = 'Сброс',
            switch = 'Сменить',
            close = 'Закрыть',
        },
        debug = {
            developmentTool = 'ИНСТРУМЕНТ НАСТРОЙКИ ПРОПА',
            outputMode = 'КОПИРОВАТЬ ЗНАЧЕНИЯ КАК',
            standard = 'ПО УМОЛЧАНИЮ',
            hotspot = 'ХОТСПОТ',
            rotation = 'ВРАЩЕНИЕ',
            distance = 'ТЕКУЩИЙ МАСШТАБ',
            tolerance = 'ДОПУСК ХОТСПОТА',
            savedZoom = 'СОХРАНЁННЫЕ ЗНАЧЕНИЯ МАСШТАБА',
            min = 'МИН',
            default = 'СТАРТ',
            max = 'МАКС',
            rotate = 'Вращать',
            zoom = 'Масштаб',
            fineZoom = 'Точный зум',
            roll = 'Наклон / крен',
            printF8 = 'Вывести config в F8',
            preview = 'ПРЕДПРОСМОТР ХОТСПОТА',
            previewNotSet = 'НЕ ЗАДАН',
            previewSearching = 'НЕ НАЙДЕН',
            previewFound = 'НАЙДЕН',
            setHotspot = 'Задать хотспот',
            clearHotspot = 'Очистить предпросмотр',
            spot = 'ТОЧКА',
            prop = 'ПРОП',
        },
    },
    native = {
        inspect = 'Нажмите ~INPUT_CONTEXT~, чтобы осмотреть ~b~%s~s~.',
        locked = '~r~%s сейчас нельзя осмотреть.~s~',
    },
    debugTool = {
        active = 'ИНСТРУМЕНТ НАСТРОЙКИ АКТИВЕН',
        modeHotspot = 'ВЫВОД ХОТСПОТА',
        modeDefault = 'ВЫВОД ПО УМОЛЧАНИЮ',
        hotspotSet = 'ПРЕДПРОСМОТР ХОТСПОТА ЗАДАН — ТА ЖЕ СТОРОНА РАБОТАЕТ И ВВЕРХ НОГАМИ',
        hotspotCleared = 'ПРЕДПРОСМОТР ХОТСПОТА ОЧИЩЕН',
        hotspotSetFirst = 'СНАЧАЛА ЗАДАЙТЕ ХОТСПОТ КЛАВИШЕЙ G',
        previewSubDescription = 'ПРЕДПРОСМОТР: Обнаружение хотспота работает правильно.',
        propChanged = 'ОБЪЕКТ СМЕНЁН',
        minSet = 'МИН. МАСШТАБ СОХРАНЁН',
        defaultSet = 'СТАРТОВЫЙ МАСШТАБ СОХРАНЁН',
        maxSet = 'МАКС. МАСШТАБ СОХРАНЁН',
        toleranceIncreased = 'ДОПУСК УВЕЛИЧЕН',
        toleranceDecreased = 'ДОПУСК УМЕНЬШЕН',
        valuesPrinted = 'CONFIG ВЫВЕДЕН В F8',
        invalidZoomOrder = 'НЕВЕРНЫЙ ПОРЯДОК МАСШТАБА: МИН ≤ СТАРТ ≤ МАКС',
        placeholderSubDescription = 'ВАШ ТЕКСТ ЗДЕСЬ',
        valuesPrintedConsole = 'Значения выведены. Скопируйте их из F8 в config.lua.',
        notOpen = 'Инструмент Prop Inspect сейчас не открыт.',
        closeCurrent = 'Закройте текущий осмотр перед открытием /%s.',
        invalidSpot = 'Неверная точка. Использование: /%s [spotId] [propIndex]',
        invalidProp = 'Неверный индекс пропа для точки %s. Использование: /%s %s [propIndex]',
        opened = 'Открыта точка %s, проп %s.',
        controls = 'Мышь = вращение | Колесо = зум | Shift+Колесо = точный зум | Q/E = наклон | 1/2/3 = сохранить Min/Start/Max | G = задать предпросмотр хотспота | X = очистить | H = Стандарт/Хотспот | Enter = вывести config',
        disableAfterSetup = 'Отключите Config.PropInspectTool.enabled после завершения настройки.',
        commandEnabled = 'Команда разработчика включена: /%s [spotId] [propIndex]',
    },

    fallback = {
        object = 'Объект',
        inspectionSpot = 'Точка осмотра %s',
    },
}


-- --------------------------------------------------------------------------
-- ES
-- --------------------------------------------------------------------------
LocaleData['es'] = {
    nui = {
        unknownObject = 'Objeto desconocido',
        inspection = 'INSPECCIÓN',
        detailDiscovered = 'DETALLE DESCUBIERTO',
        interaction = 'INTERACCIÓN',
        notAvailable = 'NO DISPONIBLE',
        press = 'Pulsa',
        locked = 'BLOQUEADO',
        inspectMessage = 'para examinar %s.',
        lockedMessage = '%s no se puede examinar ahora.',
        controls = {
            mouse = 'RATÓN',
            rotate = 'Mantén y gira',
            zoom = 'Zoom',
            reset = 'Restablecer',
            switch = 'Cambiar',
            close = 'Cerrar',
        },
        debug = {
            developmentTool = 'HERRAMIENTA DE CONFIGURACIÓN',
            outputMode = 'COPIAR VALORES COMO',
            standard = 'PREDETERMINADO',
            hotspot = 'HOTSPOT',
            rotation = 'ROTACIÓN',
            distance = 'ZOOM ACTUAL',
            tolerance = 'TOLERANCIA DEL HOTSPOT',
            savedZoom = 'VALORES DE ZOOM GUARDADOS',
            min = 'MÍN',
            default = 'INICIO',
            max = 'MÁX',
            rotate = 'Girar',
            zoom = 'Zoom',
            fineZoom = 'Zoom fino',
            roll = 'Inclinar / Rodar',
            printF8 = 'Mostrar config en F8',
            preview = 'VISTA PREVIA DEL HOTSPOT',
            previewNotSet = 'SIN DEFINIR',
            previewSearching = 'NO ENCONTRADO',
            previewFound = 'ENCONTRADO',
            setHotspot = 'Definir hotspot',
            clearHotspot = 'Limpiar vista previa',
            spot = 'PUNTO',
            prop = 'PROP',
        },
    },
    native = {
        inspect = 'Pulsa ~INPUT_CONTEXT~ para examinar ~b~%s~s~.',
        locked = '~r~%s no se puede examinar ahora.~s~',
    },
    debugTool = {
        active = 'HERRAMIENTA DE CONFIGURACIÓN ACTIVA',
        modeHotspot = 'SALIDA HOTSPOT',
        modeDefault = 'SALIDA PREDETERMINADA',
        hotspotSet = 'VISTA PREVIA DEL HOTSPOT DEFINIDA — EL MISMO LADO TAMBIÉN COINCIDE BOCA ABAJO',
        hotspotCleared = 'VISTA PREVIA DEL HOTSPOT LIMPIADA',
        hotspotSetFirst = 'PRIMERO DEFINE UN HOTSPOT CON G',
        previewSubDescription = 'VISTA PREVIA: La detección del hotspot funciona correctamente.',
        propChanged = 'PROP CAMBIADO',
        minSet = 'ZOOM MÍN GUARDADO',
        defaultSet = 'ZOOM INICIAL GUARDADO',
        maxSet = 'ZOOM MÁX GUARDADO',
        toleranceIncreased = 'TOLERANCIA AUMENTADA',
        toleranceDecreased = 'TOLERANCIA REDUCIDA',
        valuesPrinted = 'CONFIG MOSTRADO EN F8',
        invalidZoomOrder = 'ORDEN DE ZOOM NO VÁLIDO: MÍN ≤ INICIO ≤ MÁX',
        placeholderSubDescription = 'TU TEXTO AQUÍ',
        valuesPrintedConsole = 'Valores mostrados. Cópialos desde F8 a config.lua.',
        notOpen = 'La herramienta Prop Inspect no está abierta.',
        closeCurrent = 'Cierra la inspección actual antes de abrir /%s.',
        invalidSpot = 'Punto no válido. Uso: /%s [spotId] [propIndex]',
        invalidProp = 'Índice de prop no válido para el punto %s. Uso: /%s %s [propIndex]',
        opened = 'Punto %s, prop %s abierto.',
        controls = 'Ratón = rotar | Rueda = zoom | Shift+Rueda = zoom fino | Q/E = inclinar | 1/2/3 = guardar Min/Inicio/Max | G = definir vista previa del hotspot | X = limpiar vista previa | H = Predeterminado/Hotspot | Enter = imprimir config',
        disableAfterSetup = 'Desactiva Config.PropInspectTool.enabled cuando termines la configuración.',
        commandEnabled = 'Comando de desarrollo activado: /%s [spotId] [propIndex]',
    },

    fallback = {
        object = 'Objeto',
        inspectionSpot = 'Punto de inspección %s',
    },
}


-- --------------------------------------------------------------------------
-- FR
-- --------------------------------------------------------------------------
LocaleData['fr'] = {
    nui = {
        unknownObject = 'Objet inconnu',
        inspection = 'INSPECTION',
        detailDiscovered = 'DÉTAIL DÉCOUVERT',
        interaction = 'INTERACTION',
        notAvailable = 'INDISPONIBLE',
        press = 'Appuyez sur',
        locked = 'VERROUILLÉ',
        inspectMessage = 'pour examiner %s.',
        lockedMessage = '%s ne peut pas être examiné pour le moment.',
        controls = {
            mouse = 'SOURIS',
            rotate = 'Maintenir et tourner',
            zoom = 'Zoom',
            reset = 'Réinitialiser',
            switch = 'Changer',
            close = 'Fermer',
        },
        debug = {
            developmentTool = 'OUTIL DE CONFIGURATION DU PROP',
            outputMode = 'COPIER LES VALEURS COMME',
            standard = 'PAR DÉFAUT',
            hotspot = 'HOTSPOT',
            rotation = 'ROTATION',
            distance = 'ZOOM ACTUEL',
            tolerance = 'TOLÉRANCE DU HOTSPOT',
            savedZoom = 'VALEURS DE ZOOM ENREGISTRÉES',
            min = 'MIN',
            default = 'DÉPART',
            max = 'MAX',
            rotate = 'Tourner',
            zoom = 'Zoom',
            fineZoom = 'Zoom précis',
            roll = 'Incliner / Rouler',
            printF8 = 'Afficher la config dans F8',
            preview = 'APERÇU DU HOTSPOT',
            previewNotSet = 'NON DÉFINI',
            previewSearching = 'NON TROUVÉ',
            previewFound = 'TROUVÉ',
            setHotspot = 'Définir le hotspot',
            clearHotspot = 'Effacer l’aperçu',
            spot = 'POINT',
            prop = 'PROP',
        },
    },
    native = {
        inspect = 'Appuyez sur ~INPUT_CONTEXT~ pour examiner ~b~%s~s~.',
        locked = '~r~%s ne peut pas être examiné pour le moment.~s~',
    },
    debugTool = {
        active = 'OUTIL DE CONFIGURATION ACTIF',
        modeHotspot = 'SORTIE HOTSPOT',
        modeDefault = 'SORTIE PAR DÉFAUT',
        hotspotSet = 'APERÇU DU HOTSPOT DÉFINI — LA MÊME FACE FONCTIONNE AUSSI À L’ENVERS',
        hotspotCleared = 'APERÇU DU HOTSPOT EFFACÉ',
        hotspotSetFirst = 'DÉFINISSEZ D’ABORD UN HOTSPOT AVEC G',
        previewSubDescription = 'APERÇU : La détection du hotspot fonctionne correctement.',
        propChanged = 'OBJET CHANGÉ',
        minSet = 'ZOOM MIN ENREGISTRÉ',
        defaultSet = 'ZOOM DE DÉPART ENREGISTRÉ',
        maxSet = 'ZOOM MAX ENREGISTRÉ',
        toleranceIncreased = 'TOLÉRANCE AUGMENTÉE',
        toleranceDecreased = 'TOLÉRANCE RÉDUITE',
        valuesPrinted = 'CONFIG AFFICHÉE DANS F8',
        invalidZoomOrder = 'ORDRE DE ZOOM INVALIDE : MIN ≤ DÉPART ≤ MAX',
        placeholderSubDescription = 'VOTRE TEXTE ICI',
        valuesPrintedConsole = 'Valeurs affichées. Copiez-les depuis F8 dans config.lua.',
        notOpen = 'L’outil Prop Inspect n’est pas ouvert.',
        closeCurrent = 'Fermez l’inspection actuelle avant d’ouvrir /%s.',
        invalidSpot = 'Point invalide. Utilisation : /%s [spotId] [propIndex]',
        invalidProp = 'Index de prop invalide pour le point %s. Utilisation : /%s %s [propIndex]',
        opened = 'Point %s, prop %s ouvert.',
        controls = 'Souris = rotation | Molette = zoom | Shift+Molette = zoom précis | Q/E = inclinaison | 1/2/3 = enregistrer Min/Départ/Max | G = définir l’aperçu du hotspot | X = effacer l’aperçu | H = Défaut/Hotspot | Entrée = afficher la config',
        disableAfterSetup = 'Désactivez Config.PropInspectTool.enabled une fois la configuration terminée.',
        commandEnabled = 'Commande de développement activée : /%s [spotId] [propIndex]',
    },

    fallback = {
        object = 'Objet',
        inspectionSpot = 'Point d’inspection %s',
    },
}


-- ============================================================================
-- Locale API
-- ============================================================================

local FALLBACK_LOCALE = 'en'

---Normalizes Config.Locale and accepts common region formats such as de-DE.
---@return string requestedLocale
local function getRequestedLocaleCode()
    local requested = tostring((Config and Config.Locale) or FALLBACK_LOCALE)
        :lower()
        :gsub('_', '-')
        :match('^%s*(.-)%s*$')

    if requested == '' then return FALLBACK_LOCALE end
    if type(LocaleData[requested]) == 'table' then return requested end

    local baseLanguage = requested:match('^([a-z][a-z])%-')
    if baseLanguage and type(LocaleData[baseLanguage]) == 'table' then
        return baseLanguage
    end

    return requested
end

---Reads a direct key or a nested dotted path from a locale table.
---@param source table|nil
---@param key string
---@return any
local function getLocaleValue(source, key)
    if type(source) ~= 'table' then return nil end
    if source[key] ~= nil then return source[key] end

    local value = source
    for part in tostring(key):gmatch('[^.]+') do
        if type(value) ~= 'table' then return nil end
        value = value[part]
    end

    return value
end

---Replaces `%{name}` placeholders in localized strings.
---@param text any
---@param variables? table
---@return any
local function replaceVariables(text, variables)
    if type(text) ~= 'string' or type(variables) ~= 'table' then return text end

    for key, value in pairs(variables) do
        text = text:gsub('%%{' .. tostring(key) .. '}', tostring(value))
    end

    return text
end

---Recursively copies a value so NUI payload merges never mutate locale tables.
---@param source any
---@return any
local function deepCopy(source)
    if type(source) ~= 'table' then return source end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = deepCopy(value)
    end
    return copy
end

---Recursively merges one locale over the English fallback.
---@param base table
---@param override table|nil
---@return table
local function deepMerge(base, override)
    local result = deepCopy(base)
    if type(override) ~= 'table' then return result end

    for key, value in pairs(override) do
        if type(value) == 'table' and type(result[key]) == 'table' then
            result[key] = deepMerge(result[key], value)
        else
            result[key] = deepCopy(value)
        end
    end

    return result
end

---Returns the active locale code or English when Config.Locale is unavailable.
---@return string
function GetLocaleCode()
    local requested = getRequestedLocaleCode()
    if type(LocaleData[requested]) == 'table' then return requested end
    return FALLBACK_LOCALE
end

---Returns one localized value with per-key English fallback.
---@param key string
---@param variables? table
---@return any
function L(key, variables)
    local language = LocaleData[GetLocaleCode()] or {}
    local fallback = LocaleData[FALLBACK_LOCALE] or {}
    local value = getLocaleValue(language, key)

    if value == nil then
        value = getLocaleValue(fallback, key)
    end

    if value == nil then return key end
    return replaceVariables(value, variables)
end

---Returns the complete active locale merged over English for the NUI.
---@return table
function GetLocaleTable()
    local fallback = LocaleData[FALLBACK_LOCALE] or {}
    local language = LocaleData[GetLocaleCode()] or {}
    return deepMerge(fallback, language)
end

---Returns the immutable English fallback merged into a fresh table.
---@return table
function GetFallbackLocaleTable()
    return deepCopy(LocaleData[FALLBACK_LOCALE] or {})
end

---Returns sorted locale codes for diagnostics.
---@return string[]
function GetAvailableLocaleCodes()
    local codes = {}
    for code in pairs(LocaleData) do
        codes[#codes + 1] = code
    end
    table.sort(codes)
    return codes
end
