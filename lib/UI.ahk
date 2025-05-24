#Requires AutoHotkey v2.0
/**
 * UI.ahk - User interface components for RandomCursor++
 * Handles GUI creation and user interaction
 */
class UI {
    ; Main components
    config := ""
    cursorManager := ""
    logger := ""

    ; GUI components
    settingsGui := ""
    intervalEdit := ""
    notificationsCheckbox := ""
    logChangesCheckbox := ""
    schemeListBox := ""

    ; Status display components
    statusText := ""
    timerText := ""
    updateTimer := ""

    ; Hotkey components
    hotkeyChangeEdit := ""
    hotkeyPauseEdit := ""
    hotkeySettingsEdit := ""
    isCapturingHotkey := false
    currentCaptureControl := ""

    ; Preview components
    previewControls := Map()
    previewImages := []
    currentPreviewScheme := ""
    previewGdipToken := 0  ; Store GDI+ token for proper cleanup

    ; Preview constants
    static PREVIEW_TYPES := ["Arrow", "Wait", "Hand", "IBeam", "Help"]
    static PREVIEW_LABELS := ["Normal", "Busy", "Link", "Text", "Help"]
    static PREVIEW_SIZE := 32  ; Size of preview images

    __New(config, cursorManager, logger) {
        this.config := config
        this.cursorManager := cursorManager
        this.logger := logger

        ; Setup tray menu
        this.SetupTrayMenu()

        ; Initialize GDI+ once at startup
        this.previewGdipToken := this.InitializeGdiPlus()
    }

    /**
     * Sets up the system tray menu
     */
    SetupTrayMenu() {
        ; Create tray menu
        A_TrayMenu.Delete() ; Clear default menu
        A_TrayMenu.Add("Show Settings", this.ShowSettingsGUI.Bind(this))
        A_TrayMenu.Add("Change Now", this.cursorManager.ChangeCursorScheme.Bind(this.cursorManager))
        A_TrayMenu.Add("Pause Timer", this.ToggleTimerTray.Bind(this))
        A_TrayMenu.Add("Clean Memory", this.CleanMemory.Bind(this))
        A_TrayMenu.Add()
        A_TrayMenu.Add("Exit", (*) => ExitApp())
        A_TrayMenu.Default := "Show Settings"
    }

    /**
     * Toggles the timer and updates tray menu text
     */
    ToggleTimerTray(*) {
        isPaused := this.cursorManager.ToggleTimer()

        ; Update menu text based on state
        if (isPaused) {
            A_TrayMenu.Rename("Pause Timer", "Resume Timer")
        } else {
            A_TrayMenu.Rename("Resume Timer", "Pause Timer")
        }
    }

