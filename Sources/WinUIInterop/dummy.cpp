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
struct __x_ABI_CWindows_CFoundation_CNumerics_CMatrix4x4 {
    FLOAT M11, M12, M13, M14;
    FLOAT M21, M22, M23, M24;
    FLOAT M31, M32, M33, M34;
    FLOAT M41, M42, M43, M44;
};
struct __x_ABI_CWindows_CFoundation_CNumerics_CQuaternion {
    FLOAT X;
    FLOAT Y;
    FLOAT Z;
    FLOAT W;
};
struct __x_ABI_CWindows_CUI_CColor {
    BYTE A;
    BYTE R;
    BYTE G;
    BYTE B;
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
SCUI_DECLARE_INSPECTABLE(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionBrush);
SCUI_DECLARE_INSPECTABLE(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurface);
SCUI_DECLARE_INSPECTABLE(__x_ABI_CMicrosoft_CUI_CComposition_CIColorKeyFrameAnimation);
SCUI_DECLARE_INSPECTABLE(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionColorBrush);
SCUI_DECLARE_INSPECTABLE(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionAnimation);
SCUI_DECLARE_INSPECTABLE(__x_ABI_CMicrosoft_CUI_CComposition_CICubicBezierEasingFunction);
SCUI_DECLARE_INSPECTABLE(__x_ABI_CMicrosoft_CUI_CComposition_CIExpressionAnimation);
SCUI_DECLARE_INSPECTABLE(__x_ABI_CMicrosoft_CUI_CComposition_CIInsetClip);
SCUI_DECLARE_INSPECTABLE(__x_ABI_CMicrosoft_CUI_CComposition_CILinearEasingFunction);
SCUI_DECLARE_INSPECTABLE(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionPropertySet);
SCUI_DECLARE_INSPECTABLE(__x_ABI_CMicrosoft_CUI_CComposition_CIQuaternionKeyFrameAnimation);
SCUI_DECLARE_INSPECTABLE(__x_ABI_CMicrosoft_CUI_CComposition_CIScalarKeyFrameAnimation);
SCUI_DECLARE_INSPECTABLE(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionScopedBatch);
SCUI_DECLARE_INSPECTABLE(__x_ABI_CMicrosoft_CUI_CComposition_CIVector2KeyFrameAnimation);
SCUI_DECLARE_INSPECTABLE(__x_ABI_CMicrosoft_CUI_CComposition_CIVector3KeyFrameAnimation);
SCUI_DECLARE_INSPECTABLE(__x_ABI_CMicrosoft_CUI_CComposition_CIVector4KeyFrameAnimation);
SCUI_DECLARE_INSPECTABLE(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionCommitBatch);
SCUI_DECLARE_INSPECTABLE(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameter);

enum __x_ABI_CMicrosoft_CUI_CComposition_CCompositionBatchTypes {
    __x_ABI_CMicrosoft_CUI_CComposition_CCompositionBatchTypes_None = 0,
};
enum __x_ABI_CMicrosoft_CUI_CComposition_CCompositionBitmapInterpolationMode {
    __x_ABI_CMicrosoft_CUI_CComposition_CCompositionBitmapInterpolationMode_NearestNeighbor = 0,
    __x_ABI_CMicrosoft_CUI_CComposition_CCompositionBitmapInterpolationMode_Linear = 1,
};
enum __x_ABI_CMicrosoft_CUI_CComposition_CCompositionStretch {
    __x_ABI_CMicrosoft_CUI_CComposition_CCompositionStretch_None = 0,
    __x_ABI_CMicrosoft_CUI_CComposition_CCompositionStretch_Fill = 1,
    __x_ABI_CMicrosoft_CUI_CComposition_CCompositionStretch_Uniform = 2,
    __x_ABI_CMicrosoft_CUI_CComposition_CCompositionStretch_UniformToFill = 3,
};
enum __x_ABI_CMicrosoft_CUI_CComposition_CCompositionEffectFactoryLoadStatus {
    __x_ABI_CMicrosoft_CUI_CComposition_CCompositionEffectFactoryLoadStatus_Success = 0,
    __x_ABI_CMicrosoft_CUI_CComposition_CCompositionEffectFactoryLoadStatus_EffectTooComplex = 1,
    __x_ABI_CMicrosoft_CUI_CComposition_CCompositionEffectFactoryLoadStatus_Pending = 2,
    __x_ABI_CMicrosoft_CUI_CComposition_CCompositionEffectFactoryLoadStatus_Other = -1,
};
enum __x_ABI_CMicrosoft_CUI_CComposition_CCompositionBackfaceVisibility { SCUI_BackfaceVisibility_Visible = 0 };
enum __x_ABI_CMicrosoft_CUI_CComposition_CCompositionBorderMode { SCUI_BorderMode_Inherit = 0 };
enum __x_ABI_CMicrosoft_CUI_CComposition_CCompositionCompositeMode { SCUI_CompositeMode_Inherit = 0 };

typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositor __x_ABI_CMicrosoft_CUI_CComposition_CICompositor;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CIVisual __x_ABI_CMicrosoft_CUI_CComposition_CIVisual;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual __x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection __x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection;
typedef interface __x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics __x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CIVisualElement2 __x_ABI_CMicrosoft_CUI_CComposition_CIVisualElement2;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositionObject __x_ABI_CMicrosoft_CUI_CComposition_CICompositionObject;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectBrush __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectBrush;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactory __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactory;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameter __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameter;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameterFactory __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameterFactory;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush __x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositionVisualSurface __x_ABI_CMicrosoft_CUI_CComposition_CICompositionVisualSurface;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositorWithVisualSurface __x_ABI_CMicrosoft_CUI_CComposition_CICompositorWithVisualSurface;
typedef interface __x_ABI_CMicrosoft_CUI_CComposition_CISpriteVisual __x_ABI_CMicrosoft_CUI_CComposition_CISpriteVisual;
typedef interface __x_ABI_C__FIIterable_1_HSTRING __x_ABI_C__FIIterable_1_HSTRING;

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
    HRESULT (STDMETHODCALLTYPE *get_Properties)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionObject *, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionPropertySet **);
    HRESULT (STDMETHODCALLTYPE *StartAnimation)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionObject *, HSTRING, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionAnimation *);
    HRESULT (STDMETHODCALLTYPE *StopAnimation)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionObject *, HSTRING);
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
    HRESULT (STDMETHODCALLTYPE *CreateColorKeyFrameAnimation)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, __x_ABI_CMicrosoft_CUI_CComposition_CIColorKeyFrameAnimation **);
    HRESULT (STDMETHODCALLTYPE *CreateColorBrush)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionColorBrush **);
    HRESULT (STDMETHODCALLTYPE *CreateColorBrushWithColor)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, __x_ABI_CWindows_CUI_CColor, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionColorBrush **);
    HRESULT (STDMETHODCALLTYPE *CreateContainerVisual)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, __x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual **);
    HRESULT (STDMETHODCALLTYPE *CreateCubicBezierEasingFunction)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, __x_ABI_CWindows_CFoundation_CNumerics_CVector2, __x_ABI_CWindows_CFoundation_CNumerics_CVector2, __x_ABI_CMicrosoft_CUI_CComposition_CICubicBezierEasingFunction **);
    HRESULT (STDMETHODCALLTYPE *CreateEffectFactory)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, ABI::Windows::Graphics::Effects::IGraphicsEffect *, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactory **);
    HRESULT (STDMETHODCALLTYPE *CreateEffectFactoryWithProperties)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, ABI::Windows::Graphics::Effects::IGraphicsEffect *, __x_ABI_C__FIIterable_1_HSTRING *, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactory **);
    HRESULT (STDMETHODCALLTYPE *CreateExpressionAnimation)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, __x_ABI_CMicrosoft_CUI_CComposition_CIExpressionAnimation **);
    HRESULT (STDMETHODCALLTYPE *CreateExpressionAnimationWithExpression)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, HSTRING, __x_ABI_CMicrosoft_CUI_CComposition_CIExpressionAnimation **);
    HRESULT (STDMETHODCALLTYPE *CreateInsetClip)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, __x_ABI_CMicrosoft_CUI_CComposition_CIInsetClip **);
    HRESULT (STDMETHODCALLTYPE *CreateInsetClipWithInsets)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, FLOAT, FLOAT, FLOAT, FLOAT, __x_ABI_CMicrosoft_CUI_CComposition_CIInsetClip **);
    HRESULT (STDMETHODCALLTYPE *CreateLinearEasingFunction)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, __x_ABI_CMicrosoft_CUI_CComposition_CILinearEasingFunction **);
    HRESULT (STDMETHODCALLTYPE *CreatePropertySet)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionPropertySet **);
    HRESULT (STDMETHODCALLTYPE *CreateQuaternionKeyFrameAnimation)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, __x_ABI_CMicrosoft_CUI_CComposition_CIQuaternionKeyFrameAnimation **);
    HRESULT (STDMETHODCALLTYPE *CreateScalarKeyFrameAnimation)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, __x_ABI_CMicrosoft_CUI_CComposition_CIScalarKeyFrameAnimation **);
    HRESULT (STDMETHODCALLTYPE *CreateScopedBatch)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, __x_ABI_CMicrosoft_CUI_CComposition_CCompositionBatchTypes, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionScopedBatch **);
    HRESULT (STDMETHODCALLTYPE *CreateSpriteVisual)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, __x_ABI_CMicrosoft_CUI_CComposition_CISpriteVisual **);
    HRESULT (STDMETHODCALLTYPE *CreateSurfaceBrush)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush **);
    HRESULT (STDMETHODCALLTYPE *CreateSurfaceBrushWithSurface)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurface *, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush **);
    HRESULT (STDMETHODCALLTYPE *CreateVector2KeyFrameAnimation)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, __x_ABI_CMicrosoft_CUI_CComposition_CIVector2KeyFrameAnimation **);
    HRESULT (STDMETHODCALLTYPE *CreateVector3KeyFrameAnimation)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, __x_ABI_CMicrosoft_CUI_CComposition_CIVector3KeyFrameAnimation **);
    HRESULT (STDMETHODCALLTYPE *CreateVector4KeyFrameAnimation)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, __x_ABI_CMicrosoft_CUI_CComposition_CIVector4KeyFrameAnimation **);
    HRESULT (STDMETHODCALLTYPE *GetCommitBatch)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositor *, __x_ABI_CMicrosoft_CUI_CComposition_CCompositionBatchTypes, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionCommitBatch **);
} __x_ABI_CMicrosoft_CUI_CComposition_CICompositorVtbl;
interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositor {
    CONST_VTBL struct __x_ABI_CMicrosoft_CUI_CComposition_CICompositorVtbl *lpVtbl;
};

