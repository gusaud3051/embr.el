CC       ?= gcc
EMACS    ?= emacs
PKG_CONFIG ?= pkg-config
CFLAGS   ?= -O2 -Wall -Wextra -fPIC
LDFLAGS  ?= -shared
LIBS     ?= $(shell $(PKG_CONFIG) --libs libjpeg 2>/dev/null || echo -ljpeg)
# App bundles keep the header beside Resources/etc, outside compiler defaults.
# EMACS_INCLUDE can also point to the headers of a custom/patched Emacs build.
EMACS_INCLUDE ?= $(shell "$(EMACS)" -Q --batch --eval \
  '(princ (or (seq-find (lambda (dir) (file-exists-p (expand-file-name "emacs-module.h" dir))) (list (expand-file-name "../include" data-directory) (expand-file-name "../include" invocation-directory) "/opt/homebrew/include" "/usr/local/include" "/usr/include")) ""))')
CPPFLAGS += $(if $(EMACS_INCLUDE),-I"$(EMACS_INCLUDE)") $(shell $(PKG_CONFIG) --cflags libjpeg 2>/dev/null)
ASAN_CFLAGS ?= -O0 -g3 -Wall -Wextra -fPIC -fno-omit-frame-pointer -fsanitize=address,undefined
ASAN_LDFLAGS ?= -shared -fsanitize=address,undefined

TARGET = embr-canvas.so
ASAN_TARGET = embr-canvas-asan.so

all: $(TARGET)

$(TARGET): embr-canvas.c Makefile
	$(CC) $(CPPFLAGS) $(CFLAGS) -o $@ $< $(LDFLAGS) $(LIBS)

asan: $(ASAN_TARGET)

$(ASAN_TARGET): embr-canvas.c Makefile
	$(CC) $(CPPFLAGS) $(ASAN_CFLAGS) -o $@ $< $(ASAN_LDFLAGS) $(LIBS)

clean:
	rm -f $(TARGET) $(ASAN_TARGET)

.PHONY: all asan clean
