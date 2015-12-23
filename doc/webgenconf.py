# -*- coding: utf-8 -*- #

# Import common configuration
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from common_conf import *
sys.path.pop(0)

SITE_NAME = "Nuvola Player Documentation"
SITE_URL = ""

CONTENT_DIR = "."
PAGES_SUBDIR = "pages"
STATIC_SUBDIRS = ["images"]
PAGE_URL = "${dirname}${basename}.html"

OUTPUT_PATH = "../build/doc"
CACHE_PATH = "../build/doc-cache"

INTERLINKS["apiref"] = "./api_reference.html#"

def section_filter(path, section, basepath="", label=None):
    for part in (path if not path.endswith(".html") else path[:-5]).split("/"):
        if part == section:
            css_class = ' class="active"'
            break
    else:
        css_class = ""
    
    return '<li{}><a href="{}/{}.html">{}</a></li>'.format(css_class, basepath, section, label or section)
    
JINJA_FILTERS = {"section": section_filter}
