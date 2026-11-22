// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// The live caption feature’s own copy. Kept separate from the shared Strings
/// bundle, like every other feature, so a translator can see one screen’s
/// vocabulary at once.
struct CaptionFeatureStrings {
    let title: String
    let hubDescription: String
    let start: String
    let stop: String
    let listening: String
    let idle: String
    let starting: String
    let recentSessions: String
    let noSessions: String
    let exportSRT: String
    let exportMarkdown: String
    let exportPlainText: String
    let copyAll: String
    let revealInFinder: String
    let deleteSession: String
    let deleteConfirm: String
    let autoSave: String
    let saveFolder: String
    let chooseFolder: String
    let resetFolder: String
    let fontSize: String
    let maxLines: String
    let resetPosition: String
    let showOverlay: String
    let sessionLanguage: String
    let permissionRequired: String
    let unsupportedOS: String
    let speechDenied: String
    let onDeviceUnavailable: String
    let speechUnavailable: String
    let recorderConflict: String
    let audioUnavailable: String
    let dictationHint: String
    let privacyNote: String
    let exportFailed: String
}

extension FeatureStrings {
    static func captions(_ language: AppLanguage) -> CaptionFeatureStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .uk: return .uk
        }
    }
}

extension CaptionFeatureStrings {
    static let enUS = CaptionFeatureStrings(
        title: "Live captions",
        hubDescription: "Turn the sound your Mac is playing into captions on screen, with on-device recognition and a local transcript you can export.",
        start: "Start listening",
        stop: "Stop listening",
        listening: "Listening to your Mac",
        idle: "Not listening",
        starting: "Starting…",
        recentSessions: "Recent sessions",
        noSessions: "Finished sessions will appear here.",
        exportSRT: "Export SRT subtitles",
        exportMarkdown: "Export Markdown",
        exportPlainText: "Export plain text",
        copyAll: "Copy all text",
        revealInFinder: "Show in Finder",
        deleteSession: "Delete session",
        deleteConfirm: "Delete this session and its saved file?",
        autoSave: "Save sessions automatically",
        saveFolder: "Save folder",
        chooseFolder: "Choose folder…",
        resetFolder: "Use the default folder",
        fontSize: "Caption size",
        maxLines: "Maximum lines",
        resetPosition: "Reset caption position",
        showOverlay: "Show the caption bar",
        sessionLanguage: "Recognition language",
        permissionRequired: "Speech Recognition permission is required.",
        unsupportedOS: "Live captions need macOS 14.4 or later.",
        speechDenied: "Speech Recognition is turned off for Tina. Allow it in System Settings to start listening.",
        onDeviceUnavailable: "On-device recognition is not available for this language. Choose another language or add it in System Settings.",
        speechUnavailable: "Speech recognition is not available right now. Check Dictation in System Settings and try again.",
        recorderConflict: "Live captions and screen recording cannot listen to the system audio at the same time. Stop the recording first.",
        audioUnavailable: "Tina could not read your Mac’s sound. Check the System Audio Recording permission and try again.",
        dictationHint: "On macOS 14 and 15, Dictation must be turned on in System Settings.",
        privacyNote: "Recognition runs on this Mac. Captions and saved sessions never leave it.",
        exportFailed: "The session could not be exported. Check the save folder and try again."
    )

    static let ptBR = CaptionFeatureStrings(
        title: "Legendas ao vivo",
        hubDescription: "Transforme o som que o Mac está reproduzindo em legendas na tela, com reconhecimento no dispositivo e uma transcrição local para exportar.",
        start: "Começar a ouvir",
        stop: "Parar de ouvir",
        listening: "Ouvindo o seu Mac",
        idle: "Não está ouvindo",
        starting: "Iniciando…",
        recentSessions: "Sessões recentes",
        noSessions: "As sessões concluídas aparecerão aqui.",
        exportSRT: "Exportar legendas SRT",
        exportMarkdown: "Exportar Markdown",
        exportPlainText: "Exportar texto simples",
        copyAll: "Copiar todo o texto",
        revealInFinder: "Mostrar no Finder",
        deleteSession: "Apagar sessão",
        deleteConfirm: "Apagar esta sessão e o arquivo salvo?",
        autoSave: "Salvar sessões automaticamente",
        saveFolder: "Pasta de salvamento",
        chooseFolder: "Escolher pasta…",
        resetFolder: "Usar a pasta padrão",
        fontSize: "Tamanho da legenda",
        maxLines: "Máximo de linhas",
        resetPosition: "Redefinir posição da legenda",
        showOverlay: "Mostrar a barra de legendas",
        sessionLanguage: "Idioma de reconhecimento",
        permissionRequired: "A permissão de Reconhecimento de Fala é necessária.",
        unsupportedOS: "As legendas ao vivo exigem o macOS 14.4 ou posterior.",
        speechDenied: "O Reconhecimento de Fala está desativado para o Tina. Permita-o nos Ajustes do Sistema para começar a ouvir.",
        onDeviceUnavailable: "O reconhecimento no dispositivo não está disponível para este idioma. Escolha outro idioma ou adicione-o nos Ajustes do Sistema.",
        speechUnavailable: "O reconhecimento de fala não está disponível agora. Verifique o Ditado nos Ajustes do Sistema e tente novamente.",
        recorderConflict: "As legendas ao vivo e a gravação de tela não podem ouvir o áudio do sistema ao mesmo tempo. Pare a gravação primeiro.",
        audioUnavailable: "O Tina não conseguiu ler o som do Mac. Verifique a permissão de Gravação de Áudio do Sistema e tente novamente.",
        dictationHint: "No macOS 14 e 15, o Ditado precisa estar ativado nos Ajustes do Sistema.",
        privacyNote: "O reconhecimento acontece neste Mac. As legendas e as sessões salvas nunca saem dele.",
        exportFailed: "Não foi possível exportar a sessão. Verifique a pasta de salvamento e tente novamente."
    )

