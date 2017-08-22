from gi.repository import Nuvola


class ElectronOptions(Nuvola.WebOptions):
    __gtype_name__ = "ElectronOptions"

    def do_get_engine_version(self):
        return 0

    def do_create_web_engine(self):
        from nuvolaruntime.webengine.electron import ElectronEngine
        return ElectronEngine(self)
