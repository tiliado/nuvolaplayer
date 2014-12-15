#!/usr/bin/env python
# encoding: utf-8
#
# Copyright 2014 Jiří Janoušek <janousek.jiri@gmail.com>
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
NAME="Nuvola Player 3 Alpha"
APPNAME = "nuvolaplayer3"
VERSION = "3.0.0+"
UNIQUE_NAME="cz.fenryxo.NuvolaPlayer3"
GENERIC_NAME = "Cloud Player"
BLURB = "Cloud music integration for your Linux desktop"

import subprocess
try:
	try:
		# Read revision info from file revision-info created by ./waf dist
		short_id, long_id = open("revision-info", "r").read().split(" ", 1)
	except Exception as e:
		# Read revision info from current branch
		output = subprocess.Popen(["git", "log", "-n", "1", "--pretty=format:%h %H"], stdout=subprocess.PIPE).communicate()[0]
		short_id, long_id = output.split(" ", 1)
except Exception as e:
	short_id, long_id = "fuzzy_id", "fuzzy_id"

REVISION_ID = str(long_id).strip()


VERSIONS, VERSION_SUFFIX = VERSION.split("+")
if VERSION_SUFFIX == "stable":
	VERSION = VERSIONS
elif VERSION_SUFFIX == "":
	from datetime import datetime
	suffix = "{}.{}".format(datetime.utcnow().strftime("%Y%m%d%H%M"), short_id)
	VERSION_SUFFIX += suffix
	VERSION += suffix
VERSIONS = tuple(int(i) for i in VERSIONS.split("."))

import sys
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
	ctx.add_option('--with-appindicator', action='store_true', default=False, dest='appindicator', help="Build functionality dependent on libappindicator")
	ctx.add_option('--noopt', action='store_true', default=False, dest='noopt', help="Turn off compiler optimizations")
	ctx.add_option('--debug', action='store_true', default=True, dest='debug', help="Turn on debugging symbols")
	ctx.add_option('--no-debug', action='store_false', dest='debug', help="Turn off debugging symbols")
	ctx.add_option('--no-system-hooks', action='store_false', default=True, dest='system_hooks', help="Don't run system hooks after installation (ldconfig, icon cache update, ...")
	ctx.add_option('--platform', default=_PLATFORM, help="Target platform")

