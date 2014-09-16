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

if [ "$#" -lt 1 ]; then
	echo "Usage: $0 build|clean"
	echo "Usage: $0 run|debug [path]"
	exit 1
fi

set -eu

NAME="testcase"
CMD="$1"
shift
OUT=${OUT:-`dirname $PWD`/build/testcase}
BUILD=${BUILD:-`dirname $PWD`/build}
CC=${CC:-gcc}
LIBPREFIX="lib"
LIBSUFFIX=".so"
EXECSUFFIX=""
LAUNCHER=""
DEBUGGER="gdb --args"
TESTGEN="diorite-testgen"
CFLAGS="${CFLAGS:-} -g -g3"
LIB_CFLAGS="-fPIC -shared"
export LD_LIBRARY_PATH="$OUT:$BUILD:${LD_LIBRARY_PATH:-.}"

clean()
{
	set -x
	rm -rf $OUT
	{ set +x; } 2> /dev/null
}

build()
{
	set -x
	test -d ${OUT} || mkdir -p ${OUT}
	
	valac -d ${OUT} -b . --thread --save-temps -v \
	--library=${NAME} -H ${OUT}/${NAME}.h -o ${LIBPREFIX}${NAME}${LIBSUFFIX} \
	-X -fPIC -X -shared \
	--vapidir $BUILD -X -I$BUILD -X -L$BUILD \
	--vapidir $OUT -X -I$OUT -X -L$OUT -X -lnuvolaplayer3-runner \
	--vapidir $BUILD -X -I$BUILD -X -L$BUILD \
	--vapidir ../vapi --pkg glib-2.0 --target-glib=2.32 \
	--pkg=dioriteglib-0.1 --pkg nuvolaplayer3-runner \
	-X '-DG_LOG_DOMAIN="NuvolaTest"' -X -g -X -O2 \
	*.vala
	
	$TESTGEN -o "${OUT}/run-${NAME}.vala" *.vala
	
	valac -d ${OUT} -b . --thread --save-temps -v \
	--vapidir $BUILD -X -I$BUILD -X -L$BUILD \
	--vapidir $OUT -X -I$OUT -X -L$OUT -X -lnuvolaplayer3-runner -X -l${NAME} \
	--vapidir ../vapi --pkg glib-2.0 --target-glib=2.32 \
	--pkg=dioriteglib-0.1 --pkg ${NAME} \
	-X '-DG_LOG_DOMAIN="NuvolaTest"' -X -g -X -O2 \
	"${OUT}/run-${NAME}.vala"
	
	{ set +x; } 2> /dev/null
}

list()
{
	${LAUNCHER} ${OUT}/run-${NAME}${EXECSUFFIX} -l
}

build_run()
{
	build
	run "$@"
}

run()
{
	if [ $# = 0 ]; then
		all_ok=1
		for path in $(${LAUNCHER} ${OUT}/run-${NAME}${EXECSUFFIX} -l); do
			set -x
			${LAUNCHER} ${OUT}/run-${NAME}${EXECSUFFIX} --verbose -p $path || all_ok=0
			{ set +x; } 2> /dev/null
		done
		if [ $all_ok = 0 ]; then
			echo "Test case failure!"
			exit 1
		fi
	else
		for path in "$@"; do
			set -x
			${LAUNCHER} ${OUT}/run-${NAME}${EXECSUFFIX} --verbose -p $path
			{ set +x; } 2> /dev/null
		done
	fi
}

debug()
{
	if [ $# = 0 ]; then
		all_ok=1
		for path in $(${LAUNCHER} ${OUT}/run-${NAME}${EXECSUFFIX} -l); do
			set -x
			$DEBUGGER ${OUT}/run-${NAME}${EXECSUFFIX} --verbose -p $path || all_ok=0
			{ set +x; } 2> /dev/null
		done
		if [ $all_ok = 0 ]; then
			echo "Test case failure!"
			exit 1
		fi
	else
		for path in "$@"; do
			set -x
			$DEBUGGER ${OUT}/run-${NAME}${EXECSUFFIX} --verbose -p $path
			{ set +x; } 2> /dev/null
		done
	fi
}

$CMD "$@"
