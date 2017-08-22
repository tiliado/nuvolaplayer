#!/usr/bin/env python3
#
# Copyright 2014-2017 Jiří Janoušek <janousek.jiri@gmail.com>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met: 
# 
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer. 
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution. 
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

from argparse import ArgumentParser
from typing import List
import os
import sys


def main(argv: List[str]) -> int:
    parser = ArgumentParser(prog=argv[0])
    parser.add_argument(
        "--dbus", action="store_true", default=False,
        help="Connect to Nuvola via DBus.")
    parser.add_argument(
        "-D", "--debug", action="store_true", default=False,
        help="Print debugging messages")
    parser.add_argument(
        "-V", "--version", action="store_true", default=False,
        help="Print version and exit")
    parser.add_argument(
        "-v", "--verbose", action="store_true", default=False,
        help="Print informational messages")
    parser.add_argument(
        "-a", "--app-dir", required=True,
        help="Web app to run.")
    parser.add_argument(
        "--updates", action="store_true",
        help="Print modules that needs to be updated.")
    try:
        params = parser.parse_args(argv[1:])
    except Exception as e:
        sys.stderr.write("option parsing failed: %s\n" % e)
        return 1
    return start_gui(params, [])


def start_gui(params, argv, **_):
    from nuvolaruntime.pygi import set_up_requirements
    set_up_requirements()

    from nuvolaruntime.webengine.electron import setup_electron
    setup_electron()

    from gi.repository import GLib, Gio, Drt, Nuvola

    Drt.Logger.init_stderr((GLib.LogLevelFlags.LEVEL_DEBUG if params.debug else ( 
        GLib.LogLevelFlags.LEVEL_INFO if params.verbose else GLib.LogLevelFlags.LEVEL_WARNING)),
        True, "Runner")
    if os.environ.get("NUVOLA_TEST_ABORT") == "runner":
        raise RuntimeError("App runner abort requested.")
    
    print("Python app runner started.")
    app_dir = Gio.File.new_for_path(params.app_dir)
    if params.version:
        return Nuvola.startup_print_web_app_version_stdout(app_dir)

    try:
        if params.dbus:
            return Nuvola.startup_run_web_app_with_dbus_handshake(app_dir, argv)
        else:
            code = sys.stdin.readline().strip()
            return Nuvola.startup_run_web_app_as_subprocess(app_dir, code, argv)
    except GLib.Error as e:
        sys.stderr.write("Failed to load web app!\n")
        sys.stderr.write("Dir: %s\n" % params.app_dir)
        sys.stderr.write("Error: %s\n" % e)
        return 1

if __name__ == "__main__":
    sys.exit(main(sys.argv))
