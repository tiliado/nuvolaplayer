# encoding: utf-8
#
# Copyright 2014-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

# Metadata #
#==========#

top = '.'
out = 'build'

APPNAME = "nuvolaruntime"
NUVOLA_BIN = "nuvola"
NUVOLACTL_BIN = "nuvolactl"
VERSION = "4.10.0"
GENERIC_NAME = "Web Apps"
BLURB = "Tight integration of web apps with your Linux desktop"
DEFAULT_HELP_URL = "https://github.com/tiliado/nuvolaruntime/wiki/Third-Party-Builds"
DEFAULT_WEB_APP_REQUIREMENTS_HELP_URL = DEFAULT_HELP_URL

MIN_DIORITE = "4.10.0"
MIN_VALA = "0.38.4"
MIN_GLIB = "2.52.0"
MIN_GTK = "3.22.0"
LEGACY_WEBKIT = "2.18.0"
FLATPAK_WEBKIT = "2.18.1"

# Extras #
#========#

import sys
assert sys.version_info >= (3, 4, 0), "Run waf with Python >= 3.4"

import os
import json
from waflib.Errors import ConfigurationError
from waflib import TaskGen, Utils, Errors, Node, Task
from waflib.Configure import conf
from nuvolamergejs import mergejs as merge_js
import check_vala_defs

TARGET_DIORITE = str(MIN_DIORITE[0])
MIN_DIORITE.rsplit(".", 1)[0]
TARGET_GLIB = MIN_GLIB.rsplit(".", 1)[0]
REVISION_SNAPSHOT = "snapshot"


def get_git_version():
    import subprocess
    if os.path.isdir(".git"):
        output = subprocess.check_output(["git", "describe", "--tags", "--long"])
        return output.decode("utf-8").strip().split("-")
    return VERSION, "0", REVISION_SNAPSHOT

def add_version_info(ctx):
    bare_version, n_commits, revision_id = get_git_version()
    if revision_id != REVISION_SNAPSHOT:
        revision_id = "{}-{}".format(n_commits, revision_id)
    versions = list(int(i) for i in bare_version.split("."))
    versions[2] += int(n_commits)
    version = "{}.{}.{}".format(*versions)
    release = "{}.{}".format(*versions)
    ctx.env.VERSION = version
    ctx.env.VERSIONS = versions
    ctx.env.RELEASE = release
    ctx.env.REVISION_ID = revision_id

def glib_encode_version(version):
    major, minor, _ = tuple(int(i) for i in version.split("."))
    return major << 16 | minor << 8

def vala_def(ctx, vala_definition):
    """Appends a Vala definition"""
    ctx.env.append_unique("VALA_DEFINES", vala_definition)

def pkgconfig(ctx, pkg, uselib, version, mandatory=True, store=None, valadef=None, define=None):
    """Wrapper for ctx.check_cfg."""
    result = True
    try:
        res = ctx.check_cfg(package=pkg, uselib_store=uselib, atleast_version=version, mandatory=True, args = '--cflags --libs')
        if valadef:
            vala_def(ctx, valadef)
        if define:
            for key, value in define.iteritems():
                ctx.define(key, value)
    except ConfigurationError as e:
        result = False
        if mandatory:
            raise e
    finally:
        if store is not None:
            ctx.env[store] = result
    return res

def loadjson(path, optional=False):
    try:
        with open(path, "rt", encoding="utf-8") as f:
            data = "".join((line if not line.strip().startswith("//") else "\n") for line in f)
            return json.loads(data)
    except FileNotFoundError:
        if optional:
            return {}
        raise

def mask(string):
    shift = int(1.0 * os.urandom(1)[0] / 255 * 85 + 15)
    return [shift] + [c + shift for c in string.encode("utf-8")]

@conf
def gir_compile(ctx, name, lib, dirname=".", merge=None, params=""):
    if merge:
        new_gir = ctx.path.find_or_declare(dirname + "/" + name + ".gir")
        tasks = [
            ctx(
                rule='../mergegir.py ${TGT} ${SRC}',
                source=[ctx.path.find_or_declare(entry) for entry in merge],
                target=new_gir),
            ctx(
                rule='${GIR_COMPILER} ${SRC} --output=${TGT} --shared-library="lib%s.so" %s' % (lib, params),
                source=new_gir,
                target=ctx.path.find_or_declare(dirname + "/" + name + ".typelib"),
                install_path="${LIBDIR}/girepository-1.0")
        ]
    else:
        return ctx(
        rule='${GIR_COMPILER} ${SRC} --output=${TGT} --shared-library="lib%s.so" %s' % (lib, params),
            source=ctx.path.find_or_declare(dirname + "/" + name + ".gir"),
            target=ctx.path.find_or_declare(dirname + "/" + name + ".typelib"),
            install_path="${LIBDIR}/girepository-1.0")

@TaskGen.feature('mergejs')
@TaskGen.before_method('process_source', 'process_rule')
def _mergejs_taskgen(self):
    source = Utils.to_list(getattr(self, 'source', []))
    if isinstance(source, Node.Node):
        source = [source]

    target = (getattr(self, 'target', []))
    if isinstance(target, str):
        target =  self.path.find_or_declare(target)
    elif not isinstance(target, Node.Node):
        raise Errors.WafError('invalid target for %r' % self)

    for i in range(len(source)):
        item = source[i]
        if isinstance(item, str):
            source[i] =  self.path.find_resource(item)
        elif not isinstance(item, Node.Node):
            raise Errors.WafError('invalid source for %r' % self)

    task = self.create_task('mergejs', source, target)
    install_path = getattr(self, 'install_path', None)
    if install_path:
        self.bld.install_files(install_path, target, chmod=getattr(self, 'chmod', Utils.O644))

    self.source = []