typedef struct __x_ABI_CMicrosoft_CUI_CComposition_CICompositorWithVisualSurfaceVtbl {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositorWithVisualSurface *, REFIID, void **);
    ULONG (STDMETHODCALLTYPE *AddRef)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositorWithVisualSurface *);
    ULONG (STDMETHODCALLTYPE *Release)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositorWithVisualSurface *);
    HRESULT (STDMETHODCALLTYPE *GetIids)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositorWithVisualSurface *, ULONG *, IID **);
    HRESULT (STDMETHODCALLTYPE *GetRuntimeClassName)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositorWithVisualSurface *, HSTRING *);
    HRESULT (STDMETHODCALLTYPE *GetTrustLevel)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositorWithVisualSurface *, TrustLevel *);
    HRESULT (STDMETHODCALLTYPE *CreateVisualSurface)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositorWithVisualSurface *, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionVisualSurface **);
} __x_ABI_CMicrosoft_CUI_CComposition_CICompositorWithVisualSurfaceVtbl;
interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositorWithVisualSurface {
    CONST_VTBL struct __x_ABI_CMicrosoft_CUI_CComposition_CICompositorWithVisualSurfaceVtbl *lpVtbl;
};

typedef struct __x_ABI_CMicrosoft_CUI_CComposition_CICompositionVisualSurfaceVtbl {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionVisualSurface *, REFIID, void **);
    ULONG (STDMETHODCALLTYPE *AddRef)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionVisualSurface *);
    ULONG (STDMETHODCALLTYPE *Release)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionVisualSurface *);
    HRESULT (STDMETHODCALLTYPE *GetIids)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionVisualSurface *, ULONG *, IID **);
    HRESULT (STDMETHODCALLTYPE *GetRuntimeClassName)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionVisualSurface *, HSTRING *);
    HRESULT (STDMETHODCALLTYPE *GetTrustLevel)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionVisualSurface *, TrustLevel *);
    HRESULT (STDMETHODCALLTYPE *get_SourceVisual)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionVisualSurface *, __x_ABI_CMicrosoft_CUI_CComposition_CIVisual **);
    HRESULT (STDMETHODCALLTYPE *put_SourceVisual)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionVisualSurface *, __x_ABI_CMicrosoft_CUI_CComposition_CIVisual *);
    HRESULT (STDMETHODCALLTYPE *get_SourceOffset)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionVisualSurface *, __x_ABI_CWindows_CFoundation_CNumerics_CVector2 *);
    HRESULT (STDMETHODCALLTYPE *put_SourceOffset)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionVisualSurface *, __x_ABI_CWindows_CFoundation_CNumerics_CVector2);
    HRESULT (STDMETHODCALLTYPE *get_SourceSize)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionVisualSurface *, __x_ABI_CWindows_CFoundation_CNumerics_CVector2 *);
    HRESULT (STDMETHODCALLTYPE *put_SourceSize)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionVisualSurface *, __x_ABI_CWindows_CFoundation_CNumerics_CVector2);
} __x_ABI_CMicrosoft_CUI_CComposition_CICompositionVisualSurfaceVtbl;
interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositionVisualSurface {
    CONST_VTBL struct __x_ABI_CMicrosoft_CUI_CComposition_CICompositionVisualSurfaceVtbl *lpVtbl;
};

