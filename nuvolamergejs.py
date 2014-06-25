#!/usr/bin/python
# coding: utf-8

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

import os

class Source:
	def __init__(self, name, path, requires, data):
		self.path = path
		self.name = name
		self.requires = requires
		self.data = data
		self.merged = False
		self.visited = 0

def parse_sources(files):
	sources = {}
	for path in files:
		name = os.path.basename(path).rsplit(".", 1)[0]
		requires = []
		data = []
		head = True
		
		with open(path) as f:
			for line in f:
				if head:
					bare_line = line.strip()
					if bare_line and not bare_line.startswith(("/*", "*")):
						if bare_line.startswith("require("):
							for q in ('"', "'"):
								parts = bare_line.split(q)
								if len(parts) == 3:
									requires.append(parts[1])
									break
							else:
								print("Invalid line: %s" % bare_line)
						else:
							head = False
							data.append(line)
				else:
					data.append(line)
		sources[name] = Source(name, path, requires, data)
	
	return sources

def add_source(output, sources, source):
	source.visited += 1
	if source.visited > 25:
		raise Exception("Maximal recursion depth reached at '%s'" %source.path)
	
	if not source.merged:
		for dep in source.requires:
			add_source(output, sources, sources[dep])
	
	if not source.merged:
		output.append("// Included file '%s'\n\n" % source.path)
		output.extend(source.data)
		output.append("\n")
		source.merged = True

def merge_sources(sources):
	output = ["(function(Nuvola)\n{\n\n"]
	
	for source in sources.values():
		add_source(output, sources, source)
	
	output.append("\n\n})(this);  // function(Nuvola)\n")
	return "".join(output)

def mergejs(sources):
	sources = parse_sources(sources)
	output = merge_sources(sources)
	return output

if __name__ == "__main__":
	import sys
	files = sys.argv[1:]
	output = mergejs(files)
	print(output)
