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
import re
from string import Template
from xml.sax.saxutils import escape
from collections import defaultdict

MODE_CODE = 0
MODE_DOC = 1
MODE_SYMBOL = 2

FUNCTION_RE = re.compile(r"^\s*var\s+(\$?\w+(?:\.\$?\w+)*)\s+=\s+function\s*\((.*)\)$")
METHOD_RE = re.compile(r"^\s*(\$?\w+(?:\.\$?\w+)*)\s+=\s+function\s*\((.*)\)$")
PROTOTYPE_RE = re.compile(r"^\s*var\s+(\$?\w+(?:\.\$?\w+)*)\s+=\s+(?:Nuvola\.)?\$prototype\s*\((.*)\);$")
OBJECT_RE = re.compile(r"^\s*var\s+(\$?\w+(?:\.\$?\w+)*)\s+=\s+\{\s*(?:\};)?$")
SIGNAL_RE = re.compile(r"^this\.addSignal\s*\((.*)\);$")
PROPERTY_RE = re.compile(r'^["\']?(\w+)["\']?\s*:\s*(.+)$')
FIELD_RE = re.compile(r"^\s*(\$?\w+(?:\.\$?\w+)*)\s+=\s+(.*)\s*;$")
ALIAS_RE = re.compile(r"^(\$?\w+(?:\.\$?\w+)*)\s+=\s+(\$?\w+(?:\.\$?\w+)*)\s*;$")
LINK_RE = re.compile(r'@link\{(.+?)\}')

def gather_sources(sources_dir):
	for root, dirs, files in os.walk(sources_dir):
		for f in files:
			if f.endswith(".js"):
				yield os.path.join(root, f)

def rdotsplit(s):
	split =  s.rsplit(".", 1)
	return split if len(split) == 2 else (None, split[0])


class Node(object):
	def __init__(self, source, lineno, parent, name, doc, sep=".", container=True):
		self.source = source
		self.lineno = lineno
		self.parent = parent
		self.name = name
		self.doc = doc
		self.container = container
		self.sep = sep
	
	def append(self, child):
		pass
	
	@property
	def type(self):
		type = self.__class__.__name__.lower()
		if type.endswith("symbol"):
			return type[:-6]
		return type
	
	def __str__(self):
		return "%s %s %s [%s:%s]" % (self.type, self.parent, self.name, self.source, self.lineno)


class Symbols(object):
	def __init__(self, ns):
		self.node = None
		self.symbols = {}
		self.canonical = {}
		self.ns = ns
	
	def get_symbol_name(self, node):
		parent = node.parent
		if parent is True:
			return None
		
		if not parent:
			return node.name
		
		parent = self.get_canonical(parent) or parent
		return parent + node.sep + node.name
	
	def get_last_container(self):
		return self.last_container
	
	def get_symbol(self, symbol):
		return self.symbols[symbol]
	
	def is_canonical(self, symbol):
		try:
			return self.canonical[symbol] == symbol
		except KeyError:
			return False
		
	def get_canonical(self, symbol):
		try:
			return self.canonical[symbol]
		except KeyError:
			return None
	
	def add_symbol(self, node):
		if node.parent is True:
			node.parent = self.get_last_container()
		
		symbol = self.get_symbol_name(node)
		if node.container:
			self.last_container = symbol
		
		if symbol:
			self.symbols[symbol] = node
			self.canonical[symbol] = symbol
		
		if node.parent:
			try:
				parent = self.get_symbol(node.parent)
				parent.append(node)
			except KeyError as e:
				if node.parent != self.ns:
					print("Error: Parent not found for %s" % node)
	
	def add_alias(self, canonical, alias):
		node = self.symbols[alias]
		self.symbols[canonical] = node
		self.canonical[canonical] = canonical
		self.canonical[alias] = canonical