typedef struct __x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrushVtbl {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush *, REFIID, void **);
    ULONG (STDMETHODCALLTYPE *AddRef)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush *);
    ULONG (STDMETHODCALLTYPE *Release)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush *);
    HRESULT (STDMETHODCALLTYPE *GetIids)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush *, ULONG *, IID **);
    HRESULT (STDMETHODCALLTYPE *GetRuntimeClassName)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush *, HSTRING *);
    HRESULT (STDMETHODCALLTYPE *GetTrustLevel)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush *, TrustLevel *);
    HRESULT (STDMETHODCALLTYPE *get_BitmapInterpolationMode)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush *, __x_ABI_CMicrosoft_CUI_CComposition_CCompositionBitmapInterpolationMode *);
    HRESULT (STDMETHODCALLTYPE *put_BitmapInterpolationMode)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush *, __x_ABI_CMicrosoft_CUI_CComposition_CCompositionBitmapInterpolationMode);
    HRESULT (STDMETHODCALLTYPE *get_HorizontalAlignmentRatio)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush *, FLOAT *);
    HRESULT (STDMETHODCALLTYPE *put_HorizontalAlignmentRatio)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush *, FLOAT);
    HRESULT (STDMETHODCALLTYPE *get_Stretch)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush *, __x_ABI_CMicrosoft_CUI_CComposition_CCompositionStretch *);
    HRESULT (STDMETHODCALLTYPE *put_Stretch)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush *, __x_ABI_CMicrosoft_CUI_CComposition_CCompositionStretch);
    HRESULT (STDMETHODCALLTYPE *get_Surface)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush *, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurface **);
    HRESULT (STDMETHODCALLTYPE *put_Surface)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush *, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurface *);
    HRESULT (STDMETHODCALLTYPE *get_VerticalAlignmentRatio)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush *, FLOAT *);
    HRESULT (STDMETHODCALLTYPE *put_VerticalAlignmentRatio)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush *, FLOAT);
} __x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrushVtbl;
interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush {
    CONST_VTBL struct __x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrushVtbl *lpVtbl;
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
    HRESULT (STDMETHODCALLTYPE *GetSourceParameter)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectBrush *, HSTRING, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionBrush **);
    HRESULT (STDMETHODCALLTYPE *SetSourceParameter)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectBrush *, HSTRING, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionBrush *);
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
    HRESULT (STDMETHODCALLTYPE *get_ExtendedError)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactory *, HRESULT *);
    HRESULT (STDMETHODCALLTYPE *get_LoadStatus)(__x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactory *, __x_ABI_CMicrosoft_CUI_CComposition_CCompositionEffectFactoryLoadStatus *);
} __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactoryVtbl;
interface __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactory {
    CONST_VTBL struct __x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectFactoryVtbl *lpVtbl;
};