class mergejs(Task.Task):
    def run(self):
        output = merge_js([i.abspath() for i in self.inputs])
        self.outputs[0].write(output)
        return 0

@TaskGen.feature('checkvaladefs')
@TaskGen.before_method('process_source', 'process_rule')
def _checkvaladefs_taskgen(self):
    source = Utils.to_list(getattr(self, 'source', []))
    if isinstance(source, Node.Node):
        source = [source]

    for i, item in enumerate(source):
        if isinstance(item, str):
            source[i] =  self.path.find_resource(item)
        elif not isinstance(item, Node.Node):
            raise Errors.WafError('invalid source for %r' % self)

    task = self.create_task('checkvaladefs', source, None)
    try:
        task.definitions = self.definitions.split()
    except AttributeError:
        raise Errors.WafError('List of definitions is missing for %r' % self)
    self.source = []


class checkvaladefs(Task.Task):
    def run(self):
        return check_vala_defs.run(definitions=self.definitions, files=[i.abspath() for i in self.inputs])

@TaskGen.feature('valalint')
@TaskGen.before_method('process_source', 'process_rule')
def valalint_taskgen(self):
    source = Utils.to_list(getattr(self, 'source', []))
    if isinstance(source, Node.Node):
        source = [source]
    if not source:
        raise Errors.WafError('no input file')
    for i, item in enumerate(source):
        if isinstance(item, str):
            source[i] =  self.path.find_resource(item)
        elif not isinstance(item, Node.Node):
            raise Errors.WafError('invalid source for %r' % self)
    self.source = []
    task = self.create_task('valalint', source, None)

    if getattr(self, 'packages', None):
        task.packages = Utils.to_list(self.packages)
    if getattr(self, 'vapi_dirs', None):
        vapi_dirs = Utils.to_list(self.vapi_dirs)
        for vapi_dir in vapi_dirs:
            try:
                task.vapi_dirs.append(self.path.find_dir(vapi_dir).abspath())
            except AttributeError:
                Logs.warn('Unable to locate Vala API directory: %r', vapi_dir)
    if getattr(self, 'protected', None):
        task.protected = self.protected
    if getattr(self, 'private', None):
        task.private = self.private
    if getattr(self, 'inherit', None):
        task.inherit = self.inherit
    if getattr(self, 'deps', None):
        task.deps = self.deps
    if getattr(self, 'vala_defines', None):
        task.vala_defines = Utils.to_list(self.vala_defines)
    if getattr(self, 'vala_target_glib', None):
        task.vala_target_glib = self.vala_target_glib
    if getattr(self, 'enable_non_null_experimental', None):
        task.enable_non_null_experimental = self.enable_non_null_experimental
    if getattr(self, 'force', None):
        task.force = self.force
    if getattr(self, 'checks', None):
        task.valalint_checks = Utils.to_list(self.checks)


class valalint(Task.Task):
    vars  = ['VALALINT', 'VALALINTFLAGS']
    color = 'BLUE'
    def __init__(self, *k, **kw):
        Task.Task.__init__(self, *k, **kw)
        self.valalint_checks = []

    def run(self):
        cmd = [Utils.subst_vars('${VALALINT}', self.env)]
        if getattr(self, 'valalint_checks', None):
            for check in self.valalint_checks:
                cmd.append ('-c %s' % check)
        if self.env.VALALINTFLAGS:
            cmd.extend(self.env.VALALINTFLAGS)
        cmd.append (' '.join ([i.abspath() for i in self.inputs]))
        return self.generator.bld.exec_command(' '.join(cmd))


@TaskGen.feature('jslint')
@TaskGen.before_method('process_source', 'process_rule')
def jslint_taskgen(self):
    source = Utils.to_list(getattr(self, 'source', []))
    if isinstance(source, Node.Node):
        source = [source]
    if not source:
        raise Errors.WafError('no input file')
    for i, item in enumerate(source):
        if isinstance(item, str):
            source[i] =  self.path.find_resource(item)
        elif not isinstance(item, Node.Node):
            raise Errors.WafError('invalid source for %r' % self)

    self.source = []
    task = self.create_task('jslint', source, None)
    if getattr(self, 'global_vars', None):
        task.global_vars.extend(self.global_vars)


class jslint(Task.Task):
    vars  = ['JSLINT', 'JSLINTFLAGS']
    color = 'BLUE'
    def __init__(self, *k, **kw):
        Task.Task.__init__(self, *k, **kw)
        self.global_vars = []

    def run(self):
        cmd = [Utils.subst_vars('${JSLINT}', self.env)]
        if self.env.JSLINTFLAGS:
            cmd.extend(self.env.JSLINTFLAGS)
        for name in self.global_vars:
            cmd.extend(('--global', name))
        cmd.append (' '.join ([i.abspath() for i in self.inputs]))
        return self.generator.bld.exec_command(' '.join(cmd))


# Actions #
#=========#

