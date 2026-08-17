# KrishInvisable — How It Works

A Windows desktop notes window that **you can see** but is **invisible in
Microsoft Teams / Zoom / Google Meet / OBS screen shares** and in
Windows screenshots.

---

## 1. The one-line explanation

Windows has a built-in flag called **`WDA_EXCLUDEFROMCAPTURE`**. When an
app sets this flag on its window, the Windows compositor (DWM) tells every
screen-capture pipeline: *"skip this window — pretend it isn't there."*
Your eyes see the window normally because they read pixels from your monitor,
not from the capture pipeline.

The single Win32 call that does everything:

```csharp
SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE);
```

That's it. Everything else in the app is just a nice UI on top of that call.

---

## 2. What you see vs. what the other person sees

### 2.1 Normal use (no screen share)

| Who | Sees KrishInvisable window? | Sees the notes text? |
|---|---|---|
| **You** (looking at your monitor) | ✅ Yes | ✅ Yes |
| Nobody else — there's no viewer yet | — | — |

### 2.2 While you are sharing your screen in Teams / Zoom / Meet

| Who | Sees KrishInvisable window? | Sees the notes text? |
|---|---|---|
| **You** (looking at your monitor) | ✅ Yes — window looks 100% normal | ✅ Yes |
| **The other person on the call** | ❌ No — window is completely gone from the share | ❌ No |
| **The Teams "share preview" thumbnail** | ❌ No — even *you* won't see it in the preview | ❌ No |
| **Recording (Teams cloud recording, OBS, etc.)** | ❌ No | ❌ No |
| **Windows screenshot (Win+Shift+S, PrintScreen)** | ❌ No | ❌ No |

**Visualization:**

```
┌─ YOUR MONITOR ────────────────────────┐    ┌─ THE OTHER PERSON'S SCREEN ──┐
│  Teams meeting                         │    │  Teams meeting                │
│  ┌──────────────┐                      │    │  ┌──────────────┐             │
│  │  PowerPoint  │                      │    │  │  PowerPoint  │             │
│  │              │                      │    │  │              │             │
│  │      ┌──────────────────┐           │    │  │              │             │
│  │      │ KrishInvisable   │           │    │  │              │             │
│  │      │ (your notes)     │           │    │  │              │             │
│  │      │                  │           │    │  │              │             │
│  │      └──────────────────┘           │    │  │              │             │
│  └──────────────┘                      │    │  └──────────────┘             │
└────────────────────────────────────────┘    └───────────────────────────────┘
        ^ what YOU see                              ^ what the OTHER person sees
        (the notes window is there)                 (no notes window at all —
                                                     just PowerPoint behind it)
```

---

## 3. Why this actually works (technical)

Modern screen capture on Windows uses one of three APIs:

1. **DXGI Desktop Duplication** — Teams, Zoom, OBS, Win+Shift+S all use this.
2. **Graphics Capture (Windows.Graphics.Capture)** — Xbox Game Bar, newer apps.
3. **GDI BitBlt** — legacy screenshot tools.

`WDA_EXCLUDEFROMCAPTURE` (introduced in **Windows 10 version 2004**,
build 19041, released May 2020) makes the Desktop Window Manager (DWM)
composite two different frames:

- **Frame A → your monitor:** contains the KrishInvisable window (normal).
- **Frame B → capture APIs:** the KrishInvisable window is cut out; whatever
  is behind it shows through.

Your GPU shows Frame A on your physical display. Any capture consumer
(Teams share, screenshot, screen recorder) receives Frame B and never
knows Frame A existed.

The C# code that does it — [MainWindow.xaml.cs](MainWindow.xaml.cs#L14):

```csharp
private const uint WDA_EXCLUDEFROMCAPTURE = 0x00000011;

[DllImport("user32.dll", SetLastError = true)]
private static extern bool SetWindowDisplayAffinity(IntPtr hwnd, uint affinity);

private void ApplyCaptureAffinity()
{
    var hwnd = new WindowInteropHelper(this).Handle;
    SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE);
}
```