typedef struct __x_ABI_CMicrosoft_CUI_CComposition_CISpriteVisualVtbl {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(__x_ABI_CMicrosoft_CUI_CComposition_CISpriteVisual *, REFIID, void **);
    ULONG (STDMETHODCALLTYPE *AddRef)(__x_ABI_CMicrosoft_CUI_CComposition_CISpriteVisual *);
    ULONG (STDMETHODCALLTYPE *Release)(__x_ABI_CMicrosoft_CUI_CComposition_CISpriteVisual *);
    HRESULT (STDMETHODCALLTYPE *GetIids)(__x_ABI_CMicrosoft_CUI_CComposition_CISpriteVisual *, ULONG *, IID **);
    HRESULT (STDMETHODCALLTYPE *GetRuntimeClassName)(__x_ABI_CMicrosoft_CUI_CComposition_CISpriteVisual *, HSTRING *);
    HRESULT (STDMETHODCALLTYPE *GetTrustLevel)(__x_ABI_CMicrosoft_CUI_CComposition_CISpriteVisual *, TrustLevel *);
    HRESULT (STDMETHODCALLTYPE *get_Brush)(__x_ABI_CMicrosoft_CUI_CComposition_CISpriteVisual *, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionBrush **);
    HRESULT (STDMETHODCALLTYPE *put_Brush)(__x_ABI_CMicrosoft_CUI_CComposition_CISpriteVisual *, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionBrush *);
} __x_ABI_CMicrosoft_CUI_CComposition_CISpriteVisualVtbl;
interface __x_ABI_CMicrosoft_CUI_CComposition_CISpriteVisual {
    CONST_VTBL struct __x_ABI_CMicrosoft_CUI_CComposition_CISpriteVisualVtbl *lpVtbl;
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
    HRESULT (STDMETHODCALLTYPE *get_TransformMatrix)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CWindows_CFoundation_CNumerics_CMatrix4x4 *);
    HRESULT (STDMETHODCALLTYPE *put_TransformMatrix)(__x_ABI_CMicrosoft_CUI_CComposition_CIVisual *, __x_ABI_CWindows_CFoundation_CNumerics_CMatrix4x4);
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

