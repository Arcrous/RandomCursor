#Requires AutoHotkey v2.0
/**
 * Logger.ahk - Logging system for RandomCursor++
 * Handles all logging operations
 */
class Logger {
    logFile := A_ScriptDir "\RandomCursor.log"
    isEnabled := true

    __New() {
        ; Create the log file with header
        FileAppend "=== RandomCursor Log Started " FormatTime(, "yyyy-MM-dd HH:mm:ss") " ===`n", this.logFile
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
}