# Configure build process
def configure(ctx):
	ctx.env.PLATFORM = PLATFORM = ctx.options.platform.upper()
	if PLATFORM not in (LINUX,):
		print("Unsupported platform %s. Please try to talk to devs to consider support of your platform." % sys.platform)
		sys.exit(1)
	
	
	ctx.msg("Revision id", REVISION_ID, "GREEN")
	
	ctx.define(PLATFORM, 1)
	ctx.env.VALA_DEFINES = [PLATFORM]
	ctx.msg('Target platform', PLATFORM, "GREEN")
	ctx.msg('Install prefix', ctx.options.prefix, "GREEN")
	
	ctx.load('compiler_c vala')
	ctx.check_vala(min_version=(0,22,1))
	# Don't be quiet
	ctx.env.VALAFLAGS.remove("--quiet")
	ctx.env.append_value("VALAFLAGS", "-v")
	
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
	
	# Check dependencies
	ctx.env.DIORITE_SERIES = DIORITE_SERIES = "0.1"
	ctx.check_dep('glib-2.0', 'GLIB', '2.38')
	ctx.check_dep('gio-2.0', 'GIO', '2.38')
	ctx.check_dep('gthread-2.0', 'GTHREAD', '2.38')
	ctx.check_dep('gtk+-3.0', 'GTK+', '3.10')
	ctx.check_dep('gdk-3.0', 'GDK', '3.10')
	ctx.check_dep('gdk-x11-3.0', 'GDKX11', '3.10')
	ctx.check_dep('x11', 'XLIB', '0.5')
	ctx.check_dep('dioriteglib-' + DIORITE_SERIES, 'DIORITEGLIB', DIORITE_SERIES)
	ctx.check_dep('dioritegtk-' + DIORITE_SERIES, 'DIORITEGTK', DIORITE_SERIES)
	ctx.check_dep('json-glib-1.0', 'JSON-GLIB', '0.7')
	ctx.check_dep('libarchive', 'LIBARCHIVE', '3.1')
	ctx.check_dep('libnotify', 'NOTIFY', '0.7')
	ctx.check_dep("gstreamer-1.0", 'GST', "1.0")
	
	try:
		ctx.env.WEBKIT = 'webkit2gtk-3.0'
		ctx.env.WEBKITEXT = 'webkit2gtk-web-extension-3.0'
		ctx.env.JSCORE = 'javascriptcoregtk-3.0'
		ctx.check_dep(ctx.env.WEBKIT, 'WEBKIT', '2.2')
		ctx.check_dep(ctx.env.JSCORE, 'JSCORE', '1.8')
		ctx.vala_def("WEBKIT2GTK3")
	except ctx.errors.ConfigurationError:
		ctx.env.WEBKIT = 'webkit2gtk-4.0'
		ctx.env.WEBKITEXT = 'webkit2gtk-web-extension-4.0'
		ctx.env.JSCORE = 'javascriptcoregtk-4.0'
		ctx.check_dep(ctx.env.WEBKIT, 'WEBKIT', '2.6')
		ctx.check_dep(ctx.env.WEBKITEXT, 'WEBKITEXT', '2.6')
		ctx.check_dep(ctx.env.JSCORE, 'JSCORE', '2.6')
		ctx.vala_def("WEBKIT2GTK4")
		sys.stderr.write("\n*** WARNING ***\nBuild with webkit2gtk-4.0 is not functional yet.\nhttps://github.com/tiliado/nuvolaplayer/issues/2\n\n")
	
	ctx.env.with_unity = ctx.options.unity
	if ctx.options.unity:
		ctx.check_dep('unity', 'UNITY', '3.0')
		ctx.check_dep('dbusmenu-glib-0.4', 'DBUSMENU', '0.4')
		ctx.vala_def("UNITY")
	
	ctx.env.with_appindicator = ctx.options.appindicator
	if ctx.options.appindicator:
		ctx.check_dep('appindicator3-0.1', 'APPINDICATOR', '0.4')
		ctx.vala_def("APPINDICATOR")
	
	ctx.define("NUVOLA_APPNAME", APPNAME)
	ctx.define("NUVOLA_NAME", NAME)
	ctx.define("NUVOLA_UNIQUE_NAME", UNIQUE_NAME)
	ctx.define("NUVOLA_APP_ICON", APPNAME)
	ctx.define("NUVOLA_VERSION", VERSION)
	ctx.define("NUVOLA_REVISION", REVISION_ID)
	ctx.define("NUVOLA_VERSION_MAJOR", VERSIONS[0])
	ctx.define("NUVOLA_VERSION_MINOR", VERSIONS[1])
	ctx.define("NUVOLA_VERSION_BUGFIX", VERSIONS[2])
	ctx.define("NUVOLA_VERSION_SUFFIX", VERSION_SUFFIX)
	ctx.define("GETTEXT_PACKAGE", "nuvolaplayer3")
	ctx.env.NUVOLA_LIBDIR = "%s/%s" % (ctx.env.LIBDIR, APPNAME)
	ctx.define("NUVOLA_LIBDIR", ctx.env.NUVOLA_LIBDIR)
	

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
	NUVOLAKIT_RUNNER = APPNAME + "-runner"
	NUVOLAKIT_BASE = APPNAME + "-base"
	NUVOLAKIT_WORKER = APPNAME + "-worker"
	
	packages = 'dioritegtk-{0} dioriteglib-{0} '.format(ctx.env.DIORITE_SERIES)
	packages += ctx.env.JSCORE + ' libnotify libarchive gtk+-3.0 gdk-3.0 gdk-x11-3.0 x11 posix json-glib-1.0 glib-2.0 gio-2.0'
	uselib = 'NOTIFY JSCORE LIBARCHIVE DIORITEGTK DIORITEGLIB GTK+ GDK GDKX11 XLIB JSON-GLIB GLIB GTHREAD GIO'
	
	if ctx.env.with_unity:
		packages += " unity Dbusmenu-0.4"
		uselib += " UNITY DBUSMENU"
	
	if ctx.env.with_appindicator:
		packages += " appindicator3-0.1"
		uselib += " APPINDICATOR"
	
	ctx(features = "c cshlib",
		target = NUVOLAKIT_BASE,
		source = ctx.path.ant_glob('src/nuvolakit-base/*.vala'),
		packages = packages,
		uselib = uselib,
		vala_defines = vala_defines,
		defines = ['G_LOG_DOMAIN="Nuvola"'],
		vapi_dirs = ['vapi'],
		vala_target_glib = "2.32",
	)
	
	ctx(features = "c cshlib",
		target = NUVOLAKIT_RUNNER,
		source = ctx.path.ant_glob('src/nuvolakit-runner/*.vala') + ctx.path.ant_glob('src/nuvolakit-runner/*/*.vala'),
		packages = " ".join((ctx.env.WEBKIT, ctx.env.JSCORE, 'gstreamer-1.0')),
		uselib =  'JSCORE WEBKIT GST',
		use = [NUVOLAKIT_BASE],
		lib = ['m'],
		vala_defines = vala_defines,
		defines = ['G_LOG_DOMAIN="Nuvola"'],
		vapi_dirs = ['vapi'],
		vala_target_glib = "2.32",
	)
	
	ctx.program(
		target = APPNAME,
		source = ctx.path.ant_glob('src/master/*.vala'),
		packages = "",
		uselib = "",
		use = [NUVOLAKIT_BASE, NUVOLAKIT_RUNNER],
		vala_defines = vala_defines,
		defines = ['G_LOG_DOMAIN="Nuvola"'],
		vapi_dirs = ['vapi'],
		vala_target_glib = "2.32",
	)
	
	ctx.program(
		target = APP_RUNNER,
		source = ctx.path.ant_glob('src/apprunner/*.vala'),
		packages = "",
		uselib = "",
		use = [NUVOLAKIT_BASE, NUVOLAKIT_RUNNER],
		vala_defines = vala_defines,
		defines = ['G_LOG_DOMAIN="Nuvola"'],
		vapi_dirs = ['vapi'],
		vala_target_glib = "2.32",
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
		vapi_dirs = ['vapi'],
		vala_target_glib = "2.32",
	)
	
	ctx(features = "c cshlib",
		target = NUVOLAKIT_WORKER,
		source = ctx.path.ant_glob('src/nuvolakit-worker/*.vala'),
		packages = "dioriteglib-{0} {1} {2}".format(ctx.env.DIORITE_SERIES, ctx.env.WEBKITEXT, ctx.env.JSCORE),
		uselib = "DIORITEGLIB DIORITEGTK WEBKIT JSCORE",
		use = [NUVOLAKIT_BASE],
		vala_defines = vala_defines,
		cflags = ['-DG_LOG_DOMAIN="Nuvola"'],
		vapi_dirs = ['vapi'],
		vala_target_glib = "2.32",
		install_path = ctx.env.NUVOLA_LIBDIR,
	)
	
	ctx(features = 'subst',
		source = 'data/templates/launcher.desktop',
		target = "share/applications/%s.desktop" % APPNAME,
		install_path = '${PREFIX}/share/applications',
		BLURB = BLURB,
		APP_NAME = NAME,
		APP_ID = APPNAME,
		GENERIC_NAME=GENERIC_NAME,
	)
	
	web_apps = ctx.path.find_dir("web_apps")
	ctx.install_files('${PREFIX}/share/' + APPNAME, web_apps.ant_glob('**'), cwd=web_apps.parent, relative_trick=True)
	
	
	app_icons = ctx.path.find_node("data/icons")
	for size in (16, 22, 24, 32, 48, 64):
		ctx.install_as('${PREFIX}/share/icons/hicolor/%sx%s/apps/%s.png' % (size, size, APPNAME), app_icons.find_node("%s.png" % size))
	ctx.install_as('${PREFIX}/share/icons/hicolor/scalable/apps/%s.svg' % APPNAME, app_icons.find_node("scalable.svg"))
	
	ctx(features = "mergejs",
		source = ctx.path.ant_glob('src/mainjs/*.js'),
		target = 'share/%s/js/main.js' % APPNAME,
		install_path = '${PREFIX}/share/%s/js' % APPNAME
	)
	ctx(features = "subst",
		source = ctx.path.find_node("data/js/flash_detect.js"),
		target = 'share/%s/js/flash_detect.js' % APPNAME,
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
	ctx.excl = '.git .gitignore build/* **/.waf* **/*~ **/*.swp **/.lock* bzrcommit.txt **/*.pyc'
	ctx.exec_command("git log -n 1 --pretty='format:%h %H' > revision-info")
	
	def archive():
		ctx._archive()
		node = ctx.path.find_node("revision-info")
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
