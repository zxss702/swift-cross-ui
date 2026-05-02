#include "WinUIInterop.h"
#include <ShObjIdl.h>
#include <Windows.h>
#include <algorithm>
#include <cmath>
#include <d2d1effects.h>
#include <memory>
#include <roapi.h>
#include <unordered_map>
#include <utility>
#include <windows.graphics.effects.interop.h>
#include <winstring.h>
#include <wrl/client.h>
#include <wrl/implements.h>

struct __x_ABI_CWindows_CFoundation_CNumerics_CVector2 {
    FLOAT X;
    FLOAT Y;
};
struct __x_ABI_CWindows_CFoundation_CNumerics_CVector3 {
    FLOAT X;
    FLOAT Y;
    FLOAT Z;
};
struct __x_ABI_CWindows_CFoundation_CNumerics_CQuaternion {
    FLOAT X;
    FLOAT Y;
    FLOAT Z;
    FLOAT W;
};

#define SCUI_DECLARE_INSPECTABLE(name) \
    typedef interface name name; \
    typedef struct name##Vtbl { \
        HRESULT (STDMETHODCALLTYPE *QueryInterface)(name *, REFIID, void **); \
        ULONG (STDMETHODCALLTYPE *AddRef)(name *); \
        ULONG (STDMETHODCALLTYPE *Release)(name *); \
        HRESULT (STDMETHODCALLTYPE *GetIids)(name *, ULONG *, IID **); \
        HRESULT (STDMETHODCALLTYPE *GetRuntimeClassName)(name *, HSTRING *); \
        HRESULT (STDMETHODCALLTYPE *GetTrustLevel)(name *, TrustLevel *); \
    } name##Vtbl; \
    interface name { CONST_VTBL struct name##Vtbl *lpVtbl; }

SCUI_DECLARE_INSPECTABLE(__x_ABI_CMicrosoft_CUI_CXaml_CIUIElement);
SCUI_DECLARE_INSPECTABLE(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameter);

enum __x_ABI_CMicrosoft_CUI_CComposition_CCompositionBackfaceVisibility { SCUI_BackfaceVisibility_Visible = 0 };
enum __x_ABI_CMicrosoft_CUI_CComposition_CCompositionBorderMode { SCUI_BorderMode_Inherit = 0 };
enum __x_ABI_CMicrosoft_CUI_CComposition_CCompositionCompositeMode { SCUI_CompositeMode_Inherit = 0 };

typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositor __x_ABI_CMicrosoft_CUI_CComposition_CICompositor;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CIVisual __x_ABI_CMicrosoft_CUI_CComposition_CIVisual;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual __x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection __x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CIVisualElement2 __x_ABI_CMicrosoft_CUI_CComposition_CIVisualElement2;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositionObject __x_ABI_CMicrosoft_CUI_CComposition_CICompositionObject;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectBrush __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectBrush;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactory __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactory;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameter __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameter;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameterFactory __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameterFactory;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 __x_ABI_CMicrosoft_CUI_CComposition_CICompositor2;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CILayerVisual __x_ABI_CMicrosoft_CUI_CComposition_CILayerVisual;

typedef struct __x_ABI_CMicrosoft_CUI_CComposition_CIVisualElement2Vtbl {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisualElement2 *, REFIID, void **);
    ULONG (STDMETHODCALLTYPE *AddRef)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisualElement2 *);
    ULONG (STDMETHODCALLTYPE *Release)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisualElement2 *);
    HRESULT (STDMETHODCALLTYPE *GetIids)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisualElement2 *, ULONG *, IID **);
    HRESULT (STDMETHODCALLTYPE *GetRuntimeClassName)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisualElement2 *, HSTRING *);
    HRESULT (STDMETHODCALLTYPE *GetTrustLevel)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisualElement2 *, TrustLevel *);
    HRESULT (STDMETHODCALLTYPE *GetVisualInternal)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisualElement2 *, __x_ABI_CMicrosoft_CUI_CComposition_CIVisual **);
} __x_ABI_CMicrosoft_CUI_CComposition_CIVisualElement2Vtbl;
interface __x_ABI_CMicrosoft_CUI_CComposition_CIVisualElement2 {
    CONST_VTBL struct __x_ABI_CMicrosoft_CUI_CComposition_CIVisualElement2Vtbl *lpVtbl;
};

typedef struct __x_ABI_CMicrosoft_CUI_CComposition_CICompositionObjectVtbl {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionObject *, REFIID, void **);
    ULONG (STDMETHODCALLTYPE *AddRef)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionObject *);
    ULONG (STDMETHODCALLTYPE *Release)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionObject *);
    HRESULT (STDMETHODCALLTYPE *GetIids)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionObject *, ULONG *, IID **);
    HRESULT (STDMETHODCALLTYPE *GetRuntimeClassName)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionObject *, HSTRING *);
    HRESULT (STDMETHODCALLTYPE *GetTrustLevel)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionObject *, TrustLevel *);
    HRESULT (STDMETHODCALLTYPE *get_Compositor)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionObject *, __x_ABI_CMicrosoft_CUI_CComposition_CICompositor **);
} __x_ABI_CMicrosoft_CUI_CComposition_CICompositionObjectVtbl;
interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositionObject {
    CONST_VTBL struct __x_ABI_CMicrosoft_CUI_CComposition_CICompositionObjectVtbl *lpVtbl;
};