    static let tr = CaptionFeatureStrings(
        title: "Canlı altyazılar",
        hubDescription: "Mac’inizin çaldığı sesi cihaz üzerinde tanıyarak ekranda altyazıya dönüştürün ve yerel bir dökümü dışa aktarın.",
        start: "Dinlemeye başla",
        stop: "Dinlemeyi durdur",
        listening: "Mac’iniz dinleniyor",
        idle: "Dinlenmiyor",
        starting: "Başlatılıyor…",
        recentSessions: "Son oturumlar",
        noSessions: "Tamamlanan oturumlar burada görünecek.",
        exportSRT: "SRT altyazı olarak dışa aktar",
        exportMarkdown: "Markdown olarak dışa aktar",
        exportPlainText: "Düz metin olarak dışa aktar",
        copyAll: "Tüm metni kopyala",
        revealInFinder: "Finder’da göster",
        deleteSession: "Oturumu sil",
        deleteConfirm: "Bu oturum ve kayıtlı dosyası silinsin mi?",
        autoSave: "Oturumları otomatik kaydet",
        saveFolder: "Kayıt klasörü",
        chooseFolder: "Klasör seç…",
        resetFolder: "Varsayılan klasörü kullan",
        fontSize: "Altyazı boyutu",
        maxLines: "En fazla satır",
        resetPosition: "Altyazı konumunu sıfırla",
        showOverlay: "Altyazı çubuğunu göster",
        sessionLanguage: "Tanıma dili",
        permissionRequired: "Konuşma Tanıma izni gerekiyor.",
        unsupportedOS: "Canlı altyazılar macOS 14.4 veya üstünü gerektirir.",
        speechDenied: "Tina için Konuşma Tanıma kapalı. Dinlemeye başlamak için Sistem Ayarları’ndan izin verin.",
        onDeviceUnavailable: "Bu dil için cihaz üzerinde tanıma kullanılamıyor. Başka bir dil seçin veya Sistem Ayarları’ndan ekleyin.",
        speechUnavailable: "Konuşma tanıma şu anda kullanılamıyor. Sistem Ayarları’ndaki Dikteyi kontrol edip yeniden deneyin.",
        recorderConflict: "Canlı altyazılar ve ekran kaydı sistem sesini aynı anda dinleyemez. Önce kaydı durdurun.",
        audioUnavailable: "Tina Mac’inizin sesini okuyamadı. Sistem Sesi Kaydı iznini kontrol edip yeniden deneyin.",
        dictationHint: "macOS 14 ve 15’te Sistem Ayarları’nda Dikte açık olmalıdır.",
        privacyNote: "Tanıma bu Mac’te çalışır. Altyazılar ve kayıtlı oturumlar buradan ayrılmaz.",
        exportFailed: "Oturum dışa aktarılamadı. Kayıt klasörünü kontrol edip yeniden deneyin."
    )

