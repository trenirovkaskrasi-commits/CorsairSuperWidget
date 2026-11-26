#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SetTitleMatchMode 2
CoordMode "Mouse", "Screen"

; CorsairSuperWidget - clock, weather, launcher and system bar for the Corsair Xeneon Edge (2560x720)
; Requires AutoHotkey v2. All settings live in settings.ini (next to this script) or in the Settings window
; (tray icon -> Settings...). Languages: bg, ru, en, fr, es, it, pt (Language=auto follows Windows).
; Note: the comments inside the code are mostly in Bulgarian.

; ================= ОБЩИ НАСТРОЙКИ =================
settingsFile := A_ScriptDir "\settings.ini"
iniData := LoadSettings(settingsFile)
settingsGui := ""                   ; прозорецът за настройки (когато е отворен)
langCodes := ["auto", "bg", "ru", "en", "fr", "es", "it", "pt"]
langCode := ResolveLang(Cfg("General", "Language", "auto"))
uiText := Map()
LoadLang_en(uiText)                 ; английският е резервен език за липсващи ключове
if (langCode != "en")
    LoadLangByCode(langCode, uiText)
designMode := StrLower(Cfg("General", "Design", "classic"))   ; classic = сегашният; wide = горен ред: час+време+прогноза, втори ред: иконите
wide := (designMode = "wide")                                  ; всяка друга стойност = classic
AutoDetectSmallScreen := CfgBool("General", "AutoDetectScreen", true)   ; true = автоматично намира най-малкия монитор
screenX := CfgInt("General", "ManualX", 451)
screenY := CfgInt("General", "ManualY", 1440)
screenW := 2560
screenH := 720

if AutoDetectSmallScreen {
    FindSmallestMonitor(&screenX, &screenY, &screenW, &screenH)
}

; ================= НАСТРОЙКИ: ВРЕМЕ И ЧАСОВНИК =================
Lat := CfgCoord("Weather", "Lat", "42.6977")      ; София
Lon := CfgCoord("Weather", "Lon", "23.3219")
City := Cfg("Weather", "City", T("defaultCity"))
WeatherEveryMin := Max(1, CfgInt("Weather", "RefreshMinutes", 30))   ; на колко минути да обновява прогнозата
WeatherPosX := screenX + 10
WeatherPosY := screenY + 0
WeatherIconDir := ResolveDir(Cfg("Paths", "WeatherIcons", "icons"))
if !FileExist(WeatherIconDir "07.png") {
    ; без иконите всичко останало дава верига от грешки - затова спираме с едно ясно съобщение
    MsgBox(T("errIcons", WeatherIconDir "07.png"), "CorsairSuperWidget", "Icon!")
    ExitApp
}

; Разположение на прогнозата за 5 дни (classic: под часа; wide: в десния край на горния ред)
; wide: 6 дни, колоните са точно над последните 6 икони на лаунчера (стъпка 254, център на 5-ата икона = 1153)
fcDays := wide ? 6 : 5
fcX0 := wide ? 1032 : 10, fcStepX := wide ? 254 : 222
; ширини на кутиите: в wide са стеснени, за да не се застъпват (застъпената част се реже от кутията отгоре)
clockW := wide ? 520 : 580, dateW := wide ? 490 : 570
; Текущо време (размери в px; classic = както досега, wide = с ~15% по-голяма икона и шрифтове)
curIconX := wide ? 535 : 600,  curIconY := wide ? 0 : 2,    curIconW := wide ? 233 : 204, curIconH := wide ? 194 : 170
curTempX := wide ? 772 : 822,  curTempY := wide ? -33 : -5,  curTempW := wide ? 330 : 318, curTempH := wide ? 236 : 200, curTempFont := wide ? 180 : 150
curDescX := wide ? 525 : 610,  curDescY := wide ? 203 : 172, curDescW := wide ? 505 : 530, curDescH := wide ? 53 : 60, curDescFont := wide ? 40 : 44
curWindY := wide ? 256 : 228,  curWindH := wide ? 53 : 50,  curWindFont := wide ? 40 : 34
; Прогноза по дни: малко по-едри шрифтове и в двата дизайна (дни 34 -> 40, градуси 40 -> 46)
fcDayFont := wide ? 42 : 40, fcTempFont := wide ? 50 : 46, fcDayH := 58, fcTempH := 66
fcDayY := wide ? -4 : 290, fcIconY := wide ? 50 : 348, fcTempY := wide ? 245 : 519
wideTopH := 330                     ; височина на горния ред в wide
upperText := wide                   ; ден, дата, състояние, град и вятър с ГЛАВНИ БУКВИ (само в wide; false = както преди)
showWeekday := wide                 ; ред с името на деня между часа и датата (само в wide; false = без него)
; В wide денят и датата са на едно ниво (обща базова линия) с реда "състояние" и реда "град · вятър" от съседната кутия
; и са със същите шрифтове: ден = като състоянието, дата = като вятъра. Затова ползват същите стойности cur*.
dateY := wide ? curWindY : 200
dateH := wide ? curWindH : 80
dateFont := wide ? curWindFont : 54

Days := StrSplit(T("days"), "|")
Months := StrSplit(T("months"), "|")
lastClock := ""

; ================= НАСТРОЙКИ: ЛАУНЧЕР =================
marginTop := 12, marginRight := 2, marginBottom := 135
cols := 5, rows := 2, gap := 14
availH := screenH - marginTop - marginBottom
iconSize := Floor((availH - (rows + 1) * gap) / rows)
if wide {
    cols := 10, rows := 1, gap := 14, iconSize := 240       ; един ред от 10 икони, 10*240 + 11*14 = 2554 px
}
launcherIconDir := ResolveDir(Cfg("Paths", "LauncherIcons", "icons"))
chromeAppsDir := ResolveDir(Cfg("Paths", "ChromeApps", "%AppData%\Microsoft\Windows\Start Menu\Programs\" T("chromeAppsFolder")))

apps := [
    {icon: "Firefox.png",        cmd: "C:\Program Files\Mozilla Firefox\firefox.exe",                          pwa: false, kw: "Firefox"},
    {icon: "Gemini.png",         cmd: "shell:AppsFolder\com.google.gemini.windows",                            pwa: false, kw: "Gemini"},
    {icon: "YouTubeMusic.png",   cmd: chromeAppsDir "YouTube Music.lnk",                                     pwa: true,  kw: "YouTube Music"},
    {icon: "Stremio.png",        cmd: "%LocalAppData%\Programs\Stremio\stremio-shell-ng.exe",  pwa: false, kw: "Stremio"},
    {icon: "UniversalRadio.png", cmd: "shell:AppsFolder\52267melz.01.UniversalInternetRadio_0ekv48gcjdhv6!App", pwa: false, kw: "Radio"},
    {icon: "Telegram.png",       cmd: "shell:AppsFolder\TelegramMessengerLLP.TelegramDesktop_t4vj0pshhgkwm!Telegram.TelegramDesktop.Store", pwa: false, kw: "Telegram"},
    {icon: "Viber.png",          cmd: "%LocalAppData%\Viber\Viber.exe",                                      pwa: false, kw: "Viber"},
    {icon: "instagram.png",      cmd: chromeAppsDir "Instagram.lnk",                                         pwa: true,  kw: "Instagram"},
    {icon: "Pinterest.png",      cmd: chromeAppsDir "Pinterest.lnk",                                         pwa: true,  kw: "Pinterest"},
    {icon: "YouTube.png",        cmd: chromeAppsDir "YouTube.lnk",                                           pwa: true,  kw: "YouTube"}
]
; Приложенията от settings.ini ([Launcher] App1..App10) заместват горния списък, ако има поне едно валидно.
iniApps := []
Loop 10 {
    parts := StrSplit(Cfg("Launcher", "App" A_Index, ""), "|")
    if (parts.Length < 2 || Trim(parts[1]) = "" || Trim(parts[2]) = "")
        continue
    iniApps.Push({icon: Trim(parts[1])
        , cmd: StrReplace(Trim(parts[2]), "{ChromeApps}", chromeAppsDir)
        , pwa: (parts.Length >= 3 && CfgIsTrue(parts[3]))
        , kw: (parts.Length >= 4 ? Trim(parts[4]) : "")})
}
if (iniApps.Length > 0)
    apps := iniApps

; ================= НАСТРОЙКИ: ДОЛНА ЛЕНТА =================
barH := 118
driveA := CfgDrive("Bar", "Drive1", "C:")
driveB := CfgDrive("Bar", "Drive2", "D:")
wheelStep := Max(1, Min(50, CfgInt("Volume", "WheelStep", 5)))
strictTempLabels := CfgBool("Bar", "StrictTempLabels", true)            ; true = пропуска етикети с Power/Usage/Load/Clock/Fan/Voltage/Utilization/Limit
barPosX := screenX
barPosY := screenY + screenH - barH

; ================= DPI ПОМОЩНИ ФУНКЦИИ (ЗА ЧАСОВНИК/ВРЕМЕ) =================
S := A_ScreenDPI / 96
U(px) => Round(px / S)
Pt(px) => Round(px * 72 / A_ScreenDPI)

; ================= 1. GUI: ЧАСОВНИК И ПРОГНОЗА =================
g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000 +E0x02000000")
g.BackColor := "000000"
g.MarginX := 0
g.MarginY := 0

ctlDay := ""
ctlFcDay := []
ctlFcIcon := []
ctlFcTemp := []
if wide {
    ; ===== wide: ТАБЛИЦА от модули по 254 px (колкото иконите на лаунчера + разстоянието между тях) =====
    ; Три ленти: горна y 0-53 (дата | град+вятър | имена на дните), средна y 53-264 (час | икона | градуси | икони на дните),
    ; долна y 264-330 (ден | състояние | градуси на дните). Модул k = x от 254*k; текстът е с отстъп 7 px = ръба на иконите на лаунчера.
    ; Z-ред: по-рано създаденият контрол е отгоре. Горната лента се създава ПЪРВА, защото кутиите на часа и градусите
    ; са по-високи и влизат отдолу под нея (така цифрите стоят на мястото си, без да режат датата и вятъра).
    g.SetFont("s" Pt(40) " w700 cFFFFFF", "Segoe UI")
    ctlDate := g.Add("Text", "x" U(7) " y" U(0) " w" U(501) " h" U(53), "")
    ctlWind := g.Add("Text", "x" U(515) " y" U(0) " w" U(501) " h" U(53), "")
    Loop fcDays {
        mx := fcX0 - 16 + (A_Index - 1) * fcStepX          ; лява граница на модула (254 px)
        g.SetFont("s" Pt(36) " w700 cFFFFFF", "Segoe UI")
        ctlFcDay.Push(g.Add("Text", "x" U(mx) " y" U(0) " w" U(254) " h" U(53) " Center +0x200", ""))   ; +0x200 = центриран по височина
        ctlFcIcon.Push(g.Add("Picture", "x" U(mx) " y" U(53) " w" U(254) " h" U(211), WeatherIconDir "07.png"))
        g.SetFont("s" Pt(50) " w700 cFFFFFF", "Segoe UI")
        ctlFcTemp.Push(g.Add("Text", "x" U(mx) " y" U(264) " w" U(254) " h" U(66) " Center", ""))
    }
    g.SetFont("s" Pt(196) " w700 cFFFFFF", "Segoe UI")
    ctlTime := g.Add("Text", "x" U(7) " y" U(16) " w" U(501) " h" U(248), "--:--")
    ctlIcon := g.Add("Picture", "x" U(508) " y" U(53) " w" U(254) " h" U(211), WeatherIconDir "07.png")
    g.SetFont("s" Pt(172) " w700 cFFFFFF", "Segoe UI")
    ctlTemp := g.Add("Text", "x" U(762) " y" U(36) " w" U(254) " h" U(228) " Center", "")
    ; двоен клик върху градусите = обнови прогнозата (хващан от клавиша ~LButton по-долу, не от контрола - по-надеждно)
    ; ден и състояние: шрифт 40 (като датата и града/вятъра), кутии със същата височина (66) и ос като градусите на дните;
    ; +0x200 = текстът е центриран по височина, така че средата на буквите съвпада със средата на цифрите (шрифт 50)
    g.SetFont("s" Pt(40) " w700 cFFFFFF", "Segoe UI")
    if showWeekday
        ctlDay := g.Add("Text", "x" U(7) " y" U(264) " w" U(501) " h" U(66) " +0x200", "")
    ctlDesc := g.Add("Text", "x" U(515) " y" U(264) " w" U(501) " h" U(66) " +0x200", "")
} else {
; Денят от седмицата се създава ПРЕДИ часа: кутията на часа е по-висока и иначе би отрязала горния му край.
if showWeekday {
    g.SetFont("s" Pt(curDescFont) " w700 cFFFFFF", "Segoe UI")
    ctlDay := g.Add("Text", "x" U(28) " y" U(curDescY) " w" U(dateW) " h" U(curDescH), "")
}

g.SetFont("s" Pt(190) " w700 cFFFFFF", "Segoe UI")
ctlTime := g.Add("Text", "x" U(20) " y" U(wide ? -44 : -40) " w" U(clockW) " h" U(wide ? 247 : 250), "--:--")

g.SetFont("s" Pt(dateFont) " w700 cFFFFFF", "Segoe UI")
ctlDate := g.Add("Text", "x" U(28) " y" U(dateY) " w" U(dateW) " h" U(dateH), "")

; Прогнозата се създава ПРЕДИ текущото време: при застъпване на кутии по-ранният контрол е отгоре,
; така че широката кутия на градусите никога не реже колоните на прогнозата.
Loop fcDays {
    cx := fcX0 + (A_Index - 1) * fcStepX
    g.SetFont("s" Pt(fcDayFont) " w700 cFFFFFF", "Segoe UI")
    ctlFcDay.Push(g.Add("Text", "x" U(cx - (wide ? 16 : 0)) " y" U(fcDayY) " w" U(wide ? 254 : 222) " h" U(fcDayH) " Center", ""))   ; в wide кутията е по-широка (центърът остава), за да се събира "понеделник"
    ctlFcIcon.Push(g.Add("Picture", "x" U(cx + (wide ? -6 : 9)) " y" U(fcIconY) " w" U(wide ? 234 : 204) " h" U(wide ? 195 : 170), WeatherIconDir "07.png"))
    g.SetFont("s" Pt(fcTempFont) " w700 cFFFFFF", "Segoe UI")
    ctlFcTemp.Push(g.Add("Text", "x" U(cx - (wide ? 16 : 0)) " y" U(fcTempY) " w" U(wide ? 254 : 222) " h" U(fcTempH) " Center", ""))
}

ctlIcon := g.Add("Picture", "x" U(curIconX) " y" U(curIconY) " w" U(curIconW) " h" U(curIconH), WeatherIconDir "07.png")
g.SetFont("s" Pt(curTempFont) " w700 cFFFFFF", "Segoe UI")
ctlTemp := g.Add("Text", "x" U(curTempX) " y" U(curTempY) " w" U(curTempW) " h" U(curTempH), "")
; двоен клик върху градусите = обнови прогнозата (хващан от клавиша ~LButton по-долу, не от контрола - по-надеждно)
g.SetFont("s" Pt(curDescFont) " w700 cFFFFFF", "Segoe UI")
ctlDesc := g.Add("Text", "x" U(curDescX) " y" U(curDescY) " w" U(curDescW) " h" U(curDescH), "")
g.SetFont("s" Pt(curWindFont) " w700 cFFFFFF", "Segoe UI")
ctlWind := g.Add("Text", "x" U(curDescX) " y" U(curWindY) " w" U(curDescW) " h" U(curWindH), "")
}

weatherSize := wide ? (" w" U(screenW - 10) " h" U(wideTopH)) : ""      ; wide: прозорецът стига до десния ръб на екрана (10 px запас за най-дългите имена на дни)
g.Show("NoActivate x" WeatherPosX " y" WeatherPosY weatherSize)

; ================= 2. GUI: ЛАУНЧЕР =================
guiWidth := cols * iconSize + (cols + 1) * gap
guiHeight := rows * iconSize + (rows + 1) * gap
launcherPosX := wide ? screenX + (screenW - guiWidth) // 2 : screenX + screenW - guiWidth - marginRight
launcherPosY := wide ? screenY + wideTopH : screenY + marginTop

launcherGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x02000000", "Xeneon Edge Launcher")
launcherGui.BackColor := "101216"

for idx, app in apps {
    col := Mod(idx - 1, cols), row := (idx - 1) // cols
    bx := gap + col * (iconSize + gap), by := gap + row * (iconSize + gap)
    iconPath := launcherIconDir app.icon
    btn := FileExist(iconPath)
        ? launcherGui.Add("Picture", Format("x{} y{} w{} h{} BackgroundTrans", bx, by, iconSize, iconSize), iconPath)
        : launcherGui.Add("Button", Format("x{} y{} w{} h{}", bx, by, iconSize, iconSize), app.icon)
    btn.OnEvent("Click", HandleButton.Bind(idx, app.cmd, app.pwa, app.kw))
}
launcherGui.Show(Format("x{} y{} w{} h{} NoActivate", launcherPosX, launcherPosY, guiWidth, guiHeight))

appHwnds := Map(), lastClick := Map(), busyBtns := Map()

; ================= 3. GUI: ДОЛНА ЛЕНТА =================
barGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale", "EdgeBottomBar")
barGui.BackColor := "050608"
barGui.MarginX := 0, barGui.MarginY := 0

barGui.Add("Text", Format("x0 y0 w{} h2 Background687182", screenW), "")

barGui.SetFont("s38 Bold", "Segoe UI Semibold")
startBtn := barGui.Add("Text", "x17 y11 w240 h98 cFFFFFF Background0067C0 Center +0x200 +0x4000000", "START")
startBtn.OnEvent("Click", (*) => ToggleStartMenu())
startBtn.OnEvent("ContextMenu", ShowBarMenu)

; Шрифтът остава 39 (като преди). Смалява се само ако кутиите и плочката за звука не се събират
; дори с подредба на равни разстояния (измерва се с реалния шрифт на екрана).
indPad := 10
minGap := 2                         ; най-малка празнина между кутиите (преди да се смалява шрифтът)
; Всяка кутия е с по една цифра по-широка от обичайната си стойност - така видимите празнини между
; индикаторите са почти равни (както в предишната версия). Ако стойността стане по-дълга,
; текстът ползва свободното място между кутиите и не се реже.
indSamples := ["CPU:99%", "CPU:100°C", "RAM:100%", driveA "999.9 GB", driveB "999.9 GB", "GPU:100.0°C"]
barFont := 39
Loop {
    indTotal := 0
    for smp in indSamples
        indTotal += MeasureTextWidth(smp, "Segoe UI Semibold", barFont, 700) + indPad
    volBoxW := MeasureTextWidth("VOL 100%", "Segoe UI Semibold", barFont, 700) + 30
    ; зоната е от 257 (десния ръб на START, колкото първата икона на лаунчера: x 17-257) до (десния ръб 2550 - плочката - 2 за линията); между 7-те позиции са нужни поне minGap px
    if (indTotal + 7 * minGap + volBoxW <= 2291 || barFont <= 28)
        break
    barFont -= 1
}
volBoxX := 2550 - volBoxW           ; десният ръб е на същото място като преди (2550)
barGui.SetFont("s" barFont " Bold", "Segoe UI Semibold")
cpuLoadTxt := barGui.Add("Text", "x240  y5 w260 h108 cFFFFFF Background050608 +0x200", "CPU:--%")
cpuTempTxt := barGui.Add("Text", "x520  y5 w270 h108 cFFFFFF Background050608 +0x200", "CPU:--°C")
ramTxt     := barGui.Add("Text", "x810  y5 w270 h108 cFFFFFF Background050608 +0x200", "RAM:--%")
diskCTxt   := barGui.Add("Text", "x1100 y5 w340 h108 cFFFFFF Background050608 +0x200", driveA "--.- GB")
diskDTxt   := barGui.Add("Text", "x1460 y5 w340 h108 cFFFFFF Background050608 +0x200", driveB "--.- GB")
gpuTempTxt := barGui.Add("Text", "x1820 y5 w360 h108 cFFFFFF Background050608 +0x200", "GPU:--.-°C")

; Регулатор на звука: показва "VOL 20%", сила с колелцето на мишката над плочката, клик = спиране/пускане (MUTE)
barGui.Add("Text", Format("x{} y8 w2 h{} Background687182", volBoxX - 2, barH - 12), "")
barGui.Add("Text", Format("x{} y11 w{} h98 Background14171D", volBoxX, volBoxW), "")

barGui.SetFont("s" barFont " Bold", "Segoe UI Semibold")
volPctTxt := barGui.Add("Text", Format("x{} y11 w{} h98 cFFFFFF Background14171D Center +0x200", volBoxX, volBoxW), "VOL --%")
volPctTxt.OnEvent("Click", ToggleMute)

barGui.Show(Format("x{} y{} w{} h{} NoActivate", barPosX, barPosY, screenW, barH))

; ================= СЪСТОЯНИЕ И ТАЙМЕРИ =================
prevIdle := 0, prevKernel := 0, prevUser := 0
startOpenTick := 0
startMenuOpen := false
lastVolText := ""
cachedCpuHwinfoIdx := -1
cachedGpuHwinfoIdx := -1

LayoutIndicatorsEqual([cpuLoadTxt, cpuTempTxt, ramTxt, diskCTxt, diskDTxt, gpuTempTxt])

A_TrayMenu.Add()
A_TrayMenu.Add(T("mRefresh"), (*) => FetchWeather())
A_TrayMenu.Add(T("mSettings"), ShowSettingsGui)
A_TrayMenu.Add(T("mOpenIni"), OpenSettings)
A_TrayMenu.Add(T("mResetDefaults"), ResetSettingsToDefault)
A_TrayMenu.Add(T("mReload"), (*) => Reload())
A_TrayMenu.Add(T("mExit"), (*) => ExitApp())

UpdateClock()
FetchWeather()
UpdateAll()

SetTimer(UpdateClock, 10000)
SetTimer(FetchWeather, WeatherEveryMin * 60000)
SetTimer(UpdateAll, 1000)

#HotIf MouseOverTemp()
~LButton:: OnTempClick()
#HotIf

#HotIf MouseOverVolume()
WheelUp::AdjustVolume(wheelStep)
WheelDown::AdjustVolume(-wheelStep)
#HotIf

; ================= ФУНКЦИИ: МОНИТОР, ЧАСОВНИК И ВРЕМЕ =================
FindSmallestMonitor(&outX, &outY, &outW, &outH) {
    best := 0
    bestArea := 0
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &l1, &t1, &r1, &b1)
        area := (r1 - l1) * (b1 - t1)
        if (best = 0 || area < bestArea) {
            best := A_Index
            bestArea := area
            outX := l1
            outY := t1
            outW := r1 - l1
            outH := b1 - t1
        }
    }
}

