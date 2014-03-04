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
NAME="Nuvola Player"
APPNAME = "nuvolaplayer"
VERSION = "3.0.0~unstable"
SUFFIX="3"

UNIQUE_NAME="cz.fenryxo.NuvolaPlayer" + SUFFIX

VERSIONS, VERSION_SUFFIX = VERSION.split("~")
if not VERSION_SUFFIX:
	VERSION_SUFFIX = "stable"
VERSIONS = map(int, VERSIONS.split("."))


import sys
from waflib.Configure import conf
from waflib.Errors import ConfigurationError
from waflib.Context import WAFVERSION

WAF_VERSION = map(int, WAFVERSION.split("."))
REQUIRED_VERSION = [1, 7, 14] 
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
	except ConfigurationError, e:
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
	ctx.add_option('--noopt', action='store_true', default=False, dest='noopt', help="Turn off compiler optimizations")
	ctx.add_option('--debug', action='store_true', default=True, dest='debug', help="Turn on debugging symbols")
	ctx.add_option('--no-debug', action='store_false', dest='debug', help="Turn off debugging symbols")
	ctx.add_option('--no-ldconfig', action='store_false', default=True, dest='ldconfig', help="Don't run ldconfig after installation")
	ctx.add_option('--platform', default=_PLATFORM, help="Target platform")

# Configure build process
def configure(ctx):
	
	ctx.env.PLATFORM = PLATFORM = ctx.options.platform.upper()
	if PLATFORM not in (LINUX,):
		print("Unsupported platform %s. Please try to talk to devs to consider support of your platform." % sys.platform)
		sys.exit(1)
	
	ctx.define(PLATFORM, 1)
	ctx.env.VALA_DEFINES = [PLATFORM]
	ctx.msg('Target platform', PLATFORM, "GREEN")
	ctx.msg('Install prefix', ctx.options.prefix, "GREEN")
	
	ctx.load('compiler_c vala')
	ctx.check_vala(min_version=(0,16,1))
	
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
	
	# Anti-underlinking and anti-overlinking linker flags.
	ctx.env.append_unique("LINKFLAGS", ["-Wl,--no-undefined", "-Wl,--as-needed"])
	
	# Check dependencies
	ctx.check_dep('glib-2.0', 'GLIB', '2.32')
	ctx.check_dep('gio-2.0', 'GIO', '2.32')
	ctx.check_dep('gtk+-3.0', 'GTK+', '3.4')
	ctx.check_dep('gdk-3.0', 'GDK', '3.4')
	ctx.check_dep('gthread-2.0', 'GTHREAD', '2.32')
	ctx.check_dep('dioriteglib', 'DIORITEGLIB', '0.0.1')
	ctx.check_dep('dioritegtk', 'DIORITEGGTK', '0.0.1')
	ctx.check_dep('json-glib-1.0', 'JSON-GLIB', '0.7')
	ctx.check_dep('libarchive', 'LIBARCHIVE', '3.1')
	ctx.check_dep('webkit2gtk-3.0', 'WEBKIT', '2.2')
	ctx.check_dep('javascriptcoregtk-3.0', 'JSCORE', '1.8')
	
	ctx.define("NUVOLA_APPNAME", APPNAME + SUFFIX)
	ctx.define("NUVOLA_NAME", NAME)
	ctx.define("NUVOLA_UNIQUE_NAME", UNIQUE_NAME)
	ctx.define("NUVOLA_APP_ICON", APPNAME)
	ctx.define("NUVOLA_VERSION", VERSION)
	ctx.define("NUVOLA_VERSION_MAJOR", VERSIONS[0])
	ctx.define("NUVOLA_VERSION_MINOR", VERSIONS[1])
	ctx.define("NUVOLA_VERSION_BUGFIX", VERSIONS[2])
	ctx.define("NUVOLA_VERSION_SUFFIX", VERSION_SUFFIX)
	ctx.define("GETTEXT_PACKAGE", "nuvolaplayer3")

def build(ctx):
	#~ print ctx.env
	PLATFORM = ctx.env.PLATFORM
	packages = 'javascriptcoregtk-3.0 webkit2gtk-3.0 libarchive dioritegtk dioriteglib gtk+-3.0 gdk-3.0 posix json-glib-1.0 glib-2.0 gio-2.0 '
	uselib = 'JSCORE WEBKIT LIBARCHIVE DIORITEGGTK DIORITEGLIB GTK+ GDK JSON-GLIB GLIB GTHREAD GIO'
	vala_defines = ctx.env.VALA_DEFINES
	
	if PLATFORM == WIN:
		CFLAGS="-mms-bitfields"
		
	else:
		CFLAGS=""
	
	NUVOLAPLAYER = APPNAME + SUFFIX
	LIBNUVOLAPLAYER = "lib" + APPNAME + SUFFIX
	UIDEMO="uidemo"
	
	ctx(features = "c cshlib",
		target = NUVOLAPLAYER,
		name = LIBNUVOLAPLAYER,
		source = ctx.path.ant_glob('src/libnuvolaplayer/*.vala') + ctx.path.ant_glob('src/libnuvolaplayer/*.c'),
		packages = packages,
		uselib = uselib,
		includes = ["src/libnuvolaplayer"],
		vala_defines = vala_defines,
		cflags = ['-DG_LOG_DOMAIN="LibNuvola"'],
		vapi_dirs = ['vapi'],
		vala_target_glib = "2.32",
	)
	
	ctx.program(
		target = NUVOLAPLAYER,
		source = ctx.path.ant_glob('src/nuvolaplayer/*.vala') + ctx.path.ant_glob('src/nuvolaplayer/*.c'),
		packages = packages,
		uselib = uselib,
		includes = ["src/lnuvolaplayer"],
		use = [LIBNUVOLAPLAYER],
		vala_defines = vala_defines,
		cflags = ['-DG_LOG_DOMAIN="Nuvola"'],
		vapi_dirs = ['vapi'],
		vala_target_glib = "2.32",
	)
	
	ctx.program(
		target = UIDEMO,
		source = ctx.path.ant_glob('tests/ui/*.vala'),
		packages = packages,
		uselib = uselib,
		use = [LIBNUVOLAPLAYER],
		vala_defines = vala_defines,
		cflags = ['-DG_LOG_DOMAIN="Nuvola"'],
		vapi_dirs = ['vapi'],
		vala_target_glib = "2.32",
	)
	
	ctx.add_post_fun(post)

def post(ctx):
	if ctx.cmd in ('install', 'uninstall'):
		if ctx.env.PLATFORM == LINUX and ctx.options.ldconfig:
			ctx.exec_command('/sbin/ldconfig') 