typedef struct __x_ABI_CMicrosoft_CUI_CComposition_CICompositorVtbl {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, REFIID, void **);
    ULONG (STDMETHODCALLTYPE *AddRef)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *);
    ULONG (STDMETHODCALLTYPE *Release)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *);
    HRESULT (STDMETHODCALLTYPE *GetIids)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, ULONG *, IID **);
    HRESULT (STDMETHODCALLTYPE *GetRuntimeClassName)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, HSTRING *);
    HRESULT (STDMETHODCALLTYPE *GetTrustLevel)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, TrustLevel *);
    void *CreateColorKeyFrameAnimation;
    void *CreateColorBrush;
    void *CreateColorBrushWithColor;
    void *CreateContainerVisual;
    void *CreateCubicBezierEasingFunction;
    HRESULT (STDMETHODCALLTYPE *CreateEffectFactory)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, ABI::Windows::Graphics::Effects::IGraphicsEffect *, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactory **);
} __x_ABI_CMicrosoft_CUI_CComposition_CICompositorVtbl;
interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositor {
    CONST_VTBL struct __x_ABI_CMicrosoft_CUI_CComposition_CICompositorVtbl *lpVtbl;
};

typedef struct __x_ABI_CMicrosoft_CUI_CComposition_CICompositor2Vtbl {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 *, REFIID, void **);
    ULONG (STDMETHODCALLTYPE *AddRef)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 *);
    ULONG (STDMETHODCALLTYPE *Release)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 *);
    HRESULT (STDMETHODCALLTYPE *GetIids)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 *, ULONG *, IID **);
    HRESULT (STDMETHODCALLTYPE *GetRuntimeClassName)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 *, HSTRING *);
    HRESULT (STDMETHODCALLTYPE *GetTrustLevel)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 *, TrustLevel *);
    HRESULT (STDMETHODCALLTYPE *CreateAmbientLight)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 *, void **);
    HRESULT (STDMETHODCALLTYPE *CreateAnimationGroup)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 *, void **);
    HRESULT (STDMETHODCALLTYPE *CreateBackdropBrush)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 *, void **);
    HRESULT (STDMETHODCALLTYPE *CreateDistantLight)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 *, void **);
    HRESULT (STDMETHODCALLTYPE *CreateDropShadow)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 *, void **);
    HRESULT (STDMETHODCALLTYPE *CreateImplicitAnimationCollection)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 *, void **);
    HRESULT (STDMETHODCALLTYPE *CreateLayerVisual)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 *, __x_ABI_CMicrosoft_CUI_CComposition_CILayerVisual **);
    HRESULT (STDMETHODCALLTYPE *CreateMaskBrush)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 *, void **);
    HRESULT (STDMETHODCALLTYPE *CreateNineGridBrush)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 *, void **);
    HRESULT (STDMETHODCALLTYPE *CreatePointLight)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 *, void **);
    HRESULT (STDMETHODCALLTYPE *CreateSpotLight)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 *, void **);
    HRESULT (STDMETHODCALLTYPE *CreateStepEasingFunction)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 *, void **);
    HRESULT (STDMETHODCALLTYPE *CreateStepEasingFunctionWithStepCount)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 *, INT32, void **);
} __x_ABI_CMicrosoft_CUI_CComposition_CICompositor2Vtbl;
interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 {
    CONST_VTBL struct __x_ABI_CMicrosoft_CUI_CComposition_CICompositor2Vtbl *lpVtbl;
};

typedef struct __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameterFactoryVtbl {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameterFactory *, REFIID, void **);
    ULONG (STDMETHODCALLTYPE *AddRef)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameterFactory *);
    ULONG (STDMETHODCALLTYPE *Release)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameterFactory *);
    HRESULT (STDMETHODCALLTYPE *GetIids)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameterFactory *, ULONG *, IID **);
    HRESULT (STDMETHODCALLTYPE *GetRuntimeClassName)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameterFactory *, HSTRING *);
    HRESULT (STDMETHODCALLTYPE *GetTrustLevel)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameterFactory *, TrustLevel *);
    HRESULT (STDMETHODCALLTYPE *Create)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameterFactory *, HSTRING, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameter **);
} __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameterFactoryVtbl;
interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameterFactory {
    CONST_VTBL struct __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameterFactoryVtbl *lpVtbl;
};

typedef struct __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectBrushVtbl {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectBrush *, REFIID, void **);
    ULONG (STDMETHODCALLTYPE *AddRef)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectBrush *);
    ULONG (STDMETHODCALLTYPE *Release)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectBrush *);
    HRESULT (STDMETHODCALLTYPE *GetIids)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectBrush *, ULONG *, IID **);
    HRESULT (STDMETHODCALLTYPE *GetRuntimeClassName)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectBrush *, HSTRING *);
    HRESULT (STDMETHODCALLTYPE *GetTrustLevel)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectBrush *, TrustLevel *);
} __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectBrushVtbl;
interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectBrush {
    CONST_VTBL struct __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectBrushVtbl *lpVtbl;
};

typedef struct __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactoryVtbl {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactory *, REFIID, void **);
    ULONG (STDMETHODCALLTYPE *AddRef)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactory *);
    ULONG (STDMETHODCALLTYPE *Release)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactory *);
    HRESULT (STDMETHODCALLTYPE *GetIids)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactory *, ULONG *, IID **);
    HRESULT (STDMETHODCALLTYPE *GetRuntimeClassName)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactory *, HSTRING *);
    HRESULT (STDMETHODCALLTYPE *GetTrustLevel)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactory *, TrustLevel *);
    HRESULT (STDMETHODCALLTYPE *CreateBrush)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactory *, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectBrush **);
} __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactoryVtbl;
interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactory {
    CONST_VTBL struct __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactoryVtbl *lpVtbl;
};