def options(ctx):
    ctx.load('compiler_c vala')
    ctx.add_option(
        '--jsdir', type=str, default=None,
        help="Path to JavaScript modules [DATADIR/javascript].")
    ctx.add_option(
        '--branding', type=str, default="default",
        help="Branding profile to load.")
    ctx.add_option(
        '--no-debug-symbols', action='store_false', default=True, dest='debug',
        help="Turn off debugging symbols for gdb.")
    ctx.add_option(
        '--no-unity', action='store_false', default=True, dest='unity',
        help="Don't build Unity features depending on libunity.")
    ctx.add_option(
        '--no-appindicator', action='store_false', default=True, dest='appindicator',
        help="Don't build functionality dependent on libappindicator.")
    ctx.add_option(
        '--webkitgtk-supports-mse', action='store_true', default=False, dest='webkit_mse',
        help="Use only if you are absolutely sure that your particular build of the WebKitGTK library supports Media Source Extension (as of 2.15.3, it is disabled by default)")
    ctx.add_option(
        '--no-cef', action='store_false', default=True, dest='cef',
        help="Don't build experimental CEF backend depending on ValaCEF.")
    ctx.add_option(
        '--cef-default', action='store_true', default=False, dest='cef_default',
        help="Whether the CEF engine should be default.")
    ctx.add_option(
        '--nuvola-lite', action='store_true', default=False, dest='nuvola_lite',
        help="Lite version of Nuvola.")
    ctx.add_option(
        '--no-gir', action='store_false', default=True, dest='build_gir', help="Don't build GIR.")
    ctx.add_option(
        '--no-vala-lint', action='store_false', default=True, dest='lint_vala', help="Don't use Vala linter.")
    ctx.add_option(
        '--lint-vala-auto-fix', action='store_true', default=False,
        dest='lint_vala_auto_fix', help="Use Vala linter and automatically fix errors (dangerous).")
    ctx.add_option(
        '--no-js-lint', action='store_false', default=True, dest='lint_js', help="Don't use JavaScript linter.")
    ctx.add_option(
        '--lint-js-auto-fix', action='store_true', default=False,
        dest='lint_js_auto_fix', help="Use JavaScript linter and automatically fix errors (dangerous).")