typedef struct __x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStaticsVtbl {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(__x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics *, REFIID, void **);
    ULONG (STDMETHODCALLTYPE *AddRef)(__x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics *);
    ULONG (STDMETHODCALLTYPE *Release)(__x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics *);
    HRESULT (STDMETHODCALLTYPE *GetIids)(__x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics *, ULONG *, IID **);
    HRESULT (STDMETHODCALLTYPE *GetRuntimeClassName)(__x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics *, HSTRING *);
    HRESULT (STDMETHODCALLTYPE *GetTrustLevel)(__x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics *, TrustLevel *);
    HRESULT (STDMETHODCALLTYPE *GetElementVisual)(__x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics *, __x_ABI_CMicrosoft_CUI_CXaml_CIUIElement *, __x_ABI_CMicrosoft_CUI_CComposition_CIVisual **);
    HRESULT (STDMETHODCALLTYPE *GetElementChildVisual)(__x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics *, __x_ABI_CMicrosoft_CUI_CXaml_CIUIElement *, __x_ABI_CMicrosoft_CUI_CComposition_CIVisual **);
    HRESULT (STDMETHODCALLTYPE *SetElementChildVisual)(__x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics *, __x_ABI_CMicrosoft_CUI_CXaml_CIUIElement *, __x_ABI_CMicrosoft_CUI_CComposition_CIVisual *);
    HRESULT (STDMETHODCALLTYPE *GetScrollViewerManipulationPropertySet)(__x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics *, void *, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionPropertySet **);
    HRESULT (STDMETHODCALLTYPE *SetImplicitShowAnimation)(__x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics *, __x_ABI_CMicrosoft_CUI_CXaml_CIUIElement *, void *);
    HRESULT (STDMETHODCALLTYPE *SetImplicitHideAnimation)(__x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics *, __x_ABI_CMicrosoft_CUI_CXaml_CIUIElement *, void *);
    HRESULT (STDMETHODCALLTYPE *SetIsTranslationEnabled)(__x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics *, __x_ABI_CMicrosoft_CUI_CXaml_CIUIElement *, boolean);
    HRESULT (STDMETHODCALLTYPE *GetPointerPositionPropertySet)(__x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics *, __x_ABI_CMicrosoft_CUI_CXaml_CIUIElement *, __x_ABI_CMicrosoft_CUI_CComposition_CICompositionPropertySet **);
} __x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStaticsVtbl;
interface __x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics {
    CONST_VTBL struct __x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStaticsVtbl *lpVtbl;
};

