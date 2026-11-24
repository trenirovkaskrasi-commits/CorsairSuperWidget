#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SetTitleMatchMode 2
CoordMode "Mouse", "Screen"

; Промени спрямо работещата версия (дизайнът и разположението не са пипани):
;  1. Прогнозата се опитва пак след 1 минута, ако заявката не успее (напр. мрежата още не е готова).
;  2. По-кратки времена за изчакване на заявката за времето (по-малко замръзване при лоша мрежа).
;  3. Бутонът в лаунчера не остава заключен, ако стартирането на приложението хвърли грешка.
;  4. Дисковете се обновяват на 30 секунди вместо на всяка секунда.
;  5. Температурите пропускат HWiNFO етикети за мощност, натоварване, честота, вентилатор и т.н.
;     (изключва се с strictTempLabels := false).
;  6. Звукът: без бутони - и +, показва "VOL 20%", сила само с колелцето на мишката, клик спира/пуска звука.
;     Индикаторите и плочката са подредени на равни разстояния; шрифтът остава 39 и се смалява само ако не се събира.
;  7. Двоен клик върху текущата температура (градусите) обновява прогнозата веднага.
;  8. Ако липсва папката icons до скрипта, излиза едно ясно съобщение вместо верига от грешки.
;  9. Настройките (координати, град, папки, приложения, дискове, стъпка на звука) са в settings.ini до скрипта.
;     Ако settings.ini липсва или някой ред е грешен, се ползват стойностите по подразбиране от този файл.
;     Прозорец за настройки: десен клик на иконата в трея (или на START) -> "Настройки…" (записва в settings.ini).
;     След ръчна промяна в settings.ini: десен клик на иконата в трея -> "Презареди скрипта".
; 10. Design=wide в settings.ini: целият горен ред е за часа, датата, времето и 5-дневната прогноза,
;     под него са 10-те икони в един ред (по 240 px), най-долу е непроменената лента. Design=classic = както досега.

; ================= ОБЩИ НАСТРОЙКИ =================
settingsFile := A_ScriptDir "\settings.ini"
iniData := LoadSettings(settingsFile)
settingsGui := ""                   ; прозорецът за настройки (когато е отворен)
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
City := Cfg("Weather", "City", "София")
WeatherEveryMin := Max(1, CfgInt("Weather", "RefreshMinutes", 30))   ; на колко минути да обновява прогнозата
WeatherPosX := screenX + 10
WeatherPosY := screenY + 0
WeatherIconDir := ResolveDir(Cfg("Paths", "WeatherIcons", "icons"))
if !FileExist(WeatherIconDir "07.png") {
    ; без иконите всичко останало дава верига от грешки - затова спираме с едно ясно съобщение
    MsgBox("Не намирам иконите на времето:`n" WeatherIconDir "07.png`n`nСложи папката icons до този файл (или стартирай скрипта от работната му папка).", "CorsairSuperWidget", "Icon!")
    ExitApp
}

; Разположение на прогнозата за 5 дни (classic: под часа; wide: в десния край на горния ред)
; wide: 6 дни, колоните са точно над последните 6 икони на лаунчера (стъпка 254, център на 5-ата икона = 1153)
fcDays := wide ? 6 : 5
fcX0 := wide ? 1032 : 10, fcStepX := wide ? 254 : 222
; ширини на кутиите: в wide са стеснени, за да не се застъпват (застъпената част се реже от кутията отгоре)
clockW := wide ? 520 : 580, dateW := wide ? 500 : 570
; Текущо време (размери в px; classic = както досега, wide = с ~15% по-голяма икона и шрифтове)
curIconX := wide ? 535 : 600,  curIconY := wide ? 0 : 2,    curIconW := wide ? 235 : 204, curIconH := wide ? 196 : 170
curTempX := wide ? 772 : 822,  curTempY := wide ? -8 : -5,  curTempW := wide ? 330 : 318, curTempH := wide ? 230 : 200, curTempFont := wide ? 172 : 150
curDescX := wide ? 535 : 610,  curDescY := wide ? 196 : 172, curDescW := wide ? 500 : 530, curDescH := wide ? 66 : 60, curDescFont := wide ? 50 : 44
curWindY := wide ? 258 : 228,  curWindH := wide ? 52 : 50,  curWindFont := wide ? 38 : 34
; Прогноза по дни: малко по-едри шрифтове и в двата дизайна (дни 34 -> 40, градуси 40 -> 46)
fcDayFont := 40, fcTempFont := 46, fcDayH := 58, fcTempH := 66
fcDayY := wide ? 22 : 290, fcIconY := wide ? 80 : 348, fcTempY := wide ? 250 : 519
wideTopH := 330                     ; височина на горния ред в wide

