#!/usr/bin/env python3
"""生成各语言的 Localizable.strings 和 InfoPlist.strings 到 Resources/<语言>.lproj/。

要改翻译或加新语言，只改这个文件里的表格即可；build.sh 每次打包都会重新生成。
键（KEYS）就是英文原文，代码里用 L("...") 取翻译。
"""
import os

KEYS = [
    "R", "W", "Int", "Ext", "Internal", "External", "Disk",
    "Temperature %@      Health %@",
    "Good", "Failing!",
    "Read %@      Write %@",
    "Life used %@",
    "Total written %@",
    "Powered on %@ h      Unsafe shutdowns %@",
    "No temperature or health data (enclosure may not support it)",
    "%@: %@ used of %@ · %@ free",
    "Show in menu bar",
    "No disks detected",
    "smartctl not found, temperature unavailable",
    "Install it with: brew install smartmontools",
    "Launch at login",
    "Quit",
    "Couldn't change launch at login",
    "Try moving the app to the Applications folder first.",
    "Language", "Follow System",
]

APP_NAME = {
    "en": "Disk Monitor",
    "zh-Hans": "硬盘监控",
    "zh-Hant": "硬碟監控",
    "ja": "ディスクモニター",
    "ko": "디스크 모니터",
    "de": "Festplattenmonitor",
    "fr": "Moniteur de disques",
    "es": "Monitor de discos",
}