typedef struct __x_ABI_CMicrosoft_CUI_CComposition_CILayerVisualVtbl {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(__x_ABI_CMicrosoft_CUI_CComposition_CILayerVisual *, REFIID, void **);
    ULONG (STDMETHODCALLTYPE *AddRef)(__x_ABI_CMicrosoft_CUI_CComposition_CILayerVisual *);
    ULONG (STDMETHODCALLTYPE *Release)(__x_ABI_CMicrosoft_CUI_CComposition_CILayerVisual *);
    HRESULT (STDMETHODCALLTYPE *GetIids)(__x_ABI_CMicrosoft_CUI_CComposition_CILayerVisual *, ULONG *, IID **);
    HRESULT (STDMETHODCALLTYPE *GetRuntimeClassName)(__x_ABI_CMicrosoft_CUI_CComposition_CILayerVisual *, HSTRING *);
    HRESULT (STDMETHODCALLTYPE *GetTrustLevel)(__x_ABI_CMicrosoft_CUI_CComposition_CILayerVisual *, TrustLevel *);
    HRESULT (STDMETHODCALLTYPE *get_Effect)(__x_ABI_CMicrosoft_CUI_CComposition_CILayerVisual *, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectBrush **);
    HRESULT (STDMETHODCALLTYPE *put_Effect)(__x_ABI_CMicrosoft_CUI_CComposition_CILayerVisual *, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectBrush *);
} __x_ABI_CMicrosoft_CUI_CComposition_CILayerVisualVtbl;
interface __x_ABI_CMicrosoft_CUI_CComposition_CILayerVisual {
    CONST_VTBL struct __x_ABI_CMicrosoft_CUI_CComposition_CILayerVisualVtbl *lpVtbl;
};

typedef struct __x_ABI_CMicrosoft_CUI_CComposition_CIVisualVtbl {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, REFIID, void **);
    ULONG (STDMETHODCALLTYPE *AddRef)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *);
    ULONG (STDMETHODCALLTYPE *Release)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *);
    HRESULT (STDMETHODCALLTYPE *GetIids)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, ULONG *, IID **);
    HRESULT (STDMETHODCALLTYPE *GetRuntimeClassName)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, HSTRING *);
    HRESULT (STDMETHODCALLTYPE *GetTrustLevel)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, TrustLevel *);
    HRESULT (STDMETHODCALLTYPE *get_AnchorPoint)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CWindows_CFoundation_CNumerics_CVector2 *);
    HRESULT (STDMETHODCALLTYPE *put_AnchorPoint)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CWindows_CFoundation_CNumerics_CVector2);
    HRESULT (STDMETHODCALLTYPE *get_BackfaceVisibility)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CMicrosoft_CUI_CComposition_CCompositionBackfaceVisibility *);
    HRESULT (STDMETHODCALLTYPE *put_BackfaceVisibility)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CMicrosoft_CUI_CComposition_CCompositionBackfaceVisibility);
    HRESULT (STDMETHODCALLTYPE *get_BorderMode)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CMicrosoft_CUI_CComposition_CCompositionBorderMode *);
    HRESULT (STDMETHODCALLTYPE *put_BorderMode)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CMicrosoft_CUI_CComposition_CCompositionBorderMode);
    HRESULT (STDMETHODCALLTYPE *get_CenterPoint)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CWindows_CFoundation_CNumerics_CVector3 *);
    HRESULT (STDMETHODCALLTYPE *put_CenterPoint)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CWindows_CFoundation_CNumerics_CVector3);
    HRESULT (STDMETHODCALLTYPE *get_Clip)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, void **);
    HRESULT (STDMETHODCALLTYPE *put_Clip)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, void *);
    HRESULT (STDMETHODCALLTYPE *get_CompositeMode)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CMicrosoft_CUI_CComposition_CCompositionCompositeMode *);
    HRESULT (STDMETHODCALLTYPE *put_CompositeMode)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CMicrosoft_CUI_CComposition_CCompositionCompositeMode);
    HRESULT (STDMETHODCALLTYPE *get_IsVisible)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, boolean *);
    HRESULT (STDMETHODCALLTYPE *put_IsVisible)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, boolean);
    HRESULT (STDMETHODCALLTYPE *get_Offset)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CWindows_CFoundation_CNumerics_CVector3 *);
    HRESULT (STDMETHODCALLTYPE *put_Offset)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CWindows_CFoundation_CNumerics_CVector3);
    HRESULT (STDMETHODCALLTYPE *get_Opacity)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, FLOAT *);
    HRESULT (STDMETHODCALLTYPE *put_Opacity)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, FLOAT);
    HRESULT (STDMETHODCALLTYPE *get_Orientation)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CWindows_CFoundation_CNumerics_CQuaternion *);
    HRESULT (STDMETHODCALLTYPE *put_Orientation)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CWindows_CFoundation_CNumerics_CQuaternion);
    HRESULT (STDMETHODCALLTYPE *get_Parent)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual **);
    HRESULT (STDMETHODCALLTYPE *get_RotationAngle)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, FLOAT *);
    HRESULT (STDMETHODCALLTYPE *put_RotationAngle)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, FLOAT);
    HRESULT (STDMETHODCALLTYPE *get_RotationAngleInDegrees)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, FLOAT *);
    HRESULT (STDMETHODCALLTYPE *put_RotationAngleInDegrees)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, FLOAT);
    HRESULT (STDMETHODCALLTYPE *get_RotationAxis)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CWindows_CFoundation_CNumerics_CVector3 *);
    HRESULT (STDMETHODCALLTYPE *put_RotationAxis)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CWindows_CFoundation_CNumerics_CVector3);
    HRESULT (STDMETHODCALLTYPE *get_Scale)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CWindows_CFoundation_CNumerics_CVector3 *);
    HRESULT (STDMETHODCALLTYPE *put_Scale)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CWindows_CFoundation_CNumerics_CVector3);
    HRESULT (STDMETHODCALLTYPE *get_Size)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CWindows_CFoundation_CNumerics_CVector2 *);
    HRESULT (STDMETHODCALLTYPE *put_Size)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CWindows_CFoundation_CNumerics_CVector2);
} __x_ABI_CMicrosoft_CUI_CComposition_CIVisualVtbl;
interface __x_ABI_CMicrosoft_CUI_CComposition_CIVisual {
    CONST_VTBL struct __x_ABI_CMicrosoft_CUI_CComposition_CIVisualVtbl *lpVtbl;
};

