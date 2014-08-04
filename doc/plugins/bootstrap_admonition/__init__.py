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

"""
Bootstrap Admonitions
=====================

This plugin converts admonitions to Bootstrap 3 panels.
"""

from bs4 import BeautifulSoup
from pelican import signals, readers, contents

ADMONITION_CLASS = 'admonition'
ADMONITION_TITLE_CLASS = 'admonition-title'
PANEL_CLASS = "panel"
PANEL_HEADING_CLASS = "panel-heading"

def bootstrap_admonition(content):
    if isinstance(content, contents.Static):
        return
    
    soup = BeautifulSoup(content._content, 'html.parser')
    panels = soup.find_all('div', class_=ADMONITION_CLASS)
    if panels:
        for panel in panels:
            classes = panel["class"]
            index = classes.index(ADMONITION_CLASS)
            classes[index] = PANEL_CLASS
            classes[index + 1] = "{}-{}".format(PANEL_CLASS, classes[index + 1])
            
            title = panel.find("p", class_=ADMONITION_TITLE_CLASS)
            panel_contents = panel.contents[:]
            panel.clear()
             
            if title:
                classes = title["class"]
                try:
                    index = classes.index(ADMONITION_TITLE_CLASS)
                    classes[index] = PANEL_HEADING_CLASS
                except ValueError as e:
                    print(e)
                
                index = panel_contents.index(title)
                panel_contents = panel_contents[index + 1:]
                panel.append(title)
            
            body = soup.new_tag("div")
            body["class"] = ["panel-body"]
            panel.append(body)
            
            for i in panel_contents:
                body.append(i)
    
        content._content = soup.decode()

def register():
    signals.content_object_init.connect(bootstrap_admonition)
