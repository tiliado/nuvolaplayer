from typing import Any, Optional, Tuple

from gi.repository import Gtk, Gdk

Allocation = Any


class WindowSocket(Gtk.Bin):
    __gtype_name__ = "WindowSocket"

    def __init__(self, window: Optional[Gdk.Window] = None, **kwargs):
        super().__init__(**kwargs)
        self.set_has_window(False)
        self._window = window

    def embed_window(self, window: Optional[Gdk.Window]) -> Optional[Gdk.Window]:
        old_window = self._window
        realized = self.get_realized()
        visible = self.get_visible()
        if realized:
            if visible:
                self.hide()
            self.unrealize()

        self._window = window
        self.set_has_window(bool(window))

        if realized:
            self.realize()
            if visible:
                self.show()
                self.queue_resize()

        return old_window

    def do_realize(self):
        self.set_realized(True)
        window = self._window
        if window:
            window.reparent(self.get_parent_window(), 0, 0)
            allocation = self.get_allocation()
            window.move_resize(max(allocation.x, 0), max(allocation.y, 0),
                               min(allocation.width, 100), min(allocation.height, 100))
            self.set_window(window)
            self.register_window(window)
        else:
            window = self.get_parent_window()
            self.set_window(window)

    def do_get_preferred_width(self) -> Tuple[int, int]:
        return 100, 100

    def do_get_preferred_height(self) -> Tuple[int, int]:
        return 100, 100

    def do_size_allocate(self, allocation: Allocation):
        if self.get_realized() and self.get_has_window():
            x, y = self.translate_coordinates(self.get_toplevel(), allocation.x, allocation.y)
            self.get_window().move_resize(x, y, allocation.width, allocation.height)