UpdateClock() {
    global lastClock
    nowTxt := FormatTime(, "HH:mm")
    if (nowTxt = lastClock)
        return
    lastClock := nowTxt
    SetTxt(ctlTime, nowTxt)
    SetTxt(ctlDate, UpCase(T("dateFmt", Integer(A_DD), Months[Integer(A_MM)], A_Year)))
    if IsObject(ctlDay)
        SetTxt(ctlDay, UpCase(Days[Integer(A_WDay)]))
}

SetTxt(ctl, v) {
    if (ctl.Text != v)
        ctl.Text := v
}

UpCase(s) {
    return upperText ? StrUpper(s) : s
}

SetPic(ctl, name) {
    static cache := Map()
    if (cache.Has(ctl.Hwnd) && cache[ctl.Hwnd] = name)
        return
    try {
        ctl.Value := WeatherIconDir name ".png"
        cache[ctl.Hwnd] := name
    }
}

MouseOverTemp() {
    try {
        MouseGetPos(&mx, &my)
        WinGetPos(&gx, &gy, , , g.Hwnd)
        ctlTemp.GetPos(&cx, &cy, &cw, &ch)
        left := gx + cx, right := left + cw
        if wide
            right := Min(right, gx + fcX0)     ; не заемай колоните на прогнозата
        return (mx >= left && mx < right && my >= gy + cy && my < gy + cy + ch)
    }
    return false
}

OnTempClick() {
    static lastRefresh := 0
    if (A_PriorHotkey = "~LButton" && A_TimeSincePriorHotkey < DllCall("GetDoubleClickTime", "UInt")
        && (A_TickCount - lastRefresh > 1500)) {
        lastRefresh := A_TickCount
        RefreshWeatherNow()
    }
}

RefreshWeatherNow(*) {
    static busy := false
    if busy
        return
    busy := true
    try {
        prev := ctlWind.Text
        ctlWind.Text := UpCase(T("updating"))
        Sleep(30)
        if !FetchWeatherOnce() {
            ctlWind.Text := prev
            SetTimer(RetryWeather, -60000)
        }
    } finally {
        busy := false
    }
}

FetchWeather(*) {
    ; при неуспех (няма мрежа, грешка от услугата) пробва пак след 1 минута
    if !FetchWeatherOnce()
        SetTimer(RetryWeather, -60000)
}

RetryWeather(*) => FetchWeather()

FetchWeatherOnce() {
    url := "https://api.open-meteo.com/v1/forecast?latitude=" Lat "&longitude=" Lon
    url .= "&current=temperature_2m,weather_code,wind_speed_10m,is_day"
    url .= "&daily=weather_code,temperature_2m_max,temperature_2m_min"
    url .= "&timezone=auto&forecast_days=" fcDays

    try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.SetTimeouts(3000, 3000, 5000, 5000)
        http.Open("GET", url, false)
        http.Send()
        if (http.Status != 200)
            return false
        txt := http.ResponseText
    } catch {
        return false
    }

    if !RegExMatch(txt, '"current":\{([^}]*)\}', &cur)
        return false
    if !RegExMatch(cur[1], '"temperature_2m":(-?[\d.]+)', &mTemp)
        return false
    if !RegExMatch(cur[1], '"weather_code":(\d+)', &mCode)
        return false
    windTxt := ""
    if RegExMatch(cur[1], '"wind_speed_10m":(-?[\d.]+)', &mWind)
        windTxt := T("windFmt", Round(mWind[1]))
    isDay := RegExMatch(cur[1], '"is_day":(\d)', &mDay) ? Integer(mDay[1]) : 1

    if !RegExMatch(txt, '"daily":\{([^}]*)\}', &dl)
        return false
    dates := ListOf(dl[1], "time")
    codes := ListOf(dl[1], "weather_code")
    tmax := ListOf(dl[1], "temperature_2m_max")
    tmin := ListOf(dl[1], "temperature_2m_min")
    if (dates.Length < fcDays || codes.Length < fcDays || tmax.Length < fcDays || tmin.Length < fcDays)
        return false

    SetPic(ctlIcon, IconName(mCode[1], isDay))
    SetTxt(ctlTemp, Round(mTemp[1]) "°")
    SetTxt(ctlDesc, UpCase(WxText(mCode[1])))
    SetTxt(ctlWind, UpCase(City windTxt))

    Loop fcDays {
        i := A_Index
        if (i = 1) {
            dayName := T("today")
        } else if (i = 2) {
            dayName := T("tomorrow")
        } else {
            wd := Integer(FormatTime(StrReplace(dates[i], "-", ""), "WDay"))
            dayName := Days[wd]
        }
        SetTxt(ctlFcDay[i], UpCase(dayName))
        FitDayLabel(i, UpCase(dayName))
        SetPic(ctlFcIcon[i], IconName(codes[i], 1))
        SetTxt(ctlFcTemp[i], Round(tmax[i]) "° / " Round(tmin[i]) "°")
    }
    return true
}

ListOf(block, key) {
    out := []
    if !RegExMatch(block, '"' key '":\[([^\]]*)\]', &m)
        return out
    for item in StrSplit(m[1], ",")
        out.Push(Trim(item, ' "'))
    return out
}

IconName(c, isDay := 1) {
    c := Integer(c)
    if (c = 0)
        return isDay ? "01" : "33"
    if (c = 1)
        return isDay ? "02" : "34"
    if (c = 2)
        return isDay ? "03" : "35"
    if (c = 3)
        return "07"
    if (c = 45 || c = 48)
        return "11"
    if (c >= 51 && c <= 55)
        return "12"
    if (c = 56 || c = 57 || c = 66 || c = 67)
        return "26"
    if (c = 61)
        return "12"
    if (c = 63 || c = 65)
        return "18"
    if (c = 71 || c = 77)
        return "19"
    if (c = 73 || c = 75)
        return "22"
    if (c = 80)
        return isDay ? "14" : "12"
    if (c = 81 || c = 82)
        return "18"
    if (c = 85)
        return isDay ? "21" : "19"
    if (c = 86)
        return isDay ? "23" : "22"
    if (c >= 95)
        return "15"
    return "07"
}

WxText(c) {
    c := Integer(c)
    if (c = 0)
        return T("wx_clear")
    if (c = 1)
        return T("wx_mostly")
    if (c = 2)
        return T("wx_partly")
    if (c = 3)
        return T("wx_cloudy")
    if (c = 45 || c = 48)
        return T("wx_fog")
    if (c >= 51 && c <= 57)
        return T("wx_drizzle")
    if (c >= 61 && c <= 67)
        return T("wx_rain")
    if (c >= 71 && c <= 77)
        return T("wx_snow")
    if (c >= 80 && c <= 82)
        return T("wx_showers")
    if (c = 85 || c = 86)
        return T("wx_snowshowers")
    if (c >= 95)
        return T("wx_thunder")
    return T("wx_cloudy")
}

