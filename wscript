# encoding: utf-8
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

# Metadata #
#==========#

top = '.'
out = 'build'
DEFAULT_NAME="Nuvola Apps"
ADK_NAME="Nuvola ADK"
CDK_NAME="Nuvola CDK"
APPNAME = "nuvolaplayer3"
FUTURE_APPNAME = "nuvola"
VERSION = "3.1.2"
DEFAULT_UNIQUE_NAME="eu.tiliado.Nuvola"
ADK_UNIQUE_NAME="eu.tiliado.NuvolaAdk"
CDK_UNIQUE_NAME="eu.tiliado.NuvolaCdk"
GENERIC_NAME = "Cloud Player"
BLURB = "Cloud music integration for your Linux desktop"
WELCOME_SCREEN_NAME = "Nuvola Apps 3.1 Rolling Releases"

MIN_DIORITE = "0.3.3"
MIN_VALA = "0.34.0"
MIN_GLIB = "2.42.1"
MIN_GTK = "3.22.0"
LEGACY_WEBKIT = "2.14.5"
FLATPAK_WEBKIT = "2.16.1"

# Extras #
#========#

import os
from waflib.Errors import ConfigurationError
from waflib import TaskGen, Utils, Errors, Node, Task
from nuvolamergejs import mergejs as merge_js

TARGET_DIORITE = MIN_DIORITE.rsplit(".", 1)[0]
TARGET_GLIB = MIN_GLIB.rsplit(".", 1)[0]
SERIES = VERSION.rsplit(".", 1)[0]
VERSIONS = tuple(int(i) for i in VERSION.split("."))
REVISION_SNAPSHOT = "snapshot"


def get_revision_id():
	import subprocess
	try:
		output = subprocess.Popen(["git", "describe", "--tags", "--long"], stdout=subprocess.PIPE).communicate()[0]
		__, revision_id = output.decode("utf-8").strip().split("-", 1)
		revision_id = revision_id.replace("-", ".")
	except Exception as e:
		revision_id = REVISION_SNAPSHOT
	return revision_id

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


# Actions #
#=========#

def options(ctx):
	ctx.load('compiler_c vala')
	ctx.add_option('--noopt', action='store_true', default=False, dest='noopt', help="Turn off compiler optimizations")
	ctx.add_option('--flatpak', action='store_true', default=False, dest='flatpak', help="Enable Flatpak tweaks.")
	ctx.add_option('--nodebug', action='store_false', default=True, dest='debug', help="Turn off debugging symbols")
	ctx.add_option('--nounity', action='store_false', default=True, dest='unity', help="Don't build Unity features.")
	ctx.add_option('--flatpak', action='store_true', default=False, dest='flatpak', help="Apply workarounds for Flatpak.")
	ctx.add_option('--adk', action='store_true', default=False, dest='adk', help="Build as Nuvola ADK (App Developer Kit).")
	ctx.add_option('--cdk', action='store_true', default=False, dest='cdk', help="Build as Nuvola CDK (Core Developer Kit).")
	ctx.add_option('--tiliado-oauth2-server', type=str, default="https://tiliado.eu", help="Tiliado OAuth2 server to access Tiliado services.")
	ctx.add_option('--tiliado-oauth2-client-id', type=str, default="", help="Tiliado OAuth2 client id to access Tiliado services.")
	ctx.add_option('--tiliado-oauth2-client-secret', type=str, default="", help="Tiliado OAuth2 client secret to access Tiliado services.")
	ctx.add_option('--repository-index', type=str, default="https://nuvola.tiliado.eu/", help="Nuvola Apps Repository Index URI.")
	ctx.add_option('--webkitgtk-supports-mse', action='store_true', default=False, dest='webkit_mse', help="Use only if you are absolutely sure that your particular build of the WebKitGTK library supports Media Source Extension (as of 2.15.3, it is disabled by default)")