typedef struct __x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisualVtbl {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(__x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual *, REFIID, void **);
    ULONG (STDMETHODCALLTYPE *AddRef)(__x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual *);
    ULONG (STDMETHODCALLTYPE *Release)(__x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual *);
    HRESULT (STDMETHODCALLTYPE *GetIids)(__x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual *, ULONG *, IID **);
    HRESULT (STDMETHODCALLTYPE *GetRuntimeClassName)(__x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual *, HSTRING *);
    HRESULT (STDMETHODCALLTYPE *GetTrustLevel)(__x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual *, TrustLevel *);
    HRESULT (STDMETHODCALLTYPE *get_Children)(__x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual *, __x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection **);
} __x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisualVtbl;
interface __x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual {
    CONST_VTBL struct __x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisualVtbl *lpVtbl;
};

typedef struct __x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollectionVtbl {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection *, REFIID, void **);
    ULONG (STDMETHODCALLTYPE *AddRef)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection *);
    ULONG (STDMETHODCALLTYPE *Release)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection *);
    HRESULT (STDMETHODCALLTYPE *GetIids)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection *, ULONG *, IID **);
    HRESULT (STDMETHODCALLTYPE *GetRuntimeClassName)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection *, HSTRING *);
    HRESULT (STDMETHODCALLTYPE *GetTrustLevel)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection *, TrustLevel *);
    HRESULT (STDMETHODCALLTYPE *get_Count)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection *, INT32 *);
    HRESULT (STDMETHODCALLTYPE *InsertAbove)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection *, __x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CMicrosoft_CUI_CComposition_CIVisual *);
    HRESULT (STDMETHODCALLTYPE *InsertAtBottom)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection *, __x_ABI_CMicrosoft_CUI_CComposition_CIVisual *);
    HRESULT (STDMETHODCALLTYPE *InsertAtTop)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection *, __x_ABI_CMicrosoft_CUI_CComposition_CIVisual *);
    HRESULT (STDMETHODCALLTYPE *InsertBelow)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection *, __x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CMicrosoft_CUI_CComposition_CIVisual *);
    HRESULT (STDMETHODCALLTYPE *Remove)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection *, __x_ABI_CMicrosoft_CUI_CComposition_CIVisual *);
    HRESULT (STDMETHODCALLTYPE *RemoveAll)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection *);
} __x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollectionVtbl;
interface __x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection {
    CONST_VTBL struct __x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollectionVtbl *lpVtbl;
};

static const IID IID___x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameterFactory = {0x26185954, 0x4489, 0x5D0E, {0xAE, 0x4D, 0x7B, 0xC4, 0xBB, 0xBC, 0x61, 0x61}};
static const IID IID___x_ABI_CMicrosoft_CUI_CComposition_CICompositionObject = {0x0E583D49, 0xFB5E, 0x5481, {0xA4, 0x26, 0xD3, 0xC4, 0x1E, 0x05, 0x9A, 0x5A}};
static const IID IID___x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual = {0xC70DBCE1, 0x2C2F, 0x5D8E, {0x91, 0xA4, 0xAA, 0xE1, 0x12, 0x1E, 0x61, 0x86}};
static const IID IID___x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 = {0xA9FFEDAD, 0x3982, 0x576D, {0xA3, 0x8A, 0xC8, 0x88, 0xFF, 0x60, 0x58, 0x19}};
static const IID IID___x_ABI_CMicrosoft_CUI_CComposition_CILayerVisual = {0x64D05CA1, 0x3BF6, 0x5D4F, {0x98, 0xA1, 0x75, 0x00, 0xF2, 0xF2, 0x3E, 0xBE}};
static const IID IID___x_ABI_CMicrosoft_CUI_CComposition_CIVisual = {0xC0EEAB6C, 0xC897, 0x5AC6, {0xA1, 0xC9, 0x63, 0xAB, 0xD5, 0x05, 0x5B, 0x9B}};
static const IID IID___x_ABI_CMicrosoft_CUI_CComposition_CIVisualElement2 = {0xBC950C8D, 0x1DB0, 0x53AA, {0x9D, 0xEE, 0x34, 0x27, 0x1C, 0xD1, 0x8C, 0xE6}};
static const IID IID___x_ABI_CMicrosoft_CUI_CXaml_CIUIElement = {0xC3C01020, 0x320C, 0x5CF6, {0x9D, 0x24, 0xD3, 0x96, 0xBB, 0xFA, 0x4D, 0x8B}};

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

