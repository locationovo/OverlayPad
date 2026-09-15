UNAME_S := $(shell uname -s 2>/dev/null)
ifeq ($(strip $(UNAME_S)),)
$(error cannot determine host OS: uname failed)
endif

JBROOT_DIR := $(shell find /var/containers/Bundle/Application/ -maxdepth 1 \
                -name '.jbroot-*' \
                -exec test -d '{}/usr/share/SDKs/iPhoneOS.sdk' \; -print -quit \
                2>/dev/null)

ifneq ($(JBROOT_DIR),)
  HOST_KIND := iOS
  SDK ?= $(JBROOT_DIR)/usr/share/SDKs/iPhoneOS.sdk
  CC  := clang
  LD  := clang
else ifeq ($(UNAME_S),Darwin)
  HOST_KIND := macOS
  SDK ?= $(shell xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)
  CC  := $(shell xcrun --sdk iphoneos -f clang 2>/dev/null)
  ifeq ($(CC),)
  CC  := clang
  endif
  LD  := $(CC)
else ifeq ($(UNAME_S),Linux)
  HOST_KIND := Linux
  SDK ?=
  CC  := clang
  LD  := clang
else
  HOST_KIND := unsupported
  SDK ?=
  CC  := clang
  LD  := clang
endif

ARCH     ?= arm64
MIN_IOS  ?= 15.0
TARGET   ?= OverlayPad.dylib
DEBUG    ?= 0
TAGS     ?=
LIDID    ?= ldid

VERSION_BASE := $(shell sed 's|//.*||' VERSION 2>/dev/null \
              | grep -v '^[[:space:]]*$$' | head -1 | tr -d '[:space:]')
VERSION_BASE := $(if $(VERSION_BASE),$(VERSION_BASE),0.0.0)
BUILD_DATE   := $(shell date +%Y%m%d)
GIT_HASH     := $(shell git rev-parse --short=7 HEAD 2>/dev/null)
GIT_DIRTY    := $(shell git status --porcelain 2>/dev/null | head -1)

ifneq ($(GIT_HASH),)
VERSION_STR := v$(VERSION_BASE)$(if $(TAGS),-$(TAGS),)-$(BUILD_DATE)-$(GIT_HASH)$(if $(GIT_DIRTY),-dirty)
else
VERSION_STR := v$(VERSION_BASE)$(if $(TAGS),-$(TAGS),)-nogit-$(BUILD_DATE)
endif

STYLE_SRCS := $(wildcard styles/*.m)
SRCS := main.m Common.m Localization.m Settings.m Input.m Pad.m HUD.m Injector.m \
        About.m AboutContent.m Style.m DebugConsole.m Presets.m $(STYLE_SRCS)
OBJS := $(SRCS:.m=.o)
DEPS := $(OBJS:.o=.d)

AVATAR_DEP := $(if $(wildcard avatar.png),avatar_data.h)
ifneq ($(AVATAR_DEP),)
CFLAGS += -DJOY_HAS_AVATAR
endif

CFLAGS += -target $(ARCH)-apple-ios$(MIN_IOS) \
         -isysroot $(SDK) \
         -DDEBUG=$(DEBUG) \
         -DAPP_VERSION=\"$(VERSION_STR)\" \
         -fobjc-arc -fPIC -fblocks \
         -Os -g0 -MMD -MP \
         -Wall -Wextra \
         -Wno-unused-parameter -Wno-unused-variable -Wno-unused-function \
         -I.

LDFLAGS = -target $(ARCH)-apple-ios$(MIN_IOS) \
          -isysroot $(SDK) \
          -dynamiclib \
          -install_name @rpath/$(TARGET) \
          -framework UIKit -framework Foundation \
          -framework CoreGraphics -framework QuartzCore \
          -framework GameController

.PHONY: all check-sdk sign clean install info

all: check-sdk $(TARGET)

check-sdk:
	@echo "[host] $(HOST_KIND)"
	@case "$(HOST_KIND)" in \
	  iOS|macOS) ;; \
	  Linux) echo "!! host Linux cannot build iOS dylib (need macOS + Xcode or jailbroken iOS)" >&2; exit 1 ;; \
	  *) echo "!! unsupported host: '$(UNAME_S)' (need macOS + Xcode or jailbroken iOS)" >&2; exit 1 ;; \
	esac
	@test -n "$(SDK)" || { echo "!! empty SDK path (HOST_KIND=$(HOST_KIND))" >&2; exit 1; }
	@test -d "$(SDK)"  || { echo "!! SDK not a directory: $(SDK)" >&2; exit 1; }
	@test -d "$(SDK)/System/Library/Frameworks/UIKit.framework" || \
	  { echo "!! not a valid iPhoneOS SDK: $(SDK)" >&2; exit 1; }

avatar_data.h: avatar.png
	@printf '// auto-generated\n#pragma once\nstatic const char g_avatar_b64[] =\n"%s";\n' \
	  "$$(base64 avatar.png | tr -d '\n')" > $@

%.o: %.m $(AVATAR_DEP)
	@mkdir -p $(dir $@)
	@echo "  CC  $<"
	@$(CC) $(CFLAGS) -c $< -o $@

$(TARGET): $(OBJS)
	@echo "  LD  $@"
	@$(LD) $(LDFLAGS) -o $@ $(OBJS)
	@ls -lh $@

sign: $(TARGET)
	@if command -v $(LIDID) >/dev/null 2>&1; then $(LIDID) -S $<; echo "==> signed"; \
	 else echo "!! ldid not found"; fi

install: sign
	@test -n "$(DEST)" || { echo "usage: make install DEST=<dir>"; exit 1; }
	@mkdir -p "$(DEST)" && cp $(TARGET) "$(DEST)/" && echo "==> $(DEST)/$(TARGET)"

clean:
	@rm -f $(OBJS) $(DEPS) $(TARGET) avatar_data.h

info:
	@echo "[host] $(HOST_KIND)"
	@echo "SDK     = $(SDK)"
	@echo "CC      = $(CC)"
	@echo "LD      = $(LD)"
	@echo "ARCH    = $(ARCH)  MIN_IOS = $(MIN_IOS)"
	@echo "DEBUG   = $(DEBUG)"
	@echo "TAGS    = $(TAGS)"
	@echo "VERSION = $(VERSION_STR)"
	@echo "AVATAR  = $(if $(AVATAR_DEP),yes,no)"
	@echo "STYLES  = $(STYLE_SRCS)"

-include $(DEPS)