class FunctionSymbol(Node):
	def __init__(self, source, lineno, line, parts, doc):
		parent, name = rdotsplit(parts[0])
		Node.__init__(self, source, lineno, parent, name, doc, container=False)
		self.params = parts[1]
	
	def _str__(self):
		if self.parent:
			return '%s <b id="%s">%s</b>(%s)' % ("method", self.symbol, self.name, self.symbol_parts[1])
		else:
			return '%s <b id="%s">%s</b>(%s)' % ("function" , self.symbol, self.symbol, self.symbol_parts[1])


class EnumSymbol(Node):
	def __init__(self, source, lineno, line, parts, doc):
		parent, name = rdotsplit(parts[0])
		Node.__init__(self, source, lineno, parent, name, doc)
		self.items = []
	
	def append(self, child):
		self.items.append(child)
		self.items.sort(key=lambda i: i.name)
		
	def html(self):
		buffer = ['<li>enumeration <b id="%s">%s</b><ul>' % (self.symbol, self.symbol)]
		for item in self.items:
			buffer.append('<li><b id="%s">%s</b> - </li>' % (self.symbol + "." + item.name, item.name))
		buffer.append("</ul></li>")
		return "\n".join(buffer)
	
	def _str__(self):
		buffer = ['enumeration %s' % (self.symbol)]
		for item in self.items:
			buffer.append("  * " + str(item))
		return "\n".join(buffer)


class MixinSymbol(Node):
	def __init__(self, source, lineno, line, parts, doc):
		parent, name = rdotsplit(parts[0])
		Node.__init__(self, source, lineno, parent, name, doc)
		self.methods = []
	
	def append(self, child):
		if isinstance(child, FunctionSymbol):
			self.methods.append(child)
			self.methods.sort(key=lambda i: i.name)
		else:
			print("Error: type '%s' not supported for mixins. %s" % (child.type, child))


class PrototypeSymbol(Node):
	def __init__(self, source, lineno, line, parts, doc):
		parent, name = rdotsplit(parts[0])
		Node.__init__(self, source, lineno, parent, name, doc)
		self.inherits = [s.strip()  for s in parts[1].split(",")]
		if self.inherits[0] == "null":
			self.inherits[0] = "Object"
		
		self.signals = []
		self.methods = []
		self.properties = []
	
	def append(self, child):
		if isinstance(child, FunctionSymbol):
			self.methods.append(child)
			self.methods.sort(key=lambda i: i.name)
		elif isinstance(child, SignalSymbol):
			self.signals.append(child)
			self.signals.sort(key=lambda i: i.name)
		else:
			self.properties.append(child)
			self.properties.sort(key=lambda i: i.name)
	
	def html(self):
		buffer = ['<li>prototype  <b id="%s">%s</b> inherits %s<ul>' % (self.symbol, self.symbol, ", ".join(["<b>%s</b>" %i for i in self.inherits]))]
		for method in self.methods:
			buffer.append("<li>%s</li>" % method.html())
		for signal in self.signals:
			buffer.append("<li>%s</li>" % signal.html())
		for prop in self.properties:
			buffer.append("<li>%s</li>" % prop.html())
		buffer.append("</ul></li>")
		return "\n".join(buffer)


class SignalSymbol(Node):
	def __init__(self, source, lineno, line, parts, doc):
		parent, name = True, parts[0][1:-1]
		Node.__init__(self, source, lineno, parent, name, doc, "::", container=False)
	
	def set_parent(self, parent):
		self.parent = parent.parent if parent.parent else parent.symbol


class PropertySymbol(Node):
	def __init__(self, source, lineno, line, parts, doc):
		parent, name = True, parts[0]
		Node.__init__(self, source, lineno, parent, name, doc, container=False)
		
	def set_parent(self, parent):
		self.parent = parent.symbol


class FieldSymbol(Node):
	def __init__(self, source, lineno, line, parts, doc):
		parent, name = rdotsplit(parts[0])
		Node.__init__(self, source, lineno, parent, name, doc, container=False)


class Alias(object):
	def __init__(self, source, lineno, canonical, alias):
		self.canonical = canonical
		self.alias = alias
		self.source = source
		self.lineno = lineno
	
	def __str__(self):
		return "alias %s -> %s [%s:%s]" % (self.alias, self.canonical, self.source, self.lineno)