def configure(ctx):
    add_version_info(ctx)
    ctx.msg("Version", ctx.env.VERSION, "GREEN")
    if ctx.env.REVISION_ID != REVISION_SNAPSHOT:
        ctx.msg("Upstream revision", ctx.env.REVISION_ID, color="GREEN")
    else:
        ctx.msg("Upstream revision", "unknown", color="RED")
    ctx.msg('Install prefix', ctx.options.prefix, color="GREEN")

    ctx.env.append_unique("VALAFLAGS", "-v")
    ctx.env.append_unique('CFLAGS', ['-w'])
    ctx.env.append_unique("LINKFLAGS", ["-Wl,--no-undefined", "-Wl,--as-needed"])
    for path in os.environ.get("LD_LIBRARY_PATH", "").split(":"):
        path = path.strip()
        if path:
            ctx.env.append_unique('LIBPATH', path)
    ctx.env.append_unique('CFLAGS', '-O2')
    if ctx.options.debug:
        ctx.env.append_unique('CFLAGS', '-g3')

    # Branding
    ctx.env.BRANDING = ctx.options.branding or "default"
    ctx.msg("Branding", ctx.env.BRANDING, color="GREEN")
    branding_json = "branding/%s.json" % ctx.env.BRANDING
    if os.path.isfile(branding_json):
        ctx.msg("Branding metadata", branding_json, color="GREEN")
        branding = loadjson(branding_json, False)
    else:
        if ctx.env.BRANDING != "default":
            ctx.msg("Branding metadata not found", branding_json, color="RED")
        branding = {}

    ctx.env.WELCOME_XML = "branding/%s/welcome.xml" % ctx.env.BRANDING
    if os.path.isfile(ctx.env.WELCOME_XML):
        ctx.msg("Welcome screen", ctx.env.WELCOME_XML, color="GREEN")
    else:
        ctx.msg("Welcome screen not found", ctx.env.WELCOME_XML, color="RED")
        ctx.env.WELCOME_XML = "branding/default/welcome.xml"

    ctx.env.APPDATA_XML = "branding/%s/appdata.xml" % ctx.env.BRANDING
    if os.path.isfile(ctx.env.APPDATA_XML):
        ctx.msg("Welcome screen", ctx.env.APPDATA_XML, color="GREEN")
    else:
        ctx.msg("Welcome screen not found", ctx.env.APPDATA_XML, color="RED")
        ctx.env.APPDATA_XML = "branding/default/appdata.xml"

    genuine = branding.get("genuine", False)
    ctx.env.NAME = branding.get("name", "Web Apps")
    ctx.env.SHORT_NAME = branding.get("short_name", ctx.env.NAME)
    ctx.env.VENDOR = branding.get("vendor", "unknown")
    ctx.env.HELP_URL = branding.get("help_url", DEFAULT_HELP_URL)
    ctx.env.WEB_APP_REQUIREMENTS_HELP_URL = branding.get("requirements_help_url", DEFAULT_WEB_APP_REQUIREMENTS_HELP_URL)
    tiliado_api = branding.get("tiliado_api", {})

    # Variants
    ctx.env.CDK = branding.get("cdk", False)
    ctx.env.ADK = branding.get("adk", False)
    ctx.env.FLATPAK = branding.get("flatpak", False)
    MIN_WEBKIT = LEGACY_WEBKIT
    if ctx.env.CDK:
        vala_def(ctx, "NUVOLA_CDK")
        ctx.env.UNIQUE_NAME = "eu.tiliado.NuvolaCdk"
        MIN_WEBKIT = FLATPAK_WEBKIT
    elif ctx.env.ADK:
        vala_def(ctx, "NUVOLA_ADK")
        ctx.env.UNIQUE_NAME = "eu.tiliado.NuvolaAdk"
        MIN_WEBKIT = FLATPAK_WEBKIT
    else:
        vala_def(ctx, "NUVOLA_RUNTIME")
        if genuine:
            ctx.env.UNIQUE_NAME = "eu.tiliado.Nuvola"
        else:
            ctx.env.UNIQUE_NAME = "eu.tiliado.WebRuntime"
    ctx.env.ICON_NAME = ctx.env.UNIQUE_NAME
    ctx.env.NUVOLA_LITE = ctx.options.nuvola_lite
    if ctx.env.NUVOLA_LITE:
        vala_def(ctx, "NUVOLA_LITE")

    # Flatpak
    if ctx.env.FLATPAK:
        vala_def(ctx, "FLATPAK")
        MIN_WEBKIT = FLATPAK_WEBKIT

    # Base deps
    ctx.load('compiler_c vala')
    ctx.check_vala(min_version=tuple(int(i) for i in MIN_VALA.split(".")))

    pkgconfig(ctx, 'glib-2.0', 'GLIB', MIN_GLIB)
    pkgconfig(ctx, 'gio-2.0', 'GIO', MIN_GLIB)
    pkgconfig(ctx, 'gio-unix-2.0', 'UNIXGIO', MIN_GLIB)
    pkgconfig(ctx, 'gtk+-3.0', 'GTK+', MIN_GTK)
    pkgconfig(ctx, 'gdk-3.0', 'GDK', MIN_GTK)
    pkgconfig(ctx, 'gdk-x11-3.0', 'GDKX11', MIN_GTK)
    pkgconfig(ctx, 'x11', 'X11', "0")
    pkgconfig(ctx, 'sqlite3', 'SQLITE', "3.7")
    pkgconfig(ctx, 'dioriteglib' + TARGET_DIORITE, 'DIORITEGLIB', MIN_DIORITE)
    pkgconfig(ctx, 'dioritegtk' + TARGET_DIORITE, 'DIORITEGTK', MIN_DIORITE)
    pkgconfig(ctx, 'json-glib-1.0', 'JSON-GLIB', '0.7')
    pkgconfig(ctx, 'libnotify', 'NOTIFY', '0.7')
    pkgconfig(ctx, 'libsecret-1', 'SECRET', '0.16')
    pkgconfig(ctx, "gstreamer-1.0", 'GST', "1.11.90" if ctx.options.webkit_mse else "1.8")
    pkgconfig(ctx, 'webkit2gtk-4.0', 'WEBKIT', MIN_WEBKIT)
    pkgconfig(ctx, 'webkit2gtk-web-extension-4.0', 'WEBKITEXT', MIN_WEBKIT)
    pkgconfig(ctx, 'javascriptcoregtk-4.0', 'JSCORE', MIN_WEBKIT)
    pkgconfig(ctx, 'uuid', 'UUID', '0') # Engine.io
    pkgconfig(ctx, 'libsoup-2.4', 'SOUP', '0') # Engine.io
    pkgconfig(ctx, 'dri2', 'DRI2', '1.0')
    pkgconfig(ctx, 'libdrm', 'DRM', '2.2')
    pkgconfig(ctx, 'libarchive', 'LIBARCHIVE', '3.2')
    pkgconfig(ctx, 'libpulse', 'LIBPULSE', '0.0')
    pkgconfig(ctx, 'libpulse-mainloop-glib', 'LIBPULSE-GLIB', '0.0')

    ctx.env.BUILD_GIR = ctx.options.build_gir
    if ctx.env.BUILD_GIR:
        ctx.find_program('g-ir-compiler', var='GIR_COMPILER')

    ctx.env.LINT_VALA = ctx.options.lint_vala
    if ctx.env.LINT_VALA:
        ctx.find_program('valalint', var='VALALINT')

    ctx.env.LINT_JS = ctx.options.lint_js
    if ctx.env.LINT_JS:
        ctx.find_program('standard', var='JSLINT')

    # For tests
    ctx.find_program("diorite-testgen{}".format(TARGET_DIORITE), var="DIORITE_TESTGEN")

    # JavaScript dir
    ctx.env.JSDIR = ctx.options.jsdir if ctx.options.jsdir else ctx.env.DATADIR + "/javascript"

    # Optional features
    ctx.env.WEBKIT_MSE = ctx.options.webkit_mse
    if ctx.options.webkit_mse:
        vala_def(ctx, "WEBKIT_SUPPORTS_MSE")
    ctx.env.with_unity = ctx.options.unity and not ctx.env.NUVOLA_LITE
    if ctx.env.with_unity:
        pkgconfig(ctx, 'unity', 'UNITY', '3.0')
        pkgconfig(ctx, 'dbusmenu-glib-0.4', 'DBUSMENU', '0.4')
        vala_def(ctx, "UNITY")
    ctx.env.with_appindicator = ctx.options.appindicator and not ctx.env.NUVOLA_LITE
    if ctx.env.with_appindicator:
        pkgconfig(ctx, 'ayatana-appindicator3-0.1', 'APPINDICATOR', '0.4')
        vala_def(ctx, "APPINDICATOR")
    if ctx.options.cef_default:
        ctx.options.cef = True
    ctx.env.have_cef = ctx.options.cef
    if ctx.env.have_cef:
        pkgconfig(ctx, 'valacef', 'VALACEF', '3.0')
        pkgconfig(ctx, 'valacefgtk', 'VALACEFGTK', '3.0')
        vala_def(ctx, "HAVE_CEF")

    # Define HAVE_WEBKIT_X_YY Vala compiler definitions
    webkit_version = tuple(int(i) for i in ctx.check_cfg(modversion='webkit2gtk-4.0').split(".")[0:2])
    version = (2, 6)
    while version <= webkit_version:
        vala_def(ctx, "HAVE_WEBKIT_%d_%d" % version)
        version = (version[0], version[1] + 2)

    # Definitions
    ctx.env.GENUINE = genuine
    if genuine:
        vala_def(ctx, "GENUINE")
    if any((ctx.env.GENUINE, ctx.env.CDK, ctx.env.ADK)) and not ctx.env.NUVOLA_LITE:
        vala_def(ctx, "EXPERIMENTAL")
    if tiliado_api.get("enabled", False):
        vala_def(ctx, "TILIADO_API")

    vala_def(ctx, "TRUE")
    ctx.define("NUVOLA_APPNAME", APPNAME)
    ctx.define("NUVOLA_OLDNAME", "nuvolaplayer3")
    ctx.define("NUVOLA_NAME", ctx.env.NAME)
    ctx.define("NUVOLA_WELCOME_SCREEN_NAME", ctx.env.RELEASE)
    ctx.define("NUVOLA_UNIQUE_NAME", ctx.env.UNIQUE_NAME)
    ctx.define("NUVOLA_APP_ICON", ctx.env.ICON_NAME)
    ctx.define("NUVOLA_RELEASE", ctx.env.RELEASE)
    ctx.define("NUVOLA_VERSION", ctx.env.VERSION)
    ctx.define("NUVOLA_REVISION", ctx.env.REVISION_ID)
    ctx.define("NUVOLA_VERSION_MAJOR", ctx.env.VERSIONS[0])
    ctx.define("NUVOLA_VERSION_MINOR", ctx.env.VERSIONS[1])
    ctx.define("NUVOLA_VERSION_BUGFIX", ctx.env.VERSIONS[2])
    ctx.define("NUVOLA_VERSION_SUFFIX", ctx.env.REVISION_ID)
    ctx.define("GETTEXT_PACKAGE", APPNAME)
    ctx.env.NUVOLA_LIBDIR = "%s/%s" % (ctx.env.LIBDIR, APPNAME)
    ctx.define("NUVOLA_TILIADO_OAUTH2_SERVER", tiliado_api.get("server", "https://tiliado.eu"))
    ctx.define("NUVOLA_TILIADO_OAUTH2_CLIENT_ID", tiliado_api.get("client_id", ""))
    repo_index = branding.get("repository_index", "https://nuvola.tiliado.eu/").split("|")
    repo_index, repo_root = repo_index if len(repo_index) > 1 else  repo_index + repo_index
    ctx.define("NUVOLA_REPOSITORY_INDEX", repo_index)
    ctx.define("NUVOLA_REPOSITORY_ROOT", repo_root)
    ctx.define("NUVOLA_WEB_APP_REQUIREMENTS_HELP_URL", ctx.env.WEB_APP_REQUIREMENTS_HELP_URL)
    ctx.define("NUVOLA_HELP_URL", ctx.env.HELP_URL)
    ctx.define("NUVOLA_LIBDIR", ctx.env.NUVOLA_LIBDIR)
    ctx.define("NUVOLA_CEF_DEFAULT", int(ctx.options.cef_default))

    ctx.define('GLIB_VERSION_MAX_ALLOWED', glib_encode_version(MIN_GLIB))
    ctx.define('GLIB_VERSION_MIN_REQUIRED', glib_encode_version(MIN_GLIB))
    ctx.define('GDK_VERSION_MAX_ALLOWED', glib_encode_version(MIN_GTK))
    ctx.define('GDK_VERSION_MIN_REQUIRED', glib_encode_version(MIN_GTK))

    with open("build/secret.h", "wb") as f:
        client_secret = tiliado_api.get("client_secret", "")
        if client_secret:
            secret = b"{"
            for i in mask(client_secret):
                secret += str(i).encode("ascii") + b", "
            secret += b"0}"
        else:
            secret = b'""'
        f.write(
            b'#pragma once\nstatic const char NUVOLA_TILIADO_OAUTH2_CLIENT_SECRET[] = '    + secret + b';')


