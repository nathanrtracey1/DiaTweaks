CFLAGS := -arch arm64 -mmacosx-version-min=14.0 -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter
DYLIB_SOURCES := $(shell find src/dylib -name '*.[hm]')
DYLIB_SWIFT := $(shell find src/dylib -name '*.swift')
SDK := $(shell xcrun --show-sdk-path)
SWIFT_LIB := $(SDK)/usr/lib/swift
# FoundationModels is macOS 26+ only: weak-link it, stop Swift auto-linking it, and skip it when the SDK lacks it.
FOUNDATION_MODELS := $(if $(wildcard $(SDK)/System/Library/Frameworks/FoundationModels.framework),-weak_framework FoundationModels)
SWIFTFLAGS := -target arm64-apple-macos14.0 -O -parse-as-library -wmo -module-name DiaPatchesSwift \
	-Xfrontend -disable-autolink-framework -Xfrontend FoundationModels
PASSKEYS := src/dylib/Patches/Passkeys/extension
EXTENSION := $(foreach file,manifest.json page.js bridge.js worker.js,-Wl,-sectcreate,__TEXT,__pk_$(basename $(file)),$(PASSKEYS)/$(file))
PROVIDER_LOGOS := $(wildcard src/dylib/Patches/DiaChatModel/logos/*)
PROVIDER_IMAGES := $(foreach file,$(PROVIDER_LOGOS),-Wl,-sectcreate,__TEXT,__dp_$(basename $(notdir $(file))),$(file))

DYLIB_OBJS := $(patsubst src/dylib/%.m,build/obj/%.o,$(filter %.m,$(DYLIB_SOURCES)))
# diapatch records the commit it was built from, to tell a source build that is newer than the latest release from one that isn't.
COMMIT := $(shell git rev-parse HEAD 2>/dev/null)

all: build/diapatch build/DiaPatches.dylib build/patches.json

build/commit: FORCE | build
	@echo '$(COMMIT)' | cmp -s - $@ || echo '$(COMMIT)' > $@

FORCE:

build/diapatch: $(wildcard src/diapatch/*.[hm]) build/commit | build
	clang $(CFLAGS) -DDIATWEAKS_COMMIT='"$(COMMIT)"' -framework AppKit -framework CoreGraphics -framework Security -o $@ $(filter %.m,$^)

build/DiaPatchesSwift.o: $(DYLIB_SWIFT) | build
	swiftc $(SWIFTFLAGS) -emit-object -o $@ $^

build/obj/%.o: src/dylib/%.m
	@mkdir -p $(dir $@)
	clang $(CFLAGS) -Isrc/dylib -c -o $@ $<

build/DiaPatches.dylib: $(DYLIB_OBJS) build/DiaPatchesSwift.o $(wildcard $(PASSKEYS)/*) $(PROVIDER_LOGOS) | build
	clang $(CFLAGS) -Isrc/dylib -dynamiclib $(EXTENSION) $(PROVIDER_IMAGES) -framework AppKit -framework QuartzCore -framework Metal -framework UniformTypeIdentifiers -framework AVFoundation -framework VideoToolbox -framework CoreMedia -framework CoreVideo \
		-L$(SWIFT_LIB) -Wl,-rpath,/usr/lib/swift $(FOUNDATION_MODELS) -o $@ $(DYLIB_OBJS) build/DiaPatchesSwift.o

# With DIAPATCH_MANIFEST set, the dylib writes the patch list and exits as it loads, so diapatch never runs.
build/patches.json: build/DiaPatches.dylib build/diapatch
	DIAPATCH_MANIFEST=$@ DYLD_INSERT_LIBRARIES=$< build/diapatch

build:
	mkdir -p $@

GROUP_TABS := $(addprefix src/dylib/Commands/GroupTabs/,Plan.m Title.m Registrable.m Messages.m)

build/group-tabs: tests/group-tabs.m $(GROUP_TABS) | build
	clang $(CFLAGS) -Isrc/dylib -framework AppKit -o $@ $^

build/mouse-back-forward: tests/mouse-back-forward.m src/dylib/Patches/MouseBackForward/MouseBackForward.m src/dylib/StdPatch/Hook.m $(wildcard src/dylib/StdPatch/*.h) | build
	clang $(CFLAGS) -Isrc/dylib -framework AppKit -o $@ tests/mouse-back-forward.m src/dylib/StdPatch/Hook.m

SPLIT := src/dylib/Patches/SplitClientHello

build/split-client-hello: tests/split-client-hello.m $(wildcard $(SPLIT)/Split.[hm] $(SPLIT)/Write.[hm]) | build
	clang $(CFLAGS) -fsanitize=address,undefined -fno-sanitize-recover=all -Isrc/dylib -framework Foundation -o $@ \
		tests/split-client-hello.m $(SPLIT)/Split.m $(SPLIT)/Write.m

build/vertical-tab-glow: tests/vertical-tab-glow.m $(wildcard src/dylib/Patches/HideVerticalTabGlow/*.[hm]) | build
	clang $(CFLAGS) -Isrc/dylib -framework AppKit -framework QuartzCore -o $@ $<

build/profile-symbols: tests/profile-symbols.m src/dylib/Patches/ProfileEmoji/Symbols.m | build
	clang $(CFLAGS) -Isrc/dylib -framework AppKit -o $@ $^

build/peek-cursor: tests/peek-cursor.m src/dylib/Patches/Peek/Cursor.m src/dylib/Patches/Peek/Peek.h src/dylib/StdPatch/Hook.m $(wildcard src/dylib/StdPatch/*.h) | build
	clang $(CFLAGS) -Isrc/dylib -framework AppKit -o $@ $<

build/peek-link: tests/peek-link.m src/dylib/Patches/Peek/Link.m src/dylib/Patches/Peek/Peek.h $(wildcard src/dylib/StdPatch/*.h) | build
	clang $(CFLAGS) -Isrc/dylib -framework AppKit -o $@ tests/peek-link.m src/dylib/Patches/Peek/Link.m

build/safe-mode: tests/safe-mode.m src/dylib/SafeMode/SafeMode.m $(wildcard src/dylib/StdPatch/*.h) | build
	clang $(CFLAGS) -Isrc/dylib -framework AppKit -o $@ $<

build/hook-table: tests/hook-table.m src/dylib/StdPatch/Hook.m $(wildcard src/dylib/StdPatch/*.h) | build
	clang $(CFLAGS) -fsanitize=address -Isrc/dylib -framework AppKit -o $@ $<

TIDY := src/dylib/Patches/TidyTabs/Tabs.m src/dylib/Patches/CommandBar/Tabs.m src/dylib/Commands/GroupTabs/Messages.m

build/tidy-tabs: tests/tidy-tabs.m $(TIDY) | build
	clang $(CFLAGS) -Isrc/dylib -framework AppKit -framework QuartzCore -o $@ $^

build/drag-offset: tests/drag-offset.m src/dylib/Patches/CompactTabRows/CompactTabRows.m src/dylib/StdPatch/Hook.m src/dylib/StdPatch/Views.m $(wildcard src/dylib/StdPatch/*.h) | build
	clang $(CFLAGS) -Isrc/dylib -framework AppKit -o $@ tests/drag-offset.m src/dylib/StdPatch/Hook.m src/dylib/StdPatch/Views.m

build/little-dia-stack: tests/little-dia-stack.m src/dylib/Patches/LittleDia/Stack.m $(wildcard src/dylib/StdPatch/*.h) | build
	clang $(CFLAGS) -Isrc/dylib -framework AppKit -o $@ $<

build/tracking: tests/tracking.m src/dylib/Commands/GroupTabs/Tracking.m src/dylib/Commands/GroupTabs/Messages.m src/dylib/StdPatch/Hook.m src/dylib/StdPatch/Views.m $(wildcard src/dylib/StdPatch/*.h) | build
	clang $(CFLAGS) -Isrc/dylib -framework AppKit -o $@ tests/tracking.m src/dylib/StdPatch/Hook.m src/dylib/StdPatch/Views.m src/dylib/Commands/GroupTabs/Messages.m

build/little-dia-over: tests/little-dia-over.m src/dylib/Patches/LittleDia/Route.m src/dylib/StdPatch/Hook.m src/dylib/StdPatch/Views.m $(wildcard src/dylib/StdPatch/*.h) | build
	clang $(CFLAGS) -Isrc/dylib -framework AppKit -o $@ tests/little-dia-over.m src/dylib/StdPatch/Hook.m src/dylib/StdPatch/Views.m

build/launch-flags: tests/launch-flags.m src/dylib/StdPatch/Extensions.m src/dylib/StdPatch/Hook.m $(wildcard src/dylib/StdPatch/*.h) | build
	clang $(CFLAGS) -Isrc/dylib -framework AppKit -o $@ tests/launch-flags.m src/dylib/StdPatch/Hook.m

check: build/diapatch build/group-tabs build/mouse-back-forward build/vertical-tab-glow build/split-client-hello build/profile-symbols build/peek-cursor build/peek-link build/safe-mode build/hook-table build/tidy-tabs build/drag-offset build/launch-flags build/little-dia-stack build/little-dia-over build/tracking build/patches.json
	tests/tweaks-update
	build/group-tabs
	build/tidy-tabs
	build/mouse-back-forward
	build/vertical-tab-glow
	build/split-client-hello
	build/profile-symbols
	build/peek-cursor
	build/peek-link
	build/safe-mode
	build/hook-table
	build/drag-offset
	build/launch-flags
	build/little-dia-stack
	build/tracking
	build/little-dia-over
	tests/sidebar-grain
	tests/agent-transport
	tests/chat-models
	tests/providers
	scripts/check-patches

test: build/DiaPatches.dylib
	./test.sh

patch:
	@scripts/new-patch "$(NAME)"

clean:
	rm -rf build

.PHONY: all check clean test patch
