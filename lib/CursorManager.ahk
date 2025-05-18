#Requires AutoHotkey v2.0
/**
 * CursorManager.ahk - Handles cursor scheme detection and changing
 * Core functionality for cursor scheme management
 */
#Include %A_ScriptDir%\lib\RegistryHelper.ahk

class CursorManager {
    ; Cursor data
    cursorSchemes := Map()     ; Map of all available cursor schemes
    currentScheme := ""        ; Currently active scheme
    changeHistory := []        ; History of scheme changes

    ; Configuration and utilities
    config := ""
    logger := ""
    registryHelper := ""

    ; Timer handling
    timerHandle := 0
    timerCallback := ""
    isPaused := false
    lastChangeTime := 0

    __New(config, logger) {
        this.config := config
        this.logger := logger
        this.lastChangeTime := A_TickCount

        ; Initialize registry helper
        this.registryHelper := RegistryHelper(this.logger)

        ; Create timer callback
        this.timerCallback := ObjBindMethod(this, "ChangeCursorScheme")

        ; Load available cursor schemes
        this.LoadCursorSchemes()

        ; Get current scheme
        this.currentScheme := this.GetCurrentSchemeName()

        ; Validate available schemes
        if (this.cursorSchemes.Count = 0) {
            MsgBox("No cursor schemes found! The script will exit.", "RandomCursor Error", "Icon!")
            ExitApp()
        }
    }

    /**
     * Loads all available cursor schemes
     */
    LoadCursorSchemes() {
        this.cursorSchemes := Map()
        this.logger.Log("Debug: Scanning for cursor schemes")

        ; Get schemes from registry
        this.LoadSchemesFromRegistry()

        ; Get schemes from file system
        this.LoadSchemesFromFileSystem()

        ; Add default schemes if no schemes were found
        if (this.cursorSchemes.Count = 0) {
            this.AddDefaultSchemes()
        }

        this.logger.Log("Debug: Total schemes found: " this.cursorSchemes.Count)
    }

    /**
     * Loads cursor schemes from registry
     */
    LoadSchemesFromRegistry() {
        try {
            regPath := "HKEY_CURRENT_USER\Control Panel\Cursors\Schemes"
            regSchemes := RegRead(regPath)
            this.logger.Log("Debug: Found " regSchemes.Length " schemes in registry")

            loop parse, regSchemes, "`n", "`r" {
                schemeName := A_LoopField
                if (schemeName != "") {
                    ; Create a basic map for this scheme
                    schemeMap := Map(
                        "SchemeName", schemeName,
                        "Arrow", A_WinDir "\Cursors\aero_arrow.cur",
                        "Wait", A_WinDir "\Cursors\aero_busy.ani"
                        ; Add more default mappings as needed
                    )
                    this.cursorSchemes[schemeName] := schemeMap
                    this.logger.Log("Debug: Added scheme from registry: " schemeName)
                }
            }
        }
        catch as e {
            this.logger.Log("Debug: Registry scan error: " e.Message)
        }
    }

    /**
     * Loads cursor schemes from file system
     */
    LoadSchemesFromFileSystem() {
        cursorsPath := A_WinDir "\Cursors"

        try {
            loop files, cursorsPath "\*", "D" {
                if !DirExist(A_LoopFilePath)
                    continue

                schemeName := A_LoopFileName
                this.logger.Log("Debug: Found cursor folder: " schemeName)

                schemeMap := Map(
                    "SchemeName", schemeName,
                    "AppStarting", Format("{}\{}\Working.ani", cursorsPath, schemeName),
                    "Arrow", Format("{}\{}\Normal.ani", cursorsPath, schemeName),
                    "Crosshair", Format("{}\{}\Precision.ani", cursorsPath, schemeName),
                    "Hand", Format("{}\{}\Link.ani", cursorsPath, schemeName),
                    "Help", Format("{}\{}\Help.ani", cursorsPath, schemeName),
                    "IBeam", Format("{}\{}\Text.ani", cursorsPath, schemeName),
                    "No", Format("{}\{}\Unavailable.ani", cursorsPath, schemeName),
                    "NWPen", Format("{}\{}\Handwriting.ani", cursorsPath, schemeName),
                    "Person", Format("{}\{}\Person.ani", cursorsPath, schemeName),
                    "Pin", Format("{}\{}\Pin.ani", cursorsPath, schemeName),
                    "SizeAll", Format("{}\{}\Move.ani", cursorsPath, schemeName),
                    "SizeNESW", Format("{}\{}\Diagonal2.ani", cursorsPath, schemeName),
                    "SizeNS", Format("{}\{}\Vertical.ani", cursorsPath, schemeName),
                    "SizeNWSE", Format("{}\{}\Diagonal1.ani", cursorsPath, schemeName),
                    "SizeWE", Format("{}\{}\Horizontal.ani", cursorsPath, schemeName),
                    "UpArrow", Format("{}\{}\Alternate.ani", cursorsPath, schemeName),
                    "Wait", Format("{}\{}\Busy.ani", cursorsPath, schemeName)
                )

                ; Verify files exist and substitute with static cursors if needed
                validCursors := this.ValidateSchemeFiles(schemeMap)

                ; Only add scheme if it has at least some valid cursors
                if (validCursors > 0) {
                    this.cursorSchemes[schemeName] := schemeMap
                    this.logger.Log("Debug: Added folder scheme: " schemeName " with " validCursors " valid cursors")
                }
            }
        }
        catch as e {
            MsgBox("Error scanning cursor schemes: " e.Message, "RandomCursor Error", "Icon!")
            this.logger.Log("Debug: File scan error: " e.Message)
        }
    }

