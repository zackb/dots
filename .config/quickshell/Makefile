# Build artifacts the shell needs at runtime:
#   * shaders -- wallpaper transitions are GLSL fragment shaders Qt loads in
#     their baked .qsb form, so every .frag must be compiled with qsb.
#   * backend -- the Go backend daemon (backend/fenrizd) the shell launches.
#
# `make` builds everything; `make shaders` / `make backend` build one half.

QSB      ?= /usr/lib/qt6/bin/qsb
QSBFLAGS ?= --qt6

SHADER_DIR := wallpaper/shaders
SHADER_SRC := $(wildcard $(SHADER_DIR)/*.frag)
SHADER_OUT := $(SHADER_SRC:.frag=.frag.qsb)

BACKEND_DIR := backend
BACKEND_BIN := $(BACKEND_DIR)/fenrizd
BACKEND_SRC := $(shell find $(BACKEND_DIR) -name '*.go') $(BACKEND_DIR)/go.mod

.PHONY: all shaders backend clean clean-shaders clean-backend
all: shaders backend

# shaders
shaders: $(SHADER_OUT)

$(SHADER_DIR)/%.frag.qsb: $(SHADER_DIR)/%.frag
	$(QSB) $(QSBFLAGS) $< -o $@

# backend daemon
backend: $(BACKEND_BIN)

$(BACKEND_BIN): $(BACKEND_SRC)
	cd $(BACKEND_DIR) && go build -o fenrizd .

# cleanup
clean: clean-shaders clean-backend
clean-shaders:
	rm -f $(SHADER_OUT)
clean-backend:
	rm -f $(BACKEND_BIN)