    static let ru = CaptionFeatureStrings(
        title: "Живые субтитры",
        hubDescription: "Превращайте звук, который воспроизводит Mac, в субтитры на экране: с распознаванием на устройстве и локальной расшифровкой для экспорта.",
        start: "Начать прослушивание",
        stop: "Остановить прослушивание",
        listening: "Прослушивается звук Mac",
        idle: "Прослушивание выключено",
        starting: "Запуск…",
        recentSessions: "Недавние сеансы",
        noSessions: "Завершённые сеансы появятся здесь.",
        exportSRT: "Экспортировать субтитры SRT",
        exportMarkdown: "Экспортировать Markdown",
        exportPlainText: "Экспортировать простой текст",
        copyAll: "Скопировать весь текст",
        revealInFinder: "Показать в Finder",
        deleteSession: "Удалить сеанс",
        deleteConfirm: "Удалить этот сеанс и сохранённый файл?",
        autoSave: "Автоматически сохранять сеансы",
        saveFolder: "Папка сохранения",
        chooseFolder: "Выбрать папку…",
        resetFolder: "Использовать папку по умолчанию",
        fontSize: "Размер субтитров",
        maxLines: "Максимум строк",
        resetPosition: "Сбросить положение субтитров",
        showOverlay: "Показывать панель субтитров",
        sessionLanguage: "Язык распознавания",
        permissionRequired: "Требуется разрешение «Распознавание речи».",
        unsupportedOS: "Живые субтитры требуют macOS 14.4 или новее.",
        speechDenied: "Распознавание речи отключено для Tina. Разрешите его в Системных настройках, чтобы начать.",
        onDeviceUnavailable: "Распознавание на устройстве недоступно для этого языка. Выберите другой язык или добавьте его в Системных настройках.",
        speechUnavailable: "Распознавание речи сейчас недоступно. Проверьте «Диктовку» в Системных настройках и повторите попытку.",
        recorderConflict: "Живые субтитры и запись экрана не могут одновременно слушать системный звук. Сначала остановите запись.",
        audioUnavailable: "Tina не удалось прочитать звук Mac. Проверьте разрешение на запись системного звука и повторите попытку.",
        dictationHint: "В macOS 14 и 15 должна быть включена «Диктовка» в Системных настройках.",
        privacyNote: "Распознавание выполняется на этом Mac. Субтитры и сохранённые сеансы никуда не отправляются.",
        exportFailed: "Не удалось экспортировать сеанс. Проверьте папку сохранения и повторите попытку."
    )

    static let es = CaptionFeatureStrings(
        title: "Subtítulos en vivo",
        hubDescription: "Convierte el sonido que reproduce tu Mac en subtítulos en pantalla, con reconocimiento en el dispositivo y una transcripción local que puedes exportar.",
        start: "Empezar a escuchar",
        stop: "Dejar de escuchar",
        listening: "Escuchando tu Mac",
        idle: "Sin escuchar",
        starting: "Iniciando…",
        recentSessions: "Sesiones recientes",
        noSessions: "Las sesiones terminadas aparecerán aquí.",
        exportSRT: "Exportar subtítulos SRT",
        exportMarkdown: "Exportar Markdown",
        exportPlainText: "Exportar texto sin formato",
        copyAll: "Copiar todo el texto",
        revealInFinder: "Mostrar en Finder",
        deleteSession: "Eliminar sesión",
        deleteConfirm: "¿Eliminar esta sesión y su archivo guardado?",
        autoSave: "Guardar sesiones automáticamente",
        saveFolder: "Carpeta de guardado",
        chooseFolder: "Elegir carpeta…",
        resetFolder: "Usar la carpeta predeterminada",
        fontSize: "Tamaño del subtítulo",
        maxLines: "Líneas máximas",
        resetPosition: "Restablecer posición del subtítulo",
        showOverlay: "Mostrar la barra de subtítulos",
        sessionLanguage: "Idioma de reconocimiento",
        permissionRequired: "Se necesita permiso de Reconocimiento de voz.",
        unsupportedOS: "Los subtítulos en vivo requieren macOS 14.4 o posterior.",
        speechDenied: "El Reconocimiento de voz está desactivado para Tina. Permítelo en Ajustes del Sistema para empezar.",
        onDeviceUnavailable: "El reconocimiento en el dispositivo no está disponible para este idioma. Elige otro idioma o añádelo en Ajustes del Sistema.",
        speechUnavailable: "El reconocimiento de voz no está disponible ahora. Comprueba el Dictado en Ajustes del Sistema e inténtalo de nuevo.",
        recorderConflict: "Los subtítulos en vivo y la grabación de pantalla no pueden escuchar el audio del sistema a la vez. Detén la grabación primero.",
        audioUnavailable: "Tina no pudo leer el sonido de tu Mac. Comprueba el permiso de Grabación de audio del sistema e inténtalo de nuevo.",
        dictationHint: "En macOS 14 y 15, el Dictado debe estar activado en Ajustes del Sistema.",
        privacyNote: "El reconocimiento se ejecuta en este Mac. Los subtítulos y las sesiones guardadas nunca salen de él.",
        exportFailed: "No se pudo exportar la sesión. Comprueba la carpeta de guardado e inténtalo de nuevo."
    )