    /**
     * Shows the settings GUI
     */
    ShowSettingsGUI(*) {
        ; Create settings window with standard window controls - adding +DPIScale for proper scaling
        this.settingsGui := Gui("+Resize +MinSize400x450 +Caption +SysMenu")
        this.settingsGui.Title := "RandomCursor++ Settings"
        this.settingsGui.SetFont("s10", "Segoe UI")
        this.settingsGui.OnEvent("Close", this.CloseSettings.Bind(this))
        this.settingsGui.OnEvent("Escape", this.CloseSettings.Bind(this))
        this.settingsGui.BackColor := this.GetWindowBackgroundColor()  ; Get system background color

        ; Make the window movable by setting +LastFound and WS_THICKFRAME style
        WinSetExStyle("+0x20000", this.settingsGui)  ; WS_EX_STATICEDGE for better border visibility
        WinSetStyle("+0x40000", this.settingsGui)    ; WS_THICKFRAME to ensure resizability

        ; General settings
        this.settingsGui.Add("GroupBox", "x10 y10 w280 h120", "General Settings")

        this.settingsGui.Add("Text", "x20 y35", "Change Interval (seconds):")
        this.intervalEdit := this.settingsGui.Add("Edit", "x180 y32 w100", this.config.changeInterval)

        this.notificationsCheckbox := this.settingsGui.Add("CheckBox", "x20 y65 w260", "Enable Notifications")
        this.notificationsCheckbox.Value := this.config.enableNotifications

        this.logChangesCheckbox := this.settingsGui.Add("CheckBox", "x20 y95 w260", "Log Cursor Changes")
        this.logChangesCheckbox.Value := this.config.logChanges

        this.AddHotkeyConfigSection(300, 380, 300, 150)

        ; Cursor schemes (increased height to accommodate all elements)
        this.settingsGui.Add("GroupBox", "x10 y140 w280 h260", "Cursor Schemes")

        ; Status display
        this.settingsGui.Add("Text", "x20 y160", "Current Scheme:")
        this.statusText := this.settingsGui.Add("Text", "x20 y180 w260 h20 +Center", this.cursorManager.currentScheme)
        this.statusText.SetFont("bold")

        this.settingsGui.Add("Text", "x20 y205", "Next Change In:")
        this.timerText := this.settingsGui.Add("Text", "x130 y205 w150 h20 +Right", "")
        this.timerText.SetFont("bold")

        ; Separator line
        this.settingsGui.Add("Text", "x20 y230 w260 h2 +0x10")  ; SS_SUNKEN

        ; Available schemes list (adjusted height)
        this.settingsGui.Add("Text", "x20 y240", "Available Schemes:")
        this.schemeListBox := this.settingsGui.Add("ListBox", "x20 y260 w260 h120 Multi")

        ; Set up scheme selection event
        this.schemeListBox.OnEvent("Change", this.OnSchemeSelect.Bind(this))

        ; Add schemes to listbox
        this.PopulateSchemeListBox()

        ; Set up timer to update status display
        this.updateTimer := ObjBindMethod(this, "UpdateStatusDisplay")
        SetTimer(this.updateTimer, 1000)

        ; Preview section - with background color matching the GUI
        previewGroupBox := this.settingsGui.Add("GroupBox", "x300 y10 w300 h350", "Cursor Preview")
        previewBgColor := this.GetWindowBackgroundColor()

        ; Add preview controls for each cursor type
        startY := 30
        loop UI.PREVIEW_TYPES.Length {
            cursorType := UI.PREVIEW_TYPES[A_Index]
            labelText := UI.PREVIEW_LABELS[A_Index]

            ; Add label
            this.settingsGui.Add("Text", "x310 y" startY + 5, labelText ":")

            ; Add picture control for preview with proper background color
            picCtrl := this.settingsGui.Add("Picture", "x400 y" startY " w" UI.PREVIEW_SIZE " h" UI.PREVIEW_SIZE)

            ; Store control reference
            this.previewControls[cursorType] := picCtrl

            ; Increment Y position for next control
            startY += 60
        }

        ; Add "Apply This Scheme" button under preview
        applySchemeBtn := this.settingsGui.Add("Button", "x330 y" (startY + 10) " w190 h30", "Apply Selected Scheme")
        applySchemeBtn.OnEvent("Click", this.ApplySelectedScheme.Bind(this))

        ; History button
        viewHistoryBtn := this.settingsGui.Add("Button", "x10 y410 w135 h30", "View History")
        viewHistoryBtn.OnEvent("Click", this.ShowHistoryGUI.Bind(this))

        ; Control buttons
        saveBtn := this.settingsGui.Add("Button", "x155 y410 w135 h30", "Save Settings")
        saveBtn.OnEvent("Click", this.SaveSettings.Bind(this))

        changeBtn := this.settingsGui.Add("Button", "x10 y450 w135 h30", "Change Now")
        changeBtn.OnEvent("Click", (*) => this.cursorManager.ChangeCursorScheme())

        closeBtn := this.settingsGui.Add("Button", "x155 y450 w135 h30", "Close")
        closeBtn.OnEvent("Click", this.CloseSettings.Bind(this))

        ; Add Clean Memory button
        memoryBtn := this.settingsGui.Add("Button", "x10 y490 w280 h30", "Clean Memory")
        memoryBtn.OnEvent("Click", this.CleanMemory.Bind(this))

        ; Set up GUI close event
        this.settingsGui.OnEvent("Close", this.CloseSettings.Bind(this))

        ; Show the GUI
        this.settingsGui.Show("w610 h530")  ; Increased width to accommodate preview area

        ; Show current scheme
        this.UpdatePreviewForScheme(this.cursorManager.currentScheme)
    }

    /**
     * Get the current system window background color
     * @return Hex color code for background
     */
    GetWindowBackgroundColor() {
        ; Get system color for window background (COLOR_WINDOW = 5)
        bgColor := DllCall("GetSysColor", "Int", 5, "UInt")

        ; Convert to RGB format
        r := bgColor & 0xFF
        g := (bgColor >> 8) & 0xFF
        b := (bgColor >> 16) & 0xFF

        return Format("0x{:06X}", (r << 16) | (g << 8) | b)
    }

    /**
     * Initialize GDI+ for image handling
     * @return GDI+ token for later shutdown
     */
    InitializeGdiPlus() {
        ; Initialize GDI+ if not already loaded
        if !DllCall("GetModuleHandle", "str", "gdiplus", "Ptr")
            DllCall("LoadLibrary", "str", "gdiplus")

        si := Buffer(24, 0)
        NumPut("UInt", 1, si)  ; Version
        token := 0
        DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", si, "Ptr", 0)

        this.logger.Log("GDI+ initialized with token: " token)
        return token
    }

