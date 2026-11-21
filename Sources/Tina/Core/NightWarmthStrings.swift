// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// Copy for the night warmth schedule: the settings card, the panel block and
/// the one-line status both share.
struct NightWarmthStrings {
    let title: String
    let hubDescription: String
    let caption: String
    let schedule: String
    let scheduleSun: String
    let scheduleCustom: String
    let dayPhase: String
    let eveningPhase: String
    let bedtimePhase: String
    let pausedPhase: String
    /// "%@ · %d K", filled with a phase name and the temperature.
    let temperatureFormat: String
    let bedtimeToggle: String
    let bedtimeCaption: String
    let bedtimeTime: String
    let wakeTime: String
    let nightStart: String
    let nightEnd: String
    let transition: String
    let transitionSlow: String
    let transitionFast: String
    let presets: String
    let pauseHour: String
    let pauseUntilSunrise: String
    let pauseUntilWake: String
    let resume: String
    let warmer: String
    let cooler: String
    /// "Paused until %@"
    let pausedFormat: String
    /// "Next: %@"
    let nextFormat: String
    let location: String
    let useTimeZone: String
    let latitude: String
    let longitude: String
    let manualCaption: String
    let restoreCaption: String
    let unsupported: String

    func phaseName(_ phase: NightWarmthPhase) -> String {
        switch phase {
        case .day: return dayPhase
        case .evening: return eveningPhase
        case .bedtime: return bedtimePhase
        case .paused: return pausedPhase
        }
    }
}

