#include "WinUIInterop.h"
#include <ShObjIdl.h>
#include <Windows.h>

static double scui_refresh_rate_for_device(LPCWSTR deviceName) {
    DEVMODEW mode = {};
    mode.dmSize = sizeof(mode);

    if (EnumDisplaySettingsW(deviceName, ENUM_CURRENT_SETTINGS, &mode)
        && mode.dmDisplayFrequency > 1) {
        return static_cast<double>(mode.dmDisplayFrequency);
    }

    return 60.0;
}

double scui_get_primary_refresh_rate(void) {
    return scui_refresh_rate_for_device(nullptr);
}

double scui_get_refresh_rate_for_window(HWND hwnd) {
    HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
    if (monitor == nullptr) {
        return scui_get_primary_refresh_rate();
    }

    MONITORINFOEXW info = {};
    info.cbSize = sizeof(info);
    if (!GetMonitorInfoW(monitor, &info)) {
        return scui_get_primary_refresh_rate();
    }

    return scui_refresh_rate_for_device(info.szDevice);
}
