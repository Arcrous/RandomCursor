#Requires AutoHotkey v2.0
/**
 * Logger.ahk - Logging system for RandomCursor++
 * Handles all logging operations
 */
class Logger {
    logFile := A_ScriptDir "\RandomCursor.log"
    isEnabled := true
    clearTimer := ""           ; Timer for periodic clearing
    lastClearTime := 0         ; Track when log was last cleared

    __New() {
        ; Clear the log file on startup
        this.ClearLog()

        ; Create the log file with header
        ; FileAppend "=== RandomCursor Log Started " FormatTime(, "yyyy-MM-dd HH:mm:ss") " ===`n", this.logFile

        ; Set up timer to clear log every 30 minutes (1800000 ms)
        this.clearTimer := ObjBindMethod(this, "ClearLog")
        SetTimer(this.clearTimer, 1800000)
    }

    /**
     * Sets logging enabled state
     * @param enabled - Whether logging is enabled
     */
    SetEnabled(enabled) {
        this.isEnabled := enabled
    }

    /**
     * Logs a message to the log file
     * @param message - Message to log
     */
    Log(message) {
        if (!this.isEnabled)
            return

        try {
            FileAppend FormatTime(, "yyyy-MM-dd HH:mm:ss") " - " message "`n", this.logFile
        }
        catch as e {
            ; Silent fail if logging errors
        }
    }

    /**
     * Clear the log
     * @param message - Message to log
     */
    ClearLog() {
        try {
            ; Delete existing log file
            if FileExist(this.logFile)
                FileDelete(this.logFile)

            ; Create new log file with header
            FileAppend "=== RandomCursor Log Started " FormatTime(, "yyyy-MM-dd HH:mm:ss") " ===`n", this.logFile
            this.lastClearTime := A_TickCount
        }
        catch as e {
            ; Silent fail if unable to clear log
        }
    }
}
