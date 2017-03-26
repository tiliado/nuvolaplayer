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

# Top of source tree
top = '.'
# Build directory
out = 'build'

# Application name and version
DEFAULT_NAME="Nuvola Apps"
ADK_NAME="Nuvola ADK"
CDK_NAME="Nuvola CDK"
APPNAME = "nuvolaplayer3"
FUTURE_APPNAME = "nuvola"
VERSION = "3.1.1"
DEFAULT_UNIQUE_NAME="eu.tiliado.Nuvola"
ADK_UNIQUE_NAME="eu.tiliado.NuvolaAdk"
CDK_UNIQUE_NAME="eu.tiliado.NuvolaCdk"
GENERIC_NAME = "Cloud Player"
BLURB = "Cloud music integration for your Linux desktop"
WELCOME_SCREEN_NAME = "Nuvola Apps 3.1 Rolling Releases"

TARGET_GLIB = "2.42"
MIN_GLIB = "2.42.1"
MIN_GTK = "3.14.5"
MIN_WEBKIT = "2.6.2"

import subprocess
try:
	try:
		# Read revision info from file revision-info created by ./waf dist
		with open("version-info.txt", "rt") as f:
			__, revision_id = f.read().strip().split("-", 1)
	except Exception as e:
		# Read revision info from current branch
		output = subprocess.Popen(["git", "describe", "--tags", "--long"], stdout=subprocess.PIPE).communicate()[0]
		__, revision_id = output.decode("utf-8").strip().split("-", 1)
	revision_id = revision_id.replace("-", ".")
except Exception as e:
	revision_id = "snapshot"
	
REVISION_ID = revision_id
VERSION_SUFFIX = revision_id
VERSIONS = tuple(int(i) for i in VERSION.split("."))
VERSION += "+" + revision_id


import sys
import os
from waflib.Configure import conf
from waflib.Errors import ConfigurationError
from waflib.Context import WAFVERSION

WAF_VERSION = tuple(int(i) for i in WAFVERSION.split("."))
REQUIRED_VERSION = (1, 7, 14) 
if WAF_VERSION < REQUIRED_VERSION:
	print("Too old waflib %s < %s. Use waf binary distributed with the source code!" % (WAF_VERSION, REQUIRED_VERSION))
	sys.exit(1)

LINUX = "LINUX"
WIN = "WIN"

if sys.platform.startswith("linux"):
	_PLATFORM = LINUX
elif sys.platform.startswith("win"):
	_PLATFORM = WIN
else:
	_PLATFORM = sys.platform.upper()

@conf
def vala_def(ctx, vala_definition):
	"""Appends a Vala definition"""
	if not hasattr(ctx.env, "VALA_DEFINES"):
		ctx.env.VALA_DEFINES = []
	if isinstance(vala_def, tuple) or isinstance(vala_def, list):
		for d in vala_definition:
			ctx.env.VALA_DEFINES.append(d)
	else:
		ctx.env.VALA_DEFINES.append(vala_definition)

@conf
def check_dep(ctx, pkg, uselib, version, mandatory=True, store=None, vala_def=None, define=None):
	"""Wrapper for ctx.check_cfg."""
	result = True
	try:
		res = ctx.check_cfg(package=pkg, uselib_store=uselib, atleast_version=version, mandatory=True, args = '--cflags --libs')
		if vala_def:
			ctx.vala_def(vala_def)
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