extension FeatureStrings {
    static func nightWarmth(_ language: AppLanguage) -> NightWarmthStrings {
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

extension NightWarmthStrings {
    static let enUS = NightWarmthStrings(
        title: "Night warmth",
        hubDescription: "A warmer screen after sunset",
        caption: "Tints every display through the evening and restores the daytime colours in the morning.",
        schedule: "Schedule",
        scheduleSun: "Sunset to sunrise",
        scheduleCustom: "Custom hours",
        dayPhase: "Daytime",
        eveningPhase: "Evening",
        bedtimePhase: "Bedtime",
        pausedPhase: "Paused",
        temperatureFormat: "%@ · %d K",
        bedtimeToggle: "Bedtime",
        bedtimeCaption: "Use a deeper temperature between bedtime and wake time.",
        bedtimeTime: "Bedtime",
        wakeTime: "Wake time",
        nightStart: "Night starts",
        nightEnd: "Night ends",
        transition: "Transition",
        transitionSlow: "Slow, one hour",
        transitionFast: "Fast, 20 seconds",
        presets: "Presets",
        pauseHour: "Pause for 1 hour",
        pauseUntilSunrise: "Pause until sunrise",
        pauseUntilWake: "Pause until wake time",
        resume: "Resume schedule",
        warmer: "Warmer",
        cooler: "Cooler",
        pausedFormat: "Paused until %@",
        nextFormat: "Next: %@",
        location: "Location",
        useTimeZone: "Use my time zone",
        latitude: "Latitude",
        longitude: "Longitude",
        manualCaption: "Warmer, Cooler and presets last until the next scheduled change.",
        restoreCaption: "Turning this off restores the original colours.",
        unsupported: "These displays do not accept a colour table."
    )

    static let zhHans = NightWarmthStrings(
        title: "夜间色温",
        hubDescription: "日落后自动调暖屏幕",
        caption: "傍晚渐暖，早晨恢复日光色温，不修改系统 Night Shift 设置。",
        schedule: "日程",
        scheduleSun: "日落到日出",
        scheduleCustom: "自定义时段",
        dayPhase: "白天",
        eveningPhase: "傍晚",
        bedtimePhase: "睡前",
        pausedPhase: "已暂停",
        temperatureFormat: "%@ · %d K",
        bedtimeToggle: "睡前模式",
        bedtimeCaption: "在就寝到起床之间使用更暖的色温。",
        bedtimeTime: "就寝时间",
        wakeTime: "起床时间",
        nightStart: "夜间开始",
        nightEnd: "夜间结束",
        transition: "过渡",
        transitionSlow: "慢速，1 小时",
        transitionFast: "快速，20 秒",
        presets: "预设",
        pauseHour: "暂停 1 小时",
        pauseUntilSunrise: "暂停到日出",
        pauseUntilWake: "暂停到起床",
        resume: "恢复日程",
        warmer: "更暖",
        cooler: "更冷",
        pausedFormat: "已暂停至 %@",
        nextFormat: "下一步：%@",
        location: "位置",
        useTimeZone: "使用我的时区",
        latitude: "纬度",
        longitude: "经度",
        manualCaption: "更暖、更冷和预设只影响当前阶段，下一次日程变化时恢复。",
        restoreCaption: "关闭后会恢复原始颜色。",
        unsupported: "这些显示器不接受颜色表。"
    )

    static let zhTW = NightWarmthStrings(
        title: "夜間色溫",
        hubDescription: "日落後自動調暖螢幕",
        caption: "傍晚漸暖，早晨恢復日光色溫，不修改系統 Night Shift 設定。",
        schedule: "排程",
        scheduleSun: "日落到日出",
        scheduleCustom: "自訂時段",
        dayPhase: "白天",
        eveningPhase: "傍晚",
        bedtimePhase: "睡前",
        pausedPhase: "已暫停",
        temperatureFormat: "%@ · %d K",
        bedtimeToggle: "睡前模式",
        bedtimeCaption: "在就寢到起床之間使用更暖的色溫。",
        bedtimeTime: "就寢時間",
        wakeTime: "起床時間",
        nightStart: "夜間開始",
        nightEnd: "夜間結束",
        transition: "過渡",
        transitionSlow: "慢速，1 小時",
        transitionFast: "快速，20 秒",
        presets: "預設",
        pauseHour: "暫停 1 小時",
        pauseUntilSunrise: "暫停到日出",
        pauseUntilWake: "暫停到起床",
        resume: "恢復排程",
        warmer: "更暖",
        cooler: "更冷",
        pausedFormat: "已暫停至 %@",
        nextFormat: "下一步：%@",
        location: "位置",
        useTimeZone: "使用我的時區",
        latitude: "緯度",
        longitude: "經度",
        manualCaption: "更暖、更冷和預設只影響目前階段，下一次排程變化時恢復。",
        restoreCaption: "關閉後會恢復原始顏色。",
        unsupported: "這些顯示器不接受顏色表。"
    )

    static let zhHK = NightWarmthStrings(
        title: "夜間色溫",
        hubDescription: "日落後自動調暖螢幕",
        caption: "傍晚漸暖，早上恢復日光色溫，不修改系統 Night Shift 設定。",
        schedule: "時間表",
        scheduleSun: "日落到日出",
        scheduleCustom: "自訂時段",
        dayPhase: "白天",
        eveningPhase: "傍晚",
        bedtimePhase: "睡前",
        pausedPhase: "已暫停",
        temperatureFormat: "%@ · %d K",
        bedtimeToggle: "睡前模式",
        bedtimeCaption: "在就寢到起床之間使用更暖的色溫。",
        bedtimeTime: "就寢時間",
        wakeTime: "起床時間",
        nightStart: "夜間開始",
        nightEnd: "夜間結束",
        transition: "過渡",
        transitionSlow: "慢速，1 小時",
        transitionFast: "快速，20 秒",
        presets: "預設",
        pauseHour: "暫停 1 小時",
        pauseUntilSunrise: "暫停到日出",
        pauseUntilWake: "暫停到起床",
        resume: "恢復時間表",
        warmer: "更暖",
        cooler: "更冷",
        pausedFormat: "已暫停至 %@",
        nextFormat: "下一步：%@",
        location: "位置",
        useTimeZone: "使用我的時區",
        latitude: "緯度",
        longitude: "經度",
        manualCaption: "更暖、更冷和預設只影響目前階段，下一次時間表變化時恢復。",
        restoreCaption: "關閉後會恢復原有顏色。",
        unsupported: "這些顯示器不接受顏色表。"
    )

    static let ja = NightWarmthStrings(
        title: "夜間の色温度",
        hubDescription: "日没後に画面を暖かい色に調整",
        caption: "夕方から暖かくし、朝に日中の色へ戻します。システムの Night Shift 設定は変更しません。",
        schedule: "スケジュール",
        scheduleSun: "日没から日の出まで",
        scheduleCustom: "指定した時間",
        dayPhase: "日中",
        eveningPhase: "夕方",
        bedtimePhase: "就寝",
        pausedPhase: "一時停止",
        temperatureFormat: "%@ · %d K",
        bedtimeToggle: "就寝モード",
        bedtimeCaption: "就寝時刻から起床時刻まで、より暖かい色温度を使います。",
        bedtimeTime: "就寝時刻",
        wakeTime: "起床時刻",
        nightStart: "夜の開始",
        nightEnd: "夜の終了",
        transition: "切り替え",
        transitionSlow: "ゆっくり（1 時間）",
        transitionFast: "速く（20 秒）",
        presets: "プリセット",
        pauseHour: "1 時間停止",
        pauseUntilSunrise: "日の出まで停止",
        pauseUntilWake: "起床まで停止",
        resume: "スケジュールを再開",
        warmer: "暖かく",
        cooler: "涼しく",
        pausedFormat: "%@ まで停止中",
        nextFormat: "次: %@",
        location: "位置",
        useTimeZone: "タイムゾーンを使う",
        latitude: "緯度",
        longitude: "経度",
        manualCaption: "暖かく、涼しく、プリセットは次のスケジュール変更まで有効です。",
        restoreCaption: "オフにすると元の色に戻ります。",
        unsupported: "このディスプレイは色テーブルを受け付けません。"
    )

    static let ko = NightWarmthStrings(
        title: "야간 색온도",
        hubDescription: "일몰 후 화면을 따뜻하게 조정",
        caption: "저녁에는 따뜻하게, 아침에는 원래 색으로 돌아갑니다. 시스템 Night Shift 설정은 바꾸지 않습니다.",
        schedule: "일정",
        scheduleSun: "일몰부터 일출까지",
        scheduleCustom: "사용자 지정 시간",
        dayPhase: "낮",
        eveningPhase: "저녁",
        bedtimePhase: "취침",
        pausedPhase: "일시 정지",
        temperatureFormat: "%@ · %d K",
        bedtimeToggle: "취침 모드",
        bedtimeCaption: "취침 시간부터 기상 시간까지 더 따뜻한 색온도를 사용합니다.",
        bedtimeTime: "취침 시간",
        wakeTime: "기상 시간",
        nightStart: "야간 시작",
        nightEnd: "야간 종료",
        transition: "전환",
        transitionSlow: "느리게, 1시간",
        transitionFast: "빠르게, 20초",
        presets: "프리셋",
        pauseHour: "1시간 일시 정지",
        pauseUntilSunrise: "일출까지 정지",
        pauseUntilWake: "기상까지 정지",
        resume: "일정 재개",
        warmer: "더 따뜻하게",
        cooler: "더 차갑게",
        pausedFormat: "%@까지 일시 정지",
        nextFormat: "다음: %@",
        location: "위치",
        useTimeZone: "내 시간대 사용",
        latitude: "위도",
        longitude: "경도",
        manualCaption: "더 따뜻하게, 더 차갑게, 프리셋은 다음 일정 변경까지 유지됩니다.",
        restoreCaption: "끄면 원래 색으로 돌아갑니다.",
        unsupported: "이 디스플레이는 색상 테이블을 지원하지 않습니다."
    )

    static let de = NightWarmthStrings(
        title: "Nachtwärme",
        hubDescription: "Der Bildschirm wird nach Sonnenuntergang wärmer",
        caption: "Färbt abends alle Displays wärmer und stellt morgens die Tagesfarben wieder her. Die Night-Shift-Einstellungen bleiben unberührt.",
        schedule: "Zeitplan",
        scheduleSun: "Sonnenuntergang bis Sonnenaufgang",
        scheduleCustom: "Eigene Zeiten",
        dayPhase: "Tag",
        eveningPhase: "Abend",
        bedtimePhase: "Schlafenszeit",
        pausedPhase: "Pausiert",
        temperatureFormat: "%@ · %d K",
        bedtimeToggle: "Schlafenszeit",
        bedtimeCaption: "Zwischen Schlafens- und Aufwachzeit eine wärmere Temperatur verwenden.",
        bedtimeTime: "Schlafenszeit",
        wakeTime: "Aufwachzeit",
        nightStart: "Nachtbeginn",
        nightEnd: "Nachtende",
        transition: "Übergang",
        transitionSlow: "Langsam, eine Stunde",
        transitionFast: "Schnell, 20 Sekunden",
        presets: "Voreinstellungen",
        pauseHour: "1 Stunde pausieren",
        pauseUntilSunrise: "Bis Sonnenaufgang pausieren",
        pauseUntilWake: "Bis Aufwachzeit pausieren",
        resume: "Zeitplan fortsetzen",
        warmer: "Wärmer",
        cooler: "Kühler",
        pausedFormat: "Pausiert bis %@",
        nextFormat: "Weiter: %@",
        location: "Standort",
        useTimeZone: "Meine Zeitzone verwenden",
        latitude: "Breitengrad",
        longitude: "Längengrad",
        manualCaption: "Wärmer, Kühler und Voreinstellungen gelten bis zur nächsten geplanten Änderung.",
        restoreCaption: "Beim Ausschalten werden die ursprünglichen Farben wiederhergestellt.",
        unsupported: "Diese Displays akzeptieren keine Farbtabelle."
    )

    static let fr = NightWarmthStrings(
        title: "Chaleur nocturne",
        hubDescription: "Un écran plus chaud après le coucher du soleil",
        caption: "Teinte tous les écrans le soir et rétablit les couleurs de jour le matin. Les réglages Night Shift ne sont pas modifiés.",
        schedule: "Programmation",
        scheduleSun: "Du coucher au lever du soleil",
        scheduleCustom: "Heures personnalisées",
        dayPhase: "Jour",
        eveningPhase: "Soir",
        bedtimePhase: "Coucher",
        pausedPhase: "En pause",
        temperatureFormat: "%@ · %d K",
        bedtimeToggle: "Mode coucher",
        bedtimeCaption: "Utiliser une température plus chaude entre le coucher et le réveil.",
        bedtimeTime: "Heure du coucher",
        wakeTime: "Heure du réveil",
        nightStart: "Début de nuit",
        nightEnd: "Fin de nuit",
        transition: "Transition",
        transitionSlow: "Lente, une heure",
        transitionFast: "Rapide, 20 secondes",
        presets: "Préréglages",
        pauseHour: "Pause d’une heure",
        pauseUntilSunrise: "Pause jusqu’au lever",
        pauseUntilWake: "Pause jusqu’au réveil",
        resume: "Reprendre la programmation",
        warmer: "Plus chaud",
        cooler: "Plus froid",
        pausedFormat: "En pause jusqu’à %@",
        nextFormat: "Ensuite : %@",
        location: "Position",
        useTimeZone: "Utiliser mon fuseau horaire",
        latitude: "Latitude",
        longitude: "Longitude",
        manualCaption: "Plus chaud, Plus froid et les préréglages durent jusqu’au prochain changement programmé.",
        restoreCaption: "Désactiver rétablit les couleurs d’origine.",
        unsupported: "Ces écrans n’acceptent pas de table de couleurs."
    )

    static let it = NightWarmthStrings(
        title: "Calore notturno",
        hubDescription: "Riscalda lo schermo dopo il tramonto",
        caption: "Colora tutti i display la sera e ripristina i colori diurni al mattino. Le impostazioni Night Shift non vengono toccate.",
        schedule: "Programmazione",
        scheduleSun: "Dal tramonto all’alba",
        scheduleCustom: "Orari personalizzati",
        dayPhase: "Giorno",
        eveningPhase: "Sera",
        bedtimePhase: "Nanna",
        pausedPhase: "In pausa",
        temperatureFormat: "%@ · %d K",
        bedtimeToggle: "Modalità nanna",
        bedtimeCaption: "Usa una temperatura più calda tra l’ora di andare a letto e il risveglio.",
        bedtimeTime: "Ora di andare a letto",
        wakeTime: "Ora di sveglia",
        nightStart: "Inizio notte",
        nightEnd: "Fine notte",
        transition: "Transizione",
        transitionSlow: "Lenta, un’ora",
        transitionFast: "Veloce, 20 secondi",
        presets: "Preimpostazioni",
        pauseHour: "Pausa di 1 ora",
        pauseUntilSunrise: "Pausa fino all’alba",
        pauseUntilWake: "Pausa fino al risveglio",
        resume: "Riprendi programmazione",
        warmer: "Più caldo",
        cooler: "Più freddo",
        pausedFormat: "In pausa fino alle %@",
        nextFormat: "Poi: %@",
        location: "Posizione",
        useTimeZone: "Usa il mio fuso orario",
        latitude: "Latitudine",
        longitude: "Longitudine",
        manualCaption: "Più caldo, Più freddo e le preimpostazioni durano fino al prossimo cambio programmato.",
        restoreCaption: "Disattivando si ripristinano i colori originali.",
        unsupported: "Questi display non accettano una tabella colori."
    )

    static let ptBR = NightWarmthStrings(
        title: "Calor noturno",
        hubDescription: "Deixa a tela mais quente após o pôr do sol",
        caption: "Colore todos os monitores à noite e restaura as cores do dia pela manhã. As opções do Night Shift não são alteradas.",
        schedule: "Programação",
        scheduleSun: "Do pôr ao nascer do sol",
        scheduleCustom: "Horários personalizados",
        dayPhase: "Dia",
        eveningPhase: "Noite",
        bedtimePhase: "Hora de dormir",
        pausedPhase: "Pausado",
        temperatureFormat: "%@ · %d K",
        bedtimeToggle: "Modo dormir",
        bedtimeCaption: "Usar uma temperatura mais quente entre a hora de dormir e a de acordar.",
        bedtimeTime: "Hora de dormir",
        wakeTime: "Hora de acordar",
        nightStart: "Início da noite",
        nightEnd: "Fim da noite",
        transition: "Transição",
        transitionSlow: "Lenta, uma hora",
        transitionFast: "Rápida, 20 segundos",
        presets: "Predefinições",
        pauseHour: "Pausar por 1 hora",
        pauseUntilSunrise: "Pausar até o nascer do sol",
        pauseUntilWake: "Pausar até acordar",
        resume: "Retomar programação",
        warmer: "Mais quente",
        cooler: "Mais frio",
        pausedFormat: "Pausado até %@",
        nextFormat: "Próximo: %@",
        location: "Localização",
        useTimeZone: "Usar meu fuso horário",
        latitude: "Latitude",
        longitude: "Longitude",
        manualCaption: "Mais quente, Mais frio e as predefinições duram até a próxima mudança programada.",
        restoreCaption: "Desativar restaura as cores originais.",
        unsupported: "Estes monitores não aceitam tabela de cores."
    )

    static let ru = NightWarmthStrings(
        title: "Ночное тепло",
        hubDescription: "Экран теплее после заката",
        caption: "Вечером все дисплеи теплеют, утром возвращается дневной цвет. Настройки Night Shift не изменяются.",
        schedule: "Расписание",
        scheduleSun: "От заката до рассвета",
        scheduleCustom: "Своё время",
        dayPhase: "День",
        eveningPhase: "Вечер",
        bedtimePhase: "Сон",
        pausedPhase: "Пауза",
        temperatureFormat: "%@ · %d K",
        bedtimeToggle: "Режим сна",
        bedtimeCaption: "Более тёплая температура от времени сна до пробуждения.",
        bedtimeTime: "Время сна",
        wakeTime: "Время пробуждения",
        nightStart: "Начало ночи",
        nightEnd: "Конец ночи",
        transition: "Переход",
        transitionSlow: "Медленный, час",
        transitionFast: "Быстрый, 20 секунд",
        presets: "Пресеты",
        pauseHour: "Пауза на час",
        pauseUntilSunrise: "Пауза до рассвета",
        pauseUntilWake: "Пауза до пробуждения",
        resume: "Возобновить расписание",
        warmer: "Теплее",
        cooler: "Холоднее",
        pausedFormat: "Пауза до %@",
        nextFormat: "Далее: %@",
        location: "Местоположение",
        useTimeZone: "Использовать мой часовой пояс",
        latitude: "Широта",
        longitude: "Долгота",
        manualCaption: "Теплее, Холоднее и пресеты действуют до следующего изменения расписания.",
        restoreCaption: "При выключении восстанавливаются исходные цвета.",
        unsupported: "Эти дисплеи не принимают таблицу цветов."
    )

    static let uk = NightWarmthStrings(
        title: "Нічне тепло",
        hubDescription: "Екран тепліший після заходу сонця",
        caption: "Увечері всі дисплеї теплішають, уранці повертається денний колір. Налаштування Night Shift не змінюються.",
        schedule: "Розклад",
        scheduleSun: "Від заходу до сходу",
        scheduleCustom: "Власний час",
        dayPhase: "День",
        eveningPhase: "Вечір",
        bedtimePhase: "Сон",
        pausedPhase: "Пауза",
        temperatureFormat: "%@ · %d K",
        bedtimeToggle: "Режим сну",
        bedtimeCaption: "Тепліша температура від часу сну до пробудження.",
        bedtimeTime: "Час сну",
        wakeTime: "Час пробудження",
        nightStart: "Початок ночі",
        nightEnd: "Кінець ночі",
        transition: "Перехід",
        transitionSlow: "Повільний, година",
        transitionFast: "Швидкий, 20 секунд",
        presets: "Пресети",
        pauseHour: "Пауза на годину",
        pauseUntilSunrise: "Пауза до сходу",
        pauseUntilWake: "Пауза до пробудження",
        resume: "Відновити розклад",
        warmer: "Тепліше",
        cooler: "Холодніше",
        pausedFormat: "Пауза до %@",
        nextFormat: "Далі: %@",
        location: "Місце",
        useTimeZone: "Використовувати мій часовий пояс",
        latitude: "Широта",
        longitude: "Довгота",
        manualCaption: "Тепліше, Холодніше та пресети діють до наступної зміни розкладу.",
        restoreCaption: "Вимкнення відновлює початкові кольори.",
        unsupported: "Ці дисплеї не приймають таблицю кольорів."
    )

    static let es = NightWarmthStrings(
        title: "Calor nocturno",
        hubDescription: "Calienta la pantalla tras el atardecer",
        caption: "Tiñe todas las pantallas por la noche y recupera los colores diurnos por la mañana. Los ajustes de Night Shift no se tocan.",
        schedule: "Horario",
        scheduleSun: "Del atardecer al amanecer",
        scheduleCustom: "Horas personalizadas",
        dayPhase: "Día",
        eveningPhase: "Tarde",
        bedtimePhase: "Hora de dormir",
        pausedPhase: "En pausa",
        temperatureFormat: "%@ · %d K",
        bedtimeToggle: "Modo dormir",
        bedtimeCaption: "Usar una temperatura más cálida entre la hora de dormir y la de despertar.",
        bedtimeTime: "Hora de dormir",
        wakeTime: "Hora de despertar",
        nightStart: "Inicio de la noche",
        nightEnd: "Fin de la noche",
        transition: "Transición",
        transitionSlow: "Lenta, una hora",
        transitionFast: "Rápida, 20 segundos",
        presets: "Ajustes",
        pauseHour: "Pausar 1 hora",
        pauseUntilSunrise: "Pausar hasta el amanecer",
        pauseUntilWake: "Pausar hasta despertar",
        resume: "Reanudar horario",
        warmer: "Más cálido",
        cooler: "Más frío",
        pausedFormat: "En pausa hasta %@",
        nextFormat: "Siguiente: %@",
        location: "Ubicación",
        useTimeZone: "Usar mi zona horaria",
        latitude: "Latitud",
        longitude: "Longitud",
        manualCaption: "Más cálido, Más frío y los ajustes duran hasta el próximo cambio programado.",
        restoreCaption: "Al desactivarlo se restauran los colores originales.",
        unsupported: "Estas pantallas no aceptan una tabla de colores."
    )

    static let tr = NightWarmthStrings(
        title: "Gece sıcaklığı",
        hubDescription: "Gün batımından sonra ekranı ısıtır",
        caption: "Akşam tüm ekranları ısıtır, sabah gündüz renklerine döner. Night Shift ayarlarına dokunmaz.",
        schedule: "Zamanlama",
        scheduleSun: "Gün batımından gün doğumuna",
        scheduleCustom: "Özel saatler",
        dayPhase: "Gündüz",
        eveningPhase: "Akşam",
        bedtimePhase: "Uyku",
        pausedPhase: "Duraklatıldı",
        temperatureFormat: "%@ · %d K",
        bedtimeToggle: "Uyku modu",
        bedtimeCaption: "Uyku saatinden uyanma saatine kadar daha sıcak bir renk sıcaklığı kullanır.",
        bedtimeTime: "Uyku saati",
        wakeTime: "Uyanma saati",
        nightStart: "Gece başlangıcı",
        nightEnd: "Gece bitişi",
        transition: "Geçiş",
        transitionSlow: "Yavaş, bir saat",
        transitionFast: "Hızlı, 20 saniye",
        presets: "Ön ayarlar",
        pauseHour: "1 saat duraklat",
        pauseUntilSunrise: "Gün doğumuna kadar duraklat",
        pauseUntilWake: "Uyanma saatine kadar duraklat",
        resume: "Zamanlamayı sürdür",
        warmer: "Daha sıcak",
        cooler: "Daha soğuk",
        pausedFormat: "%@ saatine kadar duraklatıldı",
        nextFormat: "Sıradaki: %@",
        location: "Konum",
        useTimeZone: "Saat dilimimi kullan",
        latitude: "Enlem",
        longitude: "Boylam",
        manualCaption: "Daha sıcak, Daha soğuk ve ön ayarlar bir sonraki zamanlanmış değişikliğe kadar geçerlidir.",
        restoreCaption: "Kapatmak özgün renkleri geri yükler.",
        unsupported: "Bu ekranlar renk tablosunu kabul etmiyor."
    )

    static let sk = NightWarmthStrings(
        title: "Nočné teplo",
        hubDescription: "Zohreje obrazovku po západe slnka",
        caption: "Večer zohreje všetky displeje a ráno obnoví denné farby. Nastavenia Night Shift sa nemenia.",
        schedule: "Rozvrh",
        scheduleSun: "Od západu do východu slnka",
        scheduleCustom: "Vlastné časy",
        dayPhase: "Deň",
        eveningPhase: "Večer",
        bedtimePhase: "Spánok",
        pausedPhase: "Pozastavené",
        temperatureFormat: "%@ · %d K",
        bedtimeToggle: "Režim spánku",
        bedtimeCaption: "Použiť teplejšiu teplotu medzi časom spánku a prebudenia.",
        bedtimeTime: "Čas spánku",
        wakeTime: "Čas prebudenia",
        nightStart: "Začiatok noci",
        nightEnd: "Koniec noci",
        transition: "Prechod",
        transitionSlow: "Pomalý, hodina",
        transitionFast: "Rýchly, 20 sekúnd",
        presets: "Predvoľby",
        pauseHour: "Pozastaviť na 1 hodinu",
        pauseUntilSunrise: "Pozastaviť do východu",
        pauseUntilWake: "Pozastaviť do prebudenia",
        resume: "Obnoviť rozvrh",
        warmer: "Teplejšie",
        cooler: "Chladnejšie",
        pausedFormat: "Pozastavené do %@",
        nextFormat: "Ďalej: %@",
        location: "Poloha",
        useTimeZone: "Použiť moje časové pásmo",
        latitude: "Zemepisná šírka",
        longitude: "Zemepisná dĺžka",
        manualCaption: "Teplejšie, Chladnejšie a predvoľby platia do najbližšej zmeny rozvrhu.",
        restoreCaption: "Vypnutím sa obnovia pôvodné farby.",
        unsupported: "Tieto displeje neprijímajú tabuľku farieb."
    )
}