namespace {
using Microsoft::WRL::ClassicCom;
using Microsoft::WRL::ComPtr;
using Microsoft::WRL::Make;
using Microsoft::WRL::RuntimeClass;
using Microsoft::WRL::RuntimeClassFlags;

static constexpr GUID SCUI_CLSID_D2D1GaussianBlur = {
    0x1feb6d69,
    0x2fe6,
    0x4ac9,
    {0x8c, 0x58, 0x1d, 0x7f, 0x93, 0xe7, 0xa6, 0xa5},
};

template <typename Interface>
void scui_release(Interface *&value) {
    if (value != nullptr) {
        value->lpVtbl->Release(value);
        value = nullptr;
    }
}

template <typename Source, typename Interface>
HRESULT scui_query(Source *source, REFIID iid, Interface **result) {
    *result = nullptr;
    if (source == nullptr) {
        return E_POINTER;
    }
    auto unknown = reinterpret_cast<IUnknown *>(source);
    return unknown->QueryInterface(iid, reinterpret_cast<void **>(result));
}

HRESULT scui_make_hstring(const wchar_t *string, HSTRING *result) {
    return WindowsCreateString(
        string,
        static_cast<UINT32>(wcslen(string)),
        result
    );
}

template <typename Interface>
HRESULT scui_get_activation_factory(
    const wchar_t *className,
    REFIID iid,
    Interface **result
) {
    HSTRING hstring = nullptr;
    HRESULT hr = scui_make_hstring(className, &hstring);
    if (FAILED(hr)) {
        return hr;
    }

    hr = RoGetActivationFactory(
        hstring,
        iid,
        reinterpret_cast<void **>(result)
    );
    WindowsDeleteString(hstring);
    return hr;
}

HRESULT scui_activate(
    const wchar_t *className,
    IInspectable **result
) {
    HSTRING hstring = nullptr;
    HRESULT hr = scui_make_hstring(className, &hstring);
    if (FAILED(hr)) {
        return hr;
    }

    hr = RoActivateInstance(hstring, result);
    WindowsDeleteString(hstring);
    return hr;
}

HRESULT scui_create_single_property_value(
    float value,
    ABI::Windows::Foundation::IPropertyValue **result
) {
    *result = nullptr;
    ComPtr<ABI::Windows::Foundation::IPropertyValueStatics> statics;
    HRESULT hr = scui_get_activation_factory(
        L"Windows.Foundation.PropertyValue",
        __uuidof(ABI::Windows::Foundation::IPropertyValueStatics),
        statics.GetAddressOf()
    );
    if (FAILED(hr)) {
        return hr;
    }

    ComPtr<IInspectable> inspectable;
    hr = statics->CreateSingle(value, inspectable.GetAddressOf());
    if (FAILED(hr)) {
        return hr;
    }
    return inspectable->QueryInterface(
        __uuidof(ABI::Windows::Foundation::IPropertyValue),
        reinterpret_cast<void **>(result)
    );
}

HRESULT scui_create_uint32_property_value(
    UINT32 value,
    ABI::Windows::Foundation::IPropertyValue **result
) {
    *result = nullptr;
    ComPtr<ABI::Windows::Foundation::IPropertyValueStatics> statics;
    HRESULT hr = scui_get_activation_factory(
        L"Windows.Foundation.PropertyValue",
        __uuidof(ABI::Windows::Foundation::IPropertyValueStatics),
        statics.GetAddressOf()
    );
    if (FAILED(hr)) {
        return hr;
    }

    ComPtr<IInspectable> inspectable;
    hr = statics->CreateUInt32(value, inspectable.GetAddressOf());
    if (FAILED(hr)) {
        return hr;
    }
    return inspectable->QueryInterface(
        __uuidof(ABI::Windows::Foundation::IPropertyValue),
        reinterpret_cast<void **>(result)
    );
}

class SCUIGaussianBlurEffect final
    : public RuntimeClass<
        RuntimeClassFlags<ClassicCom>,
        ABI::Windows::Graphics::Effects::IGraphicsEffect,
        ABI::Windows::Graphics::Effects::IGraphicsEffectSource,
        ABI::Windows::Graphics::Effects::IGraphicsEffectD2D1Interop
    >
{
public:
    SCUIGaussianBlurEffect(
        ABI::Windows::Graphics::Effects::IGraphicsEffectSource *source,
        float radius
    ) : source(source), radius(radius) {}

    HRESULT STDMETHODCALLTYPE GetIids(
        ULONG *iidCount,
        IID **iids
    ) override {
        if (iidCount == nullptr || iids == nullptr) {
            return E_POINTER;
        }

        *iidCount = 3;
        *iids = static_cast<IID *>(CoTaskMemAlloc(sizeof(IID) * *iidCount));
        if (*iids == nullptr) {
            *iidCount = 0;
            return E_OUTOFMEMORY;
        }

        (*iids)[0] = __uuidof(ABI::Windows::Graphics::Effects::IGraphicsEffect);
        (*iids)[1] = __uuidof(ABI::Windows::Graphics::Effects::IGraphicsEffectSource);
        (*iids)[2] = __uuidof(ABI::Windows::Graphics::Effects::IGraphicsEffectD2D1Interop);
        return S_OK;
    }

    HRESULT STDMETHODCALLTYPE GetRuntimeClassName(
        HSTRING *className
    ) override {
        return scui_make_hstring(L"SwiftCrossUI.GaussianBlurEffect", className);
    }

    HRESULT STDMETHODCALLTYPE GetTrustLevel(
        TrustLevel *trustLevel
    ) override {
        if (trustLevel == nullptr) {
            return E_POINTER;
        }
        *trustLevel = BaseTrust;
        return S_OK;
    }

    HRESULT STDMETHODCALLTYPE get_Name(HSTRING *name) override {
        return scui_make_hstring(L"Blur", name);
    }

    HRESULT STDMETHODCALLTYPE put_Name(HSTRING) override {
        return S_OK;
    }

    HRESULT STDMETHODCALLTYPE GetEffectId(GUID *id) throw() override {
        if (id == nullptr) {
            return E_POINTER;
        }
        *id = SCUI_CLSID_D2D1GaussianBlur;
        return S_OK;
    }

    HRESULT STDMETHODCALLTYPE GetNamedPropertyMapping(
        LPCWSTR name,
        UINT *index,
        ABI::Windows::Graphics::Effects::GRAPHICS_EFFECT_PROPERTY_MAPPING *mapping
    ) throw() override {
        if (name == nullptr || index == nullptr || mapping == nullptr) {
            return E_POINTER;
        }

        if (wcscmp(name, L"BlurAmount") == 0) {
            *index = D2D1_GAUSSIANBLUR_PROP_STANDARD_DEVIATION;
            *mapping = ABI::Windows::Graphics::Effects::GRAPHICS_EFFECT_PROPERTY_MAPPING_DIRECT;
            return S_OK;
        }

        return E_INVALIDARG;
    }

    HRESULT STDMETHODCALLTYPE GetPropertyCount(UINT *count) throw() override {
        if (count == nullptr) {
            return E_POINTER;
        }
        *count = 3;
        return S_OK;
    }

    HRESULT STDMETHODCALLTYPE GetProperty(
        UINT index,
        ABI::Windows::Foundation::IPropertyValue **value
    ) throw() override {
        if (value == nullptr) {
            return E_POINTER;
        }

        switch (index) {
        case D2D1_GAUSSIANBLUR_PROP_STANDARD_DEVIATION:
            return scui_create_single_property_value(radius, value);
        case D2D1_GAUSSIANBLUR_PROP_OPTIMIZATION:
            return scui_create_uint32_property_value(
                D2D1_GAUSSIANBLUR_OPTIMIZATION_BALANCED,
                value
            );
        case D2D1_GAUSSIANBLUR_PROP_BORDER_MODE:
            return scui_create_uint32_property_value(
                D2D1_BORDER_MODE_HARD,
                value
            );
        default:
            return E_BOUNDS;
        }
    }

    HRESULT STDMETHODCALLTYPE GetSource(
        UINT index,
        ABI::Windows::Graphics::Effects::IGraphicsEffectSource **result
    ) throw() override {
        if (result == nullptr) {
            return E_POINTER;
        }
        *result = nullptr;

        if (index != 0) {
            return E_BOUNDS;
        }
        return source.CopyTo(result);
    }

    HRESULT STDMETHODCALLTYPE GetSourceCount(UINT *count) throw() override {
        if (count == nullptr) {
            return E_POINTER;
        }
        *count = 1;
        return S_OK;
    }

private:
    ComPtr<ABI::Windows::Graphics::Effects::IGraphicsEffectSource> source;
    float radius;
};

struct BlurState {
    IUnknown *identity = nullptr;
    __x_ABI_CMicrosoft_CUI_CXaml_CIUIElement *element = nullptr;
    __x_ABI_CMicrosoft_CUI_CXaml_CIUIElement *sourceElement = nullptr;
    __x_ABI_CMicrosoft_CUI_CComposition_CIVisual *sourceVisual = nullptr;
    __x_ABI_CMicrosoft_CUI_CComposition_CICompositor *compositor = nullptr;
    __x_ABI_CMicrosoft_CUI_CComposition_CILayerVisual *layerVisual = nullptr;
    __x_ABI_CMicrosoft_CUI_CComposition_CIVisual *layerAsVisual = nullptr;
    __x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual *layerContainer = nullptr;
    __x_ABI_CWindows_CFoundation_CNumerics_CVector3 originalSourceOffset = {};
    bool layerInserted = false;
    bool sourceReparented = false;
    float radius = -1;

