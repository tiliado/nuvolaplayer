#!/usr/bin/make -f

NAME = testcase
PACKAGES    = glib-2.0 dioriteglib-0.1 gtk+-3.0 javascriptcoregtk-3.0 webkit2gtk-3.0
BUILD = ../build
OUT    = $(BUILD)/tests
RUN = $(OUT)/run
VALAC        ?= valac
VALAFLAGS   ?=  
CC ?= gcc
CFLAGS ?= -g -O2
LDFLAGS ?= 
TESTGEN ?= diorite-testgen 
VALA_FILES = $(wildcard *.vala)
C_FILES=$(patsubst %.vala,$(OUT)/%.c, $(VALA_FILES))
O_FILES = $(C_FILES:c=o)
H_FILE = $(OUT)/$(NAME).h
VAPI_FILE = $(OUT)/$(NAME).vapi
CFLAGS += -I$(OUT) -I$(BUILD)
CFLAGS += $(shell pkg-config --cflags $(PACKAGES))
LDFLAGS += -L$(OUT) -L$(BUILD) -lnuvolaplayer3-base -lnuvolaplayer3-runner
LDFLAGS += $(shell pkg-config --libs $(PACKAGES))
VALAFLAGS += --vapidir $(OUT) --vapidir $(BUILD) --vapidir ../vapi
VALAFLAGS += $(PACKAGES:%=--pkg=%)
VALAFLAGS += --pkg nuvolaplayer3-runner --pkg nuvolaplayer3-base
LIBPREFIX = lib
LIBSUFFIX = .so
LIBRARYSO=$(LIBPREFIX)$(NAME)$(LIBSUFFIX)

run: all
	LD_LIBRARY_PATH=".:$(OUT):$(BUILD)" $(RUN)/$(NAME)

all: $(RUN)/$(NAME)


$(RUN):
	mkdir -p $(RUN)

$(RUN)/$(NAME): $(RUN)/$(NAME).o
	$(CC) $< -o $@ $(LDFLAGS) -l$(NAME) 

$(RUN)/$(NAME).o: $(RUN)/$(NAME).c
	$(CC) $^ -c -o $@ -fPIC '-DG_LOG_DOMAIN="NuvolaTest"' $(CFLAGS)
	
$(RUN)/$(NAME).c: $(RUN)/$(NAME).vala $(OUT)/$(LIBRARYSO)
	$(VALAC) -C -d $(OUT) -b $(OUT) --thread -v \
	--target-glib=2.32 --pkg $(NAME) $(VALAFLAGS) $<

$(RUN)/$(NAME).vala: $(VALA_FILES) | $(RUN)
	$(TESTGEN) -o $@ $(VALA_FILES)

$(OUT)/$(LIBRARYSO): $(O_FILES)
	$(CC) $^ -o $@ -shared $(LDFLAGS)

%.o : %.c
	$(CC) $^ -c -o $@ -fPIC '-DG_LOG_DOMAIN="NuvolaTest"' $(CFLAGS)

$(C_FILES) : $(VALA_FILES)
	$(VALAC) -C -d $(OUT) -b . --thread -v \
	--library=$(NAME) -H $(H_FILE)  \
	--target-glib=2.32 $(VALAFLAGS) $(VALA_FILES)

clean:
	rm -rf $(C_FILES) $(H_FILE)  $(VAPI_FILE) $(O_FILES) $(LIBRARYSO) $(RUN)