Days := ["неделя", "понеделник", "вторник", "сряда", "четвъртък", "петък", "събота"]
Months := ["януари", "февруари", "март", "април", "май", "юни", "юли", "август", "септември", "октомври", "ноември", "декември"]
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
chromeAppsDir := ResolveDir(Cfg("Paths", "ChromeApps", "%AppData%\Microsoft\Windows\Start Menu\Programs\Приложения в Chrome"))

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

g.SetFont("s" Pt(190) " w700 cFFFFFF", "Segoe UI")
ctlTime := g.Add("Text", "x" U(20) " y" U(-40) " w" U(clockW) " h" U(250), "--:--")

g.SetFont("s" Pt(54) " w700 cFFFFFF", "Segoe UI")
ctlDate := g.Add("Text", "x" U(28) " y" U(200) " w" U(dateW) " h" U(80), "")

; Прогнозата се създава ПРЕДИ текущото време: при застъпване на кутии по-ранният контрол е отгоре,
; така че широката кутия на градусите никога не реже колоните на прогнозата.
ctlFcDay := []
ctlFcIcon := []
ctlFcTemp := []
Loop fcDays {
    cx := fcX0 + (A_Index - 1) * fcStepX
    g.SetFont("s" Pt(fcDayFont) " w700 cFFFFFF", "Segoe UI")
    ctlFcDay.Push(g.Add("Text", "x" U(cx) " y" U(fcDayY) " w" U(222) " h" U(fcDayH) " Center", ""))
    ctlFcIcon.Push(g.Add("Picture", "x" U(cx + 9) " y" U(fcIconY) " w" U(204) " h" U(170), WeatherIconDir "07.png"))
    g.SetFont("s" Pt(fcTempFont) " w700 cFFFFFF", "Segoe UI")
    ctlFcTemp.Push(g.Add("Text", "x" U(cx) " y" U(fcTempY) " w" U(222) " h" U(fcTempH) " Center", ""))
}

ctlIcon := g.Add("Picture", "x" U(curIconX) " y" U(curIconY) " w" U(curIconW) " h" U(curIconH), WeatherIconDir "07.png")
g.SetFont("s" Pt(curTempFont) " w700 cFFFFFF", "Segoe UI")
ctlTemp := g.Add("Text", "x" U(curTempX) " y" U(curTempY) " w" U(curTempW) " h" U(curTempH), "")
; двоен клик върху градусите = обнови прогнозата (хващан от клавиша ~LButton по-долу, не от контрола - по-надеждно)
g.SetFont("s" Pt(curDescFont) " w700 cFFFFFF", "Segoe UI")
ctlDesc := g.Add("Text", "x" U(curDescX) " y" U(curDescY) " w" U(curDescW) " h" U(curDescH), "")
g.SetFont("s" Pt(curWindFont) " w700 cFFFFFF", "Segoe UI")
ctlWind := g.Add("Text", "x" U(curDescX) " y" U(curWindY) " w" U(curDescW) " h" U(curWindH), "")

weatherSize := wide ? (" w" U(screenW - 20) " h" U(wideTopH)) : ""
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
startBtn := barGui.Add("Text", "x10 y11 w216 h98 cFFFFFF Background0067C0 Center +0x200 +0x4000000", "START")
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
    ; зоната е от 226 до (десния ръб 2550 - плочката - 2 за линията); между 7-те позиции са нужни поне minGap px
    if (indTotal + 7 * minGap + volBoxW <= 2322 || barFont <= 28)
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
A_TrayMenu.Add("Обнови прогнозата", (*) => FetchWeather())
A_TrayMenu.Add("Настройки…", ShowSettingsGui)
A_TrayMenu.Add("Отвори settings.ini", OpenSettings)
A_TrayMenu.Add("Върни началните настройки", ResetSettingsToDefault)
A_TrayMenu.Add("Презареди скрипта", (*) => Reload())
A_TrayMenu.Add("Изход", (*) => ExitApp())

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
    SetTxt(ctlDate, Integer(A_DD) " " Months[Integer(A_MM)] " " A_Year)
}

