from .options import ElectronOptions
from .thread import ElectronThread
from .engine import ElectronEngine


def setup_electron():
    from gi.repository import Nuvola
    Nuvola.WebOptions.set_default(ElectronOptions)