T = {
    "en": {},  # 英文直接用键
    "zh-Hans": [
        "读", "写", "内置", "外置", "内置", "外置", "硬盘",
        "温度 %@      健康 %@",
        "正常", "异常！",
        "读取 %@      写入 %@",
        "寿命已用 %@",
        "累计写入 %@",
        "通电 %@ 小时      非正常关机 %@ 次",
        "读不到温度和健康信息（硬盘盒可能不支持）",
        "%@：已用 %@ / 共 %@ · 可用 %@",
        "在状态栏显示",
        "未检测到硬盘",
        "未找到 smartctl，无法读取温度",
        "请先运行：brew install smartmontools",
        "开机自动启动",
        "退出",
        "设置开机自动启动失败",
        "建议先把应用移到“应用程序”文件夹再试。",
        "语言", "跟随系统",
    ],
    "zh-Hant": [
        "讀", "寫", "內建", "外接", "內建", "外接", "硬碟",
        "溫度 %@      健康 %@",
        "正常", "異常！",
        "讀取 %@      寫入 %@",
        "壽命已用 %@",
        "累計寫入 %@",
        "通電 %@ 小時      非正常關機 %@ 次",
        "讀不到溫度和健康資訊（硬碟盒可能不支援）",
        "%@：已使用 %@ / 共 %@ · 可用 %@",
        "在選單列顯示",
        "未偵測到硬碟",
        "找不到 smartctl，無法讀取溫度",
        "請先執行：brew install smartmontools",
        "登入時自動啟動",
        "結束",
        "設定登入時自動啟動失敗",
        "建議先將 App 移到「應用程式」檔案夾再試。",
        "語言", "跟隨系統",
    ],
    "ja": [
        "読", "書", "内蔵", "外付", "内蔵", "外付け", "ディスク",
        "温度 %@      状態 %@",
        "正常", "異常！",
        "読み込み %@      書き込み %@",
        "寿命使用率 %@",
        "総書き込み量 %@",
        "通電時間 %@ 時間      異常シャットダウン %@ 回",
        "温度と状態を取得できません（ケースが非対応の可能性）",
        "%@：使用済み %@ / %@ · 空き %@",
        "メニューバーに表示",
        "ディスクが見つかりません",
        "smartctl が見つからないため温度を取得できません",
        "次を実行してください：brew install smartmontools",
        "ログイン時に起動",
        "終了",
        "ログイン時の起動を設定できませんでした",
        "アプリを「アプリケーション」フォルダに移動してから再度お試しください。",
        "言語", "システムに従う",
    ],
    "ko": [
        "읽", "쓰", "내장", "외장", "내장", "외장", "디스크",
        "온도 %@      상태 %@",
        "정상", "이상!",
        "읽기 %@      쓰기 %@",
        "수명 사용 %@",
        "총 쓰기량 %@",
        "전원 켜짐 %@시간      비정상 종료 %@회",
        "온도 및 상태 정보를 읽을 수 없음(인클로저 미지원 가능)",
        "%@: %@ 사용 / %@ · %@ 사용 가능",
        "메뉴 막대에 표시",
        "디스크를 찾을 수 없음",
        "smartctl을 찾을 수 없어 온도를 읽을 수 없음",
        "먼저 실행하세요: brew install smartmontools",
        "로그인 시 자동 실행",
        "종료",
        "로그인 시 자동 실행을 설정하지 못했습니다",
        "앱을 '응용 프로그램' 폴더로 옮긴 후 다시 시도하세요.",
        "언어", "시스템 설정 따르기",
    ],
    "de": [
        "R", "W", "Int", "Ext", "Intern", "Extern", "Disk",
        "Temperatur %@      Zustand %@",
        "Gut", "Fehlerhaft!",
        "Lesen %@      Schreiben %@",
        "Lebensdauer verbraucht %@",
        "Insgesamt geschrieben %@",
        "Betriebszeit %@ h      Unerwartete Abschaltungen %@",
        "Keine Temperatur- oder Zustandsdaten (Gehäuse evtl. nicht unterstützt)",
        "%@: %@ von %@ belegt · %@ frei",
        "In der Menüleiste anzeigen",
        "Keine Laufwerke gefunden",
        "smartctl nicht gefunden, Temperatur nicht verfügbar",
        "Installieren mit: brew install smartmontools",
        "Bei Anmeldung starten",
        "Beenden",
        "Start bei Anmeldung konnte nicht geändert werden",
        "Verschiebe die App zuerst in den Ordner „Programme“.",
        "Sprache", "Systemsprache",
    ],
    "fr": [
        "L", "É", "Int", "Ext", "Interne", "Externe", "Disque",
        "Température %@      État %@",
        "Bon", "Défaillant !",
        "Lecture %@      Écriture %@",
        "Usure %@",
        "Total écrit %@",
        "Allumé %@ h      Arrêts imprévus %@",
        "Aucune donnée de température ou d'état (boîtier peut-être non compatible)",
        "%@ : %@ utilisés sur %@ · %@ libres",
        "Afficher dans la barre des menus",
        "Aucun disque détecté",
        "smartctl introuvable, température indisponible",
        "Installez-le avec : brew install smartmontools",
        "Ouvrir à la connexion",
        "Quitter",
        "Impossible de modifier l'ouverture à la connexion",
        "Déplacez d'abord l'app dans le dossier Applications.",
        "Langue", "Langue du système",
    ],
    "es": [
        "L", "E", "Int", "Ext", "Interno", "Externo", "Disco",
        "Temperatura %@      Estado %@",
        "Bueno", "¡Fallando!",
        "Lectura %@      Escritura %@",
        "Vida usada %@",
        "Total escrito %@",
        "Encendido %@ h      Apagados inesperados %@",
        "Sin datos de temperatura ni de estado (puede que la carcasa no sea compatible)",
        "%@: %@ usados de %@ · %@ libres",
        "Mostrar en la barra de menús",
        "No se detectaron discos",
        "No se encontró smartctl, temperatura no disponible",
        "Instálalo con: brew install smartmontools",
        "Abrir al iniciar sesión",
        "Salir",
        "No se pudo cambiar el inicio al iniciar sesión",
        "Mueve primero la app a la carpeta Aplicaciones.",
        "Idioma", "Idioma del sistema",
    ],
}


# ---- 1.3 新增：关于、提醒、推出/挂载 ----
KEYS += [
    "About Disk Monitor",
    "Temperature and health alerts",
    "Disk temperature is high",
    "%@ is at %@.",
    "Disk health problem",
    "%@ failed its SMART health check. Back up your data now.",
    "Disk nearing end of life",
    "%@ has used %@ of its rated life.",
    "Shows disk temperature, health, read/write speed and free space in the menu bar.",
    "Includes smartctl from smartmontools 7.5, licensed under the GNU GPL v2. Source code:",
    "View License",
    "Eject",
    "Unmount",
    "Mount",
    "Couldn't complete the operation",
    "Safe to disconnect",
    "%@ has been ejected.",
]

