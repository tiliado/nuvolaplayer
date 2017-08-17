#!/usr/bin/python3

# mergegir.py Name-Vrsion.gir *.gir... 
import os
import sys

from xml.etree import ElementTree

INCLUDE_TAG = "{http://www.gtk.org/introspection/core/1.0}include"
C_INCLUDE_TAG = "{http://www.gtk.org/introspection/c/1.0}include"
PACKAGE_TAG = "{http://www.gtk.org/introspection/core/1.0}package"
CONSTANT_TAG = "{http://www.gtk.org/introspection/core/1.0}constant"
NAMESPACE_PREFIX = "{http://www.gtk.org/introspection/c/1.0}prefix"
NAMESPACE_TAG = "{http://www.gtk.org/introspection/core/1.0}namespace"

ElementTree.register_namespace("c", "http://www.gtk.org/introspection/c/1.0")
ElementTree.register_namespace("", "http://www.gtk.org/introspection/core/1.0")
ElementTree.register_namespace("glib", "http://www.gtk.org/introspection/glib/1.0")

target = sys.argv[1]
name, version = os.path.basename(target).rsplit(".", 1)[0].split("-")
root = None
packages = set()
includes = set()
c_includes = set()
elements = []


path = sys.argv[2]
tree = ElementTree.parse(path)
gir = root = tree.getroot()

namespace_tag = None
namespace_tag_pos = None
for i, child in enumerate(gir):
	if child.tag == INCLUDE_TAG:
		includes.add((child.attrib["name"], child.attrib["version"]))
	elif child.tag == C_INCLUDE_TAG:
		c_includes.add(child.attrib["name"])
	elif child.tag == PACKAGE_TAG:
		packages.add(child.attrib["name"])
	elif child.tag == NAMESPACE_TAG:
		namespace_tag_pos = i
		namespace_tag = child
		namespace_tag.attrib["name"] = name
		namespace_tag.attrib["version"] = version
		namespace_tag.attrib[NAMESPACE_PREFIX] = name

extra_include = [("Drt", "1.0"), ("Drtgtk", "1.0"), ("Engineio", "1.0")]
for name, version in extra_include:
	root.insert(namespace_tag_pos, ElementTree.Element(INCLUDE_TAG, attrib={"name": name, "version": version}))

for path in sys.argv[3:]:
	gir = ElementTree.parse(path).getroot()
	for child in gir:
		if child.tag == INCLUDE_TAG:
			entry = (child.attrib["name"], child.attrib["version"])
			if entry not in includes:
				includes.add(entry)
				root.insert(namespace_tag_pos, child)
		elif child.tag == C_INCLUDE_TAG:
			entry = child.attrib["name"]
			if entry not in c_includes:
				c_includes.add(entry)
				root.insert(namespace_tag_pos, child)
		elif child.tag == PACKAGE_TAG:
			entry = child.attrib["name"]
			if entry not in packages:
				packages.add(entry)
				root.insert(namespace_tag_pos, child)
		elif child.tag == NAMESPACE_TAG:
			for elm in child:
				namespace_tag.append(elm)
	gir = None

def fix_constants(elm):
	to_remove = []
	for child in elm:
		if child.tag == CONSTANT_TAG and child.attrib["value"] == "(null)":
			to_remove.append(child)
		else:
			fix_constants(child)
	for child in to_remove:
		elm.remove(child)

fix_constants(namespace_tag)

tree.write(target, encoding="utf-8", xml_declaration=True)