# Add extra options to ./waf command
def options(ctx):
	ctx.load('compiler_c vala')
	ctx.add_option('--with-unity', action='store_true', default=False, dest='unity', help="Build functionality dependent on libunity")
	ctx.add_option('--noopt', action='store_true', default=False, dest='noopt', help="Turn off compiler optimizations")
	ctx.add_option('--debug', action='store_true', default=True, dest='debug', help="Turn on debugging symbols")
	ctx.add_option('--no-debug', action='store_false', dest='debug', help="Turn off debugging symbols")
	ctx.add_option('--no-system-hooks', action='store_false', default=True, dest='system_hooks', help="Don't run system hooks after installation (ldconfig, icon cache update, ...")
	ctx.add_option('--platform', default=_PLATFORM, help="Target platform")
	ctx.add_option('--allow-fuzzy-build', action='store_true', default=False, dest='fuzzy', help="Allow building without valid git revision information and absolutely no support from upstream.")
	ctx.add_option('--snapcraft', action='store_true', default=False, dest='snapcraft', help="Apply workarounds for Snapcraft with given name.")
	ctx.add_option('--flatpak', action='store_true', default=False, dest='flatpak', help="Apply workarounds for Flatpak.")
	ctx.add_option('--adk', action='store_true', default=False, dest='adk', help="Build as Nuvola ADK (App Developer Kit).")
	ctx.add_option('--cdk', action='store_true', default=False, dest='cdk', help="Build as Nuvola CDK (Core Developer Kit).")
	ctx.add_option('--tiliado-oauth2-server', type=str, default="https://tiliado.eu", help="Tiliado OAuth2 server to access Tiliado services.")
	ctx.add_option('--tiliado-oauth2-client-id', type=str, default="", help="Tiliado OAuth2 client id to access Tiliado services.")
	ctx.add_option('--tiliado-oauth2-client-secret', type=str, default="", help="Tiliado OAuth2 client secret to access Tiliado services.")
	ctx.add_option('--repository-index', type=str, default="https://nuvola.tiliado.eu/", help="Nuvola Apps Repository Index URI.")
	ctx.add_option('--webkitgtk-supports-mse', action='store_true', default=False, dest='webkit_mse', help="Use only if you are absolutely sure that your particular build of the WebKitGTK library supports Media Source Extension (as of 2.15.3, it is disabled by default)")

