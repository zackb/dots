# The wallpaper transitions are GLSL fragment shaders that Qt loads in their
# baked .qsb form, so every .frag must be compiled with qsb after editing.
# `make shaders` (re)builds any that are out of date.

QSB      ?= /usr/lib/qt6/bin/qsb
QSBFLAGS ?= --qt6

SHADER_DIR := wallpaper/shaders
SHADER_SRC := $(wildcard $(SHADER_DIR)/*.frag)
SHADER_OUT := $(SHADER_SRC:.frag=.frag.qsb)

.PHONY: all shaders clean-shaders
all: shaders

shaders: $(SHADER_OUT)

$(SHADER_DIR)/%.frag.qsb: $(SHADER_DIR)/%.frag
	$(QSB) $(QSBFLAGS) $< -o $@

clean-shaders:
	rm -f $(SHADER_OUT)
