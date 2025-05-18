#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%\lib\Config.ahk
#Include %A_ScriptDir%\lib\RegistryHelper.ahk
#Include %A_ScriptDir%\lib\CursorManager.ahk
#Include %A_ScriptDir%\lib\UI.ahk
#Include %A_ScriptDir%\lib\Logger.ahk
#Include %A_ScriptDir%\lib\HotkeyManager.ahk  ; Add the new HotkeyManager include

/**
 * RandomCursor++ - A script to automatically change cursor schemes
 * Main script file that initializes the application
 */

; Initialize the application
class RandomCursorApp {
    ; Application components
    config := ""
    cursorManager := ""
    ui := ""
    logger := ""
    hotkeyManager := ""  ; Add hotkeyManager property

    __New() {
        ; Create the logger first so other components can use it
        this.logger := Logger()
        this.logger.Log("Application initializing...")

        ; Initialize configuration
        this.config := Config(this.logger)

        ; Initialize cursor manager
        this.cursorManager := CursorManager(this.config, this.logger)

        ; Initialize UI
        this.ui := UI(this.config, this.cursorManager, this.logger)

        ; Initialize hotkey manager
        this.hotkeyManager := HotkeyManager(this.config, this.cursorManager, this.ui, this.logger)

        ; Log startup information
        this.logger.Log("Application started. Found " this.cursorManager.GetSchemeCount() " cursor schemes.")

        ; Show initial notification
        if (this.config.enableNotifications)
            TrayTip("RandomCursor Running", "Found " this.cursorManager.GetSchemeCount() " cursor schemes`nCurrent: " this
            .cursorManager.currentScheme, 1)
    }

    StartApplication() {
        ; Start the cursor change timer
        this.cursorManager.StartTimer()

        ; Register configured hotkeys
        this.hotkeyManager.RegisterHotkeys()

        ; Set up memory management
        this.SetupWindowMonitoring()
    }

    FreeResources() {
        this.logger.Log("Freeing unused resources...")

        ; Clear unnecessary objects from memory
        this.cursorManager.CleanupUnusedSchemes()

        ; Force garbage collection
        this.CollectGarbage()

        this.logger.Log("Resources freed successfully")
    }

    CollectGarbage() {
        ; Force AHK's garbage collection
        ; This is a trick to encourage AHK to collect garbage
        loop 3 {
            obj := []
            loop 1000 {
                obj.Push({})
            }
            obj := ""
        }

        ; Run explicit garbage collection (helps in AHK v2)
        DllCall("ole32\CoFreeUnusedLibraries")
        DllCall("psapi\EmptyWorkingSet", "UInt", -1)
    }

    SetupWindowMonitoring() {
        ; Set up window state monitoring for minimizing/restoring
        WinWaitActive("ahk_class Shell_TrayWnd")
        OnMessage(0x0112, ObjBindMethod(this, "WM_SYSCOMMAND"))
        this.logger.Log("Window state monitoring initialized")
    }

    WM_SYSCOMMAND(wParam, lParam, msg, hwnd) {
        ; SC_MINIMIZE = 0xF020
        if (wParam = 0xF020) {
            this.logger.Log("Application minimized, freeing resources")
            this.FreeResources()
        }
        ; SC_RESTORE = 0xF120
        else if (wParam = 0xF120) {
            this.logger.Log("Application restored")
            ; Reload necessary resources if needed
        }
        ; Continue with default processing
        return false
    }
}

; Create and start the application
global app := RandomCursorApp()
app.StartApplication()