# Configure build process
def configure(ctx):
	ctx.env.PLATFORM = PLATFORM = ctx.options.platform.upper()
	if PLATFORM not in (LINUX,):
		print("Unsupported platform %s. Please try to talk to devs to consider support of your platform." % sys.platform)
		sys.exit(1)
	
	ctx.env.fuzzy = ctx.options.fuzzy
	ctx.msg("Version", VERSION, "GREEN")
	if REVISION_ID != "snapshot":
		ctx.msg("Upstream revision", REVISION_ID, "GREEN")
	else:
		ctx.msg("Upstream revision", "unknown (unsupported build)", "RED")
		if not ctx.env.fuzzy and VERSION_SUFFIX != "stable":
			ctx.fatal(
				"Failed to get valid git revision information. Make sure git is installed. "
				"If it is, please talk to Nuvola Player devs to investigate this issue. "
				"Alternatively, pass --allow-fuzzy-build configuration option, but don't "
				"expect any support from upstream then.")
	
	ctx.define(PLATFORM, 1)
	ctx.env.VALA_DEFINES = [PLATFORM]
	ctx.msg('Target platform', PLATFORM, "GREEN")
	ctx.msg('Install prefix', ctx.options.prefix, "GREEN")
	
	ctx.load('compiler_c vala')
	ctx.check_vala(min_version=(0, 26, 1))
	# Don't be quiet
	ctx.env.VALAFLAGS.remove("--quiet")
	ctx.env.append_value("VALAFLAGS", "-v")
	
	# Honor LD_LIBRARY_PATH
	for path in os.environ.get("LD_LIBRARY_PATH", "").split(":"):
		path = path.strip()
		if path:
			ctx.env.append_unique('LIBPATH', path)
	
	# enable threading
	ctx.env.append_value("VALAFLAGS", "--thread")
	
	# Turn compiler optimizations on/off
	if ctx.options.noopt:
		ctx.msg('Compiler optimizations', "OFF?!", "RED")
		ctx.env.append_unique('CFLAGS', '-O0')
	else:
		ctx.env.append_unique('CFLAGS', '-O2')
		ctx.msg('Compiler optimizations', "ON", "GREEN")
	
	# Include debugging symbols
	if ctx.options.debug:
		#~ ctx.env.append_unique('VALAFLAGS', '-g')
		if PLATFORM == LINUX:
			ctx.env.append_unique('CFLAGS', '-g3')
		elif PLATFORM == WIN:
			ctx.env.append_unique('CFLAGS', ['-g', '-gdwarf-2'])
	
	# Get rid of some annoying warnings (we cannot fix them anyway)
	#~ ctx.env.append_unique('CFLAGS', ['-Wno-ignored-qualifiers', '-Wno-discarded-qualifiers', '-Wno-incompatible-pointer-types'])
	ctx.env.append_unique('CFLAGS', ['-w'])
	
	# Anti-underlinking and anti-overlinking linker flags.
	ctx.env.append_unique("LINKFLAGS", ["-Wl,--no-undefined", "-Wl,--as-needed"])
	
	ctx.env.CDK = ctx.options.cdk
	ctx.env.ADK = ctx.options.adk
	if ctx.options.cdk:
		ctx.vala_def("NUVOLA_CDK")
		ctx.env.NAME = CDK_NAME
		ctx.env.UNIQUE_NAME = CDK_UNIQUE_NAME
	elif ctx.options.adk:
		ctx.vala_def("NUVOLA_ADK")
		ctx.env.NAME = ADK_NAME
		ctx.env.UNIQUE_NAME = ADK_UNIQUE_NAME
	else:
		ctx.vala_def("NUVOLA_STD")
		ctx.env.NAME = DEFAULT_NAME
		ctx.env.UNIQUE_NAME = DEFAULT_UNIQUE_NAME
	ctx.env.ICON_NAME = ctx.env.UNIQUE_NAME
	
	# Snapcraft hacks
	if ctx.options.snapcraft:
		ctx.env.SNAPCRAFT = SNAPCRAFT = os.environ["SNAPCRAFT_STAGE"]
		ctx.msg('Snapcraft stage', SNAPCRAFT, "GREEN")
		ctx.env.append_unique('CFLAGS', '-I%s/usr/include/diorite-1.0' % SNAPCRAFT)
		ctx.vala_def("SNAPCRAFT")
	else:
		ctx.env.SNAPCRAFT = None
	
	# Flatpak
	ctx.env.FLATPAK = ctx.options.flatpak
	if ctx.env.FLATPAK:
		ctx.vala_def("FLATPAK")
	
	ctx.env.WEBKIT_MSE = ctx.options.webkit_mse
	if ctx.options.webkit_mse:
		ctx.vala_def("WEBKIT_SUPPORTS_MSE")
	
	# Check dependencies
	ctx.env.DIORITE_SERIES = DIORITE_SERIES = "0.3"
	DIORITE_BUGFIX = "1"
	ctx.check_dep('glib-2.0', 'GLIB', MIN_GLIB)
	ctx.check_dep('gio-2.0', 'GIO', MIN_GLIB)
	ctx.check_dep('gthread-2.0', 'GTHREAD', MIN_GLIB)
	ctx.check_dep('gtk+-3.0', 'GTK+', MIN_GTK)
	ctx.check_dep('gdk-3.0', 'GDK', MIN_GTK)
	ctx.check_dep('gdk-x11-3.0', 'GDKX11', MIN_GTK)
	ctx.check_dep('x11', 'XLIB', '0.5')
	ctx.check_dep('dioriteglib-' + DIORITE_SERIES, 'DIORITEGLIB', DIORITE_SERIES + "." + DIORITE_BUGFIX)
	ctx.check_dep('dioritegtk-' + DIORITE_SERIES, 'DIORITEGTK', DIORITE_SERIES + "." + DIORITE_BUGFIX)
	ctx.check_dep('json-glib-1.0', 'JSON-GLIB', '0.7')
	ctx.check_dep('libarchive', 'LIBARCHIVE', '3.1')
	ctx.check_dep('libnotify', 'NOTIFY', '0.7')
	ctx.check_dep('libsecret-1', 'SECRET', '0.16')
	ctx.check_dep("gstreamer-1.0", 'GST', "1.0")
	ctx.check_dep('webkit2gtk-4.0', 'WEBKIT', MIN_WEBKIT)
	ctx.check_dep('webkit2gtk-web-extension-4.0', 'WEBKITEXT', MIN_WEBKIT)
	ctx.check_dep('javascriptcoregtk-4.0', 'JSCORE', MIN_WEBKIT)
	
	ctx.check_dep('uuid', 'UUID', '0') # Engine.io
	ctx.check_dep('libsoup-2.4', 'SOUP', '0') # Engine.io
		
	
	ctx.env.with_unity = ctx.options.unity
	if ctx.options.unity:
		ctx.check_dep('unity', 'UNITY', '3.0')
		ctx.check_dep('dbusmenu-glib-0.4', 'DBUSMENU', '0.4')
		ctx.vala_def("UNITY")
	
	ctx.vala_def("EXPERIMENTAL")
		
	# Define HAVE_WEBKIT_X_YY Vala compiler definitions
	webkit_version = tuple(int(i) for i in ctx.check_cfg(modversion='webkit2gtk-4.0').split(".")[0:2])
	version = (2, 6)
	while version <= webkit_version:
		ctx.vala_def("HAVE_WEBKIT_%d_%d" % version)
		version = (version[0], version[1] + 2)
		
	ctx.define("NUVOLA_APPNAME", APPNAME)
	ctx.define("NUVOLA_FUTURE_APPNAME", FUTURE_APPNAME)
	ctx.define("NUVOLA_NAME", ctx.env.NAME)
	ctx.define("NUVOLA_WELCOME_SCREEN_NAME", WELCOME_SCREEN_NAME)
	ctx.define("NUVOLA_UNIQUE_NAME", ctx.env.UNIQUE_NAME)
	ctx.define("NUVOLA_APP_ICON", ctx.env.ICON_NAME)
	ctx.define("NUVOLA_VERSION", VERSION)
	ctx.define("NUVOLA_REVISION", REVISION_ID)
	ctx.define("NUVOLA_VERSION_MAJOR", VERSIONS[0])
	ctx.define("NUVOLA_VERSION_MINOR", VERSIONS[1])
	ctx.define("NUVOLA_VERSION_BUGFIX", VERSIONS[2])
	ctx.define("NUVOLA_VERSION_SUFFIX", VERSION_SUFFIX)
	ctx.define("GETTEXT_PACKAGE", FUTURE_APPNAME)
	ctx.env.NUVOLA_LIBDIR = "%s/%s" % (ctx.env.LIBDIR, APPNAME)
	ctx.define("NUVOLA_TILIADO_OAUTH2_SERVER", ctx.options.tiliado_oauth2_server)
	ctx.define("NUVOLA_TILIADO_OAUTH2_CLIENT_ID", ctx.options.tiliado_oauth2_client_id)
	repo_index = ctx.options.repository_index.split("|")
	repo_index, repo_root = repo_index if len(repo_index) > 1 else  repo_index + repo_index 
	ctx.define("NUVOLA_REPOSITORY_INDEX", repo_index)
	ctx.define("NUVOLA_REPOSITORY_ROOT", repo_root)
	ctx.define("NUVOLA_LIBDIR", ctx.env.NUVOLA_LIBDIR)
	
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
	#~ print ctx.env
	PLATFORM = ctx.env.PLATFORM
	vala_defines = ctx.env.VALA_DEFINES
	
	if PLATFORM == WIN:
		CFLAGS="-mms-bitfields"
		
	else:
		CFLAGS=""
	
	APP_RUNNER = "apprunner"
	CONTROL = APPNAME + "ctl"
	ENGINEIO = "engineio"
	NUVOLAKIT_RUNNER = APPNAME + "-runner"
	NUVOLAKIT_BASE = APPNAME + "-base"
	NUVOLAKIT_WORKER = APPNAME + "-worker"
	DIORITE_GLIB = 'dioriteglib-' + ctx.env.DIORITE_SERIES
	DIORITE_GTK = 'dioriteglib-' + ctx.env.DIORITE_SERIES
	
	packages = 'dioritegtk-{0} dioriteglib-{0} '.format(ctx.env.DIORITE_SERIES)
	packages += 'javascriptcoregtk-4.0 libnotify libarchive gtk+-3.0 gdk-3.0 gdk-x11-3.0 x11 posix json-glib-1.0 glib-2.0 gio-2.0'
	uselib = 'NOTIFY JSCORE LIBARCHIVE DIORITEGTK DIORITEGLIB GTK+ GDK GDKX11 XLIB JSON-GLIB GLIB GTHREAD GIO'
	
	vapi_dirs = ['vapi', 'engineio-soup/vapi']
	env_vapi_dir = os.environ.get("VAPIDIR")
	if env_vapi_dir:
		vapi_dirs.extend(os.path.relpath(path) for path in env_vapi_dir.split(":"))
	if ctx.env.SNAPCRAFT:
		vapi_dirs.append(os.path.relpath(ctx.env.SNAPCRAFT + "/usr/share/vala/vapi"))
	
	if ctx.env.with_unity:
		packages += " unity Dbusmenu-0.4"
		uselib += " UNITY DBUSMENU"
	
	
	ctx(features = "c cshlib",
		target = ENGINEIO,
		source = ctx.path.ant_glob('engineio-soup/src/*.vala'),
		packages = 'uuid libsoup-2.4 json-glib-1.0', 
		uselib = 'UUID SOUP JSON-GLIB',
		defines = ['G_LOG_DOMAIN="Engineio"'],
		vapi_dirs = vapi_dirs,
		vala_target_glib = TARGET_GLIB,
	)
	
	ctx(features = "c cshlib",
		target = NUVOLAKIT_BASE,
		source = ctx.path.ant_glob('src/nuvolakit-base/*.vala'),
		packages = packages + ' gstreamer-1.0',
		uselib = uselib + " GST",
		vala_defines = vala_defines,
		defines = ['G_LOG_DOMAIN="Nuvola"'],
		vapi_dirs = vapi_dirs,
		vala_target_glib = TARGET_GLIB,
	)
	
	ctx(features = "c cshlib",
		target = NUVOLAKIT_RUNNER,
		source = (
			ctx.path.ant_glob('src/nuvolakit-runner/*.vala')
			+ ctx.path.ant_glob('src/nuvolakit-runner/*/*.vala')
			+ ctx.path.ant_glob('src/nuvolakit-runner/*/*/*.vala')
			+ ctx.path.ant_glob('src/nuvolakit-runner/*.vapi')),
		packages = 'webkit2gtk-4.0 javascriptcoregtk-4.0 gstreamer-1.0 libsecret-1',
		uselib =  'JSCORE WEBKIT GST SECRET',
		use = [NUVOLAKIT_BASE, ENGINEIO],
		lib = ['m'],
		vala_defines = vala_defines,
		defines = ['G_LOG_DOMAIN="Nuvola"'],
		vapi_dirs = vapi_dirs,
		vala_target_glib = TARGET_GLIB,
	)
	
	ctx.program(
		target = APPNAME,
		source = ctx.path.ant_glob('src/master/*.vala'),
		packages = "",
		uselib = "",
		use = [NUVOLAKIT_BASE, NUVOLAKIT_RUNNER],
		vala_defines = vala_defines,
		defines = ['G_LOG_DOMAIN="Nuvola"'],
		vapi_dirs = vapi_dirs,
		vala_target_glib = TARGET_GLIB,
	)
	
	ctx.program(
		target = APP_RUNNER,
		source = ctx.path.ant_glob('src/apprunner/*.vala'),
		packages = "",
		uselib = "",
		use = [NUVOLAKIT_BASE, NUVOLAKIT_RUNNER],
		vala_defines = vala_defines,
		defines = ['G_LOG_DOMAIN="Nuvola"'],
		vapi_dirs = vapi_dirs,
		vala_target_glib = TARGET_GLIB,
		install_path = ctx.env.NUVOLA_LIBDIR,
	)
	
	ctx.program(
		target = CONTROL,
		source = ctx.path.ant_glob('src/control/*.vala'),
		packages = "",
		uselib = "",
		use = [NUVOLAKIT_BASE, NUVOLAKIT_RUNNER],
		vala_defines = vala_defines,
		defines = ['G_LOG_DOMAIN="Nuvola"'],
		vapi_dirs = vapi_dirs,
		vala_target_glib = TARGET_GLIB,
	)
	
	ctx(features = "c cshlib",
		target = NUVOLAKIT_WORKER,
		source = ctx.path.ant_glob('src/nuvolakit-worker/*.vala'),
		packages = "dioriteglib-{0} {1} {2}".format(ctx.env.DIORITE_SERIES, 'webkit2gtk-web-extension-4.0', 'javascriptcoregtk-4.0'),
		uselib = "DIORITEGLIB DIORITEGTK WEBKITEXT JSCORE",
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
	ctx(features = 'subst',
		source = 'data/templates/dbus.service',
		target = "share/dbus-1/services/%s.service" % ctx.env.UNIQUE_NAME,
		install_path = '${PREFIX}/share/dbus-1/services',
		NAME = ctx.env.UNIQUE_NAME,
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
	
	ctx.symlink_as('${PREFIX}/bin/%s' % FUTURE_APPNAME, APPNAME)
	ctx.symlink_as('${PREFIX}/bin/%sctl' % FUTURE_APPNAME, CONTROL)
	ctx.install_as('${PREFIX}/share/appdata/%s.appdata.xml' % ctx.env.UNIQUE_NAME, ctx.path.find_node("data/nuvolaplayer3.appdata.xml"))
	ctx.install_as('${PREFIX}/share/metainfo/%s.appdata.xml' % ctx.env.UNIQUE_NAME, ctx.path.find_node("data/nuvolaplayer3.appdata.xml"))
	
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
	for node in ctx.path.ant_glob("data/js/*.js"):
		ctx(
			rule = 'cp -v ${SRC} ${TGT}',
			source = "data/js/%s" % node,
			target = 'share/%s/js/%s' % (APPNAME, node),
			install_path = '${PREFIX}/share/%s/js' % APPNAME
		)
	ctx(features = "subst",
		source = ctx.path.find_node("data/audio/audiotest.mp3"),
		target = 'share/%s/audio/audiotest.mp3' % APPNAME,
		install_path = '${PREFIX}/share/%s/audio' % APPNAME
	)
	
	ctx.add_post_fun(post)

def post(ctx):
	if ctx.cmd in ('install', 'uninstall'):
		if ctx.env.PLATFORM == LINUX and ctx.options.system_hooks:
			icon_dir = "%s/icons/hicolor" % ctx.env.DATADIR
			sys_hooks = (
				['/sbin/ldconfig'],
				['gtk-update-icon-cache', icon_dir],
				['gtk-update-icon-cache-3.0', icon_dir]
			)
			
			sys.stderr.write('Running system hooks (use --no-system-hooks to disable)\n')
			for cmd in sys_hooks:
				sys.stderr.write("System hook: %s\n" % " ".join(cmd))
				ctx.exec_command(cmd)

def dist(ctx):
	ctx.algo = "tar.gz"
	ctx.excl = '.git .gitignore build/* **/.waf* **/*~ **/*.swp **/.lock* bzrcommit.txt **/*.pyc core'
	ctx.exec_command("git describe --tags --long > version-info.txt")
	
	def archive():
		ctx._archive()
		node = ctx.path.find_node("version-info.txt")
		if node:
			node.delete()
	ctx._archive = ctx.archive
	ctx.archive = archive

from waflib.TaskGen import extension
@extension('.vapi')
def vapi_file(self, node):
	try:
		valatask = self.valatask
	except AttributeError:
		valatask = self.valatask = self.create_task('valac')
		self.init_vala_task()

	valatask.inputs.append(node)

from waflib import TaskGen, Utils, Errors, Node, Task
from nuvolamergejs import mergejs as merge_js

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

def mask(string):
    shift = int(1.0 * os.urandom(1)[0] / 255 * 85 + 15)
    return [shift] + [c + shift for c in string.encode("utf-8")]