    /**
     * Shutdown GDI+ properly
     * @param token - GDI+ token to shutdown
     */
    ShutdownGdiPlus(token) {
        if (token) {
            DllCall("gdiplus\GdiplusShutdown", "Ptr", token)
            this.logger.Log("GDI+ shut down, token: " token)
        }
    }

    /**
     * Handler for closing settings GUI
     * Cleans up preview resources
     */
    CloseSettings(*) {
        ; Stop the update timer
        if (this.updateTimer)
            SetTimer(this.updateTimer, 0)

        ; Clean up preview images
        this.CleanupPreviewImages()

        ; Destroy GUI
        this.settingsGui.Destroy()
    }

    /**
     * Cleans up preview image resources
     */
    CleanupPreviewImages() {
        ; Delete any temporary preview images
        for index, filePath in this.previewImages {
            try {
                if FileExist(filePath)
                    FileDelete(filePath)
            }
            catch as e {
                this.logger.Log("Failed to delete temp preview: " e.Message)
            }
        }

        ; Clear the array
        this.previewImages := []
    }

    /**
     * Event handler for scheme selection change
     */
    OnSchemeSelect(*) {
        ; Get selected items directly from ListBox
        try {
            ; Get all selected items
            selected := this.schemeListBox.Text  ; Gets array of selected items' text

            if (selected.Length > 0) {
                ; Use the first selected item's text directly
                selectedScheme := selected[1]
                this.UpdatePreviewForScheme(selectedScheme)
            }
        }
        catch as err {
            this.logger.Log("Selection error: " err.Message)
        }
    }

    /**
     * Updates preview images for the specified scheme
     * @param schemeName - Name of the scheme to preview
     */
    UpdatePreviewForScheme(schemeName) {
        ; Skip if already showing this scheme
        if (this.currentPreviewScheme = schemeName)
            return

        this.logger.Log("Updating preview for scheme: " schemeName)

        ; Clean up previous preview images first
        this.CleanupPreviewImages()

        ; Get scheme data
        schemeData := this.cursorManager.cursorSchemes.Get(schemeName, false)
        if (!schemeData) {
            this.logger.Log("Scheme not found: " schemeName)
            return
        }

        ; Store current preview scheme
        this.currentPreviewScheme := schemeName

        ; Update each preview control
        for cursorType in UI.PREVIEW_TYPES {
            ; Clear existing preview
            this.previewControls[cursorType].Value := ""

            ; Get cursor file path
            cursorPath := schemeData.Get(cursorType, "")

            ; Skip if cursor not found
            if (!cursorPath || !FileExist(cursorPath))
                continue

            ; Create new preview
            previewPath := this.CreateCursorPreview(cursorPath, cursorType)
            if (previewPath)
                this.previewControls[cursorType].Value := previewPath
        }
    }

    /**
     * Creates a preview image from a cursor file
     * @param cursorPath - Path to cursor file
     * @param cursorType - Type of cursor
     * @return Path to preview image or empty if failed
     */
    CreateCursorPreview(cursorPath, cursorType) {
        ; Create a temporary file for the preview
        tempFile := A_Temp "\rcpp_preview_" cursorType "_" A_TickCount ".png"

        try {
            ; Extract icon/cursor image using improved method for transparency
            bgColor := this.GetWindowBackgroundColor()

            ; Choose the appropriate extraction method
            fileExt := this.GetFileExtension(cursorPath)
            success := false

            if (fileExt = ".ani") {
                ; Animated cursor
                success := this.ExtractAnimatedCursorWithTransparency(cursorPath, tempFile, bgColor)
            } else {
                ; Static cursor or icon
                success := this.ExtractCursorWithTransparency(cursorPath, tempFile, bgColor)
            }

            ; Check if file was created
            if (success && FileExist(tempFile)) {
                ; Add to preview images list for cleanup later
                this.previewImages.Push(tempFile)
                return tempFile
            }
        }
        catch as e {
            this.logger.Log("Preview creation failed for " cursorPath ": " e.Message)
        }

        return ""
    }

    /**
     * Extract file extension from path
     * @param filePath - Path to file
     * @return File extension including dot
     */
    GetFileExtension(filePath) {
        if (InStr(filePath, ".")) {
            return SubStr(filePath, InStr(filePath, ".", 0, -1))
        }
        return ""
    }