SetTxt(ctl, v) {
    if (ctl.Text != v)
        ctl.Text := v
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
        ctlWind.Text := "Обновяване…"
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
        windTxt := " · вятър " Round(mWind[1]) " км/ч"
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
    SetTxt(ctlDesc, WxText(mCode[1]))
    SetTxt(ctlWind, City windTxt)

    Loop fcDays {
        i := A_Index
        if (i = 1) {
            dayName := "днес"
        } else if (i = 2) {
            dayName := "утре"
        } else {
            wd := Integer(FormatTime(StrReplace(dates[i], "-", ""), "WDay"))
            dayName := Days[wd]
        }
        SetTxt(ctlFcDay[i], dayName)
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
        return "Ясно"
    if (c = 1)
        return "Предимно ясно"
    if (c = 2)
        return "Променливо"
    if (c = 3)
        return "Облачно"
    if (c = 45 || c = 48)
        return "Мъгла"
    if (c >= 51 && c <= 57)
        return "Ръмеж"
    if (c >= 61 && c <= 67)
        return "Дъжд"
    if (c >= 71 && c <= 77)
        return "Сняг"
    if (c >= 80 && c <= 82)
        return "Превалявания"
    if (c = 85 || c = 86)
        return "Снеговалеж"
    if (c >= 95)
        return "Гръмотевици"
    return "Облачно"
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
        for hwnd in WinGetList() {
            if IsOverlayGui(hwnd)
                continue
            if ((WinGetStyle("ahk_id " hwnd) & 0x10000000) && InStr(WinGetTitle("ahk_id " hwnd), kw))
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
            MsgBox("Не е намерен файлът:`n" target, "EdgeLauncher", "Icon!")
            return
        }

        if (newHwnd := WaitForNewWindow(beforeWindows, 4500)) {
            appHwnds[btnIdx] := newHwnd
            MoveToMainMonitor(newHwnd)
            WinActivate("ahk_id " newHwnd)
        }
    } catch Error as err {
        MsgBox("Грешка при стартиране:`n" target "`n`n" err.Message, "EdgeLauncher", "Icon!")
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
    m.Add("Обнови прогнозата", (*) => FetchWeather())
    m.Add("Настройки…", ShowSettingsGui)
    m.Add("Отвори settings.ini", OpenSettings)
    m.Add("Презареди скрипта", (*) => Reload())
    m.Add()
    m.Add("Изход", (*) => ExitApp())
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

    zoneStart := 226
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
        MsgBox("Не намирам settings.ini:`n" settingsFile "`n`nСложи го до скрипта.", "CorsairSuperWidget", "Icon!")
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
    sg := Gui("+OwnDialogs", "Настройки - CorsairSuperWidget")
    settingsGui := sg
    sg.OnEvent("Close", CloseSettingsGui)
    sg.OnEvent("Escape", CloseSettingsGui)
    sg.SetFont("s10", "Segoe UI")
    tabs := sg.Add("Tab3", "x10 y10 w840 h480", ["Общи", "Време", "Лента", "Папки", "Приложения"])
    fld := Map()

    ; --- Общи ---
    tabs.UseTab(1)
    designIdx := wide ? 2 : 1
    sg.Add("Text", "x30 y58 w170", "Дизайн:")
    fld["Design"] := sg.Add("DropDownList", "x210 y54 w160 Choose" designIdx, ["classic", "wide"])
    sg.Add("Text", "x30 y95 w780 cGray", "classic = сегашният;  wide = горният ред за час, дата и прогноза, под него 10-те икони в един ред.")
    fld["Auto"] := sg.Add("Checkbox", "x30 y140 w700", "Сам да намира малкия монитор (AutoDetectScreen)")
    fld["Auto"].Value := CfgBool("General", "AutoDetectScreen", true) ? 1 : 0
    sg.Add("Text", "x30 y185 w170", "Позиция X (ManualX):")
    fld["X"] := sg.Add("Edit", "x210 y181 w110", CfgInt("General", "ManualX", 451))
    sg.Add("Text", "x30 y225 w170", "Позиция Y (ManualY):")
    fld["Y"] := sg.Add("Edit", "x210 y221 w110", CfgInt("General", "ManualY", 1440))
    sg.Add("Text", "x30 y268 w780 cGray", "X и Y се ползват само при изключено автоматично намиране (виж монитора в Настройки на дисплея на Windows).")
    fld["Autostart"] := sg.Add("Checkbox", "x30 y315 w760", "Стартирай скрипта заедно с Windows")
    fld["Autostart"].Value := AutostartEnabled() ? 1 : 0
    sg.Add("Text", "x30 y350 w780 cGray", "Слага/маха пряк път в папката Startup на потребителя. Ако ползваш HWiNFO, пусни и него със Windows (за температурите).")

    ; --- Време ---
    tabs.UseTab(2)
    sg.Add("Text", "x30 y58 w170", "Град (текст):")
    fld["City"] := sg.Add("Edit", "x210 y54 w260", Cfg("Weather", "City", "София"))
    sg.Add("Text", "x30 y98 w170", "Ширина (Lat):")
    fld["Lat"] := sg.Add("Edit", "x210 y94 w140", Cfg("Weather", "Lat", "42.6977"))
    sg.Add("Text", "x30 y138 w170", "Дължина (Lon):")
    fld["Lon"] := sg.Add("Edit", "x210 y134 w140", Cfg("Weather", "Lon", "23.3219"))
    sg.Add("Text", "x30 y178 w170", "Обновяване (минути):")
    fld["Refresh"] := sg.Add("Edit", "x210 y174 w90", CfgInt("Weather", "RefreshMinutes", 30))
    sg.Add("Text", "x30 y222 w780 cGray", "Координатите се взимат от карта (напр. Google Maps: десен клик върху мястото). Десетичен знак: точка.")

    ; --- Лента ---
    tabs.UseTab(3)
    sg.Add("Text", "x30 y58 w220", "Първи диск (Drive1):")
    fld["Drive1"] := sg.Add("Edit", "x260 y54 w80", CfgDrive("Bar", "Drive1", "C:"))
    sg.Add("Text", "x30 y98 w220", "Втори диск (Drive2):")
    fld["Drive2"] := sg.Add("Edit", "x260 y94 w80", CfgDrive("Bar", "Drive2", "D:"))
    fld["Strict"] := sg.Add("Checkbox", "x30 y142 w760", "Строг филтър на температурните етикети в HWiNFO (StrictTempLabels)")
    fld["Strict"].Value := CfgBool("Bar", "StrictTempLabels", true) ? 1 : 0
    sg.Add("Text", "x30 y188 w220", "Стъпка на звука (%):")
    fld["Wheel"] := sg.Add("Edit", "x260 y184 w80", CfgInt("Volume", "WheelStep", 5))
    sg.Add("Text", "x30 y232 w780 cGray", "Диск = буква и двоеточие, напр. C: или D:. Стъпката е колко процента променя една стъпка на колелцето над VOL (1-50).")

    ; --- Папки ---
    tabs.UseTab(4)
    pathRows := [["LauncherIcons", "Икони на лаунчера:", "icons"]
        , ["WeatherIcons", "Икони за времето:", "icons"]
        , ["ChromeApps", "Chrome приложения (PWA):", "%AppData%\Microsoft\Windows\Start Menu\Programs\Приложения в Chrome"]]
    py := 58
    for pr in pathRows {
        sg.Add("Text", "x30 y" py " w300", pr[2])
        e := sg.Add("Edit", "x30 y" . (py + 26) . " w650", Cfg("Paths", pr[1], pr[3]))
        fld["P_" pr[1]] := e
        b := sg.Add("Button", "x690 y" . (py + 24) . " w120 h30", "Избери…")
        b.OnEvent("Click", PickFolderInto.Bind(e))
        py += 80
    }
    sg.Add("Text", "x30 y" py " w780 cGray", "Може абсолютен път, път спрямо папката на скрипта (напр. icons) или с %AppData%, %LocalAppData%.")

    ; --- Приложения ---
    tabs.UseTab(5)
    sg.Add("Text", "x25 y48 w150", "Икона (PNG)")
    sg.Add("Text", "x180 y48 w400", "Какво да се стартира (път, shell:AppsFolder\…, {ChromeApps}…)")
    sg.Add("Text", "x625 y48 w60", "PWA")
    sg.Add("Text", "x690 y48 w130", "Дума в заглавие")
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
    bReset := sg.Add("Button", "x30 y500 w200 h36", "Начални настройки")
    bReset.OnEvent("Click", ResetSettingsToDefault)
    bRestore := sg.Add("Button", "x240 y500 w200 h36", "Върни предишните")
    bRestore.OnEvent("Click", RestorePreviousSettings)
    bSave := sg.Add("Button", "x470 y500 w230 h36 Default", "Запази и презареди")
    bSave.OnEvent("Click", SaveSettingsGui.Bind(fld, appFlds))
    bCancel := sg.Add("Button", "x710 y500 w140 h36", "Откажи")
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
    d := FileSelect("D", DirExist(start) ? start : "", "Избери папка")
    if (d != "")
        edit.Text := RTrim(d, "\")
}

PickFileInto(edit, *) {
    f := FileSelect(3, , "Избери програма или пряк път", "Програми и преки пътища (*.exe; *.lnk)")
    if (f != "")
        edit.Text := f
}

SaveSettingsGui(fld, appFlds, *) {
    items := []
    x := Trim(fld["X"].Text), y := Trim(fld["Y"].Text)
    if !(IsInteger(x) && IsInteger(y)) {
        MsgBox("ManualX и ManualY трябва да са цели числа.", "Настройки", "Icon!")
        return
    }
    lat := StrReplace(Trim(fld["Lat"].Text), ",", "."), lon := StrReplace(Trim(fld["Lon"].Text), ",", ".")
    if !(IsNumber(lat) && IsNumber(lon) && Abs(lat) <= 90 && Abs(lon) <= 180) {
        MsgBox("Lat (до 90) и Lon (до 180) трябва да са числа, напр. 42.6977 и 23.3219.", "Настройки", "Icon!")
        return
    }
    refresh := Trim(fld["Refresh"].Text)
    if !(IsInteger(refresh) && refresh >= 1) {
        MsgBox("Обновяването трябва да е цяло число минути (1 или повече).", "Настройки", "Icon!")
        return
    }
    drives := []
    for k in ["Drive1", "Drive2"] {
        d := RegExReplace(Trim(fld[k].Text), "[\\/]+$")
        if !RegExMatch(d, "i)^[A-Z]:$") {
            MsgBox("Дискът трябва да е буква и двоеточие, напр. C: или D:", "Настройки", "Icon!")
            return
        }
        drives.Push(StrUpper(d))
    }
    wheel := Trim(fld["Wheel"].Text)
    if !(IsInteger(wheel) && wheel >= 1 && wheel <= 50) {
        MsgBox("Стъпката на звука трябва да е число от 1 до 50.", "Настройки", "Icon!")
        return
    }

    items.Push(["General", "Design", fld["Design"].Text])
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
            MsgBox("Ред " i " в „Приложения“: попълни и иконата, и какво да се стартира (или изчисти и двете).", "Настройки", "Icon!")
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
        MsgBox("Не мога да прочета/копирам settings.ini:`n" err.Message, "Настройки", "Icon!")
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
        MsgBox("Не мога да запиша settings.ini:`n" err.Message, "Настройки", "Icon!")
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
            FileCreateShortcut(A_ScriptFullPath, link, A_ScriptDir, "", "Corsair Xeneon Edge - виджети")
        } else if FileExist(link) {
            FileDelete(link)
        }
    } catch Error as err {
        MsgBox("Не успях да променя стартирането с Windows:`n" err.Message, "Настройки", "Icon!")
    }
}