def configure(ctx):
	ctx.env.REVISION_ID = get_revision_id()
	ctx.env.VERSION  = VERSION + "+" + ctx.env.REVISION_ID
	
	ctx.msg("Version", VERSION, "GREEN")
	if ctx.env.REVISION_ID != REVISION_SNAPSHOT:
		ctx.msg("Upstream revision", ctx.env.REVISION_ID, "GREEN")
	else:
		ctx.msg("Upstream revision", "unknown", "RED")
	ctx.msg('Install prefix', ctx.options.prefix, "GREEN")
	
	ctx.env.append_unique("VALAFLAGS", "-v")
	ctx.env.append_unique('CFLAGS', ['-w'])
	ctx.env.append_unique("LINKFLAGS", ["-Wl,--no-undefined", "-Wl,--as-needed"])
	for path in os.environ.get("LD_LIBRARY_PATH", "").split(":"):
		path = path.strip()
		if path:
			ctx.env.append_unique('LIBPATH', path)
	if not ctx.options.noopt:
		ctx.env.append_unique('CFLAGS', '-O2')
	if ctx.options.debug:
		ctx.env.append_unique('VALAFLAGS', '-g')
		ctx.env.append_unique('CFLAGS', '-g3')
	
	# Variants
	genuine = False
	ctx.env.CDK = ctx.options.cdk
	ctx.env.ADK = ctx.options.adk
	MIN_WEBKIT = LEGACY_WEBKIT
	if ctx.options.cdk:
		genuine = True
		vala_def(ctx, "NUVOLA_CDK")
		ctx.env.NAME = CDK_NAME
		ctx.env.UNIQUE_NAME = CDK_UNIQUE_NAME
		MIN_WEBKIT = FLATPAK_WEBKIT
	elif ctx.options.adk:
		genuine = True
		vala_def(ctx, "NUVOLA_ADK")
		ctx.env.NAME = ADK_NAME
		ctx.env.UNIQUE_NAME = ADK_UNIQUE_NAME
		MIN_WEBKIT = FLATPAK_WEBKIT
	else:
		vala_def(ctx, "NUVOLA_STD")
		ctx.env.NAME = DEFAULT_NAME
		ctx.env.UNIQUE_NAME = DEFAULT_UNIQUE_NAME
	ctx.env.ICON_NAME = ctx.env.UNIQUE_NAME
	
	# Flatpak
	ctx.env.FLATPAK = ctx.options.flatpak
	if ctx.env.FLATPAK:
		genuine = True
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
	pkgconfig(ctx, 'dioriteglib-' + TARGET_DIORITE, 'DIORITEGLIB', MIN_DIORITE)
	pkgconfig(ctx, 'dioritegtk-' + TARGET_DIORITE, 'DIORITEGTK', MIN_DIORITE)
	pkgconfig(ctx, 'json-glib-1.0', 'JSON-GLIB', '0.7')
	pkgconfig(ctx, 'libarchive', 'LIBARCHIVE', '3.1')
	pkgconfig(ctx, 'libnotify', 'NOTIFY', '0.7')
	pkgconfig(ctx, 'libsecret-1', 'SECRET', '0.16')
	pkgconfig(ctx, "gstreamer-1.0", 'GST', "1.11.90" if ctx.options.webkit_mse else "1.8")
	pkgconfig(ctx, 'webkit2gtk-4.0', 'WEBKIT', MIN_WEBKIT)
	pkgconfig(ctx, 'webkit2gtk-web-extension-4.0', 'WEBKITEXT', MIN_WEBKIT)
	pkgconfig(ctx, 'javascriptcoregtk-4.0', 'JSCORE', MIN_WEBKIT)
	pkgconfig(ctx, 'uuid', 'UUID', '0') # Engine.io
	pkgconfig(ctx, 'libsoup-2.4', 'SOUP', '0') # Engine.io
	
	# Optional features
	ctx.env.WEBKIT_MSE = ctx.options.webkit_mse
	if ctx.options.webkit_mse:
		vala_def(ctx, "WEBKIT_SUPPORTS_MSE")
	ctx.env.with_unity = ctx.options.unity
	if ctx.options.unity:
		pkgconfig(ctx, 'unity', 'UNITY', '3.0')
		pkgconfig(ctx, 'dbusmenu-glib-0.4', 'DBUSMENU', '0.4')
		vala_def(ctx, "UNITY")
	
	# Define HAVE_WEBKIT_X_YY Vala compiler definitions
	webkit_version = tuple(int(i) for i in ctx.check_cfg(modversion='webkit2gtk-4.0').split(".")[0:2])
	version = (2, 6)
	while version <= webkit_version:
		vala_def(ctx, "HAVE_WEBKIT_%d_%d" % version)
		version = (version[0], version[1] + 2)
	
	# Definitions
	ctx.env.GENUINE = genuine
	if genuine:
		vala_def(ctx, ("EXPERIMENTAL", "GENUINE"))
	else:
		ctx.env.NAME = "Web Apps"
	ctx.define("NUVOLA_APPNAME", APPNAME)
	ctx.define("NUVOLA_FUTURE_APPNAME", FUTURE_APPNAME)
	ctx.define("NUVOLA_NAME", ctx.env.NAME)
	ctx.define("NUVOLA_WELCOME_SCREEN_NAME", WELCOME_SCREEN_NAME)
	ctx.define("NUVOLA_UNIQUE_NAME", ctx.env.UNIQUE_NAME)
	ctx.define("NUVOLA_APP_ICON", ctx.env.ICON_NAME)
	ctx.define("NUVOLA_VERSION", ctx.env.VERSION)
	ctx.define("NUVOLA_REVISION", ctx.env.REVISION_ID)
	ctx.define("NUVOLA_VERSION_MAJOR", VERSIONS[0])
	ctx.define("NUVOLA_VERSION_MINOR", VERSIONS[1])
	ctx.define("NUVOLA_VERSION_BUGFIX", VERSIONS[2])
	ctx.define("NUVOLA_VERSION_SUFFIX", ctx.env.REVISION_ID)
	ctx.define("GETTEXT_PACKAGE", FUTURE_APPNAME)
	ctx.env.NUVOLA_LIBDIR = "%s/%s" % (ctx.env.LIBDIR, APPNAME)
	ctx.define("NUVOLA_TILIADO_OAUTH2_SERVER", ctx.options.tiliado_oauth2_server)
	ctx.define("NUVOLA_TILIADO_OAUTH2_CLIENT_ID", ctx.options.tiliado_oauth2_client_id)
	repo_index = ctx.options.repository_index.split("|")
	repo_index, repo_root = repo_index if len(repo_index) > 1 else  repo_index + repo_index 
	ctx.define("NUVOLA_REPOSITORY_INDEX", repo_index)
	ctx.define("NUVOLA_REPOSITORY_ROOT", repo_root)
	ctx.define("NUVOLA_LIBDIR", ctx.env.NUVOLA_LIBDIR)
	
	ctx.define('GLIB_VERSION_MAX_ALLOWED', glib_encode_version(MIN_GLIB))
	ctx.define('GLIB_VERSION_MIN_REQUIRED', glib_encode_version(MIN_GLIB))
	ctx.define('GDK_VERSION_MAX_ALLOWED', glib_encode_version(MIN_GTK))
	ctx.define('GDK_VERSION_MIN_REQUIRED', glib_encode_version(MIN_GTK))
	
	with open("build/secret.h", "wb") as f:
		if ctx.options.tiliado_oauth2_client_secret:
			secret = b"{"
			for i in mask(ctx.options.tiliado_oauth2_client_secret):
				secret += str(i).encode("ascii") + b", "
			secret += b"0}"
		else:
			secret = b'""'
		f.write(
			b'#pragma once\nstatic const char NUVOLA_TILIADO_OAUTH2_CLIENT_SECRET[] = '	+ secret + b';')