    /**
     * Extracts cursor with proper transparency support
     * @param cursorPath - Path to cursor file
     * @param outputPath - Path to save preview image
     * @param bgColor - Background color (hex) to use
     * @return True if successful
     */
    ExtractCursorWithTransparency(cursorPath, outputPath, bgColor) {
        hCursor := 0
        hBitmap := 0
        pBitmap := 0
        hdcMem := 0
        success := false

        try {
            ; Convert hex background color to RGB
            bgR := (bgColor >> 16) & 0xFF
            bgG := (bgColor >> 8) & 0xFF
            bgB := bgColor & 0xFF

            ; Try to load cursor/icon
            hCursor := DllCall("LoadCursorFromFile", "Str", cursorPath, "Ptr")
            if (!hCursor) {
                hCursor := DllCall("LoadImage", "Ptr", 0, "Str", cursorPath, "UInt", 1,
                    "Int", UI.PREVIEW_SIZE, "Int", UI.PREVIEW_SIZE, "UInt", 0x10, "Ptr")
            }

            if (!hCursor) {
                this.logger.Log("Failed to load cursor: " cursorPath)
                return false
            }

            ; Create device context and DIB for better transparency handling
            hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
            hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")

            ; Create 32-bit bitmap with alpha channel
            bi := Buffer(40, 0)
            NumPut("UInt", 40, bi, 0)                ; Size
            NumPut("Int", UI.PREVIEW_SIZE, bi, 4)    ; Width
            NumPut("Int", UI.PREVIEW_SIZE, bi, 8)    ; Height
            NumPut("UShort", 1, bi, 12)              ; Planes
            NumPut("UShort", 32, bi, 14)             ; BitCount
            NumPut("UInt", 0, bi, 16)                ; Compression (BI_RGB)

            hBitmap := DllCall("CreateDIBSection", "Ptr", hdcMem, "Ptr", bi, "UInt", 0,
                "Ptr*", &pBits := 0, "Ptr", 0, "UInt", 0, "Ptr")

            if (!hBitmap) {
                this.logger.Log("Failed to create DIB section")
                return false
            }

            ; Select bitmap into DC
            hOldBitmap := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBitmap, "Ptr")

            ; Fill with background color
            brush := DllCall("CreateSolidBrush", "UInt", (bgB << 16) | (bgG << 8) | bgR, "Ptr")
            DllCall("FillRect", "Ptr", hdcMem, "Ptr", Buffer(16, 0).Ptr, "Ptr", brush)
            DllCall("DeleteObject", "Ptr", brush)

            ; Draw cursor with transparency
            DllCall("DrawIconEx", "Ptr", hdcMem, "Int", 0, "Int", 0, "Ptr", hCursor,
                "Int", UI.PREVIEW_SIZE, "Int", UI.PREVIEW_SIZE, "UInt", 0, "Ptr", 0, "UInt", 3)

            ; Convert to GDI+ bitmap
            pBitmap := 0
            DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hBitmap, "Ptr", 0, "Ptr*", &pBitmap)

            if (pBitmap) {
                ; Create encoder CLSID for PNG (which supports transparency)
                CLSID := Buffer(16, 0)
                DllCall("ole32\CLSIDFromString", "Str", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", CLSID)

                ; Convert path to UTF-16
                StrPutBuf := Buffer(StrPut(outputPath, "UTF-16") * 2, 0)
                StrPut(outputPath, StrPutBuf, "UTF-16")

                ; Save as PNG
                result := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "Ptr", StrPutBuf, "Ptr", CLSID, "Ptr",
                    0)
                success := (result = 0)

                ; Cleanup GDI+ bitmap
                DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
            }