; ================= ВРЪЩАНЕ НА НАСТРОЙКИТЕ =================
; Начални настройки = стойностите, с които скриптът е работил първоначално (дизайн classic).
; Преди всяко връщане текущият settings.ini се пази като settings.ini.bak.
ResetSettingsToDefault(*) {
    if (MsgBox("Да върна ли всички настройки към началните?`n`nТекущият settings.ini се запазва като settings.ini.bak (можеш да го върнеш с „Върни предишните“).", "Настройки", "YesNo Icon?") != "Yes")
        return
    try {
        if FileExist(settingsFile)
            FileCopy(settingsFile, settingsFile ".bak", 1)
        fo := FileOpen(settingsFile, "w", "UTF-8")
        fo.Write(DefaultSettingsText())
        fo.Close()
    } catch Error as err {
        MsgBox("Не успях да върна началните настройки:`n" err.Message, "Настройки", "Icon!")
        return
    }
    Reload()
}

RestorePreviousSettings(*) {
    bak := settingsFile ".bak"
    if !FileExist(bak) {
        MsgBox("Няма запазено предишно копие (settings.ini.bak).", "Настройки", "Icon!")
        return
    }
    if (MsgBox("Да върна ли настройките от предишното копие (settings.ini.bak)?`n`nТекущите ще се запазят там (можеш да се върнеш обратно със същия бутон).", "Настройки", "YesNo Icon?") != "Yes")
        return
    try {
        tmp := settingsFile ".tmp"
        if FileExist(settingsFile)
            FileCopy(settingsFile, tmp, 1)
        FileCopy(bak, settingsFile, 1)
        if FileExist(tmp)
            FileMove(tmp, bak, 1)
    } catch Error as err {
        MsgBox("Не успях да върна предишните настройки:`n" err.Message, "Настройки", "Icon!")
        return
    }
    Reload()
}

