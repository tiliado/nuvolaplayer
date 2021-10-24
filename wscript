# encoding: utf-8
#
# Copyright 2014-2020 Jiří Janoušek <janousek.jiri@gmail.com>
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

APPNAME = SHORT_ID = "nuvolaruntime"
NUVOLA_BIN = "nuvola"
NUVOLACTL_BIN = "nuvolactl"
VERSION = "4.24.0"
GENERIC_NAME = "Cloud Player"
BLURB = "Tight integration of web-based media streaming services with your Linux desktop"
DEFAULT_HELP_URL = "https://github.com/tiliado/nuvolaruntime/wiki/Third-Party-Builds"
DEFAULT_WEB_APP_REQUIREMENTS_HELP_URL = DEFAULT_HELP_URL

MIN_DIORITE = "4.24.0"
MIN_VALA = "0.48.0"
MIN_GLIB = "2.56.1"
MIN_GTK = "3.22.30"
MIN_GEE = "0.20.1"
MIN_WEBKIT = "2.18.1"

IGNORED_DEPRECATIONS = [
    "Gdk.Screen.width",
    "Gdk.Screen.height",
    "Gtk.StatusIcon",
    "Gtk.Menu.popup",
    "Gtk.Widget.override_background_color",
    "Gtk.StyleContext.get_background_color",
]

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
        return output.decode("utf-8").strip().rsplit("-", 2)
    return VERSION, "0", REVISION_SNAPSHOT