static const IID IID___x_ABI_CMicrosoft_CUI_CComposition_CICompositionBrush = {0x483924E7, 0x99A5, 0x5377, {0x96, 0x8B, 0xDE, 0xC6, 0xD4, 0x0B, 0xBC, 0xCD}};
static const IID IID___x_ABI_CMicrosoft_CUI_CComposition_CICompositionEffectSourceParameterFactory = {0x26185954, 0x4489, 0x5D0E, {0xAE, 0x4D, 0x7B, 0xC4, 0xBB, 0xBC, 0x61, 0x61}};
static const IID IID___x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurface = {0x9EC612C3, 0xA5D2, 0x4F97, {0x9D, 0xF3, 0x6B, 0x49, 0xCE, 0x73, 0x62, 0x15}};
static const IID IID___x_ABI_CMicrosoft_CUI_CComposition_CICompositionObject = {0x0E583D49, 0xFB5E, 0x5481, {0xA4, 0x26, 0xD3, 0xC4, 0x1E, 0x05, 0x9A, 0x5A}};
static const IID IID___x_ABI_CMicrosoft_CUI_CComposition_CICompositorWithVisualSurface = {0x5FCFE24A, 0x690A, 0x5378, {0xAC, 0xEE, 0x56, 0x1E, 0x84, 0xBF, 0xB9, 0x82}};
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
    __x_ABI_CMicrosoft_CUI_CComposition_CIVisual *sourceVisual = nullptr;
    __x_ABI_CMicrosoft_CUI_CComposition_CICompositor *compositor = nullptr;
    __x_ABI_CMicrosoft_CUI_CComposition_CICompositionVisualSurface *visualSurface = nullptr;
    __x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurfaceBrush *surfaceBrush = nullptr;
    __x_ABI_CMicrosoft_CUI_CComposition_CISpriteVisual *spriteVisual = nullptr;
    __x_ABI_CMicrosoft_CUI_CComposition_CIVisual *spriteAsVisual = nullptr;
    bool attachedAsElementChild = false;
    float radius = -1;

    ~BlurState() {
        clear();
    }

    BlurState() = default;
    BlurState(const BlurState &) = delete;
    BlurState &operator=(const BlurState &) = delete;

    void clear() {
        scui_release(spriteAsVisual);
        scui_release(spriteVisual);
        scui_release(surfaceBrush);
        scui_release(visualSurface);
        scui_release(compositor);
        scui_release(sourceVisual);
        scui_release(element);
        if (identity != nullptr) {
            identity->Release();
            identity = nullptr;
        }
    }
};

static std::unordered_map<IUnknown *, std::unique_ptr<BlurState>> scui_blur_states;

HRESULT scui_get_element_composition_preview(
    __x_ABI_CMicrosoft_CUI_CXaml_CIUIElement *element,
    __x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics **result
) {
    *result = nullptr;
    if (element == nullptr) {
        return E_POINTER;
    }

    static __x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics *cached = nullptr;
    if (cached != nullptr) {
        cached->lpVtbl->AddRef(cached);
        *result = cached;
        return S_OK;
    }

    ComPtr<IInspectable> inspectable;
    HRESULT hr = scui_get_activation_factory(
        L"Microsoft.UI.Xaml.Hosting.ElementCompositionPreview",
        IID_IInspectable,
        inspectable.GetAddressOf()
    );
    if (FAILED(hr)) {
        return hr;
    }

    ULONG iidCount = 0;
    IID *iids = nullptr;
    hr = inspectable->GetIids(&iidCount, &iids);
    if (FAILED(hr)) {
        return hr;
    }

    hr = E_NOINTERFACE;
    for (ULONG index = 0; index < iidCount; ++index) {
        auto candidate = static_cast<__x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics *>(nullptr);
        if (FAILED(inspectable->QueryInterface(iids[index], reinterpret_cast<void **>(&candidate)))) {
            continue;
        }

        __x_ABI_CMicrosoft_CUI_CComposition_CIVisual *visual = nullptr;
        HRESULT visualResult = candidate->lpVtbl->GetElementVisual(
            candidate,
            element,
            &visual
        );
        scui_release(visual);
        if (SUCCEEDED(visualResult)) {
            cached = candidate;
            cached->lpVtbl->AddRef(cached);
            *result = candidate;
            hr = S_OK;
            break;
        }

        candidate->lpVtbl->Release(candidate);
    }

    CoTaskMemFree(iids);
    return hr;
}

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

bool scui_insert_visual_above_siblings(
    __x_ABI_CMicrosoft_CUI_CComposition_CIVisual *visual,
    __x_ABI_CMicrosoft_CUI_CComposition_CIVisual *newChild
) {
    __x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual *parent = nullptr;
    HRESULT hr = visual->lpVtbl->get_Parent(visual, &parent);
    if (FAILED(hr) || parent == nullptr) {
        return false;
    }

    __x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection *children = nullptr;
    hr = parent->lpVtbl->get_Children(parent, &children);
    scui_release(parent);
    if (FAILED(hr) || children == nullptr) {
        return false;
    }

    hr = children->lpVtbl->InsertAtTop(children, newChild);
    scui_release(children);
    return SUCCEEDED(hr);
}

