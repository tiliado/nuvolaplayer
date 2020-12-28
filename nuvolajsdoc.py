#!/usr/bin/python3
# coding: utf-8

# Copyright 2014-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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
import sys
from importlib import import_module
from string import Template
from xml.sax.saxutils import escape
from collections import defaultdict
from markdown import Markdown
from markdown.extensions import Extension

from jinja2 import Environment, FileSystemLoader

MODE_CODE = 0
MODE_DOC = 1
MODE_SYMBOL = 2

FUNCTION_RE = re.compile(r"^\s*(?:var|let|const)\s+(\$?\w+(?:\.\$?\w+)*)\s+=\s+function\s*\((.*)\)\s*\{?$")
METHOD_RE = re.compile(r"^\s*(\$?\w+(?:\.\$?\w+)*)\s+=\s+function\s*\((.*)\)\s*\{?$")
PROTOTYPE_RE = re.compile(r"^\s*(?:var|let|const)\s+(\$?\w+(?:\.\$?\w+)*)\s+=\s+(?:Nuvola\.)?\$prototype\s*\((.*)\)$")
OBJECT_RE = re.compile(r"^\s*(?:var|let|const)\s+(\$?\w+(?:\.\$?\w+)*)\s+=\s+\{\s*(?:\})?$")
SIGNAL_RE = re.compile(r"^this\.addSignal\s*\((.*)\)$")
PROPERTY_RE = re.compile(r'^["\']?(\w+)["\']?\s*:\s*(.+)$')
FIELD_RE = re.compile(r"^\s*(\$?\w+(?:\.\$?\w+)*)\s+=\s+(.*)\s*$")
ALIAS_RE = re.compile(r"^(\$?\w+(?:\.\$?\w+)*)\s+=\s+(\$?\w+(?:\.\$?\w+)*)\s*$")
LINK_RE = re.compile(r'@link\{(?:(\w+?)&gt;)?(.+?)(?:\|(.+?))?\}')
PARAM_RE = re.compile(r'^(optional\s+)?(?:[\'"](.+?)[\'"]\s*|([^\'"].*?)\s+)(.+?)\s+(.*)$')

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
        self.last_container = None

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

        append_symbols = []
        for symbol, node in self.symbols.items():
            if node.parent == alias:
                canonical = self.get_symbol_name(node)
                self.canonical[symbol] = canonical
                self.canonical[canonical] = canonical
                append_symbols.append((canonical, node))

        for canonical, node in append_symbols:
            self.symbols[canonical] = node


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

