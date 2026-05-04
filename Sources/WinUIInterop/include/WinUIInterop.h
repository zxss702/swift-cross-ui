#pragma once

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <stdbool.h>
#include <Windows.h>

#ifdef __cplusplus
extern "C" {
#endif

double scui_get_primary_refresh_rate(void);
double scui_get_refresh_rate_for_window(HWND hwnd);
bool scui_set_element_blur(void *element, void *sourceElement, double radius, double width, double height);
void scui_clear_element_blur(void *element);

#ifdef __cplusplus
}
#endif
