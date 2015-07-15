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

# Service integration id
APP_ID = template
# Dependencies
DEPS = rsvg-convert
# Default installation destination
DEST ?= $(HOME)/.local/share/nuvolaplayer3/web_apps
# Size of PNG app icon
ICON_SIZE ?= 128

help:
	@echo "make deps                - check whether dependencies are satisfied"
	@echo "make build               - build files (graphics, etc.)"
	@echo "make clean               - clean source directory"
	@echo "make install             - install to user's local directory (~/.local)"
	@echo "make install DEST=/path  - install to '/path' directory"
	@echo "make uninstall           - uninstall from user's local directory (~/.local)"

deps:
	@$(foreach dep, $(DEPS), which $(dep) > /dev/null || (echo "Program $(dep) not found"; exit 1;);)

build: deps icon.png 

icon.png : src/icon.svg
	rsvg-convert -w $(ICON_SIZE) -h $(ICON_SIZE) $< -o $@

clean:
	rm -f icon.png

install: LICENSE metadata.json integrate.js icon.png
	install -vCd $(DEST)/$(APP_ID)
	install -vC $^ $(DEST)/$(APP_ID)

uninstall:
	rm -rv $(DEST)/$(APP_ID)