class NamespaceSymbol(Node):
    def __init__(self, source, lineno, line, parts, doc):
        parent, name = rdotsplit(parts[0])
        Node.__init__(self, source, lineno, parent, name, doc)
        self.methods = []

    def append(self, child):
        if isinstance(child, FunctionSymbol):
            self.methods.append(child)
            self.methods.sort(key=lambda i: i.name)
        else:
            print("Error: type '%s' not supported for namespaces. %s" % (child.type, child))


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
    def __init__(self, tree, ns, markdown, interlinks=None):
        self.tree = tree
        self.ns = ns
        self.index = []
        self.body = []
        ns_len = len(ns) + 1
        self.strip_ns = lambda s: s[ns_len:]
        self.markdown = markdown
        self.interlinks = interlinks if interlinks is not None else {}
        self.changelog = []

    def process(self):
        tree = self.tree
        ns = (None, self.ns)
        symbols = defaultdict(list)
        for symbol, node in tree.symbols.items():
            if node.parent in ns and tree.is_canonical(symbol):
                symbols[node.type].append(symbol)

        index = self.index
        body = self.body

        index.append("<h3>Namespace {0}</h3>".format(escape(self.ns)))
        body.append("<h2>Namespace {0}</h2>".format(escape(self.ns)))

        types = ("field", "function", "prototype", "namespace", "mixin", "enum")
        types_names = ("Fields", "Functions", "Prototypes", "Namespaces", "Mixins", "Enums")
        for i in range(len(types)):
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

        self.process_changelog()

        return "".join(self.index), "".join(self.body)

    def process_function(self, symbol, node, index, body):
        html_symbol = escape(symbol)
        html_bare_symbol = escape(self.strip_ns(symbol))
        html_params = escape(node.params)
        func_type = "async " if node.doc.get(DOC_ASYNC) else ""

        index.append('<li><a href="#{0}">{1}</a></li>\n'.format(html_symbol, html_bare_symbol))
        body.append('<li><small>{0} function</small> <b id="{1}">{1}</b>({2})<br />\n'.format(
            func_type, html_symbol, html_params))
        body.extend(self.process_doc(node))
        body.append("</li>\n\n")

    def process_method(self, symbol, node, index, body):
        html_symbol = escape(symbol)
        html_name = escape(node.name)
        html_params = escape(node.params)

        index.append('<li><a href="#{0}">{1}</a></li>\n'.format(html_symbol, html_name))
        method_type = "async " if node.doc.get(DOC_ASYNC) else ""
        body.append('<li><small>{0} method</small> <b id="{1}">{2}</b>({3})<br />\n'.format(
            method_type, html_symbol, html_name, html_params))
        body.extend(self.process_doc(node))
        body.append("</li>\n\n")

    def process_signal(self, symbol, node, index, body):
        html_symbol = escape(symbol)
        html_name = escape(node.name)
        params = [(node.parent, "emitter", "object that emitted the signal")] + node.doc.get(DOC_PARAM, [])
        node.doc[DOC_PARAM] = params

        unique_params = []
        for p in params:
            p = p[1].split(".")[0].strip()
            if not p in unique_params:
                unique_params.append(p)

        html_params = ", ".join(escape(p) for p in unique_params)
        index.append('<li><a href="#{0}">{1}</a></li>\n'.format(html_symbol, html_name))
        body.append('<li><small>signal</small> <b id="{0}">{1}</b>({2})<br />\n'.format(html_symbol, html_name, html_params))
        body.extend(self.process_doc(node))
        body.append("</li>\n\n")

    def process_prototype(self, symbol, node, index, body):
        html_symbol = escape(symbol)
        html_bare_symbol = escape(self.strip_ns(symbol))
        index.append('<li><a href="#{0}">{1}</a>\n<ul>'.format(html_symbol, html_bare_symbol))

        inherits = []
        if node.inherits:
            for i in node.inherits:
                canonical = self.tree.get_canonical(i)
                if canonical:
                    inherits.append('<a href="#{0}">{1}</a>'.format(escape(canonical), escape(i)))
                else:
                    inherits.append(escape(i))

            extends = inherits[0]
            inherits = inherits[1:]
        else:
            extends = None

        body.append('<li> <small>prototype</small> <b id="{0}">{0}</b>'.format(html_symbol))
        if extends:
            body.append(' extends {0}'.format(extends))
        if inherits:
            body.append(', contains {0}'.format(", ".join(inherits)))
        body.append("<br />\n")
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

    def process_namespace(self, symbol, node, index, body):
        html_symbol = escape(symbol)
        html_bare_symbol = escape(self.strip_ns(symbol))
        html_name = escape(node.name)
        index.append('<li><a href="#{0}">{1}</a>\n<ul>'.format(html_symbol, html_bare_symbol))
        body.append('<li><small>namespace</small> <b id="{0}">{0}</b>\n<br />'.format(html_symbol))
        body.extend(self.process_doc(node))
        body.append("<ul>\n\n")

        for method in node.methods:
            self.process_method(self.tree.get_symbol_name(method), method, index, body)

        index.append('</ul></li>\n')
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
        is_async = doc.pop(DOC_ASYNC, None)
        since = doc.pop(DOC_SINCE, None)
        deprecated = doc.pop(DOC_DEPRECATED, None)

        if desc:
            self.process_doc_text("Description", self.join_buffers(desc), buf)

        if is_async:
            buf.append(
                '<p><b>Asynchronous:</b> This function returns '
                '<a href="https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise">a'
                ' Promise object</a> to resolve the value when it is ready. Read '
                '<a href="https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Using_promises">Using '
                'Promises</a> to learn how to work with them.</p>\n')
        if since:
            since = self.process_versioned_items(since)
            for item in since:
                self.changelog.append(item + (node, 'new'))
            self.process_doc_since(since, buf)
        if deprecated:
            deprecated = self.process_versioned_items(deprecated)
            for item in deprecated:
                self.changelog.append(item + (node, 'deprecated'))
            self.process_doc_deprecated(deprecated, buf)
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
        text = '\n'.join(desc)
        text = text.replace("\n```\n", '\n```js\n')
        text = text.replace("\\/", '/')
        buf.append(self.replace_links(self.mkd(text)))

    def process_doc_params(self, params, buf):
        buf.append('<p><b>Parameters</b></p>\n<ul>\n')

        for type, name, desc in params:
            type = " ".join(self.link_symbol(s) for s in type.split(" "))
            desc = self.mkd(desc)[3:-4]
            buf.append('<li>{0} <b>{1}</b> - {2}</li>\n'.format(type, escape(name), self.replace_links(desc)))

        buf.append('</ul>\n')

    def process_doc_throws(self, items, buf):
        buf.append('<p><b>Throws</b></p>\n<ul>\n')

        for item in items:
            buf.extend(('<li>', self.replace_links(self.mkd(' '.join(s.strip() for s in item))), '</li>\n'))

        buf.append('</ul>\n')

    def process_doc_returns(self, items, buf):
        buf.append('<p><b>Returns</b></p>\n<ul>\n')

        for item in items:
            buf.extend(('<li>', self.replace_links(self.mkd(' '.join(s.strip() for s in item))), '</li>\n'))

        buf.append('</ul>\n')

    def process_versioned_items(self, items):
        result = []
        for item in items:
            version = ' '.join(s.strip() for s in item)
            try:
                version, text = [s.strip() for s in version.split(':', 1)]
            except ValueError:
                text = None
            result.append((version, text))
        return result

    def process_doc_since(self, items, buf):
        self.process_doc_version("Available", items, buf)

    def process_doc_deprecated(self, items, buf):
        self.process_doc_version("Deprecated", items, buf)

    def process_doc_version(self, label, items, buf):
        for version, text in items:
            buf.append('<p><b>{} since</b> '.format(label))
            buf.append(version)
            if text:
                buf.append(": " + self.replace_links(text))
            buf.append("</p>\n")

    def link_symbol(self, symbol, text=None):
        canonical = self.tree.get_canonical(symbol)
        if not text:
            text = symbol
        return '<a href="#{0}">{1}</a>'.format(escape(canonical), escape(text)) if canonical else escape(text)

    def process_changelog(self):
        index, body, tree = self.index, self.body, self.tree
        index.append("<h3>Changelog</h3><ul>")
        body.append("<h2 id=\"x-changelog\">Changelog</h2>")
        def key_func(i):
            key = i[0].replace('.', ' ').split()[1:] + tree.get_symbol_name(i[2]).replace('.', ' ').split()
            keys = []
            for k in key:
                try:
                    keys.append(int(k))
                except ValueError:
                    keys.append(k)
            return keys
        self.changelog.sort(key=key_func)
        changelog = defaultdict(list)
        for version, text, node, label in self.changelog:
            changelog[version].append((node, text, label))
        for version, items in changelog.items():
            version = version.split()[1]
            anchor = 'x-changelog-' + version.replace(' ', '-').replace('.', '-')
            index.append('<li><a href="#%s">%s</a></li>' % (anchor, version))
            body.append('<h3 id="%s">Since %s</h3><ul>' % (anchor, version))
            for node, text, label in items:
                link = self.link_symbol(tree.get_symbol_name(node))
                if text:
                    body.append('<li>%s <i>(%s)</i>: %s</li>' % (link, label, text))
                else:
                    body.append('<li>%s <i>(%s)</i></li>' % (link, label))
            body.append("</ul>")
        index.append("</ul>")

    def interlink(self, interlink, target, text=None):
        prefix = self.interlinks[interlink]
        return '<a href="{0}">{1}</a>'.format(escape(prefix + target), escape(text or target))

    def replace_link(self, interlink, target, text=None):
        if interlink:
            return self.interlink(interlink, target, text)
        return self.link_symbol(target, text)

    def replace_links(self, text):
        return LINK_RE.sub(lambda m: self.replace_link(m.group(1), m.group(2), m.group(3)), text)

    def mkd(self, s):
        return self.markdown.convert(s)