---

## 4. What the app looks like

- Dark, resizable window with a big text area for notes.
- **Always on top** (toggleable) — floats over Teams, PowerPoint, browsers.
- **Auto-save** — notes persist to `%LocalAppData%\KrishInvisable\notes.txt`.
- Toolbar buttons:
  - **Disable hide / Enable hide** — turn the invisibility on/off at runtime.
  - **Topmost: ON/OFF** — keep the window above everything or not.
  - **Opacity 100 → 90 → 75 → 60%** — dim the window on *your* screen
    (only affects your view; capture still sees nothing regardless).
  - **Save** — force-save notes now.

---

## 5. How to run it

```powershell
cd "C:\Users\v-kbandoju\OneDrive - Microsoft\Desktop\Test\KrishInvisable"
dotnet run
```

Or double-click the compiled exe:

```
C:\Users\v-kbandoju\OneDrive - Microsoft\Desktop\Test\KrishInvisable\bin\Debug\net8.0-windows\KrishInvisable.exe
```

---

## 6. How to prove it works (60-second test)

1. Launch KrishInvisable and type something like *"SECRET — should not be visible"*.
2. Open Microsoft Teams → start a meeting → **Share screen → your entire desktop**.
3. Look at the **share preview** in Teams — the KrishInvisable window is gone,
   but every other window (Explorer, browser, VS Code) shows normally.
4. Extra proof: press **Win + Shift + S** to take a screenshot. Draw a rectangle
   over the notes window and paste into Paint. The notes window will be
   **missing** from the screenshot too, but everything behind it will show.

If both tests pass, the hide is working correctly.

---

## 7. What it does NOT protect against

Screen-capture exclusion is a **software-only** feature. It does not stop:

| Attack | Blocked? | Why |
|---|---|---|
| Teams / Zoom / Meet screen share | ✅ Blocked | Uses DXGI capture — respects the flag |
| OBS Studio (Display Capture / Window Capture) | ✅ Blocked | Same DXGI pipeline |
| Win + Shift + S, PrintScreen, Snipping Tool | ✅ Blocked | Same DXGI pipeline |
| Windows Game Bar recording | ✅ Blocked | Uses Graphics Capture — respects the flag |
| Someone taking a **photo of your monitor** with a phone | ❌ Not blocked | The pixels are already on your screen |
| **Hardware capture card** on the HDMI output | ❌ Not blocked | It captures the wire, not the OS |
| Someone standing behind you looking at the screen | ❌ Not blocked | Same reason as the phone |
| Older Windows (before 10.0.19041, May 2020) | ⚠️ Falls back to **WDA_MONITOR** | Window shows as a **solid black rectangle** in shares instead of being invisible |
| macOS / Linux | ❌ Not applicable | This is a Windows-only Win32 API |
| Browser-based screen share of *this app itself* | Not applicable | The app is native Win32, not a browser tab |

**Bottom line:** it defeats every normal software-based screen share and
screenshot on modern Windows. It does not defeat cameras or hardware
capture. Do not use it to hide anything you would be fired for if a
coworker glanced at your monitor — this only hides from the *network*,
not from *people in the room*.

---

## 8. Runtime toggle

If you *want* the other person to see the notes window (e.g. you decide
to share it deliberately), click **Disable hide** in the toolbar. The
`SetWindowDisplayAffinity` call is repeated with `WDA_NONE` and the
window becomes a normal, capturable window again. Click **Enable hide**
to switch back.

---

## 9. Files in the project

- [KrishInvisable.csproj](KrishInvisable.csproj) — .NET 8 WPF project.
- [App.xaml](App.xaml) / [App.xaml.cs](App.xaml.cs) — WPF entry point.
- [MainWindow.xaml](MainWindow.xaml) — the notes-window UI.
- [MainWindow.xaml.cs](MainWindow.xaml.cs) — the `SetWindowDisplayAffinity`
  P/Invoke and notes save/load logic.