    static let sk = CaptionFeatureStrings(
        title: "Živé titulky",
        hubDescription: "Premeňte zvuk, ktorý Mac prehráva, na titulky na obrazovke – s rozpoznávaním v zariadení a lokálnym prepisom na export.",
        start: "Začať počúvať",
        stop: "Prestať počúvať",
        listening: "Počúva sa zvuk Macu",
        idle: "Nepočúva sa",
        starting: "Spúšťa sa…",
        recentSessions: "Nedávne relácie",
        noSessions: "Ukončené relácie sa zobrazia tu.",
        exportSRT: "Exportovať titulky SRT",
        exportMarkdown: "Exportovať Markdown",
        exportPlainText: "Exportovať čistý text",
        copyAll: "Kopírovať celý text",
        revealInFinder: "Zobraziť vo Finderi",
        deleteSession: "Odstrániť reláciu",
        deleteConfirm: "Odstrániť túto reláciu aj uložený súbor?",
        autoSave: "Automaticky ukladať relácie",
        saveFolder: "Priečinok na ukladanie",
        chooseFolder: "Vybrať priečinok…",
        resetFolder: "Použiť predvolený priečinok",
        fontSize: "Veľkosť titulkov",
        maxLines: "Maximálny počet riadkov",
        resetPosition: "Obnoviť polohu titulkov",
        showOverlay: "Zobraziť panel titulkov",
        sessionLanguage: "Jazyk rozpoznávania",
        permissionRequired: "Vyžaduje sa povolenie Rozpoznávanie reči.",
        unsupportedOS: "Živé titulky vyžadujú macOS 14.4 alebo novší.",
        speechDenied: "Rozpoznávanie reči je pre Tinu vypnuté. Povoľte ho v Nastaveniach systému, aby ste mohli začať.",
        onDeviceUnavailable: "Rozpoznávanie v zariadení nie je pre tento jazyk dostupné. Vyberte iný jazyk alebo ho pridajte v Nastaveniach systému.",
        speechUnavailable: "Rozpoznávanie reči teraz nie je dostupné. Skontrolujte Diktovanie v Nastaveniach systému a skúste to znova.",
        recorderConflict: "Živé titulky a nahrávanie obrazovky nemôžu počúvať systémový zvuk súčasne. Najprv zastavte nahrávanie.",
        audioUnavailable: "Tina nedokázala prečítať zvuk Macu. Skontrolujte povolenie Nahrávanie systémového zvuku a skúste to znova.",
        dictationHint: "V macOS 14 a 15 musí byť v Nastaveniach systému zapnuté Diktovanie.",
        privacyNote: "Rozpoznávanie prebieha na tomto Macu. Titulky ani uložené relácie ho nikdy neopustia.",
        exportFailed: "Reláciu sa nepodarilo exportovať. Skontrolujte priečinok na ukladanie a skúste to znova."
    )

    static let de = CaptionFeatureStrings(
        title: "Live-Untertitel",
        hubDescription: "Wandle den Ton, den dein Mac abspielt, in Untertitel auf dem Bildschirm um – mit Erkennung auf dem Gerät und einem lokalen Transkript zum Exportieren.",
        start: "Zuhören starten",
        stop: "Zuhören beenden",
        listening: "Dein Mac wird abgehört",
        idle: "Kein Zuhören",
        starting: "Wird gestartet…",
        recentSessions: "Letzte Sitzungen",
        noSessions: "Beendete Sitzungen erscheinen hier.",
        exportSRT: "SRT-Untertitel exportieren",
        exportMarkdown: "Markdown exportieren",
        exportPlainText: "Reinen Text exportieren",
        copyAll: "Gesamten Text kopieren",
        revealInFinder: "Im Finder zeigen",
        deleteSession: "Sitzung löschen",
        deleteConfirm: "Diese Sitzung und ihre gespeicherte Datei löschen?",
        autoSave: "Sitzungen automatisch sichern",
        saveFolder: "Speicherordner",
        chooseFolder: "Ordner wählen…",
        resetFolder: "Standardordner verwenden",
        fontSize: "Untertitelgröße",
        maxLines: "Maximale Zeilen",
        resetPosition: "Untertitelposition zurücksetzen",
        showOverlay: "Untertitelbalken anzeigen",
        sessionLanguage: "Erkennungssprache",
        permissionRequired: "Die Berechtigung zur Spracherkennung ist erforderlich.",
        unsupportedOS: "Live-Untertitel erfordern macOS 14.4 oder neuer.",
        speechDenied: "Die Spracherkennung ist für Tina ausgeschaltet. Erlaube sie in den Systemeinstellungen, um zu starten.",
        onDeviceUnavailable: "Die Erkennung auf dem Gerät ist für diese Sprache nicht verfügbar. Wähle eine andere Sprache oder füge sie in den Systemeinstellungen hinzu.",
        speechUnavailable: "Die Spracherkennung ist gerade nicht verfügbar. Prüfe das Diktat in den Systemeinstellungen und versuche es erneut.",
        recorderConflict: "Live-Untertitel und Bildschirmaufnahme können nicht gleichzeitig den Systemton abhören. Beende zuerst die Aufnahme.",
        audioUnavailable: "Tina konnte den Ton deines Macs nicht lesen. Prüfe die Berechtigung zur Aufnahme von Systemaudio und versuche es erneut.",
        dictationHint: "Unter macOS 14 und 15 muss das Diktat in den Systemeinstellungen eingeschaltet sein.",
        privacyNote: "Die Erkennung läuft auf diesem Mac. Untertitel und gespeicherte Sitzungen verlassen ihn nie.",
        exportFailed: "Die Sitzung konnte nicht exportiert werden. Prüfe den Speicherordner und versuche es erneut."
    )

