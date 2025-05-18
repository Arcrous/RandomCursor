#Requires AutoHotkey v2.0
/**
 * RegistryHelper.ahk - Optimized registry operations for RandomCursor++
 * Provides high-performance batch registry operations
 */
class RegistryHelper {
    ; Constants for registry operations
    static HKEY_CURRENT_USER := 0x80000001
    static KEY_ALL_ACCESS := 0xF003F
    static REG_SZ := 1
    static ERROR_SUCCESS := 0

    ; Logger reference
    logger := ""

    __New(logger) {
        this.logger := logger
        this.logger.Log("RegistryHelper: Initialized")
    }

    /**
     * Applies a cursor scheme using batched registry operations
     * @param cursorScheme - Map of cursor types to file paths
     * @return True if successful, False if failed
     */
    ApplyCursorSchemeBatch(cursorScheme) {
        this.logger.Log("RegistryHelper: Beginning batch registry update")

        ; Open registry key
        hKey := 0
        result := DllCall("advapi32\RegOpenKeyEx",
            "UInt", RegistryHelper.HKEY_CURRENT_USER,  ; Use class name to access static property
            "Str", "Control Panel\Cursors",
            "UInt", 0,
            "UInt", RegistryHelper.KEY_ALL_ACCESS,     ; Use class name to access static property
            "UInt*", &hKey)

        if (result != RegistryHelper.ERROR_SUCCESS) {  ; Use class name to access static property
            this.logger.Log("RegistryHelper: Failed to open registry key, error code: " result)
            return false
        }

        this.logger.Log("RegistryHelper: Registry key opened successfully")

        ; Write all cursor values in batch
        changeCount := 0
        for cursorType, cursorPath in cursorScheme {
            ; Skip the SchemeName entry - it's not a cursor type
            if (cursorType = "SchemeName")
                continue

            if !FileExist(cursorPath) {
                this.logger.Log("RegistryHelper: Cursor file not found: " cursorPath)
                continue
            }

            ; Convert string to proper format for registry
            valueLength := StrPut(cursorPath, "UTF-16") * 2

            result := DllCall("advapi32\RegSetValueEx",
                "UInt", hKey,
                "Str", cursorType,
                "UInt", 0,
                "UInt", RegistryHelper.REG_SZ,       ; Use class name to access static property
                "Str", cursorPath,
                "UInt", valueLength)

            if (result != RegistryHelper.ERROR_SUCCESS) {  ; Use class name to access static property
                this.logger.Log("RegistryHelper: Failed to set cursor " cursorType ", error code: " result)
                continue
            }

            changeCount++
        }

        ; Close registry key
        DllCall("advapi32\RegCloseKey", "UInt", hKey)
        this.logger.Log("RegistryHelper: Registry key closed, " changeCount " values written")

        ; Also update the Scheme value with the scheme name if available
        if (cursorScheme.Has("SchemeName")) {
            this.SetSchemeNameValue(cursorScheme["SchemeName"])
        }

        return changeCount > 0
    }

    /**
     * Sets the current scheme name in registry
     * @param schemeName - Name of the cursor scheme
     */
    SetSchemeNameValue(schemeName) {
        try {
            RegWrite(schemeName, "REG_SZ", "HKEY_CURRENT_USER\Control Panel\Cursors", "Scheme Source")
            this.logger.Log("RegistryHelper: Set scheme name to " schemeName)
        }
        catch as e {
            this.logger.Log("RegistryHelper: Failed to set scheme name: " e.Message)
        }
    }

    /**
     * Applies cursor changes to the system
     * More efficient implementation of system updates
     */
    ApplyCursorChanges() {
        ; Update cursor system parameter
        result := DllCall("user32\SystemParametersInfo",
            "UInt", 0x57,  ; SPI_SETCURSORS
            "UInt", 0,
            "Ptr", 0,
            "UInt", 0x01 | 0x02)  ; SPIF_UPDATEINIFILE | SPIF_SENDCHANGE

        this.logger.Log("RegistryHelper: SystemParametersInfo result: " result)

        ; Use a more direct method to reload cursors
        DllCall("user32\PostMessage", "UInt", 0xFFFF, "UInt", 0x001A, "UInt", 0, "UInt", 0)
    }

    /**
     * Retrieves all cursor settings from registry
     * @return Map of cursor types to file paths
     */
    GetCurrentCursorSettings() {
        cursorsMap := Map()

        try {
            ; Open registry key
            hKey := 0
            result := DllCall("advapi32\RegOpenKeyEx",
                "UInt", RegistryHelper.HKEY_CURRENT_USER,  ; Use class name to access static property
                "Str", "Control Panel\Cursors",
                "UInt", 0,
                "UInt", RegistryHelper.KEY_ALL_ACCESS,     ; Use class name to access static property
                "UInt*", &hKey)

            if (result != RegistryHelper.ERROR_SUCCESS) {  ; Use class name to access static property
                this.logger.Log("RegistryHelper: Failed to open registry key for reading")
                return cursorsMap
            }

            ; Query cursor values
            cursorTypes := ["AppStarting", "Arrow", "Crosshair", "Hand", "Help", "IBeam",
                "No", "NWPen", "Person", "Pin", "SizeAll", "SizeNESW",
                "SizeNS", "SizeNWSE", "SizeWE", "UpArrow", "Wait"]

            for cursorType in cursorTypes {
                ; Buffer for value
                valueSize := 260 * 2  ; MAX_PATH * sizeof(WCHAR)
                value := Buffer(valueSize, 0)

                ; Get value type and size
                valueType := 0

                result := DllCall("advapi32\RegQueryValueEx",
                    "UInt", hKey,
                    "Str", cursorType,
                    "Ptr", 0,
                    "UInt*", &valueType,
                    "Ptr", value,
                    "UInt*", &valueSize)

                if (result == RegistryHelper.ERROR_SUCCESS && valueType == RegistryHelper.REG_SZ) {  ; Use class name
                    ; Convert buffer to string
                    cursorPath := StrGet(value, "UTF-16")
                    cursorsMap[cursorType] := cursorPath
                }
            }

            ; Close registry key
            DllCall("advapi32\RegCloseKey", "UInt", hKey)
            this.logger.Log("RegistryHelper: Retrieved " cursorsMap.Count " cursor settings from registry")
        }
        catch as e {
            this.logger.Log("RegistryHelper: Error getting cursor settings: " e.Message)
        }

        return cursorsMap
    }
}
