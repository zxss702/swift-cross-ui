#pragma once

#include <Windows.h>

#ifdef __cplusplus
extern "C" {
#endif

double scui_get_primary_refresh_rate(void);
double scui_get_refresh_rate_for_window(HWND hwnd);

#ifdef __cplusplus
}
#endif