            ; Cleanup GDI objects
            DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hOldBitmap)
        }
        catch as e {
            this.logger.Log("Extract cursor error: " e.Message)
            success := false
        }
        finally {
            ; Clean up resources
            if (hBitmap)
                DllCall("DeleteObject", "Ptr", hBitmap)
            if (hdcMem)
                DllCall("DeleteDC", "Ptr", hdcMem)
            if (hCursor)
                DllCall("DestroyCursor", "Ptr", hCursor)
        }

        return success
    }

    /**
     * Extracts animated cursor with proper transparency
     * @param cursorPath - Path to cursor file
     * @param outputPath - Path to save preview image
     * @param bgColor - Background color (hex) to use
     * @return True if successful
     */
    ExtractAnimatedCursorWithTransparency(cursorPath, outputPath, bgColor) {
        ; For animated cursors, we'll extract the first frame
        ; We'll use LoadCursor to safely get the first frame

        ; Convert hex background color to RGB
        bgR := (bgColor >> 16) & 0xFF
        bgG := (bgColor >> 8) & 0xFF
        bgB := bgColor & 0xFF

        hCursor := 0
        hdcMem := 0
        hBitmap := 0
        pBitmap := 0
        success := false

        try {
            ; Try multiple methods to load the animated cursor
            hCursor := DllCall("LoadCursorFromFile", "Str", cursorPath, "Ptr")

            if (!hCursor) {
                ; Alternative method for ANI files using ExtractIcon
                hInstance := DllCall("GetModuleHandle", "Ptr", 0, "Ptr")
                hCursor := DllCall("Shell32\ExtractIconW", "Ptr", hInstance, "Str", cursorPath, "UInt", 0, "Ptr")
            }

            if (!hCursor) {
                this.logger.Log("Failed to load animated cursor: " cursorPath)
                return false
            }

            ; Create DC for drawing
            hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
            hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")

            ; Create bitmap with alpha channel
            bi := Buffer(40, 0)
            NumPut("UInt", 40, bi, 0)                ; Size
            NumPut("Int", UI.PREVIEW_SIZE, bi, 4)    ; Width
            NumPut("Int", UI.PREVIEW_SIZE, bi, 8)    ; Height
            NumPut("UShort", 1, bi, 12)              ; Planes
            NumPut("UShort", 32, bi, 14)             ; BitCount
            NumPut("UInt", 0, bi, 16)                ; Compression (BI_RGB)

            hBitmap := DllCall("CreateDIBSection", "Ptr", hdcMem, "Ptr", bi, "UInt", 0,
                "Ptr*", &pBits := 0, "Ptr", 0, "UInt", 0, "Ptr")

            ; Select bitmap into DC
            hOldBitmap := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBitmap, "Ptr")

            ; Fill with background color
            brush := DllCall("CreateSolidBrush", "UInt", (bgB << 16) | (bgG << 8) | bgR, "Ptr")
            rect := Buffer(16, 0)
            NumPut("Int", 0, rect, 0)                ; left
            NumPut("Int", 0, rect, 4)                ; top
            NumPut("Int", UI.PREVIEW_SIZE, rect, 8)  ; right
            NumPut("Int", UI.PREVIEW_SIZE, rect, 12) ; bottom
            DllCall("FillRect", "Ptr", hdcMem, "Ptr", rect, "Ptr", brush)
            DllCall("DeleteObject", "Ptr", brush)

            ; Draw cursor with transparency
            DllCall("DrawIconEx", "Ptr", hdcMem, "Int", 0, "Int", 0, "Ptr", hCursor,
                "Int", UI.PREVIEW_SIZE, "Int", UI.PREVIEW_SIZE, "UInt", 0, "Ptr", 0, "UInt", 3)

            ; Create GDI+ bitmap from the drawn image
            pBitmap := 0
            DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hBitmap, "Ptr", 0, "Ptr*", &pBitmap)

            if (pBitmap) {
                ; Save as PNG with transparency
                CLSID := Buffer(16, 0)
                DllCall("ole32\CLSIDFromString", "Str", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", CLSID)

                StrPutBuf := Buffer(StrPut(outputPath, "UTF-16") * 2, 0)
                StrPut(outputPath, StrPutBuf, "UTF-16")

                result := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "Ptr", StrPutBuf, "Ptr", CLSID, "Ptr",
                    0)
                success := (result = 0)

                ; Cleanup GDI+ bitmap
                DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
            }

            ; Cleanup GDI resources
            DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hOldBitmap)
        }
        catch as e {
            this.logger.Log("Extract animated cursor error: " e.Message)
            success := false
        }
        finally {
            ; Clean up resources
            if (hBitmap)
                DllCall("DeleteObject", "Ptr", hBitmap)
            if (hdcMem)
                DllCall("DeleteDC", "Ptr", hdcMem)
            if (hCursor)
                DllCall("DestroyCursor", "Ptr", hCursor)
        }

        return success
    }

    /**
     * Applies the currently selected scheme immediately
     */
    ApplySelectedScheme(*) {
        try {
            ; Get selected items
            selected := this.schemeListBox.Text

            if (selected.Length = 0) {
                MsgBox("Please select a cursor scheme first.", "No Scheme Selected", "Icon!")
                return
            }

            ; Use first selected scheme
            selectedScheme := selected[1]
            schemeData := this.cursorManager.cursorSchemes.Get(selectedScheme, false)

            if (!schemeData) {
                MsgBox("Selected scheme data not found.", "Error", "Icon!")
                return
            }

            ; Apply the scheme
            this.logger.Log("Manually applying scheme: " selectedScheme)
            availableSchemes := [selectedScheme]
            this.cursorManager.ApplyRandomScheme(availableSchemes)

            ; Notify user
            if (this.config.enableNotifications)
                TrayTip("Cursor Scheme Applied", "Now using: " selectedScheme, 1)
        }
        catch as err {
            this.logger.Log("Apply scheme error: " err.Message)
            MsgBox("Error applying scheme: " err.Message, "Error", "Icon!")
        }
    }

    /**
     * Populates the scheme list box with available schemes
     */
    PopulateSchemeListBox() {
        schemeNames := this.cursorManager.GetSchemeNames()

        schemeCount := 0
        for _, schemeName in schemeNames {
            this.schemeListBox.Add([schemeName])
            schemeCount++
            if this.config.IsSchemeExcluded(schemeName)
                this.schemeListBox.Choose(schemeCount)
        }

        this.logger.Log("Debug: Added " schemeCount " schemes to listbox")
    }

    /**
     * Shows the cursor change history GUI
     */
    ShowHistoryGUI(*) {
        historyGui := Gui("+Caption +Resize", "Cursor Change History")
        historyGui.SetFont("s10")

        ; Create ListView
        lv := historyGui.Add("ListView", "x10 y10 w380 h300", ["Time", "Cursor Scheme"])
        lv.ModifyCol(1, 150)
        lv.ModifyCol(2, 200)

        ; Get history data
        history := this.cursorManager.GetHistory()

        ; Add history items in reverse order (newest first)
        loop history.Length {
            index := history.Length - A_Index + 1
            item := history[index]
            lv.Add(, item.time, item.scheme)
        }

        ; Control button
        closeBtn := historyGui.Add("Button", "x310 y320 w80 h30", "Close")
        closeBtn.OnEvent("Click", (*) => historyGui.Destroy())

        ; Show the GUI
        historyGui.Show("w400 h360")
    }

    /**
     * Saves settings from the GUI with enhanced debugging and error handling
     */
    SaveSettings(*) {
        ; Get values from GUI controls
        newInterval := Integer(this.intervalEdit.Value)
        enableNotifications := this.notificationsCheckbox.Value
        logChanges := this.logChangesCheckbox.Value

        ; Build excluded schemes list
        excludeSchemes := []

        ; Get selected items from ListBox
        try {
            ; Handle both single and multiple selections properly
            selected := this.schemeListBox.Text

            ; If only one item is selected, Text returns a string, not an array
            if (Type(selected) = "String" && selected != "") {
                ; Single selection
                excludeSchemes.Push(selected)
            } else if (IsObject(selected)) {
                ; Multiple selections
                for _, itemText in selected {
                    excludeSchemes.Push(itemText)
                }
            }

            this.logger.Log("Selected schemes for exclusion: " excludeSchemes.Length)
        } catch as err {
            this.logger.Log("Error processing selections: " err.Message)
        }

        ; Get hotkey values
        changeHotkey := this.hotkeyChangeEdit.Value
        pauseHotkey := this.hotkeyPauseEdit.Value
        settingsHotkey := this.hotkeySettingsEdit.Value

        ; IMPORTANT FIX: First unregister all existing hotkeys BEFORE updating the config
        global app
        if (app.hotkeyManager) {
            this.logger.Log("UI: Unregistering all existing hotkeys before config update")
            ; app.hotkeyManager.UnregisterAllHotkeys()
        }

        if (!app.hotkeyManager) {
            this.logger.Log("UI: ERROR - app.hotkeyManager not found!")
            MsgBox("Error: Hotkey manager not available. Hotkeys may not work.", "Error", "Icon!")
            return
        }

        ; Update configuration
        if (!this.config.UpdateSettings(newInterval, enableNotifications, logChanges, excludeSchemes,
            changeHotkey, pauseHotkey, settingsHotkey))
            return ; UpdateSettings returns false if validation failed

        ; Verify config was updated correctly
        this.logger.Log("UI: Config after update:")
        this.logger.Log("  - changeHotkey: " (this.config.changeHotkey ? this.config.changeHotkey : "none"))
        this.logger.Log("  - pauseHotkey: " (this.config.pauseHotkey ? this.config.pauseHotkey : "none"))
        this.logger.Log("  - settingsHotkey: " (this.config.settingsHotkey ? this.config.settingsHotkey : "none"))

        ; Re-register hotkeys with updated configuration
        try {
            this.logger.Log("UI: Re-registering hotkeys with new configuration")
            app.hotkeyManager.RegisterHotkeys()
        } catch as err {
            this.logger.Log("UI: Exception when re-registering hotkeys: " err.Message)
            MsgBox("Error re-registering hotkeys: " err.Message, "Error", "Icon!")
        }

        ; Restart timer with new interval
        this.cursorManager.StartTimer()

        ; Notify user
        if (this.config.enableNotifications)
            TrayTip("Settings Saved", "New settings applied", 1)

        ; Close settings window
        this.CloseSettings()
    }

    CleanMemory(*) {
        global app

        ; Display memory usage before cleanup
        memBefore := this.GetMemoryUsage()

        ; First clean up previews to free GDI resources
        this.CleanupPreviewImages()

        ; Run global cleanup
        app.FreeResources()

        ; Display memory usage after cleanup
        memAfter := this.GetMemoryUsage()

        ; Show results
        MsgBox("Memory before: " memBefore " MB`nMemory after: " memAfter " MB", "Memory Cleanup")
    }

    GetMemoryUsage() {
        ; Get process handle
        hProcess := DllCall("OpenProcess", "UInt", 0x400, "Int", false, "UInt", DllCall("GetCurrentProcessId"), "Ptr")

        ; Get memory info
        memoryCounters := Buffer(40, 0)
        NumPut("UInt", memoryCounters.Size, memoryCounters, 0)
        DllCall("K32GetProcessMemoryInfo", "Ptr", hProcess, "Ptr", memoryCounters, "UInt", memoryCounters.Size)

        ; Close handle
        DllCall("CloseHandle", "Ptr", hProcess)

        ; Extract working set size (in MB)
        workingSetSize := NumGet(memoryCounters, 8, "UPtr") / 1024 / 1024
        return Round(workingSetSize, 2)
    }

    UpdateStatusDisplay(*) {
        if (!this.settingsGui || !this.statusText || !this.timerText)
            return

        ; Update current scheme
        this.statusText.Value := this.cursorManager.currentScheme

        ; Calculate and format time until next change
        if (!this.cursorManager.isPaused) {
            ; Get the last change time from CursorManager
            lastChange := this.cursorManager.lastChangeTime
            timeSinceChange := (A_TickCount - lastChange) // 1000
            timeLeft := this.config.changeInterval - timeSinceChange

            hours := Floor(timeLeft / 3600)
            minutes := Floor((timeLeft - (hours * 3600)) / 60)
            seconds := Mod(timeLeft, 60)

            if (hours > 0)
                this.timerText.Value := Format("{:02d}:{:02d}:{:02d}", hours, minutes, seconds)
            else
                this.timerText.Value := Format("{:02d}:{:02d}", minutes, seconds)
        } else {
            this.timerText.Value := "Paused"
        }
    }

    /**
     * Adds hotkey configuration controls to settings GUI
     * @param xPos - X position for controls
     * @param yPos - Y position for controls
     * @param width - Width of the group box
     * @param height - Height of the group box
     */
    AddHotkeyConfigSection(xPos, yPos, width, height) {
        ; Create group box
        this.settingsGui.Add("GroupBox", "x" xPos " y" yPos " w" width " h" height, "Hotkey Configuration")

        ; Change cursor hotkey
        this.settingsGui.Add("Text", "x" (xPos + 10) " y" (yPos + 25), "Change Cursor:")
        this.hotkeyChangeEdit := this.settingsGui.Add("Edit", "x" (xPos + 100) " y" (yPos + 22) " w120 h24 +ReadOnly",
        this.config.changeHotkey)

        captureChangeBtn := this.settingsGui.Add("Button", "x" (xPos + width - 80) " y" (yPos + 22) " w70 h24",
        "Capture")
        captureChangeBtn.OnEvent("Click", (*) => this.CaptureHotkey("change"))

        ; Pause/Resume hotkey
        this.settingsGui.Add("Text", "x" (xPos + 10) " y" (yPos + 55), "Pause/Resume:")
        this.hotkeyPauseEdit := this.settingsGui.Add("Edit", "x" (xPos + 100) " y" (yPos + 52) " w120 h24 +ReadOnly",
        this.config.pauseHotkey)

        capturePauseBtn := this.settingsGui.Add("Button", "x" (xPos + width - 80) " y" (yPos + 52) " w70 h24",
        "Capture")
        capturePauseBtn.OnEvent("Click", (*) => this.CaptureHotkey("pause"))

        ; Settings hotkey
        this.settingsGui.Add("Text", "x" (xPos + 10) " y" (yPos + 85), "Open Settings:")
        this.hotkeySettingsEdit := this.settingsGui.Add("Edit", "x" (xPos + 100) " y" (yPos + 82) " w120 h24 +ReadOnly",
        this.config.settingsHotkey)

        captureSettingsBtn := this.settingsGui.Add("Button", "x" (xPos + width - 80) " y" (yPos + 82) " w70 h24",
        "Capture")
        captureSettingsBtn.OnEvent("Click", (*) => this.CaptureHotkey("settings"))

        ; Clear all button
        clearAllBtn := this.settingsGui.Add("Button", "x" (xPos + 10) " y" (yPos + height - 35) " w" (width - 20) " h24",
        "Clear All Hotkeys")
        clearAllBtn.OnEvent("Click", (*) => this.ClearAllHotkeys())
    }

    /**
     * Starts capturing a hotkey
     * @param target - Which hotkey to capture ("change", "pause", or "settings")
     */
    CaptureHotkey(target) {
        ; Determine which control to update
        if (target = "change") {
            this.currentCaptureControl := this.hotkeyChangeEdit
            this.currentCaptureControl.Value := "Press a key..."
        } else if (target = "pause") {
            this.currentCaptureControl := this.hotkeyPauseEdit
            this.currentCaptureControl.Value := "Press a key..."
        } else if (target = "settings") {
            this.currentCaptureControl := this.hotkeySettingsEdit
            this.currentCaptureControl.Value := "Press a key..."
        } else {
            return
        }

        ; Set capturing state and target
        this.isCapturingHotkey := true
        this.captureTarget := target

        ; Set up keyboard hook using OnMessage instead of InputHook
        this.keyboardHook := ObjBindMethod(this, "KeyboardHookProc")
        OnMessage(0x100, this.keyboardHook)    ; WM_KEYDOWN
        OnMessage(0x101, this.keyboardHook)    ; WM_KEYUP

        ; Log the capture start
        this.logger.Log("Started hotkey capture for " target)
    }

    /**
     * Process keyboard messages for hotkey capture
     * @param wParam - Virtual key code
     * @param lParam - Additional message data
     * @param msg - Message ID
     * @param hwnd - Window handle
     */
    KeyboardHookProc(wParam, lParam, msg, hwnd) {
        if (!this.isCapturingHotkey)
            return

        ; Only process KeyDown events (0x100)
        if (msg != 0x100)
            return

        ; Get key name
        keyName := GetKeyName(Format("vk{:x}", wParam))
        this.logger.Log("Captured key: " keyName)

        ; Check for Escape (cancels capture)
        if (keyName = "Escape") {
            this.currentCaptureControl.Value := ""
            this.EndHotkeyCapture()
            return
        }

        ; Skip modifier-only keys to prevent infinite loops
        if (keyName ~= "i)^(Control|Alt|Shift|LWin|RWin)$") {
            return
        }

        ; Build modifiers string
        modifiers := ""
        if (GetKeyState("Ctrl", "P"))
            modifiers .= "^"
        if (GetKeyState("Alt", "P"))
            modifiers .= "!"
        if (GetKeyState("Shift", "P"))
            modifiers .= "+"
        if (GetKeyState("LWin", "P") || GetKeyState("RWin", "P"))
            modifiers .= "#"

        ; Build hotkey string
        hotkeyStr := modifiers . keyName

        ; Update the control immediately to stop further processing
        this.currentCaptureControl.Value := hotkeyStr
        this.logger.Log("Captured hotkey: " hotkeyStr)

        ; End capture IMMEDIATELY to prevent hook conflicts
        this.EndHotkeyCapture()

        ; Block the key from being processed further
        return 1
    }

    /**
     * Validates a hotkey string
     * @param hotkeyStr - The hotkey string to validate
     * @return True if valid, false otherwise
     */
    ValidateHotkey(hotkeyStr) {
        try {
            ; Basic validation - empty is valid (removes hotkey)
            if (hotkeyStr = "")
                return true

            ; Try to register with dummy function
            dummyFn := (*) => {}
            Hotkey(hotkeyStr, dummyFn)

            ; If successful, turn it off and return true
            Hotkey(hotkeyStr, "Off")
            return true
        } catch as e {
            this.logger.Log("Hotkey validation failed: " e.Message)
            return false
        }
    }

    /**
     * Ends hotkey capture mode
     */
    EndHotkeyCapture() {
        ; Remove keyboard hook
        if (this.keyboardHook) {
            OnMessage(0x100, this.keyboardHook, 0)  ; Remove WM_KEYDOWN
            OnMessage(0x101, this.keyboardHook, 0)  ; Remove WM_KEYUP
            this.keyboardHook := ""
        }

        ; Reset capture state
        this.isCapturingHotkey := false
        this.currentCaptureControl := ""
        this.captureTarget := ""
        this.logger.Log("Ended hotkey capture")
    }

    /**
     * Clears all hotkey fields
     */
    ClearAllHotkeys() {
        this.hotkeyChangeEdit.Value := ""
        this.hotkeyPauseEdit.Value := ""
        this.hotkeySettingsEdit.Value := ""
    }
}