    static let fr = CaptionFeatureStrings(
        title: "Sous-titres en direct",
        hubDescription: "Transformez le son lu par votre Mac en sous-titres à l’écran, avec une reconnaissance sur l’appareil et une transcription locale à exporter.",
        start: "Commencer l’écoute",
        stop: "Arrêter l’écoute",
        listening: "Écoute de votre Mac",
        idle: "Écoute inactive",
        starting: "Démarrage…",
        recentSessions: "Sessions récentes",
        noSessions: "Les sessions terminées apparaîtront ici.",
        exportSRT: "Exporter les sous-titres SRT",
        exportMarkdown: "Exporter en Markdown",
        exportPlainText: "Exporter en texte brut",
        copyAll: "Copier tout le texte",
        revealInFinder: "Afficher dans le Finder",
        deleteSession: "Supprimer la session",
        deleteConfirm: "Supprimer cette session et son fichier enregistré ?",
        autoSave: "Enregistrer les sessions automatiquement",
        saveFolder: "Dossier d’enregistrement",
        chooseFolder: "Choisir un dossier…",
        resetFolder: "Utiliser le dossier par défaut",
        fontSize: "Taille des sous-titres",
        maxLines: "Lignes maximum",
        resetPosition: "Réinitialiser la position des sous-titres",
        showOverlay: "Afficher la barre de sous-titres",
        sessionLanguage: "Langue de reconnaissance",
        permissionRequired: "L’autorisation Reconnaissance vocale est requise.",
        unsupportedOS: "Les sous-titres en direct nécessitent macOS 14.4 ou ultérieur.",
        speechDenied: "La Reconnaissance vocale est désactivée pour Tina. Autorisez-la dans Réglages Système pour commencer.",
        onDeviceUnavailable: "La reconnaissance sur l’appareil n’est pas disponible pour cette langue. Choisissez une autre langue ou ajoutez-la dans Réglages Système.",
        speechUnavailable: "La reconnaissance vocale n’est pas disponible pour le moment. Vérifiez la Dictée dans Réglages Système et réessayez.",
        recorderConflict: "Les sous-titres en direct et l’enregistrement d’écran ne peuvent pas écouter l’audio du système en même temps. Arrêtez d’abord l’enregistrement.",
        audioUnavailable: "Tina n’a pas pu lire le son de votre Mac. Vérifiez l’autorisation d’enregistrement de l’audio système et réessayez.",
        dictationHint: "Sous macOS 14 et 15, la Dictée doit être activée dans Réglages Système.",
        privacyNote: "La reconnaissance s’exécute sur ce Mac. Les sous-titres et les sessions enregistrées ne le quittent jamais.",
        exportFailed: "La session n’a pas pu être exportée. Vérifiez le dossier d’enregistrement et réessayez."
    )

    static let it = CaptionFeatureStrings(
        title: "Sottotitoli in tempo reale",
        hubDescription: "Trasforma l’audio riprodotto dal Mac in sottotitoli sullo schermo, con riconoscimento sul dispositivo e una trascrizione locale da esportare.",
        start: "Inizia ad ascoltare",
        stop: "Interrompi ascolto",
        listening: "Ascolto del Mac",
        idle: "Ascolto disattivato",
        starting: "Avvio…",
        recentSessions: "Sessioni recenti",
        noSessions: "Le sessioni terminate appariranno qui.",
        exportSRT: "Esporta sottotitoli SRT",
        exportMarkdown: "Esporta Markdown",
        exportPlainText: "Esporta testo semplice",
        copyAll: "Copia tutto il testo",
        revealInFinder: "Mostra nel Finder",
        deleteSession: "Elimina sessione",
        deleteConfirm: "Eliminare questa sessione e il file salvato?",
        autoSave: "Salva le sessioni automaticamente",
        saveFolder: "Cartella di salvataggio",
        chooseFolder: "Scegli cartella…",
        resetFolder: "Usa la cartella predefinita",
        fontSize: "Dimensione sottotitoli",
        maxLines: "Righe massime",
        resetPosition: "Ripristina posizione sottotitoli",
        showOverlay: "Mostra la barra dei sottotitoli",
        sessionLanguage: "Lingua di riconoscimento",
        permissionRequired: "È necessaria l’autorizzazione Riconoscimento vocale.",
        unsupportedOS: "I sottotitoli in tempo reale richiedono macOS 14.4 o successivo.",
        speechDenied: "Il Riconoscimento vocale è disattivato per Tina. Consentilo in Impostazioni di Sistema per iniziare.",
        onDeviceUnavailable: "Il riconoscimento sul dispositivo non è disponibile per questa lingua. Scegli un’altra lingua o aggiungila in Impostazioni di Sistema.",
        speechUnavailable: "Il riconoscimento vocale non è disponibile ora. Controlla il Dettato in Impostazioni di Sistema e riprova.",
        recorderConflict: "Sottotitoli in tempo reale e registrazione dello schermo non possono ascoltare l’audio di sistema insieme. Interrompi prima la registrazione.",
        audioUnavailable: "Tina non è riuscita a leggere l’audio del Mac. Controlla l’autorizzazione Registrazione audio di sistema e riprova.",
        dictationHint: "Su macOS 14 e 15, il Dettato deve essere attivo in Impostazioni di Sistema.",
        privacyNote: "Il riconoscimento avviene su questo Mac. I sottotitoli e le sessioni salvate non lo lasciano mai.",
        exportFailed: "Impossibile esportare la sessione. Controlla la cartella di salvataggio e riprova."
    )

