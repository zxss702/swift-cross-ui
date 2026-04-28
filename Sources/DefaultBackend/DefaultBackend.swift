#if SCUI_DEFAULT_BACKEND_AppKitBackend
    import AppKitBackend
    public typealias DefaultBackend = AppKitBackend
#elseif SCUI_DEFAULT_BACKEND_GtkBackend
    import GtkBackend
    public typealias DefaultBackend = GtkBackend
#elseif SCUI_DEFAULT_BACKEND_Gtk3Backend
    import Gtk3Backend
    public typealias DefaultBackend = Gtk3Backend
#elseif SCUI_DEFAULT_BACKEND_WinUIBackend
    import WinUIBackend
    public typealias DefaultBackend = WinUIBackend
#elseif SCUI_DEFAULT_BACKEND_QtBackend
    import QtBackend
    public typealias DefaultBackend = QtBackend
#elseif SCUI_DEFAULT_BACKEND_CursesBackend
    import CursesBackend
    public typealias DefaultBackend = CursesBackend
#elseif SCUI_DEFAULT_BACKEND_UIKitBackend
    import UIKitBackend
    public typealias DefaultBackend = UIKitBackend
#elseif canImport(AppKitBackend)
    import AppKitBackend
    public typealias DefaultBackend = AppKitBackend
#elseif canImport(GtkBackend)
    import GtkBackend
    public typealias DefaultBackend = GtkBackend
#elseif canImport(Gtk3Backend)
    import Gtk3Backend
    public typealias DefaultBackend = Gtk3Backend
#elseif canImport(WinUIBackend)
    import WinUIBackend
    public typealias DefaultBackend = WinUIBackend
#elseif canImport(QtBackend)
    import QtBackend
    public typealias DefaultBackend = QtBackend
#elseif canImport(CursesBackend)
    import CursesBackend
    public typealias DefaultBackend = CursesBackend
#elseif canImport(UIKitBackend)
    import UIKitBackend
    public typealias DefaultBackend = UIKitBackend
#else
    #error("Unknown backend selected")
#endif