class HtmlPrinter(object):
	def __init__(self, tree, ns):
		self.tree = tree
		self.ns = ns
		self.index = []
		self.body = []
		ns_len = len(ns) + 1
		self.strip_ns = lambda s: s[ns_len:]
	
	def process(self):
		tree = self.tree
		ns = (None, self.ns)
		symbols = defaultdict(list)
		for symbol, node in tree.symbols.iteritems():
			if node.parent in ns and tree.is_canonical(symbol):
				symbols[node.type].append(symbol)
		
		index = self.index
		body = self.body
		
		index.append("<h3>Namespace {0}</h3>".format(escape(self.ns)))
		body.append("<h2>Namespace {0}</h2>".format(escape(self.ns)))
		
		types = ("field", "function", "prototype", "mixin", "enum")
		types_names = ("Fields", "Functions", "Prototypes", "Mixins", "Enums")
		for i in xrange(len(types)):
			type_name = escape(types_names[i])
			index.append('<h4>{0}</h4>\n<ul>\n'.format(type_name))
			body.append('<h3>{0}</h3>\n<ul>\n'.format(type_name))
			
			for symbol in sorted(symbols[types[i]]):
				node = tree.get_symbol(symbol)
				type = node.type
				#~ print(symbol + " (%s) = " % type +str(node))
				try:
					method = getattr(self, "process_" + type)
				except AttributeError as e:
					print(e)
					continue
				
				method(symbol, node, index, body)
		
			index.append("</ul>")
			body.append("</ul>")
		
		return "".join(self.index), "".join(self.body)
	
	def process_function(self, symbol, node, index, body):
		html_symbol = escape(symbol)
		html_bare_symbol = escape(self.strip_ns(symbol))
		html_params = escape(node.params)
		
		index.append('<li><a href="#{0}">{1}</a></li>\n'.format(html_symbol, html_bare_symbol))
		body.append('<li><small>function</small> <b id="{0}">{0}</b>({1})<br />\n'.format(html_symbol, html_params))
		body.extend(self.process_doc(node))
		body.append("</li>\n\n")
	
	def process_method(self, symbol, node, index, body):
		html_symbol = escape(symbol)
		html_name = escape(node.name)
		html_params = escape(node.params)
		
		index.append('<li><a href="#{0}">{1}</a></li>\n'.format(html_symbol, html_name))
		body.append('<li><small>method</small> <b id="{0}">{1}</b>({2})<br />\n'.format(html_symbol, html_name, html_params))
		body.extend(self.process_doc(node))
		body.append("</li>\n\n")
		
	def process_signal(self, symbol, node, index, body):
		html_symbol = escape(symbol)
		html_name = escape(node.name)
		index.append('<li><a href="#{0}">{1}</a></li>\n'.format(html_symbol, html_name))
		body.append('<li><small>signal</small> <b id="{0}">{1}</b><br />\n'.format(html_symbol, html_name))
		body.extend(self.process_doc(node))
		body.append("</li>\n\n")
		
	def process_prototype(self, symbol, node, index, body):
		html_symbol = escape(symbol)
		html_bare_symbol = escape(self.strip_ns(symbol))
		index.append('<li><a href="#{0}">{1}</a>\n<ul>'.format(html_symbol, html_bare_symbol))
		
		inherits = []
		for i in node.inherits:
			canonical = self.tree.get_canonical(i)
			if canonical:
				inherits.append('<a href="#{0}">{1}</a>'.format(escape(canonical), escape(i)))
			else:
				inherits.append(escape(i))
		
		body.append('<li> <small>prototype</small> <b id="{0}">{0}</b> inherits {1}\n<br />'.format(html_symbol, ", ".join(inherits)))
		body.extend(self.process_doc(node))
		body.append("<ul>\n\n")
		
		for item in node.methods:
			self.process_method(self.tree.get_symbol_name(item), item, index, body)
		
		for item in node.signals:
			self.process_signal(self.tree.get_symbol_name(item), item, index, body)
			
		index.append('</ul></li>\n')
		body.append('</ul></li>\n')
	
	def process_enum(self, symbol, node, index, body):
		html_symbol = escape(symbol)
		html_bare_symbol = escape(self.strip_ns(symbol))
		html_name = escape(node.name)
		index.append('<li><a href="#{0}">{1}</a></li>\n'.format(html_symbol, html_bare_symbol))
		body.append('<li><small>enumeration</small> <b id="{0}">{0}</b><br />\n'.format(html_symbol))
		body.extend(self.process_doc(node))
		body.append("<ul>\n\n")
		
		for item in node.items:
			body.append('<li><b id="{0}">{1}</b> - {2}</li>\n'.format(escape(self.tree.get_symbol_name(item)), escape(item.name), self.replace_links(escape(" ".join(self.join_buffers(item.doc[DOC_DESC]))))))
		
		body.append('</ul></li>\n')
	
	def process_mixin(self, symbol, node, index, body):
		html_symbol = escape(symbol)
		html_bare_symbol = escape(self.strip_ns(symbol))
		html_name = escape(node.name)
		index.append('<li><a href="#{0}">{1}</a>\n<ul>'.format(html_symbol, html_bare_symbol))
		body.append('<li><small>mixin</small> <b id="{0}">{0}</b>\n<br />'.format(html_symbol))
		body.extend(self.process_doc(node))
		body.append("<ul>\n\n")
		
		for method in node.methods:
			self.process_method(self.tree.get_symbol_name(method), method, index, body)
		
		index.append('</ul></li>\n')
		body.append('</ul></li>\n')
	
	def process_field(self, symbol, node, index, body):
		html_symbol = escape(symbol)
		html_bare_symbol = escape(self.strip_ns(symbol))
		html_name = escape(node.name)
		index.append('<li><a href="#{0}">{1}</a></li>\n'.format(html_symbol, html_bare_symbol))
		body.append('<li><small>field</small> <b id="{0}">{0}</b><br />\n'.format(html_symbol))
		body.extend(self.process_doc(node))
		body.append("</li>\n\n")
	
	def process_doc(self, node):
		doc = node.doc
		buf = []
		desc = doc.pop(DOC_DESC, None)
		text = doc.pop(DOC_TEXT, None)
		params = doc.pop(DOC_PARAM, None)
		returns = doc.pop(DOC_RETURN, None)
		throws = doc.pop(DOC_THROW, None)
		
		if desc:
			self.process_doc_text("Description", self.join_buffers(desc), buf)
		
		if params:
			self.process_doc_params(params, buf)
		
		if returns:
			self.process_doc_returns(returns, buf)
		
		if throws:
			self.process_doc_throws(throws, buf)
		
		if text:
			self.process_doc_text("Additional documentation", self.join_buffers(text), buf)
		
		for key in doc:
			print("Error: extra doc key '{0}' for {1}.".format(key, str(node)))
		
		return buf
	
	def join_buffers(self, buffers):
		if len( buffers) > 1:
			result = []
			for i in  buffers:
				result.extend(i)
			return result
		
		if buffers:
			return buffers[0]
		
		return []
	
	def process_doc_text(self, header, desc, buf):
		buf.append('<p><b>{0}</b></p>\n<pre>'.format(escape(header)))
		buf.append( self.replace_links('\n'.join(desc)))
		buf.append('</pre>\n')
	
	def process_doc_params(self, params, buf):
		buf.append('<p><b>Parameters</b></p>\n<ul>\n')
		
		for p in params:
			buf.extend(('<li>', self.replace_links(' '.join(p)), '</li>\n'))
		
		buf.append('</ul>\n')
		
	def process_doc_throws(self, throws, buf):
		buf.append('<p><b>Throws</b></p>\n<ul>\n')
		
		for p in throws:
			buf.extend(('<li>', self.replace_links(' '.join(p)), '</li>\n'))
		
		buf.append('</ul>\n')
		
	def process_doc_returns(self, params, buf):
		buf.append('<p><b>Returns</b></p>\n<ul>\n')
		
		for p in params:
			buf.extend(('<p>', self.replace_links(' '.join(p)), '</p>\n'))
		
		buf.append('</ul>\n')
	
	def replace_links(self, text):
		def sub(m):
			symbol = m.group(1)
			canonical = self.tree.get_canonical(symbol)
			return '<a href="#{0}">{1}</a>'.format(escape(canonical), escape(symbol)) if canonical else escape(symbol)
		
		return LINK_RE.sub(sub, text)