    static let ja = CaptionFeatureStrings(
        title: "リアルタイム字幕",
        hubDescription: "Mac が再生している音を画面上の字幕に変換します。オンデバイス認識と、書き出せるローカル文字起こし付きです。",
        start: "聞き取りを開始",
        stop: "聞き取りを停止",
        listening: "Mac の音を聞き取り中",
        idle: "停止中",
        starting: "開始中…",
        recentSessions: "最近のセッション",
        noSessions: "終了したセッションがここに表示されます。",
        exportSRT: "SRT 字幕を書き出す",
        exportMarkdown: "Markdown を書き出す",
        exportPlainText: "プレーンテキストを書き出す",
        copyAll: "すべてのテキストをコピー",
        revealInFinder: "Finder で表示",
        deleteSession: "セッションを削除",
        deleteConfirm: "このセッションと保存ファイルを削除しますか？",
        autoSave: "セッションを自動保存",
        saveFolder: "保存先フォルダ",
        chooseFolder: "フォルダを選択…",
        resetFolder: "デフォルトのフォルダを使用",
        fontSize: "字幕サイズ",
        maxLines: "最大行数",
        resetPosition: "字幕の位置をリセット",
        showOverlay: "字幕バーを表示",
        sessionLanguage: "認識言語",
        permissionRequired: "音声認識の許可が必要です。",
        unsupportedOS: "リアルタイム字幕には macOS 14.4 以降が必要です。",
        speechDenied: "Tina の音声認識がオフになっています。システム設定で許可してから開始してください。",
        onDeviceUnavailable: "この言語ではオンデバイス認識を利用できません。別の言語を選ぶか、システム設定で追加してください。",
        speechUnavailable: "現在、音声認識を利用できません。システム設定の音声入力入力を確認して、もう一度お試しください。",
        recorderConflict: "リアルタイム字幕と画面収録は同時にシステム音声を聞き取れません。先に収録を停止してください。",
        audioUnavailable: "Mac の音を読み取れませんでした。システム音声録音の許可を確認して、もう一度お試しください。",
        dictationHint: "macOS 14 と 15 では、システム設定で音声入力入力をオンにする必要があります。",
        privacyNote: "認識はこの Mac 上で実行されます。字幕と保存したセッションが外部に送信されることはありません。",
        exportFailed: "セッションを書き出せませんでした。保存先フォルダを確認して、もう一度お試しください。"
    )

    static let ko = CaptionFeatureStrings(
        title: "실시간 자막",
        hubDescription: "Mac에서 재생되는 소리를 화면 자막으로 바꿉니다. 기기 내 인식과 내보낼 수 있는 로컬 기록을 제공합니다.",
        start: "듣기 시작",
        stop: "듣기 중지",
        listening: "Mac 소리를 듣는 중",
        idle: "듣지 않음",
        starting: "시작 중…",
        recentSessions: "최근 세션",
        noSessions: "완료된 세션이 여기에 표시됩니다.",
        exportSRT: "SRT 자막 내보내기",
        exportMarkdown: "Markdown 내보내기",
        exportPlainText: "일반 텍스트 내보내기",
        copyAll: "모든 텍스트 복사",
        revealInFinder: "Finder에서 보기",
        deleteSession: "세션 삭제",
        deleteConfirm: "이 세션과 저장된 파일을 삭제할까요?",
        autoSave: "세션 자동 저장",
        saveFolder: "저장 폴더",
        chooseFolder: "폴더 선택…",
        resetFolder: "기본 폴더 사용",
        fontSize: "자막 크기",
        maxLines: "최대 줄 수",
        resetPosition: "자막 위치 초기화",
        showOverlay: "자막 막대 표시",
        sessionLanguage: "인식 언어",
        permissionRequired: "음성 인식 권한이 필요합니다.",
        unsupportedOS: "실시간 자막에는 macOS 14.4 이상이 필요합니다.",
        speechDenied: "Tina의 음성 인식이 꺼져 있습니다. 시스템 설정에서 허용한 후 시작하세요.",
        onDeviceUnavailable: "이 언어는 기기 내 인식을 사용할 수 없습니다. 다른 언어를 선택하거나 시스템 설정에서 추가하세요.",
        speechUnavailable: "지금은 음성 인식을 사용할 수 없습니다. 시스템 설정의 받아쓰기를 확인하고 다시 시도하세요.",
        recorderConflict: "실시간 자막과 화면 기록은 동시에 시스템 오디오를 들을 수 없습니다. 먼저 기록을 중지하세요.",
        audioUnavailable: "Mac의 소리를 읽을 수 없습니다. 시스템 오디오 녹음 권한을 확인하고 다시 시도하세요.",
        dictationHint: "macOS 14 및 15에서는 시스템 설정에서 받아쓰기를 켜야 합니다.",
        privacyNote: "인식은 이 Mac에서 실행됩니다. 자막과 저장된 세션은 외부로 전송되지 않습니다.",
        exportFailed: "세션을 내보낼 수 없습니다. 저장 폴더를 확인하고 다시 시도하세요."
    )

