def set_up_requirements():
    import gi
    gi.require_version("Drt", "1.0")
    gi.require_version("Drtgtk", "1.0")
    gi.require_version("Nuvola", "1.0")
    gi.require_version("Gtk", "3.0")
    gi.require_version("Gdk", "3.0")
    gi.require_version("GdkX11", "3.0")