    /**
     * Validates cursor files and substitutes missing ones
     * @param schemeMap - Map of cursor types to file paths
     * @return Number of valid cursors
     */
    ValidateSchemeFiles(schemeMap) {
        validCursors := 0

        for key, path in schemeMap.Clone() {
            ; Skip SchemeName entry
            if (key = "SchemeName")
                continue

            if FileExist(path) {
                validCursors++
                continue
            }

            ; Try .cur extension instead of .ani
            altPath := RegExReplace(path, "\.ani$", ".cur")
            if FileExist(altPath) {
                schemeMap[key] := altPath
                validCursors++
            } else {
                ; Use system default cursor as fallback
                defaultCursor := A_WinDir "\Cursors\" key ".cur"
                if FileExist(defaultCursor) {
                    schemeMap[key] := defaultCursor
                    validCursors++
                }
            }
        }

        return validCursors
    }

    /**
     * Adds default schemes when no others are found
     */
    AddDefaultSchemes() {
        this.logger.Log("Debug: No schemes found, adding defaults")

        ; Add Windows Default scheme
        this.cursorSchemes["Windows Default"] := Map(
            "SchemeName", "Windows Default",
            "Arrow", A_WinDir "\Cursors\arrow_r.cur",
            "Help", A_WinDir "\Cursors\help_r.cur",
            "Wait", A_WinDir "\Cursors\busy_r.cur",
            "IBeam", A_WinDir "\Cursors\beam_r.cur"
        )

        ; Add Windows Aero scheme
        this.cursorSchemes["Windows Aero"] := Map(
            "SchemeName", "Windows Aero",
            "Arrow", A_WinDir "\Cursors\aero_arrow.cur",
            "Wait", A_WinDir "\Cursors\aero_busy.ani",
            "IBeam", A_WinDir "\Cursors\aero_beam.cur",
            "Help", A_WinDir "\Cursors\aero_helpsel.cur"
        )
    }

    /**
     * Determines the currently active cursor scheme
     * @return Name of current scheme or empty string if unknown
     */
    GetCurrentSchemeName() {
        try {
            ; Use registry helper to get current cursor settings
            currentSettings := this.registryHelper.GetCurrentCursorSettings()

            ; Get current cursor location from registry
            if (currentSettings.Has("Arrow")) {
                currentPath := currentSettings["Arrow"]

                ; Extract folder name from path
                if RegExMatch(currentPath, "\\Cursors\\([^\\]+)\\", &match)
                    return match[1]
            }
        }
        catch {
            ; Silently fail and return empty
        }
        return ""
    }

    /**
     * Changes to a random cursor scheme
     * @param p* - Optional parameters (unused, for timer compatibility)
     */
    ChangeCursorScheme(p*) {
        static attempts := 0
        static MAX_ATTEMPTS := 10

        ; Reset attempts if called directly (not recursively)
        if (p.Length == 0)
            attempts := 0

        if (attempts >= MAX_ATTEMPTS) {
            if (this.config.enableNotifications)
                TrayTip("Error", "Failed to find different scheme after multiple attempts", 1)
            this.logger.Log("Failed to change cursor scheme after " MAX_ATTEMPTS " attempts")
            attempts := 0
            return
        }

        attempts++

        ; Debug output
        this.logger.Log("Debug: Starting cursor change. Current scheme: " this.currentScheme)

        ; Ensure schemes are loaded
        if (this.cursorSchemes.Count = 0) {
            this.LoadCursorSchemes() ; Reload schemes if none are available
        }

        ; Get available schemes
        availableSchemes := this.GetAvailableSchemes()

        if (availableSchemes.Length = 0) {
            if (this.config.enableNotifications)
                TrayTip("Error", "No other cursor schemes available", 1)
            this.logger.Log("No other cursor schemes available")
            return
        }

        ; Select and apply random scheme
        this.ApplyRandomScheme(availableSchemes)

        this.lastChangeTime := A_TickCount
    }

    /**
     * Gets list of available schemes (excluding current and excluded)
     * @return Array of available scheme names
     */
    GetAvailableSchemes() {
        availableSchemes := []

        for schemeName, _ in this.cursorSchemes {
            if (!this.config.IsSchemeExcluded(schemeName)) {
                if (schemeName != this.currentScheme || this.cursorSchemes.Count = 1) {
                    availableSchemes.Push(schemeName)
                    this.logger.Log("Debug: Added to available: " schemeName)
                }
            }
        }

        return availableSchemes
    }