DOC_DESC = "@desc"
DOC_TEXT = "@text"
DOC_PARAM = "@param"
DOC_RETURN = "@return"
DOC_THROW = "@throws"
DOC_IGNORE = ("@signal", "@mixin", "@enum", "@namespace")
DOC_ASYNC = "@async"
DOC_SINCE = "@since"
DOC_DEPRECATED = "@deprecated"

def parse_doc_comment(doc):
    mode = DOC_DESC
    result = defaultdict(list)
    buf = []
    result[DOC_DESC].append(buf)

    for line in doc:
        for tag in (DOC_PARAM, DOC_RETURN, DOC_THROW, DOC_ASYNC, DOC_SINCE, DOC_DEPRECATED):
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

    try:
        params = result[DOC_PARAM]
        valid_params = []
        for param in params:
            res = parse_param(param)
            if res is None:
                print("Error: Invalid @param '%s'." % param)
            else:
                valid_params.append(res)

        result[DOC_PARAM] = valid_params
    except KeyError:
        pass

    return result

def parse_param(param):
    param = " ".join(s.strip() for s in param)
    m = PARAM_RE.match(param)
    if m:
        optional, type1, type2, name, desc = m.groups()
        type = type1 or type2

        if optional:
            type = optional.strip() + " " + type

        return type, name, desc

    return None

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

        if "@namespace" in doc_head:
            return NamespaceSymbol, m.groups()

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
    with open(source, "rt", encoding="utf-8") as f:
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
                    print("Error: Wrong level: %s:%s: %r" % (source, lineno, line))


                if bare == "*/":
                    mode = MODE_SYMBOL
                else:
                    doc.append(bare[2:])
            else:
                mode = MODE_CODE
                klass, parts = parse_symbol(bare, doc[0])
                if klass is None:
                    print("Error: Unknown symbol type at {0}:{1} '{2}'".format(source, lineno, bare))
                else:
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