DOC_DESC = "@desc"
DOC_TEXT = "@text"
DOC_PARAM = "@param"
DOC_RETURN = "@return"
DOC_THROW = "@throws"
DOC_IGNORE = ("@signal", "@mixin", "@enum")

def parse_doc_comment(doc):
	mode = DOC_DESC
	result = defaultdict(list)
	buf = []
	result[DOC_DESC].append(buf)
	
	for line in doc:
		for tag in (DOC_PARAM, DOC_RETURN, DOC_THROW):
			if line.startswith(tag):
				mode = tag
				buf = [line[len(tag):].strip()]
				result[tag].append(buf)
				break
			
		else:
			
			if mode not in (DOC_DESC, DOC_TEXT) and not line.startswith(" "):
				mode = DOC_TEXT
				buf = []
				result[DOC_TEXT].append(buf)
			
			for tag in DOC_IGNORE:
				if line.startswith(tag):
					line = line[len(tag)+1:]
			
			buf.append(line)
	
	return result

def parse_symbol(symbol, doc_head):
	m = METHOD_RE.match(symbol)
	if m:
		return FunctionSymbol, m.groups()
	
	m = OBJECT_RE.match(symbol)
	if m:
		if "@enum" in doc_head:
			return EnumSymbol, m.groups()
		
		if "@mixin" in doc_head:
			return MixinSymbol, m.groups()
	
	m = PROTOTYPE_RE.match(symbol)
	if m:
		return PrototypeSymbol, m.groups()
	
	m = SIGNAL_RE.match(symbol)
	if m:
		return SignalSymbol, m.groups()
	
	m = PROPERTY_RE.match(symbol)
	if m:
		return PropertySymbol, m.groups()
	
	m = FUNCTION_RE.match(symbol)
	if m:
		return FunctionSymbol, m.groups()
	
	m = FIELD_RE.match(symbol)
	if m:
		return FieldSymbol, m.groups()
		
	return None, None