def build(ctx):
    def valalint(source_dir=None, **kwargs):
        if not ctx.env.LINT_VALA:
            return
        if source_dir is not None:
            kwargs["source"] = ctx.path.ant_glob(source_dir + '/**/*.vala')
        return ctx(features="valalint", **kwargs)

    def jslint(source_dir=None, **kwargs):
        if not ctx.env.LINT_JS:
            return
        if source_dir is not None:
            kwargs["source"] = ctx.path.ant_glob(source_dir + '/**/*.js')
        return ctx(features="jslint", **kwargs)

    def valalib(source_dir=None, **kwargs):
        if source_dir is not None:
            kwargs["source"] = ctx.path.ant_glob(source_dir + '/**/*.vala') + ctx.path.ant_glob(source_dir + '/**/*.vapi')
            kwargs.setdefault("vala_dir", source_dir)
        return ctx(features="c cshlib", **kwargs)

    def valaprog(source_dir=None, **kwargs):
        if source_dir is not None:
            kwargs["source"] = ctx.path.ant_glob(source_dir + '/**/*.vala') + ctx.path.ant_glob(source_dir + '/**/*.vapi')
            kwargs.setdefault("vala_dir", source_dir)
        return ctx.program(**kwargs)

    def patch(source, patch, target):
        return ctx(
            rule='patch -i ${SRC[1]} -o ${TGT} ${SRC[0]}',
            source = [os.path.relpath(source) if source[0] == "/" else source, patch],
            target = target)

    def cp_if_found(source, target):
        return ctx(
            rule='cp -v ${SRC} ${TGT}',
            source = os.path.relpath(source) if source[0] == "/" else source,
            target = target) if os.path.isfile(source) else None

    #~ print(ctx.env)
    vala_defines = ctx.env.VALA_DEFINES
    if ctx.options.lint_vala_auto_fix:
        ctx.env.append_unique('VALALINTFLAGS', '--fix')
    if ctx.options.lint_js_auto_fix:
        ctx.env.append_unique('JSLINTFLAGS', '--fix')

    APP_RUNNER = "nuvolaruntime"
    ENGINEIO = "engineio"
    NUVOLA_SERVICE_INFO = "nuvolaserviceinfo"
    NUVOLAKIT_RUNNER = APPNAME + "-runner"
    NUVOLAKIT_BASE = APPNAME + "-base"
    NUVOLAKIT_WORKER = APPNAME + "-worker"
    NUVOLAKIT_CEF_WORKER = APPNAME + "-cef-worker"
    NUVOLAKIT_TESTS = APPNAME + "-tests"
    RUN_NUVOLAKIT_TESTS = "run-" + NUVOLAKIT_TESTS
    DIORITE_GLIB = 'dioriteglib' + TARGET_DIORITE
    DIORITE_GTK = 'dioriteglib' + TARGET_DIORITE

    packages = 'dioritegtk{0} dioriteglib{0} '.format(TARGET_DIORITE)
    packages += 'javascriptcoregtk-4.0 libnotify libarchive gtk+-3.0 gdk-3.0 gdk-x11-3.0 x11 posix json-glib-1.0 glib-2.0 gio-2.0'
    packages += ' libpulse-mainloop-glib'
    uselib = 'NOTIFY JSCORE LIBARCHIVE DIORITEGTK DIORITEGLIB GTK+ GDK GDKX11 X11 JSON-GLIB GLIB GIO LIBPULSE LIBPULSE-GLIB'

    vapi_dirs = ['build', 'vapi', 'engineio-soup/vapi']
    env_vapi_dir = os.environ.get("VAPIDIR")
    if env_vapi_dir:
        vapi_dirs.extend(os.path.relpath(path) for path in env_vapi_dir.split(":"))
    if ctx.env.SNAPCRAFT:
        vapi_dirs.append(os.path.relpath(ctx.env.SNAPCRAFT + "/usr/share/vala/vapi"))

    if ctx.env.with_unity:
        packages += " unity Dbusmenu-0.4"
        uselib += " UNITY DBUSMENU"
    if ctx.env.with_appindicator:
        packages += " ayatana-appindicator3-0.1"
        uselib += " APPINDICATOR"
    if ctx.env.have_cef:
        packages += " valacef valacefgtk"
        uselib += " VALACEF VALACEFGTK"

    for vapi in ("glib-2.0",):
        vapi_dir = '/usr/share/vala-0.38/vapi'
        for d in vapi_dirs:
            if d not in ("vapi", "build") and os.path.isfile("%s/%s.vapi" % (d, vapi)):
                vapi_dir = d
                break

        patch("%s/%s.vapi" % (vapi_dir, vapi), "vapi/%s.patch" % vapi, '%s.vapi' %  vapi)
        cp_if_found("%s/%s.deps" % (vapi_dir, vapi), '%s.deps' %  vapi)

    ctx(features = "checkvaladefs", source = ctx.path.ant_glob('src/**/*.vala'),
        definitions="FLATPAK TILIADO_API WEBKIT_SUPPORTS_MSE GENUINE UNITY APPINDICATOR EXPERIMENTAL NUVOLA_RUNTIME"
        + " NUVOLA_ADK NUVOLA_CDK HAVE_CEF FALSE TRUE NUVOLA_LITE")

    VALALINT_CHECKS = ("space_indent=4 method_call_no_space space_after_keyword space_after_comma no_space_before_comma"
        " end_of_namespace_comments no_trailing_whitespace space_before_bracket no_nested_namespaces"
        " var_keyword_object_creation var_keyword_array_creation var_keyword_cast var_keyword_literal"
        " if_else_blocks cuddled_else cuddled_catch loop_blocks")
    valalint(
        source_dir = 'engineio-soup/src',
        checks=VALALINT_CHECKS
    )
    valalint(
        source_dir = 'src/nuvolakit-base',
        checks=VALALINT_CHECKS
    )
    valalint(
        source_dir = 'src/nuvolakit-runner',
        checks=VALALINT_CHECKS
    )
    valalint(
        source_dir = 'src/master',
        checks=VALALINT_CHECKS
    )
    valalint(
        source_dir = 'src/' + NUVOLA_SERVICE_INFO,
        checks=VALALINT_CHECKS
    )
    valalint(
        source_dir = 'src/apprunner',
        checks=VALALINT_CHECKS
    )
    valalint(
        source_dir = 'src/control',
        checks=VALALINT_CHECKS
    )
    valalint(
        source_dir = 'src/nuvolakit-worker',
        checks=VALALINT_CHECKS
    )

    ctx.add_group()

    valalib(
        target = ENGINEIO,
        gir = "Engineio-1.0",
        source_dir = 'engineio-soup/src',
        packages = 'uuid libsoup-2.4 json-glib-1.0',
        uselib = 'UUID SOUP JSON-GLIB',
        defines = ['G_LOG_DOMAIN="Engineio"'],
        vapi_dirs = vapi_dirs,
        vala_target_glib = TARGET_GLIB,
    )

    valalib(
        target = NUVOLAKIT_BASE,
        gir = "NuvolaBase-1.0",
        source_dir = 'src/nuvolakit-base',
        packages = packages + ' gstreamer-1.0',
        uselib = uselib + " GST",
        vala_defines = vala_defines,
        defines = ['G_LOG_DOMAIN="Nuvola"'],
        vapi_dirs = vapi_dirs,
        vala_target_glib = TARGET_GLIB,
    )

    valalib(
        target = NUVOLAKIT_RUNNER,
        gir = "NuvolaRunner-1.0",
        source_dir = 'src/nuvolakit-runner',
        packages = packages + ' webkit2gtk-4.0 javascriptcoregtk-4.0 gstreamer-1.0 libsecret-1 dri2 libdrm libarchive prctl',
        uselib =  uselib + ' JSCORE WEBKIT GST SECRET DRI2 DRM LIBARCHIVE',
        use = [NUVOLAKIT_BASE, ENGINEIO],
        lib = ['m'],
        includes = ["build"],
        vala_defines = vala_defines,
        defines = ['G_LOG_DOMAIN="Nuvola"'],
        vapi_dirs = vapi_dirs,
        vala_target_glib = TARGET_GLIB,
    )

    if ctx.env.BUILD_GIR:
        ctx.gir_compile("Engineio-1.0", ENGINEIO, "engineio-soup/src")
        ctx.gir_compile("Nuvola-1.0", NUVOLAKIT_RUNNER, ".",
            ["src/nuvolakit-base/NuvolaBase-1.0.gir", "src/nuvolakit-runner/NuvolaRunner-1.0.gir"],
            params="--includedir='engineio-soup/src' --includedir='%s/build'" % os.environ.get("DIORITE_PATH", '.'))

    valaprog(
        target = NUVOLA_BIN,
        source_dir = 'src/master',
        packages = "",
        uselib = uselib + " SOUP WEBKIT",
        use = [NUVOLAKIT_BASE, NUVOLAKIT_RUNNER],
        vala_defines = vala_defines,
        defines = ['G_LOG_DOMAIN="Nuvola"'],
        vapi_dirs = vapi_dirs,
        vala_target_glib = TARGET_GLIB,
    )

    valaprog(
        target = NUVOLA_SERVICE_INFO,
        source_dir = 'src/' + NUVOLA_SERVICE_INFO,
        packages = "",
        uselib = uselib + " SOUP WEBKIT",
        use = [NUVOLAKIT_BASE, NUVOLAKIT_RUNNER],
        vala_defines = vala_defines,
        defines = ['G_LOG_DOMAIN="Nuvola"'],
        vapi_dirs = vapi_dirs,
        vala_target_glib = TARGET_GLIB,
    )

    valaprog(
        target = APP_RUNNER,
        source_dir = 'src/apprunner',
        packages = "",
        uselib = uselib + " SOUP WEBKIT",
        use = [NUVOLAKIT_BASE, NUVOLAKIT_RUNNER],
        vala_defines = vala_defines,
        defines = ['G_LOG_DOMAIN="Nuvola"'],
        vapi_dirs = vapi_dirs,
        vala_target_glib = TARGET_GLIB,
    )

    valaprog(
        target = NUVOLACTL_BIN,
        source_dir = 'src/control',
        packages = "",
        uselib = uselib + " SOUP WEBKIT",
        use = [NUVOLAKIT_BASE, NUVOLAKIT_RUNNER],
        vala_defines = vala_defines,
        defines = ['G_LOG_DOMAIN="Nuvola"'],
        vapi_dirs = vapi_dirs,
        vala_target_glib = TARGET_GLIB,
    )

    valalib(
        target = NUVOLAKIT_WORKER,
        source_dir = 'src/nuvolakit-worker',
        packages = "dioriteglib{0} {1} {2}".format(TARGET_DIORITE, 'webkit2gtk-web-extension-4.0', 'javascriptcoregtk-4.0'),
        uselib = "SOUP DIORITEGLIB DIORITEGTK WEBKITEXT JSCORE",
        use = [NUVOLAKIT_BASE],
        vala_defines = vala_defines,
        cflags = ['-DG_LOG_DOMAIN="Nuvola"'],
        vapi_dirs = vapi_dirs,
        vala_target_glib = TARGET_GLIB,
        install_path = ctx.env.NUVOLA_LIBDIR,
    )

    if ctx.env.have_cef:
        valalib(
            target = NUVOLAKIT_CEF_WORKER,
            source_dir = 'src/nuvolakit-cef-worker',
            packages = "dioriteglib{0} dioritegtk{0} {1} {2} javascriptcoregtk-4.0".format(TARGET_DIORITE, 'valacef', 'valacefgtk'),
            uselib = "SOUP DIORITEGLIB DIORITEGTK VALACEF VALACEFGTK JSCORE",
            use = [NUVOLAKIT_BASE],
            vala_defines = vala_defines,
            cflags = ['-DG_LOG_DOMAIN="Nuvola"'],
            vapi_dirs = vapi_dirs,
            vala_target_glib = TARGET_GLIB,
            install_path = ctx.env.NUVOLA_LIBDIR,
        )

    valalib(
        target = NUVOLAKIT_TESTS,
        source_dir = 'src/tests',
        packages = packages + ' webkit2gtk-4.0 javascriptcoregtk-4.0 gstreamer-1.0 libsecret-1',
        uselib =  uselib + ' JSCORE WEBKIT GST SECRET',
        use = [NUVOLAKIT_BASE, NUVOLAKIT_RUNNER, ENGINEIO],
        lib = ['m'],
        includes = ["build"],
        vala_defines = vala_defines,
        defines = ['G_LOG_DOMAIN="Nuvola"'],
        vapi_dirs = vapi_dirs,
        vala_target_glib = TARGET_GLIB,
        install_path = None,
        install_binding = False
    )

    ctx(
        rule='"%s" -i ${SRC} -o ${TGT}' % ctx.env.DIORITE_TESTGEN[0],
        source=ctx.path.find_or_declare('src/tests/%s.vapi' % NUVOLAKIT_TESTS),
        target=ctx.path.find_or_declare("%s.vala" % RUN_NUVOLAKIT_TESTS)
    )

    valaprog(
        target = RUN_NUVOLAKIT_TESTS,
        source = [ctx.path.find_or_declare("%s.vala" % RUN_NUVOLAKIT_TESTS)],
        packages = packages,
        uselib = uselib,
        use = [NUVOLAKIT_BASE, ENGINEIO, NUVOLAKIT_TESTS],
        vala_defines = vala_defines,
        defines = ['G_LOG_DOMAIN="Nuvola"'],
        vapi_dirs = vapi_dirs,
        vala_target_glib = TARGET_GLIB,
        install_path = None
    )

    ctx(features = 'subst',
        source = 'data/templates/launcher.desktop',
        target = "share/applications/%s.desktop" % ctx.env.UNIQUE_NAME,
        install_path = '${PREFIX}/share/applications',
        BLURB = BLURB,
        APP_NAME = (ctx.env.NAME + " Service") if ctx.env.GENUINE else ctx.env.NAME,
        ICON = ctx.env.ICON_NAME,
        EXEC = "lxterminal" if ctx.env.ADK else (NUVOLA_SERVICE_INFO if ctx.env.GENUINE else NUVOLA_BIN),
        GENERIC_NAME=GENERIC_NAME,
        WMCLASS = ctx.env.UNIQUE_NAME,
    )

    ctx(features = 'subst',
        source = ctx.env.WELCOME_XML,
        target = 'share/%s/welcome.xml' % APPNAME,
        install_path = '${PREFIX}/share/%s' % APPNAME,
        BLURB = BLURB,
        NAME = ctx.env.NAME,
        VERSION = ctx.env.RELEASE,
        FULL_VERSION = ctx.env.VERSION,
        HELP_URL = ctx.env.HELP_URL,
        WEB_APP_REQUIREMENTS_HELP_URL = ctx.env.WEB_APP_REQUIREMENTS_HELP_URL,
        VENDOR = ctx.env.VENDOR,
    )

    dbus_name = ctx.env.UNIQUE_NAME
    ctx(features = 'subst',
        source = 'data/templates/dbus.service',
        target = "share/dbus-1/services/%s.service" % dbus_name,
        install_path = '${PREFIX}/share/dbus-1/services',
        NAME = dbus_name,
        EXEC = '%s/bin/%s --gapplication-service' % (ctx.env.PREFIX, NUVOLA_BIN)
    )

    PC_CFLAGS = ""
    ctx(features = 'subst',
        source='src/nuvolakitbase.pc.in',
        target='{}-base.pc'.format(APPNAME),
        install_path='${LIBDIR}/pkgconfig',
        VERSION=ctx.env.RELEASE,
        PREFIX=ctx.env.PREFIX,
        INCLUDEDIR = ctx.env.INCLUDEDIR,
        LIBDIR = ctx.env.LIBDIR,
        APPNAME=APPNAME,
        PC_CFLAGS=PC_CFLAGS,
        LIBNAME=NUVOLAKIT_BASE,
        DIORITE_GLIB=DIORITE_GLIB,
    )

    ctx(features = 'subst',
        source='src/nuvolakitrunner.pc.in',
        target='{}-runner.pc'.format(APPNAME),
        install_path='${LIBDIR}/pkgconfig',
        VERSION=ctx.env.RELEASE,
        PREFIX=ctx.env.PREFIX,
        INCLUDEDIR = ctx.env.INCLUDEDIR,
        LIBDIR = ctx.env.LIBDIR,
        APPNAME=APPNAME,
        PC_CFLAGS=PC_CFLAGS,
        LIBNAME=NUVOLAKIT_RUNNER,
        NUVOLAKIT_BASE=NUVOLAKIT_BASE,
        DIORITE_GLIB=DIORITE_GLIB,
        DIORITE_GTK=DIORITE_GTK,
    )

    ctx(
        features = 'subst',
        source=ctx.path.find_node(ctx.env.APPDATA_XML),
        target=ctx.path.get_bld().make_node(ctx.env.UNIQUE_NAME + '.appdata.xml'),
        install_path='${PREFIX}/share/appdata',
        encoding="utf-8",
        FULL_NAME=ctx.env.NAME,
        PRELUDE=(
            "" if ctx.env.GENUINE
            else '<p>{} software is based on the open source code from the Nuvola Apps™ project.</p>'.format(ctx.env.NAME)
        ),
        UNIQUE_NAME=ctx.env.UNIQUE_NAME,
    )
    ctx.install_as(
        '${PREFIX}/share/metainfo/%s.appdata.xml' % ctx.env.UNIQUE_NAME,
        ctx.path.get_bld().find_node(ctx.env.UNIQUE_NAME + '.appdata.xml'))

    ctx.symlink_as('${PREFIX}/share/%s/www/engine.io.js' % APPNAME, ctx.env.JSDIR + '/engine.io-client/engine.io.js')

    www = ctx.path.find_dir("data/www")
    ctx.install_files('${PREFIX}/share/' + APPNAME, www.ant_glob('**'), cwd=www.parent, relative_trick=True)

    app_icons = ctx.path.find_node("data/icons")
    for size in (16, 22, 24, 32, 48, 64, 128, 256):
        ctx.install_as('${PREFIX}/share/icons/hicolor/%sx%s/apps/%s.png' % (size, size, ctx.env.ICON_NAME), app_icons.find_node("%s.png" % size))
    ctx.install_as('${PREFIX}/share/icons/hicolor/scalable/apps/%s.svg' % ctx.env.ICON_NAME, app_icons.find_node("scalable.svg"))

    ctx(features = "mergejs",
        source = ctx.path.ant_glob('src/mainjs/*.js'),
        target = 'share/%s/js/main.js' % APPNAME,
        install_path = '${PREFIX}/share/%s/js' % APPNAME
    )

    data_js =  ctx.path.find_dir("data/js")
    for node in data_js.listdir():
        ctx(
            rule = 'cp -v ${SRC} ${TGT}',
            source = data_js.find_node(node),
            target = 'share/%s/js/%s' % (APPNAME, node),
            install_path = '${PREFIX}/share/%s/js' % APPNAME
        )
    ctx(
        rule = 'cp -v ${SRC} ${TGT}',
        source = ctx.path.find_node("data/audio/audiotest.mp3"),
        target = 'share/%s/audio/audiotest.mp3' % APPNAME,
        install_path = '${PREFIX}/share/%s/audio' % APPNAME
    )

    ctx.add_group()
    jslint(source_dir = 'src/mainjs', global_vars=['Nuvola'])
    jslint(source = ['web_apps/test/home.js', 'web_apps/test/integrate.js'])

def dist(ctx):
    ctx.algo = "tar.gz"
    ctx.excl = '.git .gitignore build/* **/.waf* **/*~ **/*.swp **/.lock* bzrcommit.txt **/*.pyc core'
