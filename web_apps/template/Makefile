# Copyright 2014-2015 Jiří Janoušek <janousek.jiri@gmail.com>
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
# Sizes of the whole icon set
ICON_SIZES ?= 16 22 24 32 48 64 128 256
# Filenames
INSTALL_FILES = metadata.json integrate.js
LICENSES = LICENSE-BSD.txt LICENSE-CC-BY.txt
SOURCE_ICON ?= src/icon.svg
SOURCE_ICON_XS ?= src/icon-xs.svg
SOURCE_ICON_SM ?= src/icon-sm.svg
ICONS_DIR ?= icons
PNG_ICONS = $(foreach size,$(ICON_SIZES),$(ICONS_DIR)/$(size).png)
SCALABLE_ICON = $(ICONS_DIR)/scalable.svg

# Show help
help:
	@echo "make deps                - check whether dependencies are satisfied"
	@echo "make build               - build files (graphics, etc.)"
	@echo "make clean               - clean source directory"
	@echo "make install             - install to user's local directory (~/.local)"
	@echo "make install DEST=/path  - install to '/path' directory"
	@echo "make uninstall           - uninstall from user's local directory (~/.local)"

# Check dependencies
deps:
	@$(foreach dep, $(DEPS), which $(dep) > /dev/null || (echo "Program $(dep) not found"; exit 1;);)

# Build icons
build: deps $(PNG_ICONS) $(SCALABLE_ICON)

# Create icons dir
$(ICONS_DIR):
	mkdir -p $@
	
# Generate icon 16
$(ICONS_DIR)/16.png: $(SOURCE_ICON_XS) | $(ICONS_DIR)
	rsvg-convert -w 16 -h 16 $< -o $@

# Generate icon 22	
$(ICONS_DIR)/22.png : $(SOURCE_ICON_XS) | $(ICONS_DIR)
	rsvg-convert -w 22 -h 22 $< -o $@

# Generate icon 24	
$(ICONS_DIR)/24.png : $(SOURCE_ICON_XS) | $(ICONS_DIR)
	rsvg-convert -w 24 -h 24 $< -o $@

# Generate icon 32	
$(ICONS_DIR)/32.png : $(SOURCE_ICON_SM) | $(ICONS_DIR)
	rsvg-convert -w 32 -h 32 $< -o $@

# Generate icon 48
$(ICONS_DIR)/48.png : $(SOURCE_ICON_SM) | $(ICONS_DIR)
	rsvg-convert -w 48 -h 48 $< -o $@

# Generate icons 64 128 256
$(ICONS_DIR)/%.png : $(SOURCE_ICON) | $(ICONS_DIR)
	rsvg-convert -w $* -h $* $< -o $@

# Copy scalable icon
$(SCALABLE_ICON) : $(SOURCE_ICON) | $(ICONS_DIR)
	cp $< $@

# Clean built files
clean:
	rm -rf icons

# Install files
install: $(LICENSES) metadata.json integrate.js $(PNG_ICONS) $(SCALABLE_ICON)
	# Install data
	install -vCd $(DEST)/$(APP_ID)/$(ICONS_DIR)
	install -vC -t $(DEST)/$(APP_ID) $(LICENSES) metadata.json integrate.js
	install -vC -t $(DEST)/$(APP_ID)/$(ICONS_DIR) $(PNG_ICONS) $(SCALABLE_ICON)
	
	# Create symlinks to icons
	mkdir -pv $(DEST)/../../icons/hicolor/scalable/apps || true
	ln -s -f -v -T $(DEST)/$(APP_ID)/$(SCALABLE_ICON) \
		$(DEST)/../../icons/hicolor/scalable/apps/nuvolaplayer3_$(APP_ID).svg;
	for size in $(ICON_SIZES); do \
		mkdir -pv $(DEST)/../../icons/hicolor/$${size}x$${size}/apps || true ; \
		ln -s -f -v -T $(DEST)/$(APP_ID)/$(ICONS_DIR)/$$size.png \
		$(DEST)/../../icons/hicolor/$${size}x$${size}/apps/nuvolaplayer3_$(APP_ID).png; \
	done

# Uninstall files
uninstall:
	rm -fv $(DEST)/../../icons/hicolor/scalable/apps/nuvolaplayer3_$(APP_ID).svg
	for size in $(ICON_SIZES); do \
		rm -fv $(DEST)/../../icons/hicolor/$${size}x$${size}/apps/nuvolaplayer3_$(APP_ID).png; \
	done
	rm -rfv $(DEST)/$(APP_ID)
