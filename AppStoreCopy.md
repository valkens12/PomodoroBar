# App Store copy: PomodoroBar

Bundle ID: com.archiet4.pomodorobar
Version: 1.1.0

---

## English

### Subtitle (170 chars max)
A quiet Pomodoro timer that lives in your menu bar.

### Promotional text (170 chars max, can be changed anytime)
Focus mode pauses the timer when you switch away from the apps you chose.

### Description (4000 chars max)
PomodoroBar is a Pomodoro timer that stays out of your way. It runs entirely in the menu bar, so there is no Dock icon and no extra window to manage. Glance up to see how long is left, click once to start or pause.

Work and break sessions
- Set your work and break lengths in Settings.
- Start a session and a tomato progress ring in the menu bar counts down.
- A short animation marks the start of each session.
- When a session ends you get a notification and, if you want one, a sound.

Focus mode
- Add the apps you actually want to work in. The timer only counts down while one of them is the frontmost app; switch to anything else and it pauses on its own.
- For Safari you can go further: list the websites that count as work. The timer only ticks while the frontmost tab is on one of those sites, so time spent on other tabs does not count.

Shortcuts and launch
- Set a global keyboard shortcut to start and pause the timer without opening the menu. The default is Control-Option-P, and you can record your own.
- Turn on Launch at Login from Settings so the timer is ready when you sit down.

Statistics
- Your focus time is totaled in hours and minutes so you can see how the day and week add up.

Privacy
- Everything stays on your Mac. PomodoroBar has no account and sends nothing anywhere.
- The only thing it ever reads is the address of your active Safari tab, and only when you have turned on Safari focus domains, so it can tell whether the current tab counts as work. That address is used for that one check and is not stored or sent anywhere.

PomodoroBar is built for macOS 26 and uses the system's Liquid Glass look.

---

## German / Deutsch

### Untertitel (max. 170 Zeichen)
Ein ruhiger Pomodoro-Timer, der in der Menüleiste sitzt.

### Werbetext (max. 170 Zeichen, jederzeit änderbar)
Der Fokusmodus pausiert den Timer, wenn du die gewählten Apps verlässt.

### Beschreibung (max. 4000 Zeichen)
PomodoroBar ist ein Pomodoro-Timer, der sich aus dem Weg hält. Er läuft vollständig in der Menüleiste, es gibt also kein Dock-Icon und kein zusätzliches Fenster. Ein Blick nach oben zeigt die verbleibende Zeit, ein Klick startet oder pausiert.

Arbeits- und Pausensitzungen
- Lege die Länge deiner Arbeits- und Pausenzeiten in den Einstellungen fest.
- Starte eine Sitzung, und ein Tomaten-Fortschrittsring in der Menüleiste zählt herunter.
- Eine kurze Animation markiert den Start jeder Sitzung.
- Wenn eine Sitzung endet, bekommst du eine Benachrichtigung und auf Wunsch einen Ton.

Fokusmodus
- Füge die Apps hinzu, in denen du wirklich arbeiten willst. Der Timer zählt nur herunter, wenn eine davon die vorderste App ist; wechselst du zu etwas anderem, pausiert er von selbst.
- Bei Safari geht es genauer: Liste die Websites, die als Arbeit zählen. Der Timer läuft nur, solange der vorderste Tab auf einer dieser Seiten ist. Zeit auf anderen Tabs zählt nicht.

Shortcuts und Start
- Lege ein systemweites Tastenkürzel fest, um den Timer zu starten und zu pausieren, ohne das Menü zu öffnen. Standard ist Control-Option-P, du kannst aber dein eigenes aufzeichnen.
- Aktiviere „Bei der Anmeldung öffnen" in den Einstellungen, damit der Timer bereit ist, wenn du dich an den Mac setzt.

Statistik
- Deine Fokuszeit wird in Stunden und Minuten zusammengezählt, sodass du siehst, wie sich Tag und Woche addieren.

Datenschutz
- Alles bleibt auf deinem Mac. PomodoroBar hat kein Konto und sendet nichts irgendwohin.
- Das Einzige, das jemals ausgelesen wird, ist die Adresse deines aktiven Safari-Tabs, und auch das nur, wenn du Safari-Fokusdomains aktiviert hast, damit die App erkennen kann, ob der aktuelle Tab als Arbeit zählt. Diese Adresse wird nur für diese eine Prüfung verwendet und weder gespeichert noch versendet.

PomodoroBar wird für macOS 26 gebaut und nutzt das Liquid-Glass-Erscheinungsbild des Systems.

---

## App Review Notes (English only)

What this app is
PomodoroBar is a menu-bar-only Pomodoro timer. It sets LSUIElement, so on launch it appears in the menu bar and intentionally does not show a Dock icon or a window. Please look for the tomato icon in the menu bar to interact with it.

Permissions and entitlements, and why each is needed
- App Sandbox: enabled, as required for the Mac App Store.
- com.apple.security.temporary-exception.apple-events, target com.apple.Safari: used to read the URL of the current tab of Safari's front window, so the optional Safari focus-domains feature can decide whether the active tab counts as work. This is the minimum entitlement that lets a sandboxed app ask Safari for that single piece of information. The app does not script or control Safari in any other way. The URL is compared to the user's domain list in memory, used for that one check, and is not stored or transmitted. The feature is off by default and only does anything once the user adds Safari as a focus app and enters domains.
- Notifications: used only for session-end alerts.
- Automation permission (Apple Events to Safari): the first time the Safari focus-domains feature runs, macOS will prompt the user to let PomodoroBar control Safari. This is expected and is the same prompt any app gets when sending Apple Events to another app. If the user denies it, the app falls back to app-level focus gating (Safari counts as work whenever it is frontmost) and does not block the timer.

No account, no network
There is no sign-in, no network usage, and no analytics. All settings and statistics are stored locally on the device.

How to test
1. Launch the app. The tomato icon appears in the menu bar (not the Dock). Click it to open the popover.
2. In Settings, set work and break durations. Start a session from the popover and confirm the menu-bar ring counts down. When the session ends, confirm the notification (and sound if enabled) fires.
3. Focus mode, app level: in Settings, add an app such as Notes as a focus app. Start the timer. Make Notes frontmost: the timer ticks. Switch to another app: the timer pauses. Switch back: it resumes.
4. Focus mode, Safari domains: add Safari as a focus app and add a domain such as example.com. Start the timer. Open Safari to that domain: the timer ticks. Switch the active tab to a different domain: the timer pauses. The first time this runs, approve the "PomodoroBar wants to control Safari" prompt.
5. Global shortcut: with the default Control-Option-P, press the shortcut from any app to start and pause without opening the menu. A custom shortcut can be recorded in Settings. The shortcut is registered with the system hot-key API and does not require Accessibility or Input Monitoring access.
6. Launch at Login: toggle it in Settings and confirm the app launches on the next login.
7. Statistics: open the statistics view and confirm focus time is shown totaled in hours and minutes.

Notes
- The default global shortcut (Control-Option-P) may be bound to something else on the review machine. If so, record a different one in Settings.
- If the Safari automation prompt is dismissed or denied, the Safari focus-domains feature degrades gracefully to app-level gating and the timer keeps working.