; ================= ФУНКЦИИ: ЛАУНЧЕР =================
IsOnSmallScreen(cx, cy) => (cx >= screenX && cx < (screenX + screenW) && cy >= screenY && cy < (screenY + screenH))

IsOverlayGui(hwnd) => (hwnd = g.Hwnd || hwnd = launcherGui.Hwnd || hwnd = barGui.Hwnd)

IsTopWindowOnMainMonitor(targetHwnd) {
    if WinActive("ahk_id " targetHwnd)
        return true
    MonitorGetWorkArea(MonitorGetPrimary(), &mLeft, &mTop, &mRight, &mBottom)
    for hwnd in WinGetList() {
        if IsOverlayGui(hwnd)
            continue
        style := WinGetStyle("ahk_id " hwnd), exStyle := WinGetExStyle("ahk_id " hwnd)
        if !(style & 0x10000000) || (exStyle & 0x80) || (WinGetMinMax("ahk_id " hwnd) = -1)
            continue
        winClass := WinGetClass("ahk_id " hwnd)
        if (winClass = "Shell_TrayWnd" || winClass = "Shell_SecondaryTrayWnd" || winClass = "Progman" || winClass = "WorkerW")
            continue
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
        cx := wx + (ww // 2), cy := wy + (wh // 2)
        if (cx >= mLeft && cx < mRight && cy >= mTop && cy < mBottom)
            return (hwnd = targetHwnd)
    }
    return false
}

MoveToMainMonitor(hwnd) {
    winId := "ahk_id " hwnd
    if !WinExist(winId)
        return
    MonitorGetWorkArea(MonitorGetPrimary(), &mLeft, &mTop, &mRight, &mBottom)
    mW := mRight - mLeft, mH := mBottom - mTop
    state := WinGetMinMax(winId)
    if (state = -1) {
        WinRestore(winId)
        state := WinGetMinMax(winId)
    }
    WinGetPos(&wx, &wy, &ww, &wh, winId)
    cx := wx + (ww // 2), cy := wy + (wh // 2)
    if (IsOnSmallScreen(cx, cy) || cx < mLeft || cx >= mRight || cy < mTop || cy >= mBottom) {
        wasMax := (state = 1)
        if wasMax
            WinRestore(winId)
        newW := Min(ww, Round(mW * 0.85)), newH := Min(wh, Round(mH * 0.85))
        WinMove(mLeft + ((mW - newW) // 2), mTop + ((mH - newH) // 2), newW, newH, winId)
        if wasMax
            WinMaximize(winId)
    }
}

FocusMainMonitorBeforeRun() {
    MonitorGetWorkArea(MonitorGetPrimary(), &mLeft, &mTop, &mRight, &mBottom)
    for hwnd in WinGetList() {
        if IsOverlayGui(hwnd)
            continue
        style := WinGetStyle("ahk_id " hwnd), exStyle := WinGetExStyle("ahk_id " hwnd)
        if ((style & 0x10000000) && !(exStyle & 0x80) && WinGetMinMax("ahk_id " hwnd) != -1) {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
            cx := wx + (ww // 2), cy := wy + (wh // 2)
            if (cx >= mLeft && cx < mRight && cy >= mTop && cy < mBottom) {
                WinActivate("ahk_id " hwnd)
                return
            }
        }
    }
    if WinExist("ahk_class Progman")
        WinActivate("ahk_class Progman")
}

GetVisibleHwnds() {
    list := Map()
    for hwnd in WinGetList()
        if (!IsOverlayGui(hwnd) && (WinGetStyle("ahk_id " hwnd) & 0x10000000))
            list[hwnd] := true
    return list
}

WaitForNewWindow(beforeMap, timeoutMs := 4500) {
    deadline := A_TickCount + timeoutMs
    while (A_TickCount < deadline) {
        Sleep(120)
        for hwnd in WinGetList() {
            if (!IsOverlayGui(hwnd) && !beforeMap.Has(hwnd)) {
                style := WinGetStyle("ahk_id " hwnd), exStyle := WinGetExStyle("ahk_id " hwnd), title := WinGetTitle("ahk_id " hwnd)
                if ((style & 0x10000000) && !(exStyle & 0x80) && title != "") {
                    WinGetPos(, , &ww, &wh, "ahk_id " hwnd)
                    if (ww > 200 && wh > 200)
                        return hwnd
                }
            }
        }
    }
    return 0
}

ToggleHwnd(hwnd) {
    winId := "ahk_id " hwnd
    if !WinExist(winId)
        return false
    if (WinGetMinMax(winId) = -1) {
        WinRestore(winId)
        MoveToMainMonitor(hwnd)
        WinActivate(winId)
        return true
    }
    if IsTopWindowOnMainMonitor(hwnd)
        WinMinimize(winId)
    else {
        MoveToMainMonitor(hwnd)
        WinActivate(winId)
    }
    return true
}

FindExistingWindow(target, kw, isPwa) {
    if isPwa {
        if (kw != "") {
            for hwnd in WinGetList("ahk_exe chrome.exe") {
                if IsOverlayGui(hwnd)
                    continue
                if InStr(WinGetTitle("ahk_id " hwnd), kw)
                    return hwnd
            }
        }
        return 0
    }

    if (SubStr(target, -4) = ".exe") {
        SplitPath(target, &exeName)
        if WinExist("ahk_exe " exeName)
            return WinGetID("ahk_exe " exeName)
    }

    if (kw != "") {
        ; Търсим по дума в заглавието, но НЕ в прозорци на Explorer и на браузърите: папка или раздел
        ; със същата дума (напр. "Radio") иначе се вземат за прозореца на приложението.
        for hwnd in WinGetList() {
            if IsOverlayGui(hwnd)
                continue
            if !((WinGetStyle("ahk_id " hwnd) & 0x10000000) && InStr(WinGetTitle("ahk_id " hwnd), kw))
                continue
            try {
                exeName := WinGetProcessName("ahk_id " hwnd)
            } catch {
                continue
            }
            if (exeName = "explorer.exe" || exeName = "firefox.exe" || exeName = "chrome.exe" || exeName = "msedge.exe")
                continue
            return hwnd
        }
    }
    return 0
}

HandleButton(btnIdx, rawTarget, isPwa, kw, *) {
    now := A_TickCount
    if (lastClick.Has(btnIdx) && (now - lastClick[btnIdx] < 800)) || (busyBtns.Has(btnIdx) && busyBtns[btnIdx])
        return
    lastClick[btnIdx] := now

    if appHwnds.Has(btnIdx) {
        if ToggleHwnd(appHwnds[btnIdx])
            return
        appHwnds.Delete(btnIdx)
    }

    target := ExpandEnv(rawTarget)

    if (existingHwnd := FindExistingWindow(target, kw, isPwa)) {
        appHwnds[btnIdx] := existingHwnd
        ToggleHwnd(existingHwnd)
        return
    }

    if (!isPwa && SubStr(target, -4) = ".exe") {
        SplitPath(target, &exeName)
        if ProcessExist(exeName) {
            if (hwnd := WinExist("ahk_exe " exeName)) {
                appHwnds[btnIdx] := hwnd
                ToggleHwnd(hwnd)
            }
            return
        }
    }

    beforeWindows := GetVisibleHwnds()
    busyBtns[btnIdx] := true
    try {
        FocusMainMonitorBeforeRun()

        if (InStr(target, "http") = 1 || InStr(target, "shell:") = 1 || InStr(target, "ms-") = 1 || FileExist(target))
            Run(target)
        else {
            MsgBox(T("errFileNotFound") "`n" target, "EdgeLauncher", "Icon!")
            return
        }

        if (newHwnd := WaitForNewWindow(beforeWindows, 4500)) {
            appHwnds[btnIdx] := newHwnd
            MoveToMainMonitor(newHwnd)
            WinActivate("ahk_id " newHwnd)
        }
    } catch Error as err {
        MsgBox(T("errLaunch") "`n" target "`n`n" err.Message, "EdgeLauncher", "Icon!")
    } finally {
        busyBtns[btnIdx] := false
    }
}

; ================= ФУНКЦИИ: ДОЛНА ЛЕНТА =================
ToggleStartMenu() {
    global startOpenTick, startMenuOpen

    startHwnd := WinExist("ahk_class Windows.UI.Core.CoreWindow", "Start")
    if !startHwnd
        startHwnd := WinExist("ahk_class Launcher.ImmersiveLauncher")

    isReallyOpen := false
    if startHwnd {
        try {
            activeHwnd := WinGetID("A")
            if (activeHwnd = startHwnd) || (DllCall("IsWindowVisible", "Ptr", startHwnd) && (A_TickCount - startOpenTick < 4000))
                isReallyOpen := true
        }
    }

    if (startMenuOpen || isReallyOpen) {
        Send("{Escape}")
        startMenuOpen := false
        startOpenTick := 0
        return
    }

    Send("^{Esc}")
    startMenuOpen := true
    startOpenTick := A_TickCount
}

MouseOverVolume() {
    global barPosX, barPosY, barH, volBoxX, volBoxW
    MouseGetPos(&mx, &my)
    boxLeft := barPosX + volBoxX
    boxRight := boxLeft + volBoxW
    return (mx >= boxLeft && mx <= boxRight && my >= barPosY && my <= (barPosY + barH))
}

AdjustVolume(delta) {
    try {
        cur := SoundGetVolume()
        SoundSetVolume(Max(0, Min(100, Round(cur + delta))))
        UpdateVolumeUI()
    }
}

ToggleMute(*) {
    try {
        SoundSetMute(!SoundGetMute())
        UpdateVolumeUI()
    }
}

ShowBarMenu(*) {
    MouseGetPos(&mx, &my)
    m := Menu()
    m.Add(T("mRefresh"), (*) => FetchWeather())
    m.Add(T("mSettings"), ShowSettingsGui)
    m.Add(T("mOpenIni"), OpenSettings)
    m.Add(T("mReload"), (*) => Reload())
    m.Add()
    m.Add(T("mExit"), (*) => ExitApp())
    m.Show(mx, my)
}

UpdateAll() {
    static tick := 0
    UpdateCpuAndRam()
    if (Mod(tick, 30) = 0)
        UpdateDisks()
    tick += 1
    UpdateTemps()
    UpdateVolumeUI()
}

LayoutIndicatorsEqual(ctrls) {
    maxSamples := indSamples

    widths := []
    totalTextW := 0

    for idx, c in ctrls {
        w := MeasureTextWidth(maxSamples[idx], "Segoe UI Semibold", barFont, 700) + indPad
        widths.Push(w)
        totalTextW += w
    }

    zoneStart := 257
    zoneEnd   := volBoxX - 2
    zoneW     := zoneEnd - zoneStart

    gap := Max(minGap, (zoneW - totalTextW) / 7.0)

    curX := zoneStart + gap
    for idx, c in ctrls {
        w := Round(widths[idx])
        x := Round(curX)
        c.Move(x, 5, w + Max(0, Round(gap) - 4), 108)
        curX += w + gap
    }
}

; Ако името на деня е по-широко от колоната (напр. понеделник/ПОНЕДЕЛНИК), кутията му се разширява поравно
; и се вдига над съседните (върху празното им място), така че буквите не се режат. Не излиза извън прозореца.
; Работи и в двата дизайна (wide: колона 254 px, шрифт 36; classic: колона 222 px, шрифт 40).
FitDayLabel(i, name) {
    colW := wide ? 254 : fcStepX
    mx := wide ? fcX0 - 16 + (i - 1) * fcStepX : fcX0 + (i - 1) * fcStepX
    ty := wide ? 0 : fcDayY
    th := wide ? 53 : fcDayH
    need := MeasureTextWidth(name, "Segoe UI", wide ? Pt(36) : Pt(fcDayFont), 700) + 8
    extra := Max(0, need - colW)
    extra += Mod(extra, 2)
    left := mx - extra // 2
    right := mx + colW + extra // 2
    WinGetClientPos(, , &winW, , g.Hwnd)
    if (right > winW)
        left -= right - winW
    ; HWND_TOP (0) само при разширена кутия; иначе само позиция/размер (SWP_NOZORDER 0x4), за да не пада разширената под съседна
    flags := (extra > 0) ? 0x10 : 0x14
    DllCall("SetWindowPos", "Ptr", ctlFcDay[i].Hwnd, "Ptr", 0, "Int", left, "Int", ty, "Int", colW + extra, "Int", th, "UInt", flags)
}

MeasureTextWidth(text, fontName, fontSize, weight := 700) {
    hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
    dpiY := DllCall("GetDeviceCaps", "Ptr", hdc, "Int", 90)
    height := -DllCall("MulDiv", "Int", fontSize, "Int", dpiY, "Int", 72, "Int")
    hFont := DllCall("CreateFontW"
        , "Int", height
        , "Int", 0
        , "Int", 0
        , "Int", 0
        , "Int", weight
        , "UInt", 0
        , "UInt", 0
        , "UInt", 0
        , "UInt", 1
        , "UInt", 0
        , "UInt", 0
        , "UInt", 5
        , "UInt", 0
        , "Str", fontName
        , "Ptr")

    hOld := DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")
    sz := Buffer(8, 0)
    DllCall("GetTextExtentPoint32W", "Ptr", hdc, "Str", text, "Int", StrLen(text), "Ptr", sz)
    w := NumGet(sz, 0, "Int")

    DllCall("SelectObject", "Ptr", hdc, "Ptr", hOld, "Ptr")
    DllCall("DeleteObject", "Ptr", hFont)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
    return w
}

UpdateCpuAndRam() {
    global prevIdle, prevKernel, prevUser, cpuLoadTxt, ramTxt
    mem := Buffer(64, 0)
    NumPut("UInt", 64, mem, 0)
    if DllCall("GlobalMemoryStatusEx", "Ptr", mem) {
        newRam := Format("RAM:{}%", NumGet(mem, 4, "UInt"))
        if (ramTxt.Text != newRam)
            ramTxt.Text := newRam
    }
    idle := Buffer(8, 0), kernel := Buffer(8, 0), user := Buffer(8, 0)
    if DllCall("GetSystemTimes", "Ptr", idle, "Ptr", kernel, "Ptr", user) {
        i := NumGet(idle, 0, "UInt64"), k := NumGet(kernel, 0, "UInt64"), u := NumGet(user, 0, "UInt64")
        if (prevKernel > 0 || prevUser > 0) {
            sysTotal := (k - prevKernel) + (u - prevUser)
            idleDiff := i - prevIdle
            if (sysTotal > 0) {
                cpuLoad := Max(0, Min(100, Round((1 - (idleDiff / sysTotal)) * 100)))
                newCpu := Format("CPU:{}%", cpuLoad)
                if (cpuLoadTxt.Text != newCpu)
                    cpuLoadTxt.Text := newCpu
            }
        }
        prevIdle := i, prevKernel := k, prevUser := u
    }
}

UpdateDisks() {
    global diskCTxt, diskDTxt
    try {
        totalC := DriveGetCapacity(driveA "\")
        freeC := DriveGetSpaceFree(driveA "\")
        usedC := (totalC - freeC) / 1024
        newC := Format("{}{:.1f} GB", driveA, usedC)
        if (diskCTxt.Text != newC)
            diskCTxt.Text := newC
    }
    try {
        totalD := DriveGetCapacity(driveB "\")
        freeD := DriveGetSpaceFree(driveB "\")
        usedD := (totalD - freeD) / 1024
        newD := Format("{}{:.1f} GB", driveB, usedD)
        if (diskDTxt.Text != newD)
            diskDTxt.Text := newD
    }
}

UpdateTemps() {
    global cpuTempTxt, gpuTempTxt

    cpuT := GetCpuTempFromHwinfo()
    if (cpuT != "") {
        newCpuT := Format("CPU:{}°C", Round(Float(cpuT)))
        if (cpuTempTxt.Text != newCpuT)
            cpuTempTxt.Text := newCpuT
    }

    gpuT := GetGpuTempFromHwinfo()
    if (gpuT != "") {
        newGpuT := Format("GPU:{:.1f}°C", Float(gpuT))
        if (gpuTempTxt.Text != newGpuT)
            gpuTempTxt.Text := newGpuT
    }
}

ParseHwinfoTempAt(regPath, idx, mode) {
    lbl := RegRead(regPath, "Label" idx, "")
    if (lbl = "")
        return ""

    matched := false
    if (mode = "cpu") {
        if (InStr(lbl, "CPU Package") || InStr(lbl, "Core Max") || InStr(lbl, "Tctl/Tdie") || InStr(lbl, "CPU"))
            matched := true
    } else if (mode = "gpu") {
        if (InStr(lbl, "GPU Temperature") || InStr(lbl, "GPU Core") || InStr(lbl, "GPU"))
            matched := true
    }

    if !matched
        return ""

    if (strictTempLabels) {
        for bad in ["Power", "Usage", "Load", "Clock", "Fan", "Voltage", "Utilization", "Limit"] {
            if InStr(lbl, bad)
                return ""
        }
    }

    valRaw := RegRead(regPath, "Value" idx, "")
    if RegExMatch(valRaw, "[-+]?\d+(\.\d+)?", &m) {
        num := Float(m[0])
        if (num > 5 && num < 130)
            return num
    }
    return ""
}

FindHwinfoTemp(regPath, mode, &cacheIdx) {
    try {
        if (cacheIdx >= 0) {
            fastVal := ParseHwinfoTempAt(regPath, cacheIdx, mode)
            if (fastVal != "")
                return fastVal
            cacheIdx := -1
        }

        loop 256 {
            idx := A_Index - 1
            val := ParseHwinfoTempAt(regPath, idx, mode)
            if (val != "") {
                cacheIdx := idx
                return val
            }
        }
    }
    return ""
}

GetCpuTempFromHwinfo() {
    global cachedCpuHwinfoIdx
    regPath := "HKEY_CURRENT_USER\Software\HWiNFO64\VSB"
    return FindHwinfoTemp(regPath, "cpu", &cachedCpuHwinfoIdx)
}

GetGpuTempFromHwinfo() {
    global cachedGpuHwinfoIdx
    regPath := "HKEY_CURRENT_USER\Software\HWiNFO64\VSB"
    return FindHwinfoTemp(regPath, "gpu", &cachedGpuHwinfoIdx)
}

UpdateVolumeUI() {
    global lastVolText, volPctTxt
    try {
        vol := Round(SoundGetVolume())
        mute := SoundGetMute()
        newVolText := mute ? "MUTE" : Format("VOL {}%", vol)
        if (newVolText != lastVolText) {
            lastVolText := newVolText
            volPctTxt.Text := newVolText
        }
    }
}

; ================= ФУНКЦИИ: settings.ini =================
; Собствен четец на INI (IniRead е лош с UTF-8 и кирилица). Секции [Име], редове Ключ = Стойност,
; коментари с ; или # в началото на реда (или " ;" след стойността).
LoadSettings(path) {
    data := Map()
    data.CaseSense := "Off"
    if !FileExist(path)
        return data
    try {
        txt := FileRead(path, "UTF-8")
    } catch {
        return data
    }
    sec := ""
    for line in StrSplit(txt, "`n", "`r") {
        line := Trim(line)
        if (line = "" || SubStr(line, 1, 1) = ";" || SubStr(line, 1, 1) = "#")
            continue
        if (SubStr(line, 1, 1) = "[" && SubStr(line, -1) = "]") {
            sec := Trim(SubStr(line, 2, StrLen(line) - 2))
            continue
        }
        p := InStr(line, "=")
        if (p < 2)
            continue
        key := Trim(SubStr(line, 1, p - 1))
        val := Trim(SubStr(line, p + 1))
        val := Trim(RegExReplace(val, "\s;.*$"))
        if (StrLen(val) >= 2 && SubStr(val, 1, 1) = '"' && SubStr(val, -1) = '"')
            val := SubStr(val, 2, StrLen(val) - 2)
        data[sec "|" key] := val
    }
    return data
}

Cfg(sec, key, def := "") {
    k := sec "|" key
    if (iniData.Has(k) && iniData[k] != "")
        return iniData[k]
    return def
}

CfgIsTrue(v) => RegExMatch(Trim(v), "i)^(1|true|yes|on|да)$") ? true : false

CfgBool(sec, key, def) {
    v := Cfg(sec, key, "")
    if (v = "")
        return def
    return CfgIsTrue(v)
}

CfgInt(sec, key, def) {
    v := Cfg(sec, key, "")
    return IsInteger(v) ? Integer(v) : def
}

CfgCoord(sec, key, def) {
    v := Cfg(sec, key, "")
    return IsNumber(v) ? v : def
}

CfgDrive(sec, key, def) {
    v := RegExReplace(Cfg(sec, key, def), "[\\/]+$")
    return RegExMatch(v, "i)^[A-Z]:$") ? StrUpper(v) : def
}

ExpandEnv(str) {
    if !InStr(str, "%")
        return str
    n := DllCall("ExpandEnvironmentStringsW", "Str", str, "Ptr", 0, "UInt", 0, "UInt")
    if (n = 0)
        return str
    buf := Buffer(n * 2, 0)
    DllCall("ExpandEnvironmentStringsW", "Str", str, "Ptr", buf, "UInt", n, "UInt")
    return StrGet(buf, "UTF-16")
}

; Папка: разширява %ENV%, относителните пътища се броят от папката на скрипта, добавя краен ""
ResolveDir(path) {
    path := ExpandEnv(Trim(path))
    if !(SubStr(path, 2, 1) = ":" || SubStr(path, 1, 2) = "\\")
        path := A_ScriptDir "\" path
    return RTrim(path, "\") "\"
}

OpenSettings(*) {
    if FileExist(settingsFile)
        Run('notepad.exe "' settingsFile '"')
    else
        MsgBox(T("iniMissing", settingsFile), "CorsairSuperWidget", "Icon!")
}

; ================= ПРОЗОРЕЦ ЗА НАСТРОЙКИ =================
; Отваря се от трея / менюто на START. Записва в settings.ini (коментарите във файла се запазват,
; преди запис се прави копия settings.ini.bak) и презарежда скрипта.
ShowSettingsGui(*) {
    global settingsGui
    if IsObject(settingsGui) {
        try {
            settingsGui.Show()
            return
        }
    }
    sg := Gui("+OwnDialogs", T("msgTitle") " - CorsairSuperWidget")
    settingsGui := sg
    sg.OnEvent("Close", CloseSettingsGui)
    sg.OnEvent("Escape", CloseSettingsGui)
    sg.SetFont("s10", "Segoe UI")
    tabs := sg.Add("Tab3", "x10 y10 w840 h480", [T("tabGeneral"), T("tabWeather"), T("tabBar"), T("tabFolders"), T("tabApps")])
    fld := Map()

    ; --- Общи ---
    tabs.UseTab(1)
    designIdx := wide ? 2 : 1
    sg.Add("Text", "x30 y58 w210", T("lblDesign"))
    fld["Design"] := sg.Add("DropDownList", "x245 y54 w160 Choose" designIdx, ["classic", "wide"])
    sg.Add("Text", "x30 y95 w780 cGray", T("hintDesign"))
    fld["Auto"] := sg.Add("Checkbox", "x30 y140 w700", T("chkAuto"))
    fld["Auto"].Value := CfgBool("General", "AutoDetectScreen", true) ? 1 : 0
    sg.Add("Text", "x30 y185 w210", T("lblX"))
    fld["X"] := sg.Add("Edit", "x245 y181 w110", CfgInt("General", "ManualX", 451))
    sg.Add("Text", "x30 y225 w210", T("lblY"))
    fld["Y"] := sg.Add("Edit", "x245 y221 w110", CfgInt("General", "ManualY", 1440))
    sg.Add("Text", "x30 y268 w780 cGray", T("hintXY"))
    fld["Autostart"] := sg.Add("Checkbox", "x30 y315 w760", T("chkAutostart"))
    fld["Autostart"].Value := AutostartEnabled() ? 1 : 0
    sg.Add("Text", "x30 y350 w780 cGray", T("hintAutostart"))
    sg.Add("Text", "x30 y398 w210", T("lblLanguage"))
    langIdx := 1
    for i, c in langCodes
        if (c = StrLower(Cfg("General", "Language", "auto")))
            langIdx := i
    fld["Lang"] := sg.Add("DropDownList", "x245 y394 w230 Choose" langIdx, [T("langAuto"), "Български", "Русский", "English", "Français", "Español", "Italiano", "Português"])
    sg.Add("Text", "x30 y432 w780 cGray", T("hintLanguage"))

    ; --- Време ---
    tabs.UseTab(2)
    sg.Add("Text", "x30 y58 w210", T("lblCity"))
    fld["City"] := sg.Add("Edit", "x245 y54 w260", Cfg("Weather", "City", T("defaultCity")))
    sg.Add("Text", "x30 y98 w210", T("lblLat"))
    fld["Lat"] := sg.Add("Edit", "x245 y94 w140", Cfg("Weather", "Lat", "42.6977"))
    sg.Add("Text", "x30 y138 w210", T("lblLon"))
    fld["Lon"] := sg.Add("Edit", "x245 y134 w140", Cfg("Weather", "Lon", "23.3219"))
    sg.Add("Text", "x30 y178 w210", T("lblRefresh"))
    fld["Refresh"] := sg.Add("Edit", "x245 y174 w90", CfgInt("Weather", "RefreshMinutes", 30))
    sg.Add("Text", "x30 y222 w780 cGray", T("hintCoords"))

    ; --- Лента ---
    tabs.UseTab(3)
    sg.Add("Text", "x30 y58 w250", T("lblDrive1"))
    fld["Drive1"] := sg.Add("Edit", "x285 y54 w80", CfgDrive("Bar", "Drive1", "C:"))
    sg.Add("Text", "x30 y98 w250", T("lblDrive2"))
    fld["Drive2"] := sg.Add("Edit", "x285 y94 w80", CfgDrive("Bar", "Drive2", "D:"))
    fld["Strict"] := sg.Add("Checkbox", "x30 y142 w760", T("chkStrict"))
    fld["Strict"].Value := CfgBool("Bar", "StrictTempLabels", true) ? 1 : 0
    sg.Add("Text", "x30 y188 w250", T("lblWheel"))
    fld["Wheel"] := sg.Add("Edit", "x285 y184 w80", CfgInt("Volume", "WheelStep", 5))
    sg.Add("Text", "x30 y232 w780 cGray", T("hintBar"))

    ; --- Папки ---
    tabs.UseTab(4)
    pathRows := [["LauncherIcons", T("lblIcons"), "icons"]
        , ["WeatherIcons", T("lblWeatherIcons"), "icons"]
        , ["ChromeApps", T("lblChromeApps"), "%AppData%\Microsoft\Windows\Start Menu\Programs\" T("chromeAppsFolder")]]
    py := 58
    for pr in pathRows {
        sg.Add("Text", "x30 y" py " w300", pr[2])
        e := sg.Add("Edit", "x30 y" . (py + 26) . " w650", Cfg("Paths", pr[1], pr[3]))
        fld["P_" pr[1]] := e
        b := sg.Add("Button", "x690 y" . (py + 24) . " w120 h30", T("btnBrowse"))
        b.OnEvent("Click", PickFolderInto.Bind(e))
        py += 80
    }
    sg.Add("Text", "x30 y" py " w780 cGray", T("hintPaths"))

    ; --- Приложения ---
    tabs.UseTab(5)
    sg.Add("Text", "x25 y48 w150", T("colIcon"))
    sg.Add("Text", "x180 y48 w400", T("colCmd"))
    sg.Add("Text", "x625 y48 w60", "PWA")
    sg.Add("Text", "x690 y48 w130", T("colKw"))
    appFlds := []
    Loop 10 {
        yy := 74 + (A_Index - 1) * 36
        ic := "", cm := "", pw := 0, kwv := ""
        if (A_Index <= apps.Length) {
            ic := apps[A_Index].icon
            cm := apps[A_Index].cmd
            pw := apps[A_Index].pwa ? 1 : 0
            kwv := apps[A_Index].kw
            if (chromeAppsDir != "" && InStr(cm, chromeAppsDir) = 1)
                cm := "{ChromeApps}" SubStr(cm, StrLen(chromeAppsDir) + 1)
        }
        eIc := sg.Add("Edit", "x25 y" yy " w150", ic)
        eCm := sg.Add("Edit", "x180 y" yy " w400", cm)
        bBr := sg.Add("Button", "x583 y" . (yy - 1) . " w34 h28", "…")
        bBr.OnEvent("Click", PickFileInto.Bind(eCm))
        cP := sg.Add("Checkbox", "x630 y" . (yy + 3) . " w50", "")
        cP.Value := pw
        eKw := sg.Add("Edit", "x690 y" yy " w130", kwv)
        appFlds.Push({icon: eIc, cmd: eCm, pwa: cP, kw: eKw})
    }

    tabs.UseTab(0)
    bReset := sg.Add("Button", "x30 y500 w200 h36", T("btnReset"))
    bReset.OnEvent("Click", ResetSettingsToDefault)
    bRestore := sg.Add("Button", "x240 y500 w200 h36", T("btnRestore"))
    bRestore.OnEvent("Click", RestorePreviousSettings)
    bSave := sg.Add("Button", "x470 y500 w230 h36 Default", T("btnSave"))
    bSave.OnEvent("Click", SaveSettingsGui.Bind(fld, appFlds))
    bCancel := sg.Add("Button", "x710 y500 w140 h36", T("btnCancel"))
    bCancel.OnEvent("Click", CloseSettingsGui)

    ; прозорецът се показва в средата на ОСНОВНИЯ монитор (не върху малкия екран)
    sg.Show("Hide AutoSize")
    sg.GetPos(, , &sw, &sh)
    MonitorGetWorkArea(MonitorGetPrimary(), &mL, &mT, &mR, &mB)
    sg.Show("x" . (mL + ((mR - mL) - sw) // 2) . " y" . (mT + ((mB - mT) - sh) // 2))
}

CloseSettingsGui(*) {
    global settingsGui
    try settingsGui.Destroy()
    settingsGui := ""
}

PickFolderInto(edit, *) {
    start := ExpandEnv(edit.Text)
    d := FileSelect("D", DirExist(start) ? start : "", T("pickFolder"))
    if (d != "")
        edit.Text := RTrim(d, "\")
}

PickFileInto(edit, *) {
    f := FileSelect(3, , T("pickProgram"), T("pickFilter"))
    if (f != "")
        edit.Text := f
}

SaveSettingsGui(fld, appFlds, *) {
    items := []
    x := Trim(fld["X"].Text), y := Trim(fld["Y"].Text)
    if !(IsInteger(x) && IsInteger(y)) {
        MsgBox(T("errXY"), T("msgTitle"), "Icon!")
        return
    }
    lat := StrReplace(Trim(fld["Lat"].Text), ",", "."), lon := StrReplace(Trim(fld["Lon"].Text), ",", ".")
    if !(IsNumber(lat) && IsNumber(lon) && Abs(lat) <= 90 && Abs(lon) <= 180) {
        MsgBox(T("errLatLon"), T("msgTitle"), "Icon!")
        return
    }
    refresh := Trim(fld["Refresh"].Text)
    if !(IsInteger(refresh) && refresh >= 1) {
        MsgBox(T("errRefresh"), T("msgTitle"), "Icon!")
        return
    }
    drives := []
    for k in ["Drive1", "Drive2"] {
        d := RegExReplace(Trim(fld[k].Text), "[\\/]+$")
        if !RegExMatch(d, "i)^[A-Z]:$") {
            MsgBox(T("errDrive"), T("msgTitle"), "Icon!")
            return
        }
        drives.Push(StrUpper(d))
    }
    wheel := Trim(fld["Wheel"].Text)
    if !(IsInteger(wheel) && wheel >= 1 && wheel <= 50) {
        MsgBox(T("errWheel"), T("msgTitle"), "Icon!")
        return
    }

    items.Push(["General", "Design", fld["Design"].Text])
    items.Push(["General", "Language", langCodes[Max(1, fld["Lang"].Value)]])
    items.Push(["General", "AutoDetectScreen", fld["Auto"].Value ? 1 : 0])
    items.Push(["General", "ManualX", Integer(x)])
    items.Push(["General", "ManualY", Integer(y)])
    items.Push(["Paths", "LauncherIcons", Trim(fld["P_LauncherIcons"].Text)])
    items.Push(["Paths", "WeatherIcons", Trim(fld["P_WeatherIcons"].Text)])
    items.Push(["Paths", "ChromeApps", Trim(fld["P_ChromeApps"].Text)])
    items.Push(["Weather", "City", Trim(fld["City"].Text)])
    items.Push(["Weather", "Lat", lat])
    items.Push(["Weather", "Lon", lon])
    items.Push(["Weather", "RefreshMinutes", Integer(refresh)])
    items.Push(["Bar", "Drive1", drives[1]])
    items.Push(["Bar", "Drive2", drives[2]])
    items.Push(["Bar", "StrictTempLabels", fld["Strict"].Value ? 1 : 0])
    items.Push(["Volume", "WheelStep", Integer(wheel)])

    for i, a in appFlds {
        ic := Trim(a.icon.Text), cm := Trim(a.cmd.Text), kwv := Trim(a.kw.Text)
        if ((ic = "") != (cm = "")) {
            MsgBox(T("errAppRow", i), T("msgTitle"), "Icon!")
            return
        }
        v := (ic = "") ? "" : (StrReplace(ic, "|", "") . " | " . StrReplace(cm, "|", "") . " | " . (a.pwa.Value ? 1 : 0) . " | " . StrReplace(kwv, "|", ""))
        items.Push(["Launcher", "App" i, v])
    }

    if !WriteSettingsFile(settingsFile, items)
        return
    SetAutostart(fld["Autostart"].Value ? true : false)
    Reload()
}

; Променя само стойностите (коментарите и подредбата остават). Липсващи ключове/секции се добавят.
WriteSettingsFile(path, items) {
    lines := []
    try {
        if FileExist(path) {
            for l in StrSplit(FileRead(path, "UTF-8"), "`n", "`r")
                lines.Push(l)
            while (lines.Length > 0 && Trim(lines[lines.Length]) = "")
                lines.Pop()
            FileCopy(path, path ".bak", 1)
        }
    } catch Error as err {
        MsgBox(T("errReadIni", err.Message), T("msgTitle"), "Icon!")
        return false
    }
    for it in items {
        sec := it[1], key := it[2], val := it[3]
        inSec := false, secEnd := 0, done := false
        for i, l in lines {
            t := Trim(l)
            if (SubStr(t, 1, 1) = "[" && SubStr(t, -1) = "]") {
                if inSec
                    break
                inSec := (StrLower(Trim(SubStr(t, 2, StrLen(t) - 2))) = StrLower(sec))
                if inSec
                    secEnd := i
                continue
            }
            if (!inSec || t = "")
                continue
            secEnd := i
            if (SubStr(t, 1, 1) = ";" || SubStr(t, 1, 1) = "#")
                continue
            p := InStr(t, "=")
            if (p > 1 && StrLower(Trim(SubStr(t, 1, p - 1))) = StrLower(key)) {
                lines[i] := key "=" val
                done := true
                break
            }
        }
        if done
            continue
        if (secEnd > 0) {
            lines.InsertAt(secEnd + 1, key "=" val)
        } else {
            if (lines.Length > 0)
                lines.Push("")
            lines.Push("[" sec "]")
            lines.Push(key "=" val)
        }
    }
    out := ""
    for l in lines
        out .= l "`r`n"
    try {
        fo := FileOpen(path, "w", "UTF-8")
        fo.Write(out)
        fo.Close()
    } catch Error as err {
        MsgBox(T("errWriteIni", err.Message), T("msgTitle"), "Icon!")
        return false
    }
    return true
}

; ================= СТАРТИРАНЕ С WINDOWS =================
; Пряк път в папката Startup на потребителя (без регистър, без администраторски права).
AutostartLink() => A_Startup "\CorsairSuperWidget.lnk"

AutostartEnabled() => FileExist(AutostartLink()) ? true : false

SetAutostart(on) {
    link := AutostartLink()
    try {
        if on {
            FileCreateShortcut(A_ScriptFullPath, link, A_ScriptDir, "", T("shortcutDesc"))
        } else if FileExist(link) {
            FileDelete(link)
        }
    } catch Error as err {
        MsgBox(T("errAutostart", err.Message), T("msgTitle"), "Icon!")
    }
}

; ================= ВРЪЩАНЕ НА НАСТРОЙКИТЕ =================
; Начални настройки = стойностите, с които скриптът е работил първоначално (дизайн classic).
; Преди всяко връщане текущият settings.ini се пази като settings.ini.bak.
ResetSettingsToDefault(*) {
    if (MsgBox(T("askReset"), T("msgTitle"), "YesNo Icon?") != "Yes")
        return
    try {
        if FileExist(settingsFile)
            FileCopy(settingsFile, settingsFile ".bak", 1)
        fo := FileOpen(settingsFile, "w", "UTF-8")
        fo.Write(DefaultSettingsText())
        fo.Close()
    } catch Error as err {
        MsgBox(T("errReset", err.Message), T("msgTitle"), "Icon!")
        return
    }
    Reload()
}

RestorePreviousSettings(*) {
    bak := settingsFile ".bak"
    if !FileExist(bak) {
        MsgBox(T("noBackup"), T("msgTitle"), "Icon!")
        return
    }
    if (MsgBox(T("askRestore"), T("msgTitle"), "YesNo Icon?") != "Yes")
        return
    try {
        tmp := settingsFile ".tmp"
        if FileExist(settingsFile)
            FileCopy(settingsFile, tmp, 1)
        FileCopy(bak, settingsFile, 1)
        if FileExist(tmp)
            FileMove(tmp, bak, 1)
    } catch Error as err {
        MsgBox(T("errRestore", err.Message), T("msgTitle"), "Icon!")
        return
    }
    Reload()
}

DefaultSettingsText() {
    lines := []
    lines.Push("; ====================================================================")
    lines.Push(";  settings.ini for CorsairSuperWidget.ahk")
    lines.Push(";  Put it in the same folder as the script. After editing:")
    lines.Push(";  right-click the tray icon -> Reload script.")
    lines.Push(";  If a line is missing or wrong, the built-in value is used.")
    lines.Push(";  Comments: lines starting with a semicolon or a hash sign")
    lines.Push("; ====================================================================")
    lines.Push("")
    lines.Push("[General]")
    lines.Push("; Design:")
    lines.Push(";   classic = clock and forecast on the left, 2 rows of icons on the right")
    lines.Push(";   wide    = top row for time, date and 6-day forecast, the 10 icons in one row below")
    lines.Push("Design=classic")
    lines.Push("; Language: auto (follows Windows) or bg, ru, en, fr, es, it, pt")
    lines.Push("Language=auto")
    lines.Push("; 1 = finds the smallest monitor automatically, 0 = uses ManualX/ManualY")
    lines.Push("AutoDetectScreen=1")
    lines.Push("ManualX=451")
    lines.Push("ManualY=1440")
    lines.Push("")
    lines.Push("[Paths]")
    lines.Push("; Launcher icons folder (absolute path or relative to the script folder)")
    lines.Push("LauncherIcons=icons")
    lines.Push("; Weather icons folder (07.png, 01.png ...)")
    lines.Push("WeatherIcons=icons")
    lines.Push("; Folder with Chrome app (PWA) shortcuts, may contain %AppData%. Empty = default for the selected language")
    lines.Push("ChromeApps=")
    lines.Push("")
    lines.Push("[Weather]")
    lines.Push("; City label under the temperature. Empty = Sofia (in the selected language)")
    lines.Push("City=")
    lines.Push("Lat=42.6977")
    lines.Push("Lon=23.3219")
    lines.Push("; refresh interval in minutes")
    lines.Push("RefreshMinutes=30")
    lines.Push("")
    lines.Push("[Bar]")
    lines.Push("; Which two drives the bottom bar shows")
    lines.Push("Drive1=C:")
    lines.Push("Drive2=D:")
    lines.Push("; 1 = skips HWiNFO labels for power, load, clock, fan when reading temperatures")
    lines.Push("StrictTempLabels=1")
    lines.Push("")
    lines.Push("[Volume]")
    lines.Push("; percent per wheel step over the VOL tile")
    lines.Push("WheelStep=5")
    lines.Push("")
    lines.Push("[Launcher]")
    lines.Push("; Format:  AppN = icon name | what to launch | pwa (1/0) | word from the window title")
    lines.Push("; {ChromeApps} is replaced with the ChromeApps folder above. You can use %LocalAppData%, %ProgramFiles% and so on.")
    lines.Push("App1=Firefox.png | C:\Program Files\Mozilla Firefox\firefox.exe | 0 | Firefox")
    lines.Push("App2=Gemini.png | shell:AppsFolder\com.google.gemini.windows | 0 | Gemini")
    lines.Push("App3=YouTubeMusic.png | {ChromeApps}YouTube Music.lnk | 1 | YouTube Music")
    lines.Push("App4=Stremio.png | %LocalAppData%\Programs\Stremio\stremio-shell-ng.exe | 0 | Stremio")
    lines.Push("App5=UniversalRadio.png | shell:AppsFolder\52267melz.01.UniversalInternetRadio_0ekv48gcjdhv6!App | 0 | Radio")
    lines.Push("App6=Telegram.png | shell:AppsFolder\TelegramMessengerLLP.TelegramDesktop_t4vj0pshhgkwm!Telegram.TelegramDesktop.Store | 0 | Telegram")
    lines.Push("App7=Viber.png | %LocalAppData%\Viber\Viber.exe | 0 | Viber")
    lines.Push("App8=instagram.png | {ChromeApps}Instagram.lnk | 1 | Instagram")
    lines.Push("App9=Pinterest.png | {ChromeApps}Pinterest.lnk | 1 | Pinterest")
    lines.Push("App10=YouTube.png | {ChromeApps}YouTube.lnk | 1 | YouTube")
    out := ""
    for l in lines
        out .= l "`r`n"
    return out
}


; ================= ЕЗИЦИ (i18n) =================
; Език: Language=auto (по Windows) или bg, ru, en, fr, es, it, pt в settings.ini / в прозореца за настройки.
; Липсващ ключ в избрания език се взема от английския.
T(key, args*) {
    s := uiText.Has(key) ? uiText[key] : key
    for i, a in args
        s := StrReplace(s, "{" i "}", a)
    return s
}

ResolveLang(v) {
    v := StrLower(Trim(v))
    if (v = "bg" || v = "ru" || v = "en" || v = "fr" || v = "es" || v = "it" || v = "pt")
        return v
    p := StrUpper(SubStr(A_Language, 3, 2))
    if (p = "02")
        return "bg"
    if (p = "19")
        return "ru"
    if (p = "0C")
        return "fr"
    if (p = "0A")
        return "es"
    if (p = "10")
        return "it"
    if (p = "16")
        return "pt"
    return "en"
}

LoadLangByCode(code, t) {
    if (code = "bg")
        LoadLang_bg(t)
    else if (code = "ru")
        LoadLang_ru(t)
    else if (code = "fr")
        LoadLang_fr(t)
    else if (code = "es")
        LoadLang_es(t)
    else if (code = "it")
        LoadLang_it(t)
    else if (code = "pt")
        LoadLang_pt(t)
}

LoadLang_bg(t) {
    t["defaultCity"] := "София"
    t["chromeAppsFolder"] := "Приложения в Chrome"
    t["days"] := "неделя|понеделник|вторник|сряда|четвъртък|петък|събота"
    t["months"] := "януари|февруари|март|април|май|юни|юли|август|септември|октомври|ноември|декември"
    t["dateFmt"] := "{1} {2} {3}"
    t["today"] := "днес"
    t["tomorrow"] := "утре"
    t["windFmt"] := " · вятър {1} км/ч"
    t["updating"] := "Обновяване…"
    t["wx_clear"] := "Ясно"
    t["wx_mostly"] := "Предимно ясно"
    t["wx_partly"] := "Променливо"
    t["wx_cloudy"] := "Облачно"
    t["wx_fog"] := "Мъгла"
    t["wx_drizzle"] := "Ръмеж"
    t["wx_rain"] := "Дъжд"
    t["wx_snow"] := "Сняг"
    t["wx_showers"] := "Превалявания"
    t["wx_snowshowers"] := "Снеговалеж"
    t["wx_thunder"] := "Гръмотевици"
    t["mRefresh"] := "Обнови прогнозата"
    t["mSettings"] := "Настройки…"
    t["mOpenIni"] := "Отвори settings.ini"
    t["mResetDefaults"] := "Върни началните настройки"
    t["mReload"] := "Презареди скрипта"
    t["mExit"] := "Изход"
    t["msgTitle"] := "Настройки"
    t["errIcons"] := "Не намирам иконите на времето:`n{1}`n`nСложи папката icons до този файл (или стартирай скрипта от работната му папка)."
    t["errFileNotFound"] := "Не е намерен файлът:"
    t["errLaunch"] := "Грешка при стартиране:"
    t["iniMissing"] := "Не намирам settings.ini:`n{1}`n`nСложи го до скрипта."
    t["tabGeneral"] := "Общи"
    t["tabWeather"] := "Време"
    t["tabBar"] := "Лента"
    t["tabFolders"] := "Папки"
    t["tabApps"] := "Приложения"
    t["lblDesign"] := "Дизайн:"
    t["hintDesign"] := "classic = сегашният;  wide = горният ред за час, дата и прогноза, под него 10-те икони в един ред."
    t["chkAuto"] := "Сам да намира малкия монитор (AutoDetectScreen)"
    t["lblX"] := "Позиция X (ManualX):"
    t["lblY"] := "Позиция Y (ManualY):"
    t["hintXY"] := "X и Y се ползват само при изключено автоматично намиране (виж монитора в Настройки на дисплея на Windows)."
    t["chkAutostart"] := "Стартирай скрипта заедно с Windows"
    t["hintAutostart"] := "Слага/маха пряк път в папката Startup на потребителя. Ако ползваш HWiNFO, пусни и него със Windows (за температурите)."
    t["lblLanguage"] := "Език:"
    t["hintLanguage"] := "Езикът се прилага след „Запази и презареди“."
    t["langAuto"] := "Автоматично (Windows)"
    t["lblCity"] := "Град (текст):"
    t["lblLat"] := "Ширина (Lat):"
    t["lblLon"] := "Дължина (Lon):"
    t["lblRefresh"] := "Обновяване (минути):"
    t["hintCoords"] := "Координатите се взимат от карта (напр. Google Maps: десен клик върху мястото). Десетичен знак: точка."
    t["lblDrive1"] := "Първи диск (Drive1):"
    t["lblDrive2"] := "Втори диск (Drive2):"
    t["chkStrict"] := "Строг филтър на температурните етикети в HWiNFO (StrictTempLabels)"
    t["lblWheel"] := "Стъпка на звука (%):"
    t["hintBar"] := "Диск = буква и двоеточие, напр. C: или D:. Стъпката е колко процента променя една стъпка на колелцето над VOL (1-50)."
    t["lblIcons"] := "Икони на лаунчера:"
    t["lblWeatherIcons"] := "Икони за времето:"
    t["lblChromeApps"] := "Chrome приложения (PWA):"
    t["btnBrowse"] := "Избери…"
    t["hintPaths"] := "Може абсолютен път, път спрямо папката на скрипта (напр. icons) или с %AppData%, %LocalAppData%."
    t["colIcon"] := "Икона (PNG)"
    t["colCmd"] := "Какво да се стартира (път, shell:AppsFolder\…, {ChromeApps}…)"
    t["colKw"] := "Дума в заглавие"
    t["btnReset"] := "Начални настройки"
    t["btnRestore"] := "Върни предишните"
    t["btnSave"] := "Запази и презареди"
    t["btnCancel"] := "Откажи"
    t["pickFolder"] := "Избери папка"
    t["pickProgram"] := "Избери програма или пряк път"
    t["pickFilter"] := "Програми и преки пътища (*.exe; *.lnk)"
    t["errXY"] := "ManualX и ManualY трябва да са цели числа."
    t["errLatLon"] := "Lat (до 90) и Lon (до 180) трябва да са числа, напр. 42.6977 и 23.3219."
    t["errRefresh"] := "Обновяването трябва да е цяло число минути (1 или повече)."
    t["errDrive"] := "Дискът трябва да е буква и двоеточие, напр. C: или D:"
    t["errWheel"] := "Стъпката на звука трябва да е число от 1 до 50."
    t["errAppRow"] := "Ред {1} в „Приложения“: попълни и иконата, и какво да се стартира (или изчисти и двете)."
    t["errReadIni"] := "Не мога да прочета/копирам settings.ini:`n{1}"
    t["errWriteIni"] := "Не мога да запиша settings.ini:`n{1}"
    t["errAutostart"] := "Не успях да променя стартирането с Windows:`n{1}"
    t["askReset"] := "Да върна ли всички настройки към началните?`n`nТекущият settings.ini се запазва като settings.ini.bak (можеш да го върнеш с „Върни предишните“)."
    t["errReset"] := "Не успях да върна началните настройки:`n{1}"
    t["noBackup"] := "Няма запазено предишно копие (settings.ini.bak)."
    t["askRestore"] := "Да върна ли настройките от предишното копие (settings.ini.bak)?`n`nТекущите ще се запазят там (можеш да се върнеш обратно със същия бутон)."
    t["errRestore"] := "Не успях да върна предишните настройки:`n{1}"
    t["shortcutDesc"] := "Corsair Xeneon Edge widgets"
}

LoadLang_en(t) {
    t["defaultCity"] := "Sofia"
    t["chromeAppsFolder"] := "Chrome Apps"
    t["days"] := "Sunday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday"
    t["months"] := "January|February|March|April|May|June|July|August|September|October|November|December"
    t["dateFmt"] := "{1} {2} {3}"
    t["today"] := "today"
    t["tomorrow"] := "tomorrow"
    t["windFmt"] := " · wind {1} km/h"
    t["updating"] := "Updating…"
    t["wx_clear"] := "Clear"
    t["wx_mostly"] := "Mostly clear"
    t["wx_partly"] := "Partly cloudy"
    t["wx_cloudy"] := "Cloudy"
    t["wx_fog"] := "Fog"
    t["wx_drizzle"] := "Drizzle"
    t["wx_rain"] := "Rain"
    t["wx_snow"] := "Snow"
    t["wx_showers"] := "Showers"
    t["wx_snowshowers"] := "Snow showers"
    t["wx_thunder"] := "Thunderstorm"
    t["mRefresh"] := "Refresh forecast"
    t["mSettings"] := "Settings…"
    t["mOpenIni"] := "Open settings.ini"
    t["mResetDefaults"] := "Restore default settings"
    t["mReload"] := "Reload script"
    t["mExit"] := "Exit"
    t["msgTitle"] := "Settings"
    t["errIcons"] := "Weather icons not found:`n{1}`n`nPut the icons folder next to this file (or run the script from its own folder)."
    t["errFileNotFound"] := "File not found:"
    t["errLaunch"] := "Launch error:"
    t["iniMissing"] := "settings.ini not found:`n{1}`n`nPut it next to the script."
    t["tabGeneral"] := "General"
    t["tabWeather"] := "Weather"
    t["tabBar"] := "Bar"
    t["tabFolders"] := "Folders"
    t["tabApps"] := "Apps"
    t["lblDesign"] := "Design:"
    t["hintDesign"] := "classic = clock and forecast on the left, 2 rows of icons on the right.  wide = top row for time, date and forecast, the 10 icons in one row below."
    t["chkAuto"] := "Find the small monitor automatically (AutoDetectScreen)"
    t["lblX"] := "Position X (ManualX):"
    t["lblY"] := "Position Y (ManualY):"
    t["hintXY"] := "X and Y are used only when automatic detection is off (see the monitor position in Windows Display settings)."
    t["chkAutostart"] := "Start the script with Windows"
    t["hintAutostart"] := "Adds/removes a shortcut in the user’s Startup folder. If you use HWiNFO, start it with Windows too (for temperatures)."
    t["lblLanguage"] := "Language:"
    t["hintLanguage"] := "The language is applied after Save and reload."
    t["langAuto"] := "Auto (Windows)"
    t["lblCity"] := "City (label):"
    t["lblLat"] := "Latitude (Lat):"
    t["lblLon"] := "Longitude (Lon):"
    t["lblRefresh"] := "Refresh (minutes):"
    t["hintCoords"] := "Take the coordinates from a map (e.g. Google Maps: right-click the place). Decimal separator: dot."
    t["lblDrive1"] := "First drive (Drive1):"
    t["lblDrive2"] := "Second drive (Drive2):"
    t["chkStrict"] := "Strict filter for HWiNFO temperature labels (StrictTempLabels)"
    t["lblWheel"] := "Volume step (%):"
    t["hintBar"] := "Drive = letter and colon, e.g. C: or D:. The step is how many percent one wheel notch over VOL changes the volume (1-50)."
    t["lblIcons"] := "Launcher icons:"
    t["lblWeatherIcons"] := "Weather icons:"
    t["lblChromeApps"] := "Chrome apps (PWA):"
    t["btnBrowse"] := "Browse…"
    t["hintPaths"] := "Absolute path, path relative to the script folder (e.g. icons), or with %AppData%, %LocalAppData%."
    t["colIcon"] := "Icon (PNG)"
    t["colCmd"] := "What to launch (path, shell:AppsFolder\…, {ChromeApps}…)"
    t["colKw"] := "Title keyword"
    t["btnReset"] := "Default settings"
    t["btnRestore"] := "Restore previous"
    t["btnSave"] := "Save and reload"
    t["btnCancel"] := "Cancel"
    t["pickFolder"] := "Select folder"
    t["pickProgram"] := "Select a program or shortcut"
    t["pickFilter"] := "Programs and shortcuts (*.exe; *.lnk)"
    t["errXY"] := "ManualX and ManualY must be whole numbers."
    t["errLatLon"] := "Lat (up to 90) and Lon (up to 180) must be numbers, e.g. 42.6977 and 23.3219."
    t["errRefresh"] := "Refresh must be a whole number of minutes (1 or more)."
    t["errDrive"] := "A drive must be a letter and a colon, e.g. C: or D:"
    t["errWheel"] := "The volume step must be a number from 1 to 50."
    t["errAppRow"] := "Row {1} in Apps: fill in both the icon and what to launch (or clear both)."
    t["errReadIni"] := "Cannot read/copy settings.ini:`n{1}"
    t["errWriteIni"] := "Cannot write settings.ini:`n{1}"
    t["errAutostart"] := "Could not change start with Windows:`n{1}"
    t["askReset"] := "Restore all settings to the defaults?`n`nThe current settings.ini is kept as settings.ini.bak (you can bring it back with Restore previous)."
    t["errReset"] := "Could not restore the default settings:`n{1}"
    t["noBackup"] := "There is no saved previous copy (settings.ini.bak)."
    t["askRestore"] := "Restore the settings from the previous copy (settings.ini.bak)?`n`nThe current ones are kept there (you can switch back with the same button)."
    t["errRestore"] := "Could not restore the previous settings:`n{1}"
    t["shortcutDesc"] := "Corsair Xeneon Edge widgets"
}

LoadLang_ru(t) {
    t["defaultCity"] := "София"
    t["chromeAppsFolder"] := "Приложения Chrome"
    t["days"] := "вс|пн|вт|ср|чт|пт|сб"
    t["months"] := "января|февраля|марта|апреля|мая|июня|июля|августа|сентября|октября|ноября|декабря"
    t["dateFmt"] := "{1} {2} {3}"
    t["today"] := "сегодня"
    t["tomorrow"] := "завтра"
    t["windFmt"] := " · ветер {1} км/ч"
    t["updating"] := "Обновление…"
    t["wx_clear"] := "Ясно"
    t["wx_mostly"] := "Малооблачно"
    t["wx_partly"] := "Переменно"
    t["wx_cloudy"] := "Облачно"
    t["wx_fog"] := "Туман"
    t["wx_drizzle"] := "Морось"
    t["wx_rain"] := "Дождь"
    t["wx_snow"] := "Снег"
    t["wx_showers"] := "Ливни"
    t["wx_snowshowers"] := "Снегопад"
    t["wx_thunder"] := "Гроза"
    t["mRefresh"] := "Обновить прогноз"
    t["mSettings"] := "Настройки…"
    t["mOpenIni"] := "Открыть settings.ini"
    t["mResetDefaults"] := "Вернуть настройки по умолчанию"
    t["mReload"] := "Перезагрузить скрипт"
    t["mExit"] := "Выход"
    t["msgTitle"] := "Настройки"
    t["errIcons"] := "Не найдены значки погоды:`n{1}`n`nПоместите папку icons рядом с этим файлом (или запускайте скрипт из его папки)."
    t["errFileNotFound"] := "Файл не найден:"
    t["errLaunch"] := "Ошибка запуска:"
    t["iniMissing"] := "Файл settings.ini не найден:`n{1}`n`nПоместите его рядом со скриптом."
    t["tabGeneral"] := "Общие"
    t["tabWeather"] := "Погода"
    t["tabBar"] := "Панель"
    t["tabFolders"] := "Папки"
    t["tabApps"] := "Приложения"
    t["lblDesign"] := "Дизайн:"
    t["hintDesign"] := "classic = часы и прогноз слева, 2 ряда значков справа.  wide = верхний ряд для времени, даты и прогноза, ниже 10 значков в один ряд."
    t["chkAuto"] := "Находить маленький монитор автоматически (AutoDetectScreen)"
    t["lblX"] := "Позиция X (ManualX):"
    t["lblY"] := "Позиция Y (ManualY):"
    t["hintXY"] := "X и Y используются только при выключенном автоопределении (положение монитора смотрите в параметрах дисплея Windows)."
    t["chkAutostart"] := "Запускать скрипт вместе с Windows"
    t["hintAutostart"] := "Добавляет/удаляет ярлык в папке «Автозагрузка» пользователя. Если вы используете HWiNFO, запускайте и его с Windows (для температур)."
    t["lblLanguage"] := "Язык:"
    t["hintLanguage"] := "Язык применяется после «Сохранить и перезагрузить»."
    t["langAuto"] := "Авто (Windows)"
    t["lblCity"] := "Город (подпись):"
    t["lblLat"] := "Широта (Lat):"
    t["lblLon"] := "Долгота (Lon):"
    t["lblRefresh"] := "Обновление (мин.):"
    t["hintCoords"] := "Координаты берутся с карты (например Google Maps: правый клик по месту). Десятичный разделитель: точка."
    t["lblDrive1"] := "Первый диск (Drive1):"
    t["lblDrive2"] := "Второй диск (Drive2):"
    t["chkStrict"] := "Строгий фильтр меток температуры HWiNFO (StrictTempLabels)"
    t["lblWheel"] := "Шаг громкости (%):"
    t["hintBar"] := "Диск = буква и двоеточие, напр. C: или D:. Шаг — на сколько процентов меняется громкость за одно деление колёсика над VOL (1-50)."
    t["lblIcons"] := "Значки лаунчера:"
    t["lblWeatherIcons"] := "Значки погоды:"
    t["lblChromeApps"] := "Приложения Chrome (PWA):"
    t["btnBrowse"] := "Выбрать…"
    t["hintPaths"] := "Абсолютный путь, путь относительно папки скрипта (напр. icons) или с %AppData%, %LocalAppData%."
    t["colIcon"] := "Значок (PNG)"
    t["colCmd"] := "Что запускать (путь, shell:AppsFolder\…, {ChromeApps}…)"
    t["colKw"] := "Слово в заголовке"
    t["btnReset"] := "По умолчанию"
    t["btnRestore"] := "Вернуть прежние"
    t["btnSave"] := "Сохранить и перезагрузить"
    t["btnCancel"] := "Отмена"
    t["pickFolder"] := "Выберите папку"
    t["pickProgram"] := "Выберите программу или ярлык"
    t["pickFilter"] := "Программы и ярлыки (*.exe; *.lnk)"
    t["errXY"] := "ManualX и ManualY должны быть целыми числами."
    t["errLatLon"] := "Lat (до 90) и Lon (до 180) должны быть числами, напр. 42.6977 и 23.3219."
    t["errRefresh"] := "Обновление — целое число минут (1 или больше)."
    t["errDrive"] := "Диск — это буква и двоеточие, напр. C: или D:"
    t["errWheel"] := "Шаг громкости — число от 1 до 50."
    t["errAppRow"] := "Строка {1} во вкладке «Приложения»: заполните и значок, и команду запуска (или очистите обе)."
    t["errReadIni"] := "Не удаётся прочитать/скопировать settings.ini:`n{1}"
    t["errWriteIni"] := "Не удаётся записать settings.ini:`n{1}"
    t["errAutostart"] := "Не удалось изменить автозапуск с Windows:`n{1}"
    t["askReset"] := "Вернуть все настройки по умолчанию?`n`nТекущий settings.ini сохранится как settings.ini.bak (его можно вернуть кнопкой «Вернуть прежние»)."
    t["errReset"] := "Не удалось вернуть настройки по умолчанию:`n{1}"
    t["noBackup"] := "Нет сохранённой предыдущей копии (settings.ini.bak)."
    t["askRestore"] := "Вернуть настройки из предыдущей копии (settings.ini.bak)?`n`nТекущие сохранятся там (вернуться обратно можно той же кнопкой)."
    t["errRestore"] := "Не удалось вернуть прежние настройки:`n{1}"
    t["shortcutDesc"] := "Corsair Xeneon Edge widgets"
}

LoadLang_fr(t) {
    t["defaultCity"] := "Sofia"
    t["chromeAppsFolder"] := "Applications Chrome"
    t["days"] := "dimanche|lundi|mardi|mercredi|jeudi|vendredi|samedi"
    t["months"] := "janvier|février|mars|avril|mai|juin|juillet|août|septembre|octobre|novembre|décembre"
    t["dateFmt"] := "{1} {2} {3}"
    t["today"] := "aujourd'hui"
    t["tomorrow"] := "demain"
    t["windFmt"] := " · vent {1} km/h"
    t["updating"] := "Actualisation…"
    t["wx_clear"] := "Dégagé"
    t["wx_mostly"] := "Peu nuageux"
    t["wx_partly"] := "Éclaircies"
    t["wx_cloudy"] := "Couvert"
    t["wx_fog"] := "Brouillard"
    t["wx_drizzle"] := "Bruine"
    t["wx_rain"] := "Pluie"
    t["wx_snow"] := "Neige"
    t["wx_showers"] := "Averses"
    t["wx_snowshowers"] := "Averses de neige"
    t["wx_thunder"] := "Orages"
    t["mRefresh"] := "Actualiser les prévisions"
    t["mSettings"] := "Paramètres…"
    t["mOpenIni"] := "Ouvrir settings.ini"
    t["mResetDefaults"] := "Restaurer les paramètres par défaut"
    t["mReload"] := "Recharger le script"
    t["mExit"] := "Quitter"
    t["msgTitle"] := "Paramètres"
    t["errIcons"] := "Icônes météo introuvables :`n{1}`n`nPlacez le dossier icons à côté de ce fichier (ou lancez le script depuis son dossier)."
    t["errFileNotFound"] := "Fichier introuvable :"
    t["errLaunch"] := "Erreur de lancement :"
    t["iniMissing"] := "settings.ini introuvable :`n{1}`n`nPlacez-le à côté du script."
    t["tabGeneral"] := "Général"
    t["tabWeather"] := "Météo"
    t["tabBar"] := "Barre"
    t["tabFolders"] := "Dossiers"
    t["tabApps"] := "Applications"
    t["lblDesign"] := "Design :"
    t["hintDesign"] := "classic = horloge et prévisions à gauche, 2 rangées d’icônes à droite.  wide = rangée du haut pour l’heure, la date et les prévisions, les 10 icônes sur une rangée en dessous."
    t["chkAuto"] := "Détecter automatiquement le petit écran (AutoDetectScreen)"
    t["lblX"] := "Position X (ManualX) :"
    t["lblY"] := "Position Y (ManualY) :"
    t["hintXY"] := "X et Y ne sont utilisés que si la détection automatique est désactivée (voir la position de l’écran dans les paramètres d’affichage de Windows)."
    t["chkAutostart"] := "Lancer le script avec Windows"
    t["hintAutostart"] := "Ajoute/supprime un raccourci dans le dossier Démarrage de l’utilisateur. Si vous utilisez HWiNFO, lancez-le aussi avec Windows (pour les températures)."
    t["lblLanguage"] := "Langue :"
    t["hintLanguage"] := "La langue est appliquée après « Enregistrer et recharger »."
    t["langAuto"] := "Auto (Windows)"
    t["lblCity"] := "Ville (libellé) :"
    t["lblLat"] := "Latitude (Lat) :"
    t["lblLon"] := "Longitude (Lon) :"
    t["lblRefresh"] := "Actualisation (min) :"
    t["hintCoords"] := "Prenez les coordonnées sur une carte (p. ex. Google Maps : clic droit sur le lieu). Séparateur décimal : point."
    t["lblDrive1"] := "Premier disque (Drive1) :"
    t["lblDrive2"] := "Second disque (Drive2) :"
    t["chkStrict"] := "Filtre strict des libellés de température HWiNFO (StrictTempLabels)"
    t["lblWheel"] := "Pas du volume (%) :"
    t["hintBar"] := "Disque = lettre et deux-points, p. ex. C: ou D:. Le pas indique de combien de pour cent un cran de molette sur VOL change le volume (1-50)."
    t["lblIcons"] := "Icônes du lanceur :"
    t["lblWeatherIcons"] := "Icônes météo :"
    t["lblChromeApps"] := "Applications Chrome (PWA) :"
    t["btnBrowse"] := "Parcourir…"
    t["hintPaths"] := "Chemin absolu, chemin relatif au dossier du script (p. ex. icons) ou avec %AppData%, %LocalAppData%."
    t["colIcon"] := "Icône (PNG)"
    t["colCmd"] := "Que lancer (chemin, shell:AppsFolder\…, {ChromeApps}…)"
    t["colKw"] := "Mot du titre"
    t["btnReset"] := "Par défaut"
    t["btnRestore"] := "Restaurer précédents"
    t["btnSave"] := "Enregistrer et recharger"
    t["btnCancel"] := "Annuler"
    t["pickFolder"] := "Choisir un dossier"
    t["pickProgram"] := "Choisir un programme ou un raccourci"
    t["pickFilter"] := "Programmes et raccourcis (*.exe; *.lnk)"
    t["errXY"] := "ManualX et ManualY doivent être des nombres entiers."
    t["errLatLon"] := "Lat (max 90) et Lon (max 180) doivent être des nombres, p. ex. 42.6977 et 23.3219."
    t["errRefresh"] := "L’actualisation doit être un nombre entier de minutes (1 ou plus)."
    t["errDrive"] := "Un disque doit être une lettre suivie de deux-points, p. ex. C: ou D:"
    t["errWheel"] := "Le pas du volume doit être un nombre de 1 à 50."
    t["errAppRow"] := "Ligne {1} dans Applications : renseignez l’icône et la commande (ou videz les deux)."
    t["errReadIni"] := "Impossible de lire/copier settings.ini :`n{1}"
    t["errWriteIni"] := "Impossible d’écrire settings.ini :`n{1}"
    t["errAutostart"] := "Impossible de modifier le démarrage avec Windows :`n{1}"
    t["askReset"] := "Restaurer tous les paramètres par défaut ?`n`nLe settings.ini actuel est conservé sous settings.ini.bak (vous pouvez le récupérer avec « Restaurer précédents »)."
    t["errReset"] := "Impossible de restaurer les paramètres par défaut :`n{1}"
    t["noBackup"] := "Aucune copie précédente (settings.ini.bak)."
    t["askRestore"] := "Restaurer les paramètres depuis la copie précédente (settings.ini.bak) ?`n`nLes paramètres actuels y sont conservés (vous pouvez revenir avec le même bouton)."
    t["errRestore"] := "Impossible de restaurer les paramètres précédents :`n{1}"
    t["shortcutDesc"] := "Corsair Xeneon Edge widgets"
}

LoadLang_es(t) {
    t["defaultCity"] := "Sofía"
    t["chromeAppsFolder"] := "Aplicaciones de Chrome"
    t["days"] := "domingo|lunes|martes|miércoles|jueves|viernes|sábado"
    t["months"] := "enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre"
    t["dateFmt"] := "{1} {2} {3}"
    t["today"] := "hoy"
    t["tomorrow"] := "mañana"
    t["windFmt"] := " · viento {1} km/h"
    t["updating"] := "Actualizando…"
    t["wx_clear"] := "Despejado"
    t["wx_mostly"] := "Poco nuboso"
    t["wx_partly"] := "Nubes y claros"
    t["wx_cloudy"] := "Nublado"
    t["wx_fog"] := "Niebla"
    t["wx_drizzle"] := "Llovizna"
    t["wx_rain"] := "Lluvia"
    t["wx_snow"] := "Nieve"
    t["wx_showers"] := "Chubascos"
    t["wx_snowshowers"] := "Nevadas"
    t["wx_thunder"] := "Tormenta"
    t["mRefresh"] := "Actualizar pronóstico"
    t["mSettings"] := "Ajustes…"
    t["mOpenIni"] := "Abrir settings.ini"
    t["mResetDefaults"] := "Restaurar ajustes predeterminados"
    t["mReload"] := "Recargar script"
    t["mExit"] := "Salir"
    t["msgTitle"] := "Ajustes"
    t["errIcons"] := "No se encuentran los iconos del tiempo:`n{1}`n`nColoca la carpeta icons junto a este archivo (o ejecuta el script desde su carpeta)."
    t["errFileNotFound"] := "Archivo no encontrado:"
    t["errLaunch"] := "Error al iniciar:"
    t["iniMissing"] := "No se encuentra settings.ini:`n{1}`n`nColócalo junto al script."
    t["tabGeneral"] := "General"
    t["tabWeather"] := "Tiempo"
    t["tabBar"] := "Barra"
    t["tabFolders"] := "Carpetas"
    t["tabApps"] := "Aplicaciones"
    t["lblDesign"] := "Diseño:"
    t["hintDesign"] := "classic = reloj y pronóstico a la izquierda, 2 filas de iconos a la derecha.  wide = fila superior para hora, fecha y pronóstico, los 10 iconos en una fila debajo."
    t["chkAuto"] := "Detectar el monitor pequeño automáticamente (AutoDetectScreen)"
    t["lblX"] := "Posición X (ManualX):"
    t["lblY"] := "Posición Y (ManualY):"
    t["hintXY"] := "X e Y solo se usan si la detección automática está desactivada (consulta la posición del monitor en la configuración de pantalla de Windows)."
    t["chkAutostart"] := "Iniciar el script con Windows"
    t["hintAutostart"] := "Añade/quita un acceso directo en la carpeta Inicio del usuario. Si usas HWiNFO, inícialo también con Windows (para las temperaturas)."
    t["lblLanguage"] := "Idioma:"
    t["hintLanguage"] := "El idioma se aplica tras «Guardar y recargar»."
    t["langAuto"] := "Auto (Windows)"
    t["lblCity"] := "Ciudad (texto):"
    t["lblLat"] := "Latitud (Lat):"
    t["lblLon"] := "Longitud (Lon):"
    t["lblRefresh"] := "Actualizar (minutos):"
    t["hintCoords"] := "Toma las coordenadas de un mapa (p. ej. Google Maps: clic derecho en el lugar). Separador decimal: punto."
    t["lblDrive1"] := "Primera unidad (Drive1):"
    t["lblDrive2"] := "Segunda unidad (Drive2):"
    t["chkStrict"] := "Filtro estricto de etiquetas de temperatura de HWiNFO (StrictTempLabels)"
    t["lblWheel"] := "Paso de volumen (%):"
    t["hintBar"] := "Unidad = letra y dos puntos, p. ej. C: o D:. El paso indica cuántos puntos porcentuales cambia cada muesca de la rueda sobre VOL (1-50)."
    t["lblIcons"] := "Iconos del lanzador:"
    t["lblWeatherIcons"] := "Iconos del tiempo:"
    t["lblChromeApps"] := "Aplicaciones de Chrome (PWA):"
    t["btnBrowse"] := "Examinar…"
    t["hintPaths"] := "Ruta absoluta, ruta relativa a la carpeta del script (p. ej. icons) o con %AppData%, %LocalAppData%."
    t["colIcon"] := "Icono (PNG)"
    t["colCmd"] := "Qué iniciar (ruta, shell:AppsFolder\…, {ChromeApps}…)"
    t["colKw"] := "Palabra del título"
    t["btnReset"] := "Predeterminados"
    t["btnRestore"] := "Restaurar anteriores"
    t["btnSave"] := "Guardar y recargar"
    t["btnCancel"] := "Cancelar"
    t["pickFolder"] := "Seleccionar carpeta"
    t["pickProgram"] := "Selecciona un programa o acceso directo"
    t["pickFilter"] := "Programas y accesos directos (*.exe; *.lnk)"
    t["errXY"] := "ManualX y ManualY deben ser números enteros."
    t["errLatLon"] := "Lat (hasta 90) y Lon (hasta 180) deben ser números, p. ej. 42.6977 y 23.3219."
    t["errRefresh"] := "La actualización debe ser un número entero de minutos (1 o más)."
    t["errDrive"] := "Una unidad debe ser una letra y dos puntos, p. ej. C: o D:"
    t["errWheel"] := "El paso de volumen debe ser un número de 1 a 50."
    t["errAppRow"] := "Fila {1} en Aplicaciones: rellena el icono y qué iniciar (o borra ambos)."
    t["errReadIni"] := "No se puede leer/copiar settings.ini:`n{1}"
    t["errWriteIni"] := "No se puede escribir settings.ini:`n{1}"
    t["errAutostart"] := "No se pudo cambiar el inicio con Windows:`n{1}"
    t["askReset"] := "¿Restaurar todos los ajustes a los predeterminados?`n`nEl settings.ini actual se guarda como settings.ini.bak (puedes recuperarlo con «Restaurar anteriores»)."
    t["errReset"] := "No se pudieron restaurar los ajustes predeterminados:`n{1}"
    t["noBackup"] := "No hay copia anterior guardada (settings.ini.bak)."
    t["askRestore"] := "¿Restaurar los ajustes de la copia anterior (settings.ini.bak)?`n`nLos actuales se guardan allí (puedes volver con el mismo botón)."
    t["errRestore"] := "No se pudieron restaurar los ajustes anteriores:`n{1}"
    t["shortcutDesc"] := "Corsair Xeneon Edge widgets"
}

LoadLang_it(t) {
    t["defaultCity"] := "Sofia"
    t["chromeAppsFolder"] := "App di Chrome"
    t["days"] := "domenica|lunedì|martedì|mercoledì|giovedì|venerdì|sabato"
    t["months"] := "gennaio|febbraio|marzo|aprile|maggio|giugno|luglio|agosto|settembre|ottobre|novembre|dicembre"
    t["dateFmt"] := "{1} {2} {3}"
    t["today"] := "oggi"
    t["tomorrow"] := "domani"
    t["windFmt"] := " · vento {1} km/h"
    t["updating"] := "Aggiornamento…"
    t["wx_clear"] := "Sereno"
    t["wx_mostly"] := "Poco nuvoloso"
    t["wx_partly"] := "Variabile"
    t["wx_cloudy"] := "Coperto"
    t["wx_fog"] := "Nebbia"
    t["wx_drizzle"] := "Pioggerella"
    t["wx_rain"] := "Pioggia"
    t["wx_snow"] := "Neve"
    t["wx_showers"] := "Rovesci"
    t["wx_snowshowers"] := "Rovesci di neve"
    t["wx_thunder"] := "Temporale"
    t["mRefresh"] := "Aggiorna previsioni"
    t["mSettings"] := "Impostazioni…"
    t["mOpenIni"] := "Apri settings.ini"
    t["mResetDefaults"] := "Ripristina impostazioni predefinite"
    t["mReload"] := "Ricarica script"
    t["mExit"] := "Esci"
    t["msgTitle"] := "Impostazioni"
    t["errIcons"] := "Icone meteo non trovate:`n{1}`n`nMetti la cartella icons accanto a questo file (o avvia lo script dalla sua cartella)."
    t["errFileNotFound"] := "File non trovato:"
    t["errLaunch"] := "Errore di avvio:"
    t["iniMissing"] := "settings.ini non trovato:`n{1}`n`nMettilo accanto allo script."
    t["tabGeneral"] := "Generale"
    t["tabWeather"] := "Meteo"
    t["tabBar"] := "Barra"
    t["tabFolders"] := "Cartelle"
    t["tabApps"] := "App"
    t["lblDesign"] := "Design:"
    t["hintDesign"] := "classic = orologio e previsioni a sinistra, 2 righe di icone a destra.  wide = riga superiore per ora, data e previsioni, le 10 icone in una riga sotto."
    t["chkAuto"] := "Rileva automaticamente il monitor piccolo (AutoDetectScreen)"
    t["lblX"] := "Posizione X (ManualX):"
    t["lblY"] := "Posizione Y (ManualY):"
    t["hintXY"] := "X e Y vengono usati solo se il rilevamento automatico è disattivato (vedi la posizione del monitor nelle impostazioni dello schermo di Windows)."
    t["chkAutostart"] := "Avvia lo script con Windows"
    t["hintAutostart"] := "Aggiunge/rimuove un collegamento nella cartella Esecuzione automatica dell’utente. Se usi HWiNFO, avvialo anche con Windows (per le temperature)."
    t["lblLanguage"] := "Lingua:"
    t["hintLanguage"] := "La lingua viene applicata dopo «Salva e ricarica»."
    t["langAuto"] := "Auto (Windows)"
    t["lblCity"] := "Città (testo):"
    t["lblLat"] := "Latitudine (Lat):"
    t["lblLon"] := "Longitudine (Lon):"
    t["lblRefresh"] := "Aggiornamento (minuti):"
    t["hintCoords"] := "Prendi le coordinate da una mappa (ad es. Google Maps: clic destro sul luogo). Separatore decimale: punto."
    t["lblDrive1"] := "Primo disco (Drive1):"
    t["lblDrive2"] := "Secondo disco (Drive2):"
    t["chkStrict"] := "Filtro rigoroso delle etichette di temperatura HWiNFO (StrictTempLabels)"
    t["lblWheel"] := "Passo volume (%):"
    t["hintBar"] := "Disco = lettera e due punti, ad es. C: o D:. Il passo indica di quanti punti percentuali cambia il volume a ogni scatto della rotellina su VOL (1-50)."
    t["lblIcons"] := "Icone del launcher:"
    t["lblWeatherIcons"] := "Icone meteo:"
    t["lblChromeApps"] := "App di Chrome (PWA):"
    t["btnBrowse"] := "Sfoglia…"
    t["hintPaths"] := "Percorso assoluto, relativo alla cartella dello script (ad es. icons) o con %AppData%, %LocalAppData%."
    t["colIcon"] := "Icona (PNG)"
    t["colCmd"] := "Cosa avviare (percorso, shell:AppsFolder\…, {ChromeApps}…)"
    t["colKw"] := "Parola nel titolo"
    t["btnReset"] := "Predefinite"
    t["btnRestore"] := "Ripristina precedenti"
    t["btnSave"] := "Salva e ricarica"
    t["btnCancel"] := "Annulla"
    t["pickFolder"] := "Seleziona cartella"
    t["pickProgram"] := "Seleziona un programma o collegamento"
    t["pickFilter"] := "Programmi e collegamenti (*.exe; *.lnk)"
    t["errXY"] := "ManualX e ManualY devono essere numeri interi."
    t["errLatLon"] := "Lat (max 90) e Lon (max 180) devono essere numeri, ad es. 42.6977 e 23.3219."
    t["errRefresh"] := "L’aggiornamento deve essere un numero intero di minuti (1 o più)."
    t["errDrive"] := "Un disco deve essere una lettera e i due punti, ad es. C: o D:"
    t["errWheel"] := "Il passo del volume deve essere un numero da 1 a 50."
    t["errAppRow"] := "Riga {1} in App: compila sia l’icona sia cosa avviare (o svuota entrambi)."
    t["errReadIni"] := "Impossibile leggere/copiare settings.ini:`n{1}"
    t["errWriteIni"] := "Impossibile scrivere settings.ini:`n{1}"
    t["errAutostart"] := "Impossibile modificare l’avvio con Windows:`n{1}"
    t["askReset"] := "Ripristinare tutte le impostazioni predefinite?`n`nL’attuale settings.ini viene conservato come settings.ini.bak (puoi recuperarlo con «Ripristina precedenti»)."
    t["errReset"] := "Impossibile ripristinare le impostazioni predefinite:`n{1}"
    t["noBackup"] := "Nessuna copia precedente salvata (settings.ini.bak)."
    t["askRestore"] := "Ripristinare le impostazioni dalla copia precedente (settings.ini.bak)?`n`nQuelle attuali vengono conservate lì (puoi tornare indietro con lo stesso pulsante)."
    t["errRestore"] := "Impossibile ripristinare le impostazioni precedenti:`n{1}"
    t["shortcutDesc"] := "Corsair Xeneon Edge widgets"
}

LoadLang_pt(t) {
    t["defaultCity"] := "Sófia"
    t["chromeAppsFolder"] := "Aplicações do Chrome"
    t["days"] := "domingo|segunda|terça|quarta|quinta|sexta|sábado"
    t["months"] := "janeiro|fevereiro|março|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro"
    t["dateFmt"] := "{1} {2} {3}"
    t["today"] := "hoje"
    t["tomorrow"] := "amanhã"
    t["windFmt"] := " · vento {1} km/h"
    t["updating"] := "A atualizar…"
    t["wx_clear"] := "Limpo"
    t["wx_mostly"] := "Pouco nublado"
    t["wx_partly"] := "Variável"
    t["wx_cloudy"] := "Nublado"
    t["wx_fog"] := "Nevoeiro"
    t["wx_drizzle"] := "Chuvisco"
    t["wx_rain"] := "Chuva"
    t["wx_snow"] := "Neve"
    t["wx_showers"] := "Aguaceiros"
    t["wx_snowshowers"] := "Aguaceiros de neve"
    t["wx_thunder"] := "Trovoada"
    t["mRefresh"] := "Atualizar previsão"
    t["mSettings"] := "Definições…"
    t["mOpenIni"] := "Abrir settings.ini"
    t["mResetDefaults"] := "Repor definições predefinidas"
    t["mReload"] := "Recarregar script"
    t["mExit"] := "Sair"
    t["msgTitle"] := "Definições"
    t["errIcons"] := "Ícones do tempo não encontrados:`n{1}`n`nColoque a pasta icons junto a este ficheiro (ou execute o script a partir da sua pasta)."
    t["errFileNotFound"] := "Ficheiro não encontrado:"
    t["errLaunch"] := "Erro ao iniciar:"
    t["iniMissing"] := "settings.ini não encontrado:`n{1}`n`nColoque-o junto ao script."
    t["tabGeneral"] := "Geral"
    t["tabWeather"] := "Tempo"
    t["tabBar"] := "Barra"
    t["tabFolders"] := "Pastas"
    t["tabApps"] := "Aplicações"
    t["lblDesign"] := "Design:"
    t["hintDesign"] := "classic = relógio e previsão à esquerda, 2 filas de ícones à direita.  wide = fila superior para hora, data e previsão, os 10 ícones numa fila por baixo."
    t["chkAuto"] := "Detetar automaticamente o monitor pequeno (AutoDetectScreen)"
    t["lblX"] := "Posição X (ManualX):"
    t["lblY"] := "Posição Y (ManualY):"
    t["hintXY"] := "X e Y só são usados quando a deteção automática está desligada (veja a posição do monitor nas definições de ecrã do Windows)."
    t["chkAutostart"] := "Iniciar o script com o Windows"
    t["hintAutostart"] := "Adiciona/remove um atalho na pasta Arranque do utilizador. Se usa o HWiNFO, inicie-o também com o Windows (para as temperaturas)."
    t["lblLanguage"] := "Idioma:"
    t["hintLanguage"] := "O idioma é aplicado após «Guardar e recarregar»."
    t["langAuto"] := "Auto (Windows)"
    t["lblCity"] := "Cidade (texto):"
    t["lblLat"] := "Latitude (Lat):"
    t["lblLon"] := "Longitude (Lon):"
    t["lblRefresh"] := "Atualizar (minutos):"
    t["hintCoords"] := "Obtenha as coordenadas de um mapa (p. ex. Google Maps: clique direito no local). Separador decimal: ponto."
    t["lblDrive1"] := "Primeira unidade (Drive1):"
    t["lblDrive2"] := "Segunda unidade (Drive2):"
    t["chkStrict"] := "Filtro rigoroso das etiquetas de temperatura do HWiNFO (StrictTempLabels)"
    t["lblWheel"] := "Passo do volume (%):"
    t["hintBar"] := "Unidade = letra e dois pontos, p. ex. C: ou D:. O passo indica quantos por cento muda o volume a cada entalhe da roda sobre VOL (1-50)."
    t["lblIcons"] := "Ícones do lançador:"
    t["lblWeatherIcons"] := "Ícones do tempo:"
    t["lblChromeApps"] := "Aplicações do Chrome (PWA):"
    t["btnBrowse"] := "Procurar…"
    t["hintPaths"] := "Caminho absoluto, relativo à pasta do script (p. ex. icons) ou com %AppData%, %LocalAppData%."
    t["colIcon"] := "Ícone (PNG)"
    t["colCmd"] := "O que iniciar (caminho, shell:AppsFolder\…, {ChromeApps}…)"
    t["colKw"] := "Palavra no título"
    t["btnReset"] := "Predefinições"
    t["btnRestore"] := "Repor anteriores"
    t["btnSave"] := "Guardar e recarregar"
    t["btnCancel"] := "Cancelar"
    t["pickFolder"] := "Selecionar pasta"
    t["pickProgram"] := "Selecione um programa ou atalho"
    t["pickFilter"] := "Programas e atalhos (*.exe; *.lnk)"
    t["errXY"] := "ManualX e ManualY devem ser números inteiros."
    t["errLatLon"] := "Lat (até 90) e Lon (até 180) devem ser números, p. ex. 42.6977 e 23.3219."
    t["errRefresh"] := "A atualização deve ser um número inteiro de minutos (1 ou mais)."
    t["errDrive"] := "Uma unidade deve ser uma letra e dois pontos, p. ex. C: ou D:"
    t["errWheel"] := "O passo do volume deve ser um número de 1 a 50."
    t["errAppRow"] := "Linha {1} em Aplicações: preencha o ícone e o que iniciar (ou limpe ambos)."
    t["errReadIni"] := "Não é possível ler/copiar settings.ini:`n{1}"
    t["errWriteIni"] := "Não é possível escrever settings.ini:`n{1}"
    t["errAutostart"] := "Não foi possível alterar o arranque com o Windows:`n{1}"
    t["askReset"] := "Repor todas as definições para as predefinidas?`n`nO settings.ini atual é guardado como settings.ini.bak (pode recuperá-lo com «Repor anteriores»)."
    t["errReset"] := "Não foi possível repor as definições predefinidas:`n{1}"
    t["noBackup"] := "Não existe cópia anterior guardada (settings.ini.bak)."
    t["askRestore"] := "Repor as definições da cópia anterior (settings.ini.bak)?`n`nAs atuais ficam guardadas lá (pode voltar com o mesmo botão)."
    t["errRestore"] := "Não foi possível repor as definições anteriores:`n{1}"
    t["shortcutDesc"] := "Corsair Xeneon Edge widgets"
}