    static let zhHans = CaptionFeatureStrings(
        title: "实时字幕",
        hubDescription: "把 Mac 正在播放的声音变成屏幕字幕，使用设备端识别，并保存可导出的本地文字记录。",
        start: "开始收听",
        stop: "停止收听",
        listening: "正在收听 Mac 的声音",
        idle: "未收听",
        starting: "正在启动…",
        recentSessions: "最近会话",
        noSessions: "结束的会话会显示在这里。",
        exportSRT: "导出 SRT 字幕",
        exportMarkdown: "导出 Markdown",
        exportPlainText: "导出纯文本",
        copyAll: "复制全部文字",
        revealInFinder: "在 Finder 中显示",
        deleteSession: "删除会话",
        deleteConfirm: "删除这个会话及其保存的文件？",
        autoSave: "自动保存会话",
        saveFolder: "保存文件夹",
        chooseFolder: "选择文件夹…",
        resetFolder: "使用默认文件夹",
        fontSize: "字幕大小",
        maxLines: "最大行数",
        resetPosition: "重置字幕位置",
        showOverlay: "显示字幕条",
        sessionLanguage: "识别语言",
        permissionRequired: "需要语音识别权限。",
        unsupportedOS: "实时字幕需要 macOS 14.4 或更高版本。",
        speechDenied: "Tina 的语音识别已关闭。请在系统设置中允许后再开始。",
        onDeviceUnavailable: "该语言不支持设备端识别。请选择其他语言，或在系统设置中添加该语言。",
        speechUnavailable: "当前无法使用语音识别。请在系统设置中检查听写并重试。",
        recorderConflict: "实时字幕与屏幕录制不能同时收听系统音频。请先停止录制。",
        audioUnavailable: "Tina 无法读取 Mac 的声音。请检查系统音频录制权限后重试。",
        dictationHint: "在 macOS 14 和 15 上，需要在系统设置中开启听写。",
        privacyNote: "识别在本机完成。字幕和保存的会话不会离开这台 Mac。",
        exportFailed: "无法导出会话。请检查保存文件夹后重试。"
    )

    static let zhTW = CaptionFeatureStrings(
        title: "即時字幕",
        hubDescription: "把 Mac 正在播放的聲音變成螢幕字幕，使用裝置端辨識，並保存可匯出的本機文字記錄。",
        start: "開始聆聽",
        stop: "停止聆聽",
        listening: "正在聆聽 Mac 的聲音",
        idle: "未聆聽",
        starting: "正在啟動…",
        recentSessions: "最近工作階段",
        noSessions: "結束的工作階段會顯示在這裡。",
        exportSRT: "匯出 SRT 字幕",
        exportMarkdown: "匯出 Markdown",
        exportPlainText: "匯出純文字",
        copyAll: "複製全部文字",
        revealInFinder: "在 Finder 中顯示",
        deleteSession: "刪除工作階段",
        deleteConfirm: "刪除這個工作階段及其儲存的檔案？",
        autoSave: "自動儲存工作階段",
        saveFolder: "儲存資料夾",
        chooseFolder: "選擇資料夾…",
        resetFolder: "使用預設資料夾",
        fontSize: "字幕大小",
        maxLines: "最大行數",
        resetPosition: "重設字幕位置",
        showOverlay: "顯示字幕列",
        sessionLanguage: "辨識語言",
        permissionRequired: "需要語音辨識權限。",
        unsupportedOS: "即時字幕需要 macOS 14.4 或以上版本。",
        speechDenied: "Tina 的語音辨識已關閉。請在系統設定中允許後再開始。",
        onDeviceUnavailable: "此語言不支援裝置端辨識。請選擇其他語言，或在系統設定中加入此語言。",
        speechUnavailable: "目前無法使用語音辨識。請在系統設定中檢查聽寫並再試一次。",
        recorderConflict: "即時字幕與螢幕錄影不能同時聆聽系統音訊。請先停止錄影。",
        audioUnavailable: "Tina 無法讀取 Mac 的聲音。請檢查系統音訊錄製權限後再試一次。",
        dictationHint: "在 macOS 14 和 15 上，需要在系統設定中開啟聽寫。",
        privacyNote: "辨識在本機完成。字幕和儲存的工作階段不會離開這台 Mac。",
        exportFailed: "無法匯出工作階段。請檢查儲存資料夾後再試一次。"
    )