def build(ctx):
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
	
	#~ print(ctx.env)
	vala_defines = ctx.env.VALA_DEFINES
	
	APP_RUNNER = "apprunner"
	CONTROL = APPNAME + "ctl"
	ENGINEIO = "engineio"
	NUVOLAKIT_RUNNER = APPNAME + "-runner"
	NUVOLAKIT_BASE = APPNAME + "-base"
	NUVOLAKIT_WORKER = APPNAME + "-worker"
	DIORITE_GLIB = 'dioriteglib-' + TARGET_DIORITE
	DIORITE_GTK = 'dioriteglib-' + TARGET_DIORITE
	
	packages = 'dioritegtk-{0} dioriteglib-{0} '.format(TARGET_DIORITE)
	packages += 'javascriptcoregtk-4.0 libnotify libarchive gtk+-3.0 gdk-3.0 gdk-x11-3.0 x11 posix json-glib-1.0 glib-2.0 gio-2.0'
	uselib = 'NOTIFY JSCORE LIBARCHIVE DIORITEGTK DIORITEGLIB GTK+ GDK GDKX11 X11 JSON-GLIB GLIB GIO'
	
	vapi_dirs = ['vapi', 'engineio-soup/vapi']
	env_vapi_dir = os.environ.get("VAPIDIR")
	if env_vapi_dir:
		vapi_dirs.extend(os.path.relpath(path) for path in env_vapi_dir.split(":"))
	if ctx.env.SNAPCRAFT:
		vapi_dirs.append(os.path.relpath(ctx.env.SNAPCRAFT + "/usr/share/vala/vapi"))
	
	if ctx.env.with_unity:
		packages += " unity Dbusmenu-0.4"
		uselib += " UNITY DBUSMENU"
	
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
		packages = packages + ' webkit2gtk-4.0 javascriptcoregtk-4.0 gstreamer-1.0 libsecret-1',
		uselib =  uselib + ' JSCORE WEBKIT GST SECRET',
		use = [NUVOLAKIT_BASE, ENGINEIO],
		lib = ['m'],
		includes = ["build"],
		vala_defines = vala_defines,
		defines = ['G_LOG_DOMAIN="Nuvola"'],
		vapi_dirs = vapi_dirs,
		vala_target_glib = TARGET_GLIB,
	)

	valaprog(
		target = APPNAME,
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
		target = APP_RUNNER,
		source_dir = 'src/apprunner',
		packages = "",
		uselib = uselib + " SOUP WEBKIT",
		use = [NUVOLAKIT_BASE, NUVOLAKIT_RUNNER],
		vala_defines = vala_defines,
		defines = ['G_LOG_DOMAIN="Nuvola"'],
		vapi_dirs = vapi_dirs,
		vala_target_glib = TARGET_GLIB,
		install_path = ctx.env.NUVOLA_LIBDIR,
	)
	
	valaprog(
		target = CONTROL,
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
		packages = "dioriteglib-{0} {1} {2}".format(TARGET_DIORITE, 'webkit2gtk-web-extension-4.0', 'javascriptcoregtk-4.0'),
		uselib = "SOUP DIORITEGLIB DIORITEGTK WEBKITEXT JSCORE",
		use = [NUVOLAKIT_BASE],
		vala_defines = vala_defines,
		cflags = ['-DG_LOG_DOMAIN="Nuvola"'],
		vapi_dirs = vapi_dirs,
		vala_target_glib = TARGET_GLIB,
		install_path = ctx.env.NUVOLA_LIBDIR,
	)
	
	ctx(features = 'subst',
		source = 'data/templates/launcher.desktop',
		target = "share/applications/%s.desktop" % ctx.env.UNIQUE_NAME,
		install_path = '${PREFIX}/share/applications',
		BLURB = BLURB,
		APP_NAME = ctx.env.NAME,
		ICON = ctx.env.ICON_NAME,
		EXEC = APPNAME if not ctx.env.ADK else "lxterminal",
		GENERIC_NAME=GENERIC_NAME,
		WMCLASS = ctx.env.UNIQUE_NAME,
	)
	
	dbus_name = ctx.env.UNIQUE_NAME if ctx.env.GENUINE else "eu.tiliado.NuvolaOse"	
	ctx(features = 'subst',
		source = 'data/templates/dbus.service',
		target = "share/dbus-1/services/%s.service" % dbus_name,
		install_path = '${PREFIX}/share/dbus-1/services',
		NAME = dbus_name,
		EXEC = '%s/bin/%s --gapplication-service' % (ctx.env.PREFIX, APPNAME)
	)
	
	PC_CFLAGS = ""
	ctx(features = 'subst',
		source='src/nuvolakitbase.pc.in',
		target='{}-base.pc'.format(APPNAME),
		install_path='${LIBDIR}/pkgconfig',
		VERSION=VERSION,
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
		VERSION=VERSION,
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
		source=ctx.path.find_node("data/nuvolaplayer3.appdata.xml"),
		target=ctx.path.get_bld().make_node(ctx.env.UNIQUE_NAME + '.appdata.xml'),
		install_path='${PREFIX}/share/appdata',
		encoding="utf-8",
		FULL_NAME=ctx.env.NAME,
		PRELUDE=(
			"" if ctx.env.GENUINE
			else '<p>{} software is based on the open source code from the Nuvola Apps™ project.</p>'.format(ctx.env.NAME)
		),
	)
	ctx.install_as(
		'${PREFIX}/share/metainfo/%s.appdata.xml' % ctx.env.UNIQUE_NAME,
		ctx.path.get_bld().find_node(ctx.env.UNIQUE_NAME + '.appdata.xml'))
	
	ctx.symlink_as('${PREFIX}/bin/%s' % FUTURE_APPNAME, APPNAME)
	ctx.symlink_as('${PREFIX}/bin/%sctl' % FUTURE_APPNAME, CONTROL)
	
	web_apps = ctx.path.find_dir("web_apps")
	ctx.install_files('${PREFIX}/share/' + APPNAME, web_apps.ant_glob('**'), cwd=web_apps.parent, relative_trick=True)
	www = ctx.path.find_dir("data/www")
	ctx.install_files('${PREFIX}/share/' + APPNAME, www.ant_glob('**'), cwd=www.parent, relative_trick=True)
	
	app_icons = ctx.path.find_node("data/icons")
	for size in (16, 22, 24, 32, 48, 64):
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

def dist(ctx):
	ctx.algo = "tar.gz"
	ctx.excl = '.git .gitignore build/* **/.waf* **/*~ **/*.swp **/.lock* bzrcommit.txt **/*.pyc core'
