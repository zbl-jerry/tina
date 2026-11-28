// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

struct AppRepairStrings {
    let title: String
    let hubDescription: String
    let caption: String
    let empty: String
    let verificationFailure: String
    let quarantined: String
    let invalidSignature: String
    let notAccepted: String
    let removeQuarantine: String
    let confirmTitle: String
    /// "%@" is the app's display name.
    let confirmMessage: String
}

extension FeatureStrings {
    static func appRepair(_ language: AppLanguage) -> AppRepairStrings {
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

extension AppRepairStrings {
    static let enUS = AppRepairStrings(
        title: "App Repair",
        hubDescription: "See why an installed app will not open and clear a download quarantine when the signature still verifies.",
        caption: "Only apps with a quarantine flag, an invalid signature or a Gatekeeper refusal are listed. A quarantine flag is removed only when the signature verifies.",
        empty: "No problems found.",
        verificationFailure: "Could not verify this app. Scan again before retrying.",
        quarantined: "Downloaded from the internet",
        invalidSignature: "Signature is invalid",
        notAccepted: "Gatekeeper refuses it",
        removeQuarantine: "Remove Quarantine",
        confirmTitle: "Remove the quarantine flag?",
        confirmMessage: "%@ will open without the first-launch Gatekeeper prompt. Only continue for an app you trust."
    )

    static let ptBR = AppRepairStrings(
        title: "Reparo de Apps",
        hubDescription: "Veja por que um app instalado não abre e remova a quarentena de download quando a assinatura ainda é válida.",
        caption: "Apenas apps com quarentena, assinatura inválida ou recusa do Gatekeeper são listados. A quarentena só é removida quando a assinatura é válida.",
        empty: "Nenhum problema encontrado.",
        verificationFailure: "Não foi possível verificar este app. Faça uma nova análise antes de tentar novamente.",
        quarantined: "Baixado da internet",
        invalidSignature: "Assinatura inválida",
        notAccepted: "O Gatekeeper recusa",
        removeQuarantine: "Remover quarentena",
        confirmTitle: "Remover a quarentena?",
        confirmMessage: "%@ abrirá sem o aviso do Gatekeeper na primeira execução. Continue apenas para um app em que você confia."
    )

    static let tr = AppRepairStrings(
        title: "Uygulama Onarımı",
        hubDescription: "Yüklü bir uygulamanın neden açılmadığını görün ve imza hâlâ geçerliyse indirme karantinasını kaldırın.",
        caption: "Yalnızca karantinada, imzası geçersiz veya Gatekeeper tarafından reddedilen uygulamalar listelenir. Karantina yalnızca imza geçerliyse kaldırılır.",
        empty: "Sorun bulunamadı.",
        verificationFailure: "Bu uygulama doğrulanamadı. Tekrar denemeden önce yeniden tarayın.",
        quarantined: "İnternetten indirildi",
        invalidSignature: "İmza geçersiz",
        notAccepted: "Gatekeeper reddediyor",
        removeQuarantine: "Karantinayı kaldır",
        confirmTitle: "Karantina kaldırılsın mı?",
        confirmMessage: "%@ ilk açılışta Gatekeeper uyarısı olmadan açılacak. Yalnızca güvendiğiniz bir uygulama için devam edin."
    )

    static let ru = AppRepairStrings(
        title: "Исправление приложений",
        hubDescription: "Посмотрите, почему установленное приложение не открывается, и снимите карантин загрузки, если подпись ещё действительна.",
        caption: "Показываются только приложения в карантине, с недействительной подписью или отклонённые Gatekeeper. Карантин снимается только при действительной подписи.",
        empty: "Проблем не найдено.",
        verificationFailure: "Не удалось проверить приложение. Перед новой попыткой повторите сканирование.",
        quarantined: "Загружено из интернета",
        invalidSignature: "Подпись недействительна",
        notAccepted: "Gatekeeper отклоняет",
        removeQuarantine: "Снять карантин",
        confirmTitle: "Снять карантин?",
        confirmMessage: "%@ откроется без предупреждения Gatekeeper при первом запуске. Продолжайте, только если доверяете приложению."
    )

    static let es = AppRepairStrings(
        title: "Reparación de apps",
        hubDescription: "Mira por qué una app instalada no abre y quita la cuarentena de descarga cuando la firma sigue siendo válida.",
        caption: "Solo se listan las apps en cuarentena, con firma no válida o rechazadas por Gatekeeper. La cuarentena se quita solo si la firma es válida.",
        empty: "No se encontraron problemas.",
        verificationFailure: "No se pudo verificar esta app. Vuelve a analizarla antes de intentarlo de nuevo.",
        quarantined: "Descargada de internet",
        invalidSignature: "La firma no es válida",
        notAccepted: "Gatekeeper la rechaza",
        removeQuarantine: "Quitar cuarentena",
        confirmTitle: "¿Quitar la cuarentena?",
        confirmMessage: "%@ se abrirá sin el aviso de Gatekeeper en el primer inicio. Continúa solo con una app de confianza."
    )

    static let sk = AppRepairStrings(
        title: "Oprava aplikácií",
        hubDescription: "Pozrite, prečo sa nainštalovaná aplikácia neotvára, a odstráňte karanténu stiahnutia, ak je podpis stále platný.",
        caption: "Zobrazujú sa iba aplikácie v karanténe, s neplatným podpisom alebo odmietnuté Gatekeeperom. Karanténa sa odstráni iba pri platnom podpise.",
        empty: "Nenašli sa žiadne problémy.",
        verificationFailure: "Aplikáciu sa nepodarilo overiť. Pred ďalším pokusom ju znova skontrolujte.",
        quarantined: "Stiahnuté z internetu",
        invalidSignature: "Podpis je neplatný",
        notAccepted: "Gatekeeper ju odmieta",
        removeQuarantine: "Odstrániť karanténu",
        confirmTitle: "Odstrániť karanténu?",
        confirmMessage: "%@ sa otvorí bez výzvy Gatekeepera pri prvom spustení. Pokračujte iba pri aplikácii, ktorej dôverujete."
    )

    static let de = AppRepairStrings(
        title: "App-Reparatur",
        hubDescription: "Sehen Sie, warum eine installierte App nicht öffnet, und entfernen Sie die Download-Quarantäne, wenn die Signatur noch gültig ist.",
        caption: "Nur Apps mit Quarantäne, ungültiger Signatur oder Gatekeeper-Ablehnung werden gelistet. Die Quarantäne wird nur bei gültiger Signatur entfernt.",
        empty: "Keine Probleme gefunden.",
        verificationFailure: "Diese App konnte nicht überprüft werden. Scanne sie vor einem erneuten Versuch.",
        quarantined: "Aus dem Internet geladen",
        invalidSignature: "Signatur ist ungültig",
        notAccepted: "Gatekeeper lehnt sie ab",
        removeQuarantine: "Quarantäne entfernen",
        confirmTitle: "Quarantäne entfernen?",
        confirmMessage: "%@ öffnet dann ohne den Gatekeeper-Hinweis beim ersten Start. Fahren Sie nur bei einer App fort, der Sie vertrauen."
    )

    static let fr = AppRepairStrings(
        title: "Réparation d’app",
        hubDescription: "Voyez pourquoi une app installée ne s’ouvre pas et retirez la quarantaine de téléchargement quand la signature est encore valide.",
        caption: "Seules les apps en quarantaine, à signature invalide ou refusées par Gatekeeper sont listées. La quarantaine n’est retirée que si la signature est valide.",
        empty: "Aucun problème trouvé.",
        verificationFailure: "Impossible de vérifier cette app. Relancez l’analyse avant de réessayer.",
        quarantined: "Téléchargée depuis Internet",
        invalidSignature: "La signature est invalide",
        notAccepted: "Gatekeeper la refuse",
        removeQuarantine: "Retirer la quarantaine",
        confirmTitle: "Retirer la quarantaine ?",
        confirmMessage: "%@ s’ouvrira sans l’invite Gatekeeper au premier lancement. Ne continuez que pour une app de confiance."
    )

    static let it = AppRepairStrings(
        title: "Riparazione app",
        hubDescription: "Scopri perché un’app installata non si apre e rimuovi la quarantena del download quando la firma è ancora valida.",
        caption: "Sono elencate solo le app in quarantena, con firma non valida o rifiutate da Gatekeeper. La quarantena viene rimossa solo se la firma è valida.",
        empty: "Nessun problema trovato.",
        verificationFailure: "Impossibile verificare questa app. Esegui una nuova scansione prima di riprovare.",
        quarantined: "Scaricata da Internet",
        invalidSignature: "La firma non è valida",
        notAccepted: "Gatekeeper la rifiuta",
        removeQuarantine: "Rimuovi quarantena",
        confirmTitle: "Rimuovere la quarantena?",
        confirmMessage: "%@ si aprirà senza l’avviso di Gatekeeper al primo avvio. Continua solo per un’app di cui ti fidi."
    )

    static let ja = AppRepairStrings(
        title: "アプリの修復",
        hubDescription: "インストール済みのアプリが開かない理由を確認し、署名が有効な場合に限りダウンロード隔離を解除します。",
        caption: "隔離属性、無効な署名、Gatekeeper による拒否があるアプリだけを表示します。隔離属性の解除は署名が有効な場合のみ行えます。",
        empty: "問題は見つかりませんでした。",
        verificationFailure: "このアプリを検証できませんでした。もう一度スキャンしてから再試行してください。",
        quarantined: "インターネットからダウンロード",
        invalidSignature: "署名が無効",
        notAccepted: "Gatekeeper が拒否",
        removeQuarantine: "隔離を解除",
        confirmTitle: "隔離属性を解除しますか？",
        confirmMessage: "%@ は初回起動時の Gatekeeper 確認なしで開きます。信頼できるアプリにのみ続行してください。"
    )

    static let ko = AppRepairStrings(
        title: "앱 복구",
        hubDescription: "설치된 앱이 열리지 않는 이유를 확인하고 서명이 유효할 때만 다운로드 격리를 해제합니다.",
        caption: "격리 표시, 유효하지 않은 서명 또는 Gatekeeper 거부가 있는 앱만 표시됩니다. 격리는 서명이 유효할 때만 해제됩니다.",
        empty: "문제를 찾지 못했습니다.",
        verificationFailure: "이 앱을 확인할 수 없습니다. 다시 시도하기 전에 다시 검사하세요.",
        quarantined: "인터넷에서 다운로드됨",
        invalidSignature: "서명이 유효하지 않음",
        notAccepted: "Gatekeeper가 거부함",
        removeQuarantine: "격리 해제",
        confirmTitle: "격리를 해제할까요?",
        confirmMessage: "%@은(는) 첫 실행 시 Gatekeeper 확인 없이 열립니다. 신뢰하는 앱에만 계속하십시오."
    )

    static let zhHans = AppRepairStrings(
        title: "App 修复",
        hubDescription: "查看已安装 App 无法打开的原因，并仅在签名有效时移除下载隔离。",
        caption: "只列出带隔离属性、签名无效或被 Gatekeeper 拒绝的 App。仅当签名有效时才提供移除隔离。",
        empty: "未发现问题。",
        verificationFailure: "无法验证此 App。请重新扫描后再试。",
        quarantined: "从互联网下载",
        invalidSignature: "签名无效",
        notAccepted: "被 Gatekeeper 拒绝",
        removeQuarantine: "移除隔离",
        confirmTitle: "要移除隔离属性吗？",
        confirmMessage: "%@ 将在首次启动时跳过 Gatekeeper 提示。只对信任的 App 继续。"
    )

    static let zhTW = AppRepairStrings(
        title: "App 修復",
        hubDescription: "查看已安裝 App 無法開啟的原因，並僅在簽章有效時移除下載隔離。",
        caption: "只列出帶隔離屬性、簽章無效或被 Gatekeeper 拒絕的 App。僅在簽章有效時提供移除隔離。",
        empty: "未發現問題。",
        verificationFailure: "無法驗證此 App。請重新掃描後再試。",
        quarantined: "從網際網路下載",
        invalidSignature: "簽章無效",
        notAccepted: "被 Gatekeeper 拒絕",
        removeQuarantine: "移除隔離",
        confirmTitle: "要移除隔離屬性嗎？",
        confirmMessage: "%@ 將在首次啟動時略過 Gatekeeper 提示。只對信任的 App 繼續。"
    )

    static let zhHK = AppRepairStrings(
        title: "App 修復",
        hubDescription: "查看已安裝 App 無法開啟的原因，並僅在簽章有效時移除下載隔離。",
        caption: "只列出帶隔離屬性、簽章無效或被 Gatekeeper 拒絕的 App。僅在簽章有效時提供移除隔離。",
        empty: "未發現問題。",
        verificationFailure: "無法驗證此 App。請重新掃描後再試。",
        quarantined: "從網際網路下載",
        invalidSignature: "簽章無效",
        notAccepted: "被 Gatekeeper 拒絕",
        removeQuarantine: "移除隔離",
        confirmTitle: "要移除隔離屬性嗎？",
        confirmMessage: "%@ 將在首次啟動時略過 Gatekeeper 提示。只對信任的 App 繼續。"
    )

    static let uk = AppRepairStrings(
        title: "Виправлення програм",
        hubDescription: "Подивіться, чому встановлена програма не відкривається, і зніміть карантин завантаження, якщо підпис ще дійсний.",
        caption: "Показуються лише програми в карантині, з недійсним підписом або відхилені Gatekeeper. Карантин знімається лише за дійсного підпису.",
        empty: "Проблем не знайдено.",
        verificationFailure: "Не вдалося перевірити програму. Перед новою спробою повторіть сканування.",
        quarantined: "Завантажено з інтернету",
        invalidSignature: "Підпис недійсний",
        notAccepted: "Gatekeeper відхиляє",
        removeQuarantine: "Зняти карантин",
        confirmTitle: "Зняти карантин?",
        confirmMessage: "%@ відкриється без попередження Gatekeeper під час першого запуску. Продовжуйте, лише якщо довіряєте програмі."
    )
}