DefaultSettingsText() {
    lines := []
    lines.Push("; ====================================================================")
    lines.Push(";  settings.ini за CorsairSuperWidget.ahk")
    lines.Push(";  Слага се в същата папка като скрипта. След промяна:")
    lines.Push(";  десен клик на иконата в трея -> „Презареди скрипта“.")
    lines.Push(";  Ако ред липсва или е грешен, скриптът ползва вградената стойност.")
    lines.Push(";  Коментари: редове, започващи с `; или #")
    lines.Push("; ====================================================================")
    lines.Push("")
    lines.Push("[General]")
    lines.Push("; Дизайн:")
    lines.Push(";   classic = сегашният (час и прогноза вляво, 2 реда икони вдясно)")
    lines.Push(";   wide    = целият горен ред за часа, датата, времето и 5-дневната прогноза,")
    lines.Push(";             под него 10-те икони в един ред, най-долу лентата")
    lines.Push("Design=classic")
    lines.Push("; 1 = сам намира най-малкия монитор; 0 = ползва ManualX/ManualY")
    lines.Push("AutoDetectScreen=1")
    lines.Push("ManualX=451")
    lines.Push("ManualY=1440")
    lines.Push("")
    lines.Push("[Paths]")
    lines.Push("; Папка с иконите на лаунчера (абсолютен път или спрямо папката на скрипта)")
    lines.Push("LauncherIcons=icons")
    lines.Push("; Папка с иконите за времето (07.png, 01.png ...)")
    lines.Push("WeatherIcons=icons")
    lines.Push("; Папка с преките пътища на Chrome приложенията (PWA); може да има %AppData% и др.")
    lines.Push("ChromeApps=%AppData%\Microsoft\Windows\Start Menu\Programs\Приложения в Chrome")
    lines.Push("")
    lines.Push("[Weather]")
    lines.Push("City=София")
    lines.Push("Lat=42.6977")
    lines.Push("Lon=23.3219")
    lines.Push("; на колко минути се обновява прогнозата")
    lines.Push("RefreshMinutes=30")
    lines.Push("")
    lines.Push("[Bar]")
    lines.Push("; Кои два диска да показва долната лента")
    lines.Push("Drive1=C:")
    lines.Push("Drive2=D:")
    lines.Push("; 1 = за температурите пропуска HWiNFO етикети за мощност, натоварване, честота, вентилатор")
    lines.Push("StrictTempLabels=1")
    lines.Push("")
    lines.Push("[Volume]")
    lines.Push("; процента на една „крачка“ на колелцето над плочката VOL")
    lines.Push("WheelStep=5")
    lines.Push("")
    lines.Push("[Launcher]")
    lines.Push("; Формат:  AppN = име на иконата | какво да се стартира | pwa (1/0) | дума от заглавието на прозореца")
    lines.Push("; {ChromeApps} се заменя с папката ChromeApps отгоре; може да ползваш %LocalAppData%, %ProgramFiles% и др.")
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