void scui_remove_visual_from_parent(
    __x_ABI_CMicrosoft_CUI_CComposition_CIVisual *visual
) {
    if (visual == nullptr) {
        return;
    }

    __x_ABI_CMicrosoft_CUI_CComposition_CIContainerVisual *parent = nullptr;
    HRESULT hr = visual->lpVtbl->get_Parent(visual, &parent);
    if (FAILED(hr) || parent == nullptr) {
        return;
    }

    __x_ABI_CMicrosoft_CUI_CComposition_CIVisualCollection *children = nullptr;
    hr = parent->lpVtbl->get_Children(parent, &children);
    scui_release(parent);
    if (FAILED(hr) || children == nullptr) {
        return;
    }

    children->lpVtbl->Remove(children, visual);
    scui_release(children);
}

bool scui_attach_visual_to_element(
    __x_ABI_CMicrosoft_CUI_CXaml_CIUIElement *element,
    __x_ABI_CMicrosoft_CUI_CComposition_CIVisual *visual
) {
    __x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics *preview = nullptr;
    HRESULT hr = scui_get_element_composition_preview(element, &preview);
    if (FAILED(hr)) {
        return false;
    }

    hr = preview->lpVtbl->SetElementChildVisual(preview, element, visual);
    preview->lpVtbl->Release(preview);
    return SUCCEEDED(hr);
}

void scui_detach_visual_from_element(
    __x_ABI_CMicrosoft_CUI_CXaml_CIUIElement *element
) {
    __x_ABI_CMicrosoft_CUI_CXaml_CHosting_CIElementCompositionPreviewStatics *preview = nullptr;
    HRESULT hr = scui_get_element_composition_preview(element, &preview);
    if (FAILED(hr)) {
        return;
    }

    preview->lpVtbl->SetElementChildVisual(preview, element, nullptr);
    preview->lpVtbl->Release(preview);
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

    __x_ABI_CWindows_CFoundation_CNumerics_CVector2 sourceOffset = {
        -margin,
        -margin,
    };
    __x_ABI_CWindows_CFoundation_CNumerics_CVector2 size = {
        clampedWidth + margin * 2.0f,
        clampedHeight + margin * 2.0f,
    };

    HRESULT hr = state.visualSurface->lpVtbl->put_SourceOffset(
        state.visualSurface,
        sourceOffset
    );
    if (FAILED(hr)) {
        return false;
    }

    hr = state.visualSurface->lpVtbl->put_SourceSize(
        state.visualSurface,
        size
    );
    if (FAILED(hr)) {
        return false;
    }

    __x_ABI_CWindows_CFoundation_CNumerics_CVector3 offset = {};
    if (SUCCEEDED(state.sourceVisual->lpVtbl->get_Offset(state.sourceVisual, &offset))) {
        offset.X -= margin;
        offset.Y -= margin;
        hr = state.spriteAsVisual->lpVtbl->put_Offset(state.spriteAsVisual, offset);
        if (FAILED(hr)) {
            return false;
        }
    }

    hr = state.spriteAsVisual->lpVtbl->put_Size(state.spriteAsVisual, size);
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

    __x_ABI_CMicrosoft_CUI_CComposition_CICompositionBrush *sourceBrush = nullptr;
    hr = scui_query(
        state.surfaceBrush,
        IID___x_ABI_CMicrosoft_CUI_CComposition_CICompositionBrush,
        &sourceBrush
    );
    if (FAILED(hr)) {
        scui_release(effectBrush);
        return false;
    }

    HSTRING sourceName = nullptr;
    hr = scui_make_hstring(L"source", &sourceName);
    if (SUCCEEDED(hr)) {
        hr = effectBrush->lpVtbl->SetSourceParameter(
            effectBrush,
            sourceName,
            sourceBrush
        );
        WindowsDeleteString(sourceName);
    }
    scui_release(sourceBrush);
    if (FAILED(hr)) {
        scui_release(effectBrush);
        return false;
    }

    __x_ABI_CMicrosoft_CUI_CComposition_CICompositionBrush *blurBrush = nullptr;
    hr = scui_query(
        effectBrush,
        IID___x_ABI_CMicrosoft_CUI_CComposition_CICompositionBrush,
        &blurBrush
    );
    if (FAILED(hr)) {
        scui_release(effectBrush);
        return false;
    }

    hr = state.spriteVisual->lpVtbl->put_Brush(state.spriteVisual, blurBrush);
    scui_release(blurBrush);
    scui_release(effectBrush);
    if (FAILED(hr)) {
        return false;
    }

    state.radius = radius;
    return true;
}