T["zh-Hans"] += [
    "关于硬盘监控", "温度和健康提醒", "硬盘温度过高", "%@ 当前温度 %@。",
    "硬盘健康异常", "%@ 的 SMART 健康检查未通过，请立即备份数据。",
    "硬盘寿命即将耗尽", "%@ 已用掉 %@ 的额定寿命。",
    "在状态栏显示硬盘温度、健康度、读写速度和剩余空间。",
    "内置 smartmontools 7.5 中的 smartctl，采用 GNU GPL v2 许可证。源码：",
    "查看许可证", "推出", "卸载", "挂载", "操作失败", "可以安全拔出", "%@ 已推出。",
]
T["zh-Hant"] += [
    "關於硬碟監控", "溫度和健康提醒", "硬碟溫度過高", "%@ 目前溫度 %@。",
    "硬碟健康異常", "%@ 的 SMART 健康檢查未通過，請立即備份資料。",
    "硬碟壽命即將耗盡", "%@ 已用掉 %@ 的額定壽命。",
    "在選單列顯示硬碟溫度、健康度、讀寫速度和剩餘空間。",
    "內建 smartmontools 7.5 中的 smartctl，採用 GNU GPL v2 授權。原始碼：",
    "檢視授權條款", "退出", "卸載", "掛載", "操作失敗", "可以安全拔除", "%@ 已退出。",
]
T["ja"] += [
    "ディスクモニターについて", "温度と状態の通知", "ディスクの温度が高くなっています", "%@ の温度は %@ です。",
    "ディスクの状態に問題があります", "%@ が SMART 状態チェックに失敗しました。今すぐデータをバックアップしてください。",
    "ディスクの寿命が近づいています", "%@ は定格寿命の %@ を使用しました。",
    "メニューバーにディスクの温度、状態、読み書き速度、空き容量を表示します。",
    "smartmontools 7.5 の smartctl を同梱しています（GNU GPL v2 ライセンス）。ソースコード：",
    "ライセンスを表示", "取り出す", "マウント解除", "マウント", "操作を完了できませんでした",
    "安全に取り外せます", "%@ を取り出しました。",
]
T["ko"] += [
    "디스크 모니터 정보", "온도 및 상태 알림", "디스크 온도가 높습니다", "%@의 온도가 %@입니다.",
    "디스크 상태 이상", "%@이(가) SMART 상태 검사에 실패했습니다. 지금 데이터를 백업하세요.",
    "디스크 수명이 얼마 남지 않았습니다", "%@의 정격 수명 중 %@를 사용했습니다.",
    "메뉴 막대에 디스크 온도, 상태, 읽기/쓰기 속도, 여유 공간을 표시합니다.",
    "smartmontools 7.5의 smartctl을 포함하며 GNU GPL v2 라이선스를 따릅니다. 소스 코드:",
    "라이선스 보기", "추출", "마운트 해제", "마운트", "작업을 완료할 수 없습니다",
    "안전하게 분리할 수 있습니다", "%@이(가) 추출되었습니다.",
]
T["de"] += [
    "Über Festplattenmonitor", "Temperatur- und Zustandswarnungen", "Laufwerkstemperatur ist hoch", "%@ hat %@.",
    "Problem mit dem Laufwerkszustand", "%@ hat die SMART-Zustandsprüfung nicht bestanden. Sichere jetzt deine Daten.",
    "Laufwerk nähert sich dem Lebensende", "%@ hat %@ seiner Nennlebensdauer verbraucht.",
    "Zeigt Temperatur, Zustand, Lese-/Schreibgeschwindigkeit und freien Speicher der Laufwerke in der Menüleiste.",
    "Enthält smartctl aus smartmontools 7.5, lizenziert unter der GNU GPL v2. Quellcode:",
    "Lizenz anzeigen", "Auswerfen", "Deaktivieren", "Aktivieren", "Vorgang konnte nicht abgeschlossen werden",
    "Kann sicher getrennt werden", "%@ wurde ausgeworfen.",
]
T["fr"] += [
    "À propos de Moniteur de disques", "Alertes de température et d'état", "La température du disque est élevée", "%@ est à %@.",
    "Problème d'état du disque", "%@ a échoué au contrôle SMART. Sauvegardez vos données maintenant.",
    "Le disque arrive en fin de vie", "%@ a utilisé %@ de sa durée de vie nominale.",
    "Affiche la température, l'état, la vitesse de lecture/écriture et l'espace libre des disques dans la barre des menus.",
    "Inclut smartctl de smartmontools 7.5, sous licence GNU GPL v2. Code source :",
    "Voir la licence", "Éjecter", "Démonter", "Monter", "Impossible d'effectuer l'opération",
    "Peut être déconnecté en toute sécurité", "%@ a été éjecté.",
]
T["es"] += [
    "Acerca de Monitor de discos", "Alertas de temperatura y estado", "La temperatura del disco es alta", "%@ está a %@.",
    "Problema de estado del disco", "%@ no superó la comprobación SMART. Haz una copia de seguridad ahora.",
    "El disco se acerca al final de su vida útil", "%@ ha usado el %@ de su vida útil nominal.",
    "Muestra la temperatura, el estado, la velocidad de lectura/escritura y el espacio libre de los discos en la barra de menús.",
    "Incluye smartctl de smartmontools 7.5, con licencia GNU GPL v2. Código fuente:",
    "Ver licencia", "Expulsar", "Desmontar", "Montar", "No se pudo completar la operación",
    "Se puede desconectar con seguridad", "%@ se ha expulsado.",
]


