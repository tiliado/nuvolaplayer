#!/bin/bash

# Author: Jiří Janoušek <janousek.jiri@gmail.com>
#
# To the extent possible under law, author has waived all
# copyright and related or neighboring rights to this file.
# http://creativecommons.org/publicdomain/zero/1.0/
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHORS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

OUT=${OUT:-./build}
BUILD=${BUILD:-../build}
# On Fedora 20
MINGW_BIN=${MINGW_BIN:-/usr/i686-w64-mingw32/sys-root/mingw/bin}
MINGW_LIB=${MINGW_LIB:-/usr/i686-w64-mingw32/sys-root/mingw/lib}
case $PLATFORM in
mingw*)
	PLATFORM="WIN"
	LIBPREFIX="lib"
	LIBSUFFIX=".dll"
	EXECSUFFIX=".exe"
	LAUNCHER="wine"
	DEBUGGER="winedbg --gdb"
	TESTER="${LAUNCHER} ${OUT}/dioritetester.exe"
	TESTGEN="${LAUNCHER} ${OUT}/dioritetestgen.exe"
	CFLAGS="${CFLAGS:-} -g -gdwarf-2"
	LIB_CFLAGS="-shared"
;;
lin*)
	CC=${CC:-gcc}
	PLATFORM="LINUX"
	LIBPREFIX="lib"
	LIBSUFFIX=".so"
	EXECSUFFIX=""
	LAUNCHER=""
	DEBUGGER="gdb --args"
	TESTER="dioritetester"
	TESTGEN="dioritetestgen"
	CFLAGS="${CFLAGS:-} -g -g3"
	LIB_CFLAGS="-fPIC -shared"
	export LD_LIBRARY_PATH="$BUILD"
;;
*)
	echo "Unsupported platform: $PLATFORM"
	exit 1
esac

clean()
{
	echo "*** $0 clean ***"
	rm -rf $OUT
}

dist()
{
	echo "*** $0 dist ***"
	mkdir -p ${OUT}
	if [ "$PLATFORM" == "WIN" ]; then
		for file in  \
		libglib-2.0-0.dll libgobject-2.0-0.dll libgthread-2.0-0.dll \
		libgcc_s_sjlj-1.dll libintl-8.dll libffi-6.dll iconv.dll \
		libgio-2.0-0.dll libgmodule-2.0-0.dll zlib1.dll libvala-0.16-0.dll \
		libgtk-3-0.dll libgdk-3-0.dll libatk-1.0-0.dll libcairo-gobject-2.dll \
		libcairo-2.dll libgdk_pixbuf-2.0-0.dll libpango-1.0-0.dll libpangocairo-1.0-0.dll \
		libpixman-1-0.dll libpng16-16.dll libpangowin32-1.0-0.dll \
		gspawn-win32-helper.exe gspawn-win32-helper-console.exe
		do
			cp -spuvf ${MINGW_BIN}/$file ${OUT}
		done
		
		for file in \
		dioriteglib-0.dll dioritegtk-0.dll dioriteinterrupthelper.exe dioritetestgen.exe dioritetester.exe
		do
			cp -lpuvf ${BUILD}/$file ${OUT}
		done
	fi
}