    /**
     * Selects and applies a random scheme from the available ones
     * @param availableSchemes - Array of available scheme names
     */
    ApplyRandomScheme(availableSchemes) {
        ; Select random scheme
        randomIndex := Random(1, availableSchemes.Length)
        selectedSchemeName := availableSchemes[randomIndex]
        selectedScheme := this.cursorSchemes[selectedSchemeName]

        this.logger.Log("Debug: Selected scheme: " selectedSchemeName)

        ; Apply the scheme using batch registry updates
        try {
            ; Use registry helper for batch updates
            if (!this.registryHelper.ApplyCursorSchemeBatch(selectedScheme)) {
                this.logger.Log("Error: Failed to apply cursor scheme batch update")
                this.ChangeCursorScheme()
                return
            }

            ; Apply system changes
            this.registryHelper.ApplyCursorChanges()

            ; Update history
            this.AddToHistory(selectedSchemeName)

            ; Update current scheme
            this.currentScheme := selectedSchemeName

            ; Notify user
            if (this.config.enableNotifications)
                TrayTip("Cursor Scheme Changed", "New scheme: " selectedSchemeName, 1)

            this.logger.Log("Changed cursor scheme to: " selectedSchemeName)
        }
        catch as e {
            this.logger.Log("Error applying cursor scheme: " e.Message)
            this.ChangeCursorScheme()
        }
    }

    /**
     * Adds a scheme change to the history
     * @param schemeName - Name of the scheme that was applied
     */
    AddToHistory(schemeName) {
        this.changeHistory.Push({
            scheme: schemeName,
            time: FormatTime(, "yyyy-MM-dd HH:mm:ss")
        })

        ; Limit history length
        if (this.changeHistory.Length > 50)
            this.changeHistory.RemoveAt(1)
    }

    /**
     * Starts the timer for automatic cursor changes
     */
    StartTimer() {
        if (this.timerHandle)
            SetTimer(this.timerHandle, 0) ; Clear existing timer

        SetTimer(this.timerCallback, this.config.changeInterval * 1000)
        this.timerHandle := this.timerCallback
        this.logger.Log("Timer started - Interval: " this.config.changeInterval " seconds")
    }

    /**
     * Toggles the timer between paused and running states
     * @return Current pause state after toggle
     */
    ToggleTimer() {
        if (!this.isPaused) {
            if (this.timerHandle)
                SetTimer(this.timerHandle, 0)

            if (this.config.enableNotifications)
                TrayTip("RandomCursor", "Timer paused", 1)

            this.logger.Log("Timer paused")
        } else {
            this.StartTimer()

            if (this.config.enableNotifications)
                TrayTip("RandomCursor", "Timer resumed", 1)

            this.logger.Log("Timer resumed")
        }

        this.isPaused := !this.isPaused
        return this.isPaused
    }

    /**
     * Gets the number of available cursor schemes
     * @return Number of schemes
     */
    GetSchemeCount() {
        return this.cursorSchemes.Count
    }

    /**
     * Gets all cursor scheme names
     * @return Array of scheme names
     */
    GetSchemeNames() {
        schemeNames := []
        for schemeName, _ in this.cursorSchemes {
            schemeNames.Push(schemeName)
        }
        return schemeNames
    }

    /**
     * Gets the change history
     * @return Array of history entries
     */
    GetHistory() {
        return this.changeHistory
    }

    CleanupUnusedSchemes() {
        ; Only keep the current scheme and a small cache of recently used schemes
        if (this.changeHistory.Length <= 5)
            return  ; Not enough history to clean up

        ; Get list of recently used schemes (last 5)
        recentSchemes := []
        maxRecent := Min(5, this.changeHistory.Length)

        loop maxRecent {
            index := this.changeHistory.Length - A_Index + 1
            if (index > 0)
                recentSchemes.Push(this.changeHistory[index].scheme)
        }

        ; Add current scheme to preserved list
        if (!this.HasValue(recentSchemes, this.currentScheme))
            recentSchemes.Push(this.currentScheme)

        ; Create a new map with only needed schemes
        cleanedSchemes := Map()
        for schemeName, schemeData in this.cursorSchemes {
            if (this.HasValue(recentSchemes, schemeName)) {
                cleanedSchemes[schemeName] := schemeData
                continue
            }

            ; Always keep important system schemes
            if (schemeName = "Windows Default" || schemeName = "Windows Aero") {
                cleanedSchemes[schemeName] := schemeData
            }
        }

        ; Check if we're not removing too many schemes
        if (cleanedSchemes.Count >= 3) {
            this.cursorSchemes := cleanedSchemes
            this.logger.Log("Memory cleanup: Reduced to " cleanedSchemes.Count " schemes")
        } else {
            this.logger.Log("Memory cleanup: Skipped - not enough schemes to remove")
        }
    }

    HasValue(arr, value) {
        if (!IsObject(arr))
            return false

        for item in arr {
            if (item = value)
                return true
        }
        return false
    }
}