def add_version_info(ctx):
    bare_version, n_commits, revision_id = get_git_version()
    if revision_id != REVISION_SNAPSHOT:
        revision_id = "{}-{}".format(n_commits, revision_id)
    numeric, pre_release = bare_version.split("-", 1) if "-" in bare_version else (bare_version, "")
    versions = [int(i) for i in numeric.split(".")]
    if pre_release:
        pre_release = "-{}{}".format(pre_release, n_commits)
    else:
        versions[2] += int(n_commits)
    version = "{}.{}.{}{}".format(*versions, pre_release)
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
        '--dummy-engine', action='store_true', default=False, dest='dummy_engine',
        help="Whether to build with a dummy web engine instead of ValaCEF.")
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
    ctx.add_option('--no-strict', action='store_false', default=True,
        dest='strict', help="Disable strict checks (e.g. fatal warnings).")
    ctx.add_option(
        '--no-vapi-patch', action='store_false', default=True, dest='patch_vapi',
        help="Don't use a patched copy of system vapi files as needed but use them as is.")

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

    if ctx.options.strict:
        ctx.env.append_unique("VALAFLAGS", ["--fatal-warnings"])
        ctx.env.append_unique("VALADOCFLAGS", ["--fatal-warnings"])

        if IGNORED_DEPRECATIONS:  # Patched Vala compiler required so keep it hidden behind `if ctx.options.strict`.
            ctx.env.append_unique("VALAFLAGS", ["--ignore-deprecated=" + x for x in IGNORED_DEPRECATIONS])

        ctx.env.append_unique('CFLAGS', ['-Wall', '-Werror'])

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
        ctx.fatal("Branding metadata not found: '%s'" % branding_json)

    ctx.env.APPDATA_XML = "branding/%s/appdata.xml" % ctx.env.BRANDING
    if os.path.isfile(ctx.env.APPDATA_XML):
        ctx.msg("App data XML", ctx.env.APPDATA_XML, color="GREEN")
    else:
        ctx.msg("App data XML not found", ctx.env.APPDATA_XML, color="RED")
        ctx.env.APPDATA_XML = "branding/default/appdata.xml"

    genuine = branding.get("genuine", False)
    ctx.env.NAME = branding.get("name", "Cloud Player")
    ctx.env.SHORT_NAME = branding.get("short_name", ctx.env.NAME)
    ctx.env.VENDOR = branding.get("vendor", "unknown")
    ctx.env.WEB_APP_REQUIREMENTS_HELP_URL = branding.get("requirements_help_url", DEFAULT_WEB_APP_REQUIREMENTS_HELP_URL)
    tiliado_api = branding.get("tiliado_api", {})

    # Variants
    ctx.env.CDK = branding.get("cdk", False)
    ctx.env.ADK = branding.get("adk", False)
    ctx.env.FLATPAK = branding.get("flatpak", False)
    if ctx.env.CDK:
        vala_def(ctx, "NUVOLA_CDK")
        ctx.env.UNIQUE_NAME = "eu.tiliado.NuvolaCdk"
    elif ctx.env.ADK:
        vala_def(ctx, "NUVOLA_ADK")
        ctx.env.UNIQUE_NAME = "eu.tiliado.NuvolaAdk"
    else:
        vala_def(ctx, "NUVOLA_RUNTIME")
        if genuine:
            ctx.env.UNIQUE_NAME = "eu.tiliado.Nuvola"
        else:
            ctx.env.UNIQUE_NAME = "eu.tiliado.WebRuntime"
    ctx.env.ICON_NAME = ctx.env.UNIQUE_NAME

    # Flatpak
    if ctx.env.FLATPAK:
        vala_def(ctx, "FLATPAK")

    # Base deps
    ctx.load('compiler_c vala')
    ctx.check_vala(min_version=tuple(int(i) for i in MIN_VALA.split(".")))

    pkgconfig(ctx, 'glib-2.0', 'GLIB', MIN_GLIB)
    pkgconfig(ctx, 'gio-2.0', 'GIO', MIN_GLIB)
    pkgconfig(ctx, 'gio-unix-2.0', 'UNIXGIO', MIN_GLIB)
    pkgconfig(ctx, 'gtk+-3.0', 'GTK+', MIN_GTK)
    pkgconfig(ctx, 'gdk-3.0', 'GDK', MIN_GTK)
    pkgconfig(ctx, 'gdk-x11-3.0', 'GDKX11', MIN_GTK)
    pkgconfig(ctx, 'gee-0.8', 'GEE', MIN_GEE)
    pkgconfig(ctx, 'x11', 'X11', "0")
    pkgconfig(ctx, 'sqlite3', 'SQLITE', "3.7")
    pkgconfig(ctx, 'dioriteglib' + TARGET_DIORITE, 'DIORITEGLIB', MIN_DIORITE)
    pkgconfig(ctx, 'dioritegtk' + TARGET_DIORITE, 'DIORITEGTK', MIN_DIORITE)
    pkgconfig(ctx, 'json-glib-1.0', 'JSON-GLIB', '0.7')
    pkgconfig(ctx, 'libnotify', 'NOTIFY', '0.7')
    pkgconfig(ctx, 'libsecret-1', 'SECRET', '0.16')
    pkgconfig(ctx, "gstreamer-1.0", 'GST', "1.12")
    pkgconfig(ctx, 'javascriptcoregtk-4.0', 'JSCORE', MIN_WEBKIT)
    pkgconfig(ctx, 'uuid', 'UUID', '0') # Engine.io
    pkgconfig(ctx, 'libsoup-2.4', 'SOUP', '0') # Engine.io
    pkgconfig(ctx, 'dri2', 'DRI2', '1.0')
    pkgconfig(ctx, 'libdrm', 'DRM', '2.2')
    pkgconfig(ctx, 'libarchive', 'LIBARCHIVE', '3.2')
    pkgconfig(ctx, 'libpulse', 'LIBPULSE', '0.0')
    pkgconfig(ctx, 'libpulse-mainloop-glib', 'LIBPULSE-GLIB', '0.0')

    ctx.env.LINT_VALA = ctx.options.lint_vala
    if ctx.env.LINT_VALA:
        ctx.find_program('valalint', var='VALALINT')

    ctx.env.LINT_JS = ctx.options.lint_js
    if ctx.env.LINT_JS:
        ctx.find_program('standard', var='JSLINT')

    ctx.env.PATCH_VAPI = ctx.options.patch_vapi

    # For tests
    ctx.find_program("diorite-testgen{}".format(TARGET_DIORITE), var="DIORITE_TESTGEN")

    # JavaScript dir
    ctx.env.JSDIR = ctx.options.jsdir if ctx.options.jsdir else ctx.env.DATADIR + "/javascript"

    # Optional features
    ctx.env.with_unity = ctx.options.unity
    if ctx.env.with_unity:
        pkgconfig(ctx, 'unity', 'UNITY', '3.0')
        pkgconfig(ctx, 'dbusmenu-glib-0.4', 'DBUSMENU', '0.4')
        vala_def(ctx, "UNITY")
    ctx.env.with_appindicator = ctx.options.appindicator
    if ctx.env.with_appindicator:
        pkgconfig(ctx, 'ayatana-appindicator3-0.1', 'APPINDICATOR', '0.4')
        vala_def(ctx, "APPINDICATOR")
    ctx.env.have_cef = not ctx.options.dummy_engine
    if ctx.env.have_cef:
        pkgconfig(ctx, 'valacef', 'VALACEF', '3.0')
        pkgconfig(ctx, 'valacefgtk', 'VALACEFGTK', '3.0')
        vala_def(ctx, "HAVE_CEF")

    vala_series = ctx.env.VALAC_VERSION[:2]
    ctx.env.VALAC_SERIES = '%s.%s' % (vala_series[0], vala_series[1] + 1 if vala_series[1] % 2 else vala_series[1])

    # Definitions
    ctx.env.GENUINE = genuine
    if genuine:
        vala_def(ctx, "GENUINE")
    if any((ctx.env.GENUINE, ctx.env.CDK, ctx.env.ADK)):
        vala_def(ctx, "EXPERIMENTAL")
    if tiliado_api.get("enabled", False):
        vala_def(ctx, "TILIADO_API")

    vala_def(ctx, "TRUE")
    ctx.define("NUVOLA_SHORT_ID", SHORT_ID)
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
    ctx.define("GETTEXT_PACKAGE", SHORT_ID)
    ctx.env.NUVOLA_LIBDIR = "%s/%s" % (ctx.env.LIBDIR, SHORT_ID)
    ctx.define("NUVOLA_TILIADO_OAUTH2_SERVER", tiliado_api.get("server", "https://tiliado.eu"))
    ctx.define("NUVOLA_TILIADO_OAUTH2_CLIENT_ID", tiliado_api.get("client_id", ""))
    ctx.define("NUVOLA_WEB_APP_REQUIREMENTS_HELP_URL", ctx.env.WEB_APP_REQUIREMENTS_HELP_URL)
    ctx.define("NUVOLA_NEWS_URL", branding.get("news_url", "https://nuvola.tiliado.eu/docs/4/news/?genuine=false"))
    ctx.define("NUVOLA_HELP_URL", branding.get("help_url", DEFAULT_HELP_URL))
    ctx.define("NUVOLA_HELP_URL_TEMPLATE", branding.get(
        "help_url_template", "https://nuvola.tiliado.eu/docs/4/{page}.html?genuine=false"))
    ctx.define("NUVOLA_LIBDIR", ctx.env.NUVOLA_LIBDIR)

    ctx.define('GLIB_VERSION_MAX_ALLOWED', glib_encode_version(MIN_GLIB))
    ctx.define('GLIB_VERSION_MIN_REQUIRED', glib_encode_version(MIN_GLIB))
    ctx.define('GDK_VERSION_MAX_ALLOWED', glib_encode_version(MIN_GTK))
    ctx.define('GDK_VERSION_MIN_REQUIRED', glib_encode_version(MIN_GTK))

    for url in ("report_bug", "request_feature", "ask_question"):
        ctx.define("NUVOLA_%s_URL" % url.upper(), branding.get(url + "_url", "").strip())


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
    NUVOLAKIT_RUNNER = SHORT_ID + "-runner"
    NUVOLAKIT_BASE = SHORT_ID + "-base"
    NUVOLAKIT_WORKER = SHORT_ID + "-worker"
    NUVOLAKIT_CEF_WORKER = SHORT_ID + "-cef-worker"
    NUVOLAKIT_TESTS = SHORT_ID + "-tests"
    RUN_NUVOLAKIT_TESTS = "run-" + NUVOLAKIT_TESTS
    DIORITE_GLIB = 'dioriteglib' + TARGET_DIORITE
    DIORITE_GTK = 'dioriteglib' + TARGET_DIORITE

    packages = 'dioritegtk{0} dioriteglib{0} '.format(TARGET_DIORITE)
    packages += 'javascriptcore javascriptcoregtk-4.0 libnotify libarchive gtk+-3.0 gdk-3.0 gdk-x11-3.0 x11 posix json-glib-1.0 glib-2.0 gio-2.0'
    packages += ' libpulse-mainloop-glib gee-0.8'
    uselib = 'NOTIFY JSCORE LIBARCHIVE DIORITEGTK DIORITEGLIB GTK+ GDK GDKX11 X11 JSON-GLIB GLIB GIO LIBPULSE LIBPULSE-GLIB GEE'

    vapi_dirs = ['build', 'vapi', 'engineio-soup/vapi']
    env_vapi_dir = os.environ.get("VAPIDIR")
    vapi_to_patch = []

    if env_vapi_dir:
        vapi_dirs.extend(os.path.relpath(path) for path in env_vapi_dir.split(":"))
    if ctx.env.SNAPCRAFT:
        vapi_dirs.append(os.path.relpath(ctx.env.SNAPCRAFT + "/usr/share/vala/vapi"))

    if ctx.env.with_unity:
        packages += " unity Dbusmenu-0.4"
        uselib += " UNITY DBUSMENU"
        vapi_to_patch.append("dee-1.0")
    if ctx.env.with_appindicator:
        packages += " ayatana-appindicator3-0.1"
        uselib += " APPINDICATOR"
    if ctx.env.have_cef:
        packages += " valacef valacefgtk"
        uselib += " VALACEF VALACEFGTK"

    if not ctx.env.PATCH_VAPI:
        vapi_to_patch.clear()

    # The vapi files are not patched in-place - the result is stored in our build directory.
    for vapi in vapi_to_patch:
        all_vapi_dirs = [path.format(vala=ctx.env.VALAC_SERIES) for path in (
            '/app/share/vala-{vala}/vapi', '/usr/share/vala-{vala}/vapi', '/app/share/vala/vapi', '/usr/share/vala/vapi'
        )]
        all_vapi_dirs.extend(d for d in vapi_dirs if d not in ("vapi", "build"))
        for vapi_dir in all_vapi_dirs:
            if os.path.isfile("%s/%s.vapi" % (vapi_dir, vapi)):
                patch("%s/%s.vapi" % (vapi_dir, vapi), "vapi/%s.patch" % vapi, '%s.vapi' %  vapi)
                cp_if_found("%s/%s.deps" % (vapi_dir, vapi), '%s.deps' %  vapi)
                break
        else:
            ctx.fatal('Cannot find "%s.vapi" in %s.' % (vapi, all_vapi_dirs))

    ctx(features = "checkvaladefs", source = ctx.path.ant_glob('src/**/*.vala'),
        definitions="FLATPAK TILIADO_API GENUINE UNITY APPINDICATOR EXPERIMENTAL NUVOLA_RUNTIME"
        + " NUVOLA_ADK NUVOLA_CDK HAVE_CEF FALSE TRUE")

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

    ctx.add_group()

    valalib(
        target = ENGINEIO,
        source_dir = 'engineio-soup/src',
        packages = 'uuid libsoup-2.4 json-glib-1.0',
        uselib = 'UUID SOUP JSON-GLIB',
        defines = ['G_LOG_DOMAIN="Engineio"'],
        vapi_dirs = vapi_dirs,
        vala_target_glib = TARGET_GLIB,
    )

    valalib(
        target = NUVOLAKIT_BASE,
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
        source_dir = 'src/nuvolakit-runner',
        packages = packages + ' javascriptcoregtk-4.0 gstreamer-1.0 libsecret-1 dri2 libdrm libarchive prctl libsoup-2.4',
        uselib =  uselib + ' JSCORE GST SECRET DRI2 DRM LIBARCHIVE SOUP',
        use = [NUVOLAKIT_BASE, ENGINEIO],
        lib = ['m'],
        includes = ["build"],
        vala_defines = vala_defines,
        defines = ['G_LOG_DOMAIN="Nuvola"'],
        vapi_dirs = vapi_dirs,
        vala_target_glib = TARGET_GLIB,
    )

    valaprog(
        target = NUVOLA_BIN,
        source_dir = 'src/master',
        packages = " libsoup-2.4",
        uselib = uselib + " SOUP",
        use = [NUVOLAKIT_BASE, NUVOLAKIT_RUNNER],
        vala_defines = vala_defines,
        defines = ['G_LOG_DOMAIN="Nuvola"'],
        vapi_dirs = vapi_dirs,
        vala_target_glib = TARGET_GLIB,
    )

    valaprog(
        target = NUVOLA_SERVICE_INFO,
        source_dir = 'src/' + NUVOLA_SERVICE_INFO,
        packages = " libsoup-2.4",
        uselib = uselib + " SOUP",
        use = [NUVOLAKIT_BASE, NUVOLAKIT_RUNNER],
        vala_defines = vala_defines,
        defines = ['G_LOG_DOMAIN="Nuvola"'],
        vapi_dirs = vapi_dirs,
        vala_target_glib = TARGET_GLIB,
    )

    valaprog(
        target = APP_RUNNER,
        source_dir = 'src/apprunner',
        packages = " libsoup-2.4",
        uselib = uselib + " SOUP",
        use = [NUVOLAKIT_BASE, NUVOLAKIT_RUNNER],
        vala_defines = vala_defines,
        defines = ['G_LOG_DOMAIN="Nuvola"'],
        vapi_dirs = vapi_dirs,
        vala_target_glib = TARGET_GLIB,
    )

    valaprog(
        target = NUVOLACTL_BIN,
        source_dir = 'src/control',
        packages = " libsoup-2.4",
        uselib = uselib + " SOUP",
        use = [NUVOLAKIT_BASE, NUVOLAKIT_RUNNER],
        vala_defines = vala_defines,
        defines = ['G_LOG_DOMAIN="Nuvola"'],
        vapi_dirs = vapi_dirs,
        vala_target_glib = TARGET_GLIB,
    )


    if ctx.env.have_cef:
        valalib(
            target = NUVOLAKIT_CEF_WORKER,
            source_dir = 'src/nuvolakit-cef-worker',
            packages = " libsoup-2.4 dioriteglib{0} dioritegtk{0} {1} {2} javascriptcoregtk-4.0".format(TARGET_DIORITE, 'valacef', 'valacefgtk'),
            uselib = "SOUP DIORITEGLIB DIORITEGTK VALACEF VALACEFGTK JSCORE GEE",
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
        packages = packages + ' libsoup-2.4  javascriptcoregtk-4.0 gstreamer-1.0 libsecret-1',
        uselib =  uselib + ' SOUP JSCORE GST SECRET',
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

    dbus_name = ctx.env.UNIQUE_NAME
    ctx(features = 'subst',
        source = 'data/templates/dbus.service',
        target = "share/dbus-1/services/%s.service" % dbus_name,
        install_path = '${PREFIX}/share/dbus-1/services',
        NAME = dbus_name,
        EXEC = '%s/bin/%s --gapplication-service' % (ctx.env.PREFIX, NUVOLA_BIN)
    )

    PC_CFLAGS = ""
    # https://www.bassi.io/articles/2018/03/15/pkg-config-and-paths/
    PREFIX = ctx.env.PREFIX
    PC_PATHS = {}
    for name in "LIBDIR", "INCLUDEDIR", "DATADIR":
        path = getattr(ctx.env, name)
        PC_PATHS[name] = "${prefix}" + path[len(PREFIX):] if path.startswith(PREFIX + "/") else path

    ctx(features = 'subst',
        source='src/nuvolakitbase.pc.in',
        target='{}-base.pc'.format(SHORT_ID),
        install_path='${LIBDIR}/pkgconfig',
        VERSION=ctx.env.RELEASE,
        PREFIX=PREFIX,
        SHORT_ID=SHORT_ID,
        PC_CFLAGS=PC_CFLAGS,
        LIBNAME=NUVOLAKIT_BASE,
        DIORITE_GLIB=DIORITE_GLIB,
        **PC_PATHS,
    )

    ctx(features = 'subst',
        source='src/nuvolakitrunner.pc.in',
        target='{}-runner.pc'.format(SHORT_ID),
        install_path='${LIBDIR}/pkgconfig',
        VERSION=ctx.env.RELEASE,
        PREFIX=PREFIX,
        SHORT_ID=SHORT_ID,
        PC_CFLAGS=PC_CFLAGS,
        LIBNAME=NUVOLAKIT_RUNNER,
        NUVOLAKIT_BASE=NUVOLAKIT_BASE,
        DIORITE_GLIB=DIORITE_GLIB,
        DIORITE_GTK=DIORITE_GTK,
        **PC_PATHS,
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
            else '<p>{} software is based on the open source code from the Nuvola Player™ project.</p>'.format(ctx.env.NAME)
        ),
        UNIQUE_NAME=ctx.env.UNIQUE_NAME,
    )
    ctx.install_as(
        '${PREFIX}/share/metainfo/%s.appdata.xml' % ctx.env.UNIQUE_NAME,
        ctx.path.get_bld().find_node(ctx.env.UNIQUE_NAME + '.appdata.xml'))

    ctx.symlink_as('${PREFIX}/share/%s/www/engine.io.js' % SHORT_ID, ctx.env.JSDIR + '/engine.io-client/engine.io.js')

    for dirname in "www", "tips":
        directory = ctx.path.find_dir("data/" + dirname)
        ctx.install_files('${PREFIX}/share/' + SHORT_ID, directory.ant_glob('**'), cwd=directory.parent, relative_trick=True)

    app_icons = ctx.path.find_node("data/icons")
    for size in (16, 22, 24, 32, 48, 64, 128, 256):
        ctx.install_as('${PREFIX}/share/icons/hicolor/%sx%s/apps/%s.png' % (size, size, ctx.env.ICON_NAME), app_icons.find_node("%s.png" % size))
    ctx.install_as('${PREFIX}/share/icons/hicolor/scalable/apps/%s.svg' % ctx.env.ICON_NAME, app_icons.find_node("scalable.svg"))

    ctx(features = "mergejs",
        source = ctx.path.ant_glob('src/mainjs/*.js'),
        target = 'share/%s/js/main.js' % SHORT_ID,
        install_path = '${PREFIX}/share/%s/js' % SHORT_ID
    )

    ctx.add_group()
    jslint(source_dir = 'src/mainjs', global_vars=['Nuvola'])
    jslint(source = ['web_apps/test/home.js', 'web_apps/test/integrate.js'])

def dist(ctx):
    ctx.algo = "tar.gz"
    ctx.excl = '.git .gitignore build/* **/.waf* **/*~ **/*.swp **/.lock* bzrcommit.txt **/*.pyc core'