    static let zhHK = CaptionFeatureStrings(
        title: "即時字幕",
        hubDescription: "將 Mac 正在播放的聲音變成螢幕字幕，使用裝置端辨識，並保存可匯出的本機文字記錄。",
        start: "開始聆聽",
        stop: "停止聆聽",
        listening: "正在聆聽 Mac 的聲音",
        idle: "未聆聽",
        starting: "正在啟動…",
        recentSessions: "最近工作階段",
        noSessions: "結束的工作階段會顯示在這裡。",
        exportSRT: "匯出 SRT 字幕",
        exportMarkdown: "匯出 Markdown",
        exportPlainText: "匯出純文字",
        copyAll: "複製全部文字",
        revealInFinder: "在 Finder 中顯示",
        deleteSession: "刪除工作階段",
        deleteConfirm: "刪除這個工作階段及其儲存的檔案？",
        autoSave: "自動儲存工作階段",
        saveFolder: "儲存資料夾",
        chooseFolder: "選擇資料夾…",
        resetFolder: "使用預設資料夾",
        fontSize: "字幕大小",
        maxLines: "最大行數",
        resetPosition: "重設字幕位置",
        showOverlay: "顯示字幕列",
        sessionLanguage: "辨識語言",
        permissionRequired: "需要語音辨識權限。",
        unsupportedOS: "即時字幕需要 macOS 14.4 或以上版本。",
        speechDenied: "Tina 的語音辨識已關閉。請在系統設定中允許後再開始。",
        onDeviceUnavailable: "此語言不支援裝置端辨識。請選擇其他語言，或在系統設定中加入此語言。",
        speechUnavailable: "目前無法使用語音辨識。請在系統設定中檢查聽寫並再試一次。",
        recorderConflict: "即時字幕與螢幕錄影不能同時聆聽系統音訊。請先停止錄影。",
        audioUnavailable: "Tina 無法讀取 Mac 的聲音。請檢查系統音訊錄製權限後再試一次。",
        dictationHint: "在 macOS 14 和 15 上，需要在系統設定中開啟聽寫。",
        privacyNote: "辨識在本機完成。字幕和儲存的工作階段不會離開這台 Mac。",
        exportFailed: "無法匯出工作階段。請檢查儲存資料夾後再試一次。"
    )

    static let uk = CaptionFeatureStrings(
        title: "Живі субтитри",
        hubDescription: "Перетворюйте звук, який відтворює Mac, на субтитри на екрані: з розпізнаванням на пристрої та локальним текстом для експорту.",
        start: "Почати слухати",
        stop: "Припинити слухати",
        listening: "Прослуховується звук Mac",
        idle: "Прослуховування вимкнено",
        starting: "Запуск…",
        recentSessions: "Недавні сеанси",
        noSessions: "Завершені сеанси з’являться тут.",
        exportSRT: "Експортувати субтитри SRT",
        exportMarkdown: "Експортувати Markdown",
        exportPlainText: "Експортувати простий текст",
        copyAll: "Скопіювати весь текст",
        revealInFinder: "Показати у Finder",
        deleteSession: "Видалити сеанс",
        deleteConfirm: "Видалити цей сеанс і збережений файл?",
        autoSave: "Автоматично зберігати сеанси",
        saveFolder: "Папка збереження",
        chooseFolder: "Вибрати папку…",
        resetFolder: "Використовувати типову папку",
        fontSize: "Розмір субтитрів",
        maxLines: "Максимум рядків",
        resetPosition: "Скинути положення субтитрів",
        showOverlay: "Показувати панель субтитрів",
        sessionLanguage: "Мова розпізнавання",
        permissionRequired: "Потрібен дозвіл «Розпізнавання мовлення».",
        unsupportedOS: "Живі субтитри потребують macOS 14.4 або новішої.",
        speechDenied: "Розпізнавання мовлення вимкнено для Tina. Дозвольте його в Системних налаштуваннях, щоб почати.",
        onDeviceUnavailable: "Розпізнавання на пристрої недоступне для цієї мови. Виберіть іншу мову або додайте її в Системних налаштуваннях.",
        speechUnavailable: "Розпізнавання мовлення зараз недоступне. Перевірте «Диктування» в Системних налаштуваннях і спробуйте ще раз.",
        recorderConflict: "Живі субтитри й запис екрана не можуть одночасно слухати системний звук. Спочатку зупиніть запис.",
        audioUnavailable: "Tina не вдалося прочитати звук Mac. Перевірте дозвіл на запис системного звуку й спробуйте ще раз.",
        dictationHint: "У macOS 14 і 15 потрібно ввімкнути «Диктування» в Системних налаштуваннях.",
        privacyNote: "Розпізнавання виконується на цьому Mac. Субтитри й збережені сеанси ніколи його не залишають.",
        exportFailed: "Не вдалося експортувати сеанс. Перевірте папку збереження й спробуйте ще раз."
    )
}
