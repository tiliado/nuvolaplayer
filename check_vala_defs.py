#!/usr/bin/python3
# coding: utf-8
#
# Copyright 2017 Jiří Janoušek <janousek.jiri@gmail.com>
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

__doc__ = "Checks whether only allowed Vala definition are used in source *.vala files."

import os
import re
import sys
from os.path import join as joinpath
from argparse import ArgumentParser, FileType
from collections import namedtuple


_NOT_IDENTIFIER_CHARS_RE = re.compile(r'[^a-zA-Z-0-9_ ]')
Error = namedtuple("Error", "path line code flag")


def check_definitions_in_files(definitions, buffers):
	errors = []
	for buffer in buffers:
		check_definitions_in_file(definitions, buffer, errors)
	return errors


def check_definitions_in_file(definitions, buffer, errors):
	for line, code in enumerate(buffer):
		code = code.strip()
		try:
			if code.startswith("#if"):
				check_expression(code[3:], definitions)
			elif code.startswith("#elif"):
				check_expression(codee[5:], definitions)
		except ValueError as e:
			errors.append(Error(buffer.name, line, code, e.args[0]))


def check_expression(expr, definitions):
	flags = _NOT_IDENTIFIER_CHARS_RE.sub(' ', expr).split()
	for flag in flags:
		if flag and flag not in definitions:
			raise ValueError(flag)


def print_errors(errors, *, output=sys.stderr, count=True):
	if count:
		print("%s Errors:" % len(errors), file=output)
	for error in errors:
		print("Error {path}:{line}\n=> `{code}` => {flag} not allowed".format(**error._asdict()), file=output)


def scan_dirs_for_vala_source(buffers, directories):
	buffers.extend(
		open(joinpath(root, path), "rt", encoding="utf-8") 
		for directory in directories
		for root, dirs, files in os.walk(directory)
		for path in files if path.endswith(".vala"))


def main(argv):
	parser = ArgumentParser(
		argv[0],
		description=__doc__,
		epilog="Returns 0 on success, 1 when there are errors, 2 on unexpected failure.")
	parser.add_argument("-D", "--define", action='append', default=[], help="Add allowed Vala definition")
	parser.add_argument("-d", "--directory", action='append', default=[], help="Add source directory")
	parser.add_argument("files", type=FileType('rt', encoding="utf-8"), default=[], nargs='*', help="Source files *.vala")
	args = parser.parse_args(argv[1:])
	
	definitions = set(args.define)
	buffers = args.files
	scan_dirs_for_vala_source(buffers, args.directory)
	errors = check_definitions_in_files(definitions, buffers)
	if not errors:
		return 0
	else:
		print_errors(errors)
		return 1


if __name__ == "__main__":
	try:
		code = main(sys.argv)
	except Exception as e:
		import traceback
		print("Unexpected failure:", file=sys.stderr)
		traceback.print_exc()
		code = 2
	sys.exit(code)