    ~BlurState() {
        clear();
    }

    BlurState() = default;
    BlurState(const BlurState &) = delete;
    BlurState &operator=(const BlurState &) = delete;

    void clear() {
        restoreSourceVisual();
        removeLayerVisual();
        scui_release(layerContainer);
        scui_release(layerAsVisual);
        scui_release(layerVisual);
        scui_release(compositor);
        scui_release(sourceVisual);
        scui_release(sourceElement);
        scui_release(element);
        if (identity != nullptr) {
            identity->Release();
            identity = nullptr;
        }
    }

    void removeLayerVisual() {
        if (!layerInserted || layerAsVisual == nullptr) {
            return;
        }

        __x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual *parent = nullptr;
        HRESULT hr = layerAsVisual->lpVtbl->get_Parent(layerAsVisual, &parent);
        if (SUCCEEDED(hr) && parent != nullptr) {
            __x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection *children = nullptr;
            hr = parent->lpVtbl->get_Children(parent, &children);
            scui_release(parent);
            if (SUCCEEDED(hr) && children != nullptr) {
                children->lpVtbl->Remove(children, layerAsVisual);
                scui_release(children);
            }
        }

        layerInserted = false;
    }

    void restoreSourceVisual() {
        if (!sourceReparented || sourceVisual == nullptr || layerAsVisual == nullptr) {
            return;
        }

        if (layerContainer != nullptr) {
            __x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection *layerChildren = nullptr;
            if (SUCCEEDED(layerContainer->lpVtbl->get_Children(layerContainer, &layerChildren))
                && layerChildren != nullptr) {
                layerChildren->lpVtbl->Remove(layerChildren, sourceVisual);
                scui_release(layerChildren);
            }
        }

        __x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual *parent = nullptr;
        HRESULT hr = layerAsVisual->lpVtbl->get_Parent(layerAsVisual, &parent);
        if (SUCCEEDED(hr) && parent != nullptr) {
            __x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection *children = nullptr;
            hr = parent->lpVtbl->get_Children(parent, &children);
            scui_release(parent);
            if (SUCCEEDED(hr) && children != nullptr) {
                sourceVisual->lpVtbl->put_Offset(sourceVisual, originalSourceOffset);
                children->lpVtbl->InsertBelow(children, sourceVisual, layerAsVisual);
                children->lpVtbl->Remove(children, layerAsVisual);
                scui_release(children);
                layerInserted = false;
            }
        }

        sourceReparented = false;
    }
};

static std::unordered_map<IUnknown *, std::unique_ptr<BlurState>> scui_blur_states;

HRESULT scui_get_blur_identity(void *element, IUnknown **identity) {
    *identity = nullptr;
    if (element == nullptr) {
        return E_POINTER;
    }
    auto unknown = reinterpret_cast<IUnknown *>(element);
    return unknown->QueryInterface(
        IID_IUnknown,
        reinterpret_cast<void **>(identity)
    );
}

HRESULT scui_create_blur_source_parameter(
    ABI::Windows::Graphics::Effects::IGraphicsEffectSource **result
) {
    *result = nullptr;

    __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameterFactory *factory = nullptr;
    HRESULT hr = scui_get_activation_factory(
        L"Microsoft.UI.Composition.CompositionEffectSourceParameter",
        IID___x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameterFactory,
        &factory
    );
    if (FAILED(hr)) {
        return hr;
    }

    HSTRING sourceName = nullptr;
    hr = scui_make_hstring(L"source", &sourceName);
    if (FAILED(hr)) {
        scui_release(factory);
        return hr;
    }

    __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameter *parameter = nullptr;
    hr = factory->lpVtbl->Create(factory, sourceName, &parameter);
    WindowsDeleteString(sourceName);
    scui_release(factory);
    if (FAILED(hr)) {
        return hr;
    }

    auto unknown = reinterpret_cast<IUnknown *>(parameter);
    hr = unknown->QueryInterface(
        __uuidof(ABI::Windows::Graphics::Effects::IGraphicsEffectSource),
        reinterpret_cast<void **>(result)
    );
    scui_release(parameter);
    return hr;
}

bool scui_update_blur_state_size(
    BlurState &state,
    double width,
    double height,
    float radius
) {
    const float clampedWidth = static_cast<float>((std::max)(0.0, width));
    const float clampedHeight = static_cast<float>((std::max)(0.0, height));
    const float margin = std::ceil((std::max)(0.0f, radius) * 3.0f);

    __x_ABI_CWindows_CFoundation_CNumerics_CVector2 size = {
        clampedWidth + margin * 2.0f,
        clampedHeight + margin * 2.0f,
    };

    __x_ABI_CWindows_CFoundation_CNumerics_CVector3 layerOffset = state.originalSourceOffset;
    layerOffset.X -= margin;
    layerOffset.Y -= margin;
    HRESULT hr = state.layerAsVisual->lpVtbl->put_Offset(state.layerAsVisual, layerOffset);
    if (FAILED(hr)) {
        return false;
    }

    __x_ABI_CWindows_CFoundation_CNumerics_CVector3 sourceOffset = {};
    sourceOffset.X = margin;
    sourceOffset.Y = margin;
    sourceOffset.Z = state.originalSourceOffset.Z;
    hr = state.sourceVisual->lpVtbl->put_Offset(state.sourceVisual, sourceOffset);
    if (FAILED(hr)) {
        return false;
    }

    hr = state.layerAsVisual->lpVtbl->put_Size(state.layerAsVisual, size);
    return SUCCEEDED(hr);
}

bool scui_rebuild_blur_brush(
    BlurState &state,
    float radius
) {
    ComPtr<ABI::Windows::Graphics::Effects::IGraphicsEffectSource> sourceParameter;
    HRESULT hr = scui_create_blur_source_parameter(sourceParameter.GetAddressOf());
    if (FAILED(hr)) {
        return false;
    }

    ComPtr<SCUIGaussianBlurEffect> blurEffect =
        Make<SCUIGaussianBlurEffect>(sourceParameter.Get(), radius);
    if (!blurEffect) {
        return false;
    }

    __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactory *effectFactory = nullptr;
    hr = state.compositor->lpVtbl->CreateEffectFactory(
        state.compositor,
        reinterpret_cast<ABI::Windows::Graphics::Effects::IGraphicsEffect *>(
            blurEffect.Get()
        ),
        &effectFactory
    );
    if (FAILED(hr)) {
        return false;
    }

    __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectBrush *effectBrush = nullptr;
    hr = effectFactory->lpVtbl->CreateBrush(effectFactory, &effectBrush);
    scui_release(effectFactory);
    if (FAILED(hr)) {
        return false;
    }

    hr = state.layerVisual->lpVtbl->put_Effect(state.layerVisual, effectBrush);
    scui_release(effectBrush);
    if (FAILED(hr)) {
        return false;
    }

    state.radius = radius;
    return true;
}

bool scui_initialize_blur_state(
    void *elementPointer,
    void *sourceElementPointer,
    BlurState &state,
    IUnknown *identity
) {
    identity->AddRef();
    state.identity = identity;

    HRESULT hr = scui_query(
        identity,
        IID___x_ABI_CMicrosoft_CUI_CXaml_CIUIElement,
        &state.element
    );
    if (FAILED(hr)) {
        return false;
    }

    auto sourceUnknown = reinterpret_cast<IUnknown *>(
        sourceElementPointer != nullptr ? sourceElementPointer : elementPointer
    );
    hr = sourceUnknown->QueryInterface(
        IID___x_ABI_CMicrosoft_CUI_CXaml_CIUIElement,
        reinterpret_cast<void **>(&state.sourceElement)
    );
    if (FAILED(hr)) {
        return false;
    }

    __x_ABI_CMicrosoft_CUI_CComposition_CIVisualElement2 *visualElement = nullptr;
    hr = sourceUnknown->QueryInterface(
        IID___x_ABI_CMicrosoft_CUI_CComposition_CIVisualElement2,
        reinterpret_cast<void **>(&visualElement)
    );
    if (FAILED(hr)) {
        return false;
    }

    hr = visualElement->lpVtbl->GetVisualInternal(
        visualElement,
        &state.sourceVisual
    );
    scui_release(visualElement);
    if (FAILED(hr)) {
        return false;
    }

    __x_ABI_CMicrosoft_CUI_CComposition_CICompositionObject *compositionObject = nullptr;
    hr = scui_query(
        state.sourceVisual,
        IID___x_ABI_CMicrosoft_CUI_CComposition_CICompositionObject,
        &compositionObject
    );
    if (FAILED(hr)) {
        return false;
    }

    hr = compositionObject->lpVtbl->get_Compositor(
        compositionObject,
        &state.compositor
    );
    scui_release(compositionObject);
    if (FAILED(hr)) {
        return false;
    }

    __x_ABI_CMicrosoft_CUI_CComposition_CICompositor2 *compositor2 = nullptr;
    hr = scui_query(
        state.compositor,
        IID___x_ABI_CMicrosoft_CUI_CComposition_CICompositor2,
        &compositor2
    );
    if (FAILED(hr)) {
        return false;
    }

    hr = compositor2->lpVtbl->CreateLayerVisual(
        compositor2,
        &state.layerVisual
    );
    scui_release(compositor2);
    if (FAILED(hr)) {
        return false;
    }

    hr = scui_query(
        state.layerVisual,
        IID___x_ABI_CMicrosoft_CUI_CComposition_CIVisual,
        &state.layerAsVisual
    );
    if (FAILED(hr)) {
        return false;
    }

    hr = scui_query(
        state.layerVisual,
        IID___x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual,
        &state.layerContainer
    );
    if (FAILED(hr)) {
        return false;
    }

    if (FAILED(state.sourceVisual->lpVtbl->get_Offset(
        state.sourceVisual,
        &state.originalSourceOffset
    ))) {
        state.originalSourceOffset = {};
    }

    __x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual *parent = nullptr;
    hr = state.sourceVisual->lpVtbl->get_Parent(state.sourceVisual, &parent);
    if (FAILED(hr) || parent == nullptr) {
        return false;
    }

    __x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection *parentChildren = nullptr;
    hr = parent->lpVtbl->get_Children(parent, &parentChildren);
    scui_release(parent);
    if (FAILED(hr) || parentChildren == nullptr) {
        return false;
    }

    hr = parentChildren->lpVtbl->InsertAbove(
        parentChildren,
        state.layerAsVisual,
        state.sourceVisual
    );
    if (FAILED(hr)) {
        scui_release(parentChildren);
        return false;
    }
    state.layerInserted = true;

    hr = parentChildren->lpVtbl->Remove(parentChildren, state.sourceVisual);
    scui_release(parentChildren);
    if (FAILED(hr)) {
        return false;
    }

    __x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection *layerChildren = nullptr;
    hr = state.layerContainer->lpVtbl->get_Children(
        state.layerContainer,
        &layerChildren
    );
    if (FAILED(hr)) {
        return false;
    }

    hr = layerChildren->lpVtbl->InsertAtTop(layerChildren, state.sourceVisual);
    scui_release(layerChildren);
    if (FAILED(hr)) {
        return false;
    }

    state.sourceReparented = true;
    return true;
}

void scui_remove_blur_state(IUnknown *identity) {
    auto iterator = scui_blur_states.find(identity);
    if (iterator == scui_blur_states.end()) {
        return;
    }

    scui_blur_states.erase(iterator);
}
} // namespace