bool scui_initialize_blur_state(
    void *elementPointer,
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

    __x_ABI_CMicrosoft_CUI_CComposition_CIVisualElement2 *visualElement = nullptr;
    hr = scui_query(
        identity,
        IID___x_ABI_CMicrosoft_CUI_CComposition_CIVisualElement2,
        &visualElement
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

    __x_ABI_CMicrosoft_CUI_CComposition_CICompositorWithVisualSurface *visualSurfaceCompositor = nullptr;
    hr = scui_query(
        state.compositor,
        IID___x_ABI_CMicrosoft_CUI_CComposition_CICompositorWithVisualSurface,
        &visualSurfaceCompositor
    );
    if (FAILED(hr)) {
        return false;
    }

    hr = visualSurfaceCompositor->lpVtbl->CreateVisualSurface(
        visualSurfaceCompositor,
        &state.visualSurface
    );
    scui_release(visualSurfaceCompositor);
    if (FAILED(hr)) {
        return false;
    }

    hr = state.visualSurface->lpVtbl->put_SourceVisual(
        state.visualSurface,
        state.sourceVisual
    );
    if (FAILED(hr)) {
        return false;
    }

    __x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurface *surface = nullptr;
    hr = scui_query(
        state.visualSurface,
        IID___x_ABI_CMicrosoft_CUI_CComposition_CICompositionSurface,
        &surface
    );
    if (FAILED(hr)) {
        return false;
    }

    hr = state.compositor->lpVtbl->CreateSurfaceBrushWithSurface(
        state.compositor,
        surface,
        &state.surfaceBrush
    );
    scui_release(surface);
    if (FAILED(hr)) {
        return false;
    }

    state.surfaceBrush->lpVtbl->put_Stretch(
        state.surfaceBrush,
        __x_ABI_CMicrosoft_CUI_CComposition_CCompositionStretch_Fill
    );

    hr = state.compositor->lpVtbl->CreateSpriteVisual(
        state.compositor,
        &state.spriteVisual
    );
    if (FAILED(hr)) {
        return false;
    }

    hr = scui_query(
        state.spriteVisual,
        IID___x_ABI_CMicrosoft_CUI_CComposition_CIVisual,
        &state.spriteAsVisual
    );
    if (FAILED(hr)) {
        return false;
    }

    __x_ABI_CWindows_CFoundation_CNumerics_CVector3 offset = {};
    if (SUCCEEDED(state.sourceVisual->lpVtbl->get_Offset(state.sourceVisual, &offset))) {
        state.spriteAsVisual->lpVtbl->put_Offset(state.spriteAsVisual, offset);
    }

    if (scui_attach_visual_to_element(state.element, state.spriteAsVisual)) {
        state.attachedAsElementChild = true;
        return true;
    }

    return scui_insert_visual_above_siblings(state.sourceVisual, state.spriteAsVisual);
}

void scui_remove_blur_state(IUnknown *identity) {
    auto iterator = scui_blur_states.find(identity);
    if (iterator == scui_blur_states.end()) {
        return;
    }

    if (iterator->second->attachedAsElementChild) {
        scui_detach_visual_from_element(iterator->second->element);
    } else {
        scui_remove_visual_from_parent(iterator->second->spriteAsVisual);
    }

    scui_blur_states.erase(iterator);
}
} // namespace

bool scui_set_element_blur(
    void *element,
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
        if (!scui_initialize_blur_state(element, *state, identity)) {
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

bool scui_update_element_blur_size(
    void *element,
    double width,
    double height
) {
    IUnknown *identity = nullptr;
    if (FAILED(scui_get_blur_identity(element, &identity))) {
        return false;
    }

    auto iterator = scui_blur_states.find(identity);
    identity->Release();
    if (iterator == scui_blur_states.end()) {
        return true;
    }
    return scui_update_blur_state_size(
        *iterator->second,
        width,
        height,
        iterator->second->radius
    );
}

void scui_clear_element_blur(void *element) {
    IUnknown *identity = nullptr;
    if (FAILED(scui_get_blur_identity(element, &identity))) {
        return;
    }

    scui_remove_blur_state(identity);
    identity->Release();
}
