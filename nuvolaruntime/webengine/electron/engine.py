from queue import Empty

import sys
from gi.repository import Nuvola, GLib, GdkX11, Gdk, Gtk

from nuvolaruntime.webengine.electron.thread import ElectronThread
from nuvolaruntime.widgets.windowsocket import WindowSocket


class ElectronEngine(Nuvola.WebEngine):
    __gtype_name__ = "ElectronEngine"
    socket: WindowSocket
    electron: ElectronThread

    def __init__(self, options):
        super().__init__(options=options, storage=options.get_storage())
        self._web_plugins = False
        self.socket = Gtk.Socket()
        self.electron = None
        self.web_app = None

    def do_set_media_source_extension(self, enabled: bool):
        pass

    def do_set_web_plugins(self, enabled: bool):
        self._web_plugins = enabled

    def do_get_main_web_view(self):
        return self.socket

    def do_early_init(self, runner_app: Nuvola.AppRunnerController, ipc_bus: Nuvola.IpcBus,
                      web_app: Nuvola.WebApp, config: Nuvola.Config, connection: Nuvola.Connection,
                      worker_data: GLib.HashTable):
        self.web_app = web_app
        url = 'https://play.google.com/music/'  # self.web_app.get_home_url()
        self.electron = ElectronThread(["data/electron/main.js", "URL:" + url])
        self.electron.start()
        GLib.timeout_add(10, self._attach_electron_window_cb)

    def _attach_electron_window_cb(self):
        try:
            xid_info = self.electron.stdout.get_nowait()
        except Empty:
            return True

        xid_bytes = bytes([int(s) for s in xid_info.split(b':')[1:-1]])
        xid = int.from_bytes(xid_bytes, sys.byteorder)
        self.socket.show()
        self.socket.add_id(xid)
        self.socket.set_can_focus(True)
        self.event_box.child_focus(Gtk.DirectionType.TAB_FORWARD)
        self.socket.grab_focus()

        def key_event(*args):
            print("KeyPress", args)
            return Gdk.EVENT_PROPAGATE

        self.socket.connect("key-press-event", key_event)

        GLib.timeout_add(10, self._print_electron_stdout_cb)
        return False

    def _print_electron_stdout_cb(self):
        try:
            while True:
                print(self.electron.stdout.get_nowait().strip())
        except Empty:
            return True

    def do_init(self):
        pass

    def do_init_app_runner(self):
        pass

    def do_load_app(self):
        pass

    def do_go_home(self):
        pass

    def do_apply_network_proxy(self, connection: Nuvola.Connection):
        pass

    def do_go_back(self):
        pass

    def do_go_forward(self):
        pass

    def do_reload(self):
        pass

    def do_zoom_in(self):
        pass

    def do_zoom_out(self):
        pass

    def do_zoom_reset(self):
        pass

    def do_set_user_agent(self, user_agent: str = None):
        pass

    def do_get_preferences(self):  # out Variant values, out Variant entries):
        return None, None

        # def do_call_function(self, name: str, params):  # Variant params throws GLib.Error;
        #     pass
