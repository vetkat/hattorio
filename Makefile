# lua52-busted on Arch installs the rock off PATH and its shebang points at
# lua 5.5, where the 5.2 modules do not exist. Prefer a busted on PATH (CI,
# most distros) and fall back to the Arch rock path.
ARCH_BUSTED := /usr/lib/luarocks/rocks-5.2/busted/2.3.0-1/bin/busted
LUA         := lua5.2
BUSTED      := $(shell command -v busted 2>/dev/null)

ifeq ($(BUSTED),)
  RUN_BUSTED := $(LUA) $(ARCH_BUSTED) --lua=$(LUA)
else
  RUN_BUSTED := $(BUSTED)
endif

.PHONY: all test pytest lint data check preview wiki

all: check

## Lua test suite, under the version Factorio embeds
test:
	$(RUN_BUSTED)

## offline pipeline tests
pytest:
	python3 -m pytest tools/tests -q

## regenerate data/ and the test fixtures
data:
	python3 -m tools.emit_lua
	python3 -m tools.export_golden

## regenerate the preview images
preview:
	$(LUA) tools/render.lua 5 12 340 docs/preview/tiling.svg
	rsvg-convert -w 900 docs/preview/tiling.svg -o docs/preview/tiling.png
	for s in 15 26 41 52; do \
	  $(LUA) tools/render_bands.lua $$s 2 320 docs/preview/bands-$$s-2.svg && \
	  rsvg-convert -w 900 docs/preview/bands-$$s-2.svg -o docs/preview/bands-$$s-2.png; \
	done

lint:
	luacheck hat spec

check: pytest test lint

## publish wiki/ to the GitHub wiki (needs one page created in the UI first)
wiki:
	@rm -rf .wiki-tmp
	git clone -q git@github.com:vetkat/hattorio.wiki.git .wiki-tmp || \
	  { echo "Wiki repo does not exist yet. Create any page at"; \
	    echo "  https://github.com/vetkat/hattorio/wiki"; \
	    echo "then re-run 'make wiki'."; exit 1; }
	@# sync, not copy: pages removed from wiki/ should disappear from the wiki
	rm -f .wiki-tmp/*.md
	cp wiki/*.md .wiki-tmp/
	rm -f .wiki-tmp/README.md
	cd .wiki-tmp && git add -A && \
	  (git diff --cached --quiet || git commit -q -m "Update wiki from wiki/") && \
	  git push -q
	@rm -rf .wiki-tmp
	@echo "wiki published: https://github.com/vetkat/hattorio/wiki"