# ---- 1.4 新增：网速 ----
KEYS += ["Network", "Upload %@      Download %@", "Total: %@ sent · %@ received", "Show network speed in menu bar"]
T["zh-Hans"] += ["网络", "上传 %@      下载 %@", "累计：已上传 %@ · 已下载 %@", "在状态栏显示网速"]
T["zh-Hant"] += ["網路", "上傳 %@      下載 %@", "累計：已上傳 %@ · 已下載 %@", "在選單列顯示網速"]
T["ja"] += ["ネットワーク", "アップロード %@      ダウンロード %@", "累計：送信 %@ · 受信 %@", "メニューバーにネットワーク速度を表示"]
T["ko"] += ["네트워크", "업로드 %@      다운로드 %@", "누적: 보냄 %@ · 받음 %@", "메뉴 막대에 네트워크 속도 표시"]
T["de"] += ["Netzwerk", "Upload %@      Download %@", "Gesamt: %@ gesendet · %@ empfangen", "Netzwerkgeschwindigkeit in der Menüleiste anzeigen"]
T["fr"] += ["Réseau", "Envoi %@      Réception %@", "Total : %@ envoyés · %@ reçus", "Afficher le débit réseau dans la barre des menus"]
T["es"] += ["Red", "Subida %@      Bajada %@", "Total: %@ enviados · %@ recibidos", "Mostrar velocidad de red en la barra de menús"]


def esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def main() -> None:
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources")
    for lang, values in T.items():
        if lang == "en":
            values = KEYS
        if len(values) != len(KEYS):
            raise SystemExit(f"{lang}: 翻译条数 {len(values)} 与键数 {len(KEYS)} 不一致")
        if any(k.count("%@") != v.count("%@") for k, v in zip(KEYS, values)):
            raise SystemExit(f"{lang}: 占位符 %@ 数量与原文不一致")
        d = os.path.join(root, f"{lang}.lproj")
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "Localizable.strings"), "w", encoding="utf-8") as f:
            for k, v in zip(KEYS, values):
                f.write(f'"{esc(k)}" = "{esc(v)}";\n')
        with open(os.path.join(d, "InfoPlist.strings"), "w", encoding="utf-8") as f:
            name = esc(APP_NAME[lang])
            f.write(f'"CFBundleDisplayName" = "{name}";\n"CFBundleName" = "{name}";\n')
    print(f"已生成 {len(T)} 种语言")


if __name__ == "__main__":
    main()
