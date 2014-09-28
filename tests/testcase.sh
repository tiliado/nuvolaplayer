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
	echo "Usage: $0 list"
	echo "Usage: $0 run|debug [path]"
	exit 1
fi

set -eu
NAME="testcase"
CMD="$1"
shift
OUT=${OUT:-`dirname $PWD`/build/tests}
BUILD=${BUILD:-`dirname $PWD`/build}
RUN="$OUT/run"
EXECSUFFIX=""
LAUNCHER=""
DEBUGGER="gdb --args"
export LD_LIBRARY_PATH="$RUN:$OUT:$BUILD:${LD_LIBRARY_PATH:-.}"

list()
{
	if [ -e ${RUN}/${NAME}${EXECSUFFIX} ]; then
		${LAUNCHER} ${RUN}/${NAME}${EXECSUFFIX} -l
	else
		echo "Run \`make all\` to build test cases."
		exit 1
	fi
}

run()
{
	make all
	if [ $# = 0 ]; then
		all_ok=1
		for path in $(${LAUNCHER} ${RUN}/${NAME}${EXECSUFFIX} -l); do
			echo
			echo \$ $0 run $path
			set -x
			${LAUNCHER} ${RUN}/${NAME}${EXECSUFFIX} --verbose -p $path || all_ok=0
			{ set +x; } 2> /dev/null
		done
		if [ $all_ok = 0 ]; then
			echo "Test case failure!"
			exit 1
		fi
	else
		for path in "$@"; do
			set -x
			${LAUNCHER} ${RUN}/${NAME}${EXECSUFFIX} --verbose -p $path
			{ set +x; } 2> /dev/null
		done
	fi
}

debug()
{
	if [ $# = 0 ]; then
		all_ok=1
		for path in $(${LAUNCHER} ${RUN}/${NAME}${EXECSUFFIX} -l); do
			set -x
			$DEBUGGER ${RUN}/${NAME}${EXECSUFFIX} --verbose -p $path || all_ok=0
			{ set +x; } 2> /dev/null
		done
		if [ $all_ok = 0 ]; then
			echo "Test case failure!"
			exit 1
		fi
	else
		for path in "$@"; do
			set -x
			$DEBUGGER ${RUN}/${NAME}${EXECSUFFIX} --verbose -p $path
			{ set +x; } 2> /dev/null
		done
	fi
}

$CMD "$@"