def process_template(template, data):
    loader = FileSystemLoader(os.path.dirname(template), encoding='utf-8')
    env = Environment(loader=loader)
    template = env.get_template(os.path.basename(template))
    return template.render(**data)

def load_config(config_file):
    sys.path.insert(0, os.path.dirname(config_file))
    config = import_module(os.path.basename(config_file).rsplit(".", 1)[0])
    sys.path.pop(0)
    return config

def generate_doc(ns, out_file, sources_dir, config_file, template=None):
    config = load_config(config_file)
    if template is None:
        try:
            template = config.TEMPLATE
        except AttributeError:
            raise ValueError("Template not specified")

    tree = Symbols(ns)

    for source in gather_sources(sources_dir):
        make_tree(tree, parse_source(source))


    markdown = Markdown(
        extensions = ['sane_lists', 'fenced_code', 'codehilite', 'def_list', 'attr_list', 'abbr', 'admonition'],
        safe_mode='escape',
        lazy_ol=False)

    interlinks = getattr(config, "INTERLINKS", defaultdict(str))
    printer = HtmlPrinter(tree, ns, markdown, interlinks=interlinks)
    index, body = printer.process()

    data = {key: getattr(config, key) for key in dir(config) if not key.startswith("_")}
    data["index"] = index
    data["body"] = body

    try:
        os.makedirs(os.path.dirname(out_file))
    except OSError:
        pass
    with open(out_file, "wt", encoding="utf-8") as f:
        f.write(process_template(template, data))

if __name__ == "__main__":
    import sys
    import argparse
    parser = argparse.ArgumentParser(description='Generates JavaScript documentation.')
    parser.add_argument('-t','--template',  help='template to use')
    result = parser.parse_args(sys.argv[1:])
    generate_doc("Nuvola", "build/doc/apps/api_reference.html", "src/mainjs", "doc/jsdoc_conf.py",
        result.template)