bool scui_set_element_blur(
    void *element,
    void *sourceElement,
    double radius,
    double width,
    double height
) {
    IUnknown *identity = nullptr;
    if (FAILED(scui_get_blur_identity(element, &identity))) {
        return false;
    }

    const float clampedRadius = static_cast<float>((std::max)(0.0, radius));
    if (clampedRadius <= 0.0f) {
        scui_remove_blur_state(identity);
        identity->Release();
        return true;
    }

    auto iterator = scui_blur_states.find(identity);
    if (iterator == scui_blur_states.end()) {
        auto state = std::make_unique<BlurState>();
        if (!scui_initialize_blur_state(element, sourceElement, *state, identity)) {
            identity->Release();
            return false;
        }
        iterator = scui_blur_states.emplace(identity, std::move(state)).first;
    }

    identity->Release();

    BlurState &state = *iterator->second;
    if (state.radius != clampedRadius) {
        if (!scui_rebuild_blur_brush(state, clampedRadius)) {
            return false;
        }
    }

    return scui_update_blur_state_size(state, width, height, clampedRadius);
}

void scui_clear_element_blur(void *element) {
    IUnknown *identity = nullptr;
    if (FAILED(scui_get_blur_identity(element, &identity))) {
        return;
    }

    scui_remove_blur_state(identity);
    identity->Release();
}