def parse_source(source):
	mode = MODE_CODE
	level = 0
	doc = None
	with open(source, "rt") as f:
		lineno = 0
		for line in f:
			bare = line.strip()
			lineno += 1
			if mode == MODE_CODE: 
				level = line.find("/**")
				if level >= 0:
					mode = MODE_DOC
					doc = []
				else:
					m = ALIAS_RE.match(line)
					if m:
						yield Alias(source, lineno, m.group(1), m.group(2))
						
			elif mode == MODE_DOC:
				if line[level:level+2] != " *":
					print("Error: Wrong level: %s: %r" % (lineno, line))
				
				
				if bare == "*/":
					mode = MODE_SYMBOL
				else:
					doc.append(bare[2:])
			else:
				mode = MODE_CODE
				klass, parts = parse_symbol(bare, doc[0])
				
				yield klass(source, lineno, bare, parts, parse_doc_comment(doc))

def make_tree(tree, nodes):
	for node in nodes:
		if isinstance(node, Alias):
			try:
				tree.add_alias(node.canonical, node.alias)
			except KeyError:
				print("Error: No documented symbol '%s' has been found for %s" % (node.alias, node))
		else:
			tree.add_symbol(node)

def generate_doc(ns, out_file, sources_dir):
	tree = Symbols(ns)
	
	for source in gather_sources(sources_dir):
		make_tree(tree, parse_source(source))
	
	printer = HtmlPrinter(tree, ns)
	index, body = printer.process()
	
	with open("doc/template.html", "rt") as f:
		template = Template(f.read())
	
	with open(out_file, "wt") as f:
		f.write(template.safe_substitute(index=index, body=body))

if __name__ == "__main__":
	generate_doc("Nuvola", "doc.html", "src/mainjs")
