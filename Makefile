# On Arch, lua52-busted installs the rock outside PATH, and its shebang points
# at lua 5.5, where the 5.2 modules do not exist. Use a busted on PATH if there
# is one (CI, most distros). If not, use the Arch rock path.
ARCH_BUSTED := /usr/lib/luarocks/rocks-5.2/busted/2.3.0-1/bin/busted
LUA         := lua5.2
BUSTED      := $(shell command -v busted 2>/dev/null)

ifeq ($(BUSTED),)
  RUN_BUSTED := $(LUA) $(ARCH_BUSTED) --lua=$(LUA)
else
  RUN_BUSTED := $(BUSTED)
endif

.PHONY: all setup fast check test pytest pytest-fast lint markdown links text ingame stamp \
        data preview wiki package version

LUA_FILES := hat mod prototypes spec tests control.lua data.lua \
             data-final-fixes.lua settings.lua
MARKDOWN   = $(shell git ls-files '*.md')

all: check

## once, after a clone: install the npm tools and activate the git hook
setup:
	npm ci
	git config core.hooksPath .githooks

## every commit (the git hook). It must stay under about 10 seconds.
fast: version pytest-fast test lint markdown links text

## before a PR: every check, with the in-game tests
check: version pytest test lint markdown links text ingame

## Lua test suite, under the Lua version that Factorio embeds
test:
	$(RUN_BUSTED)

## all the Python tests, the slow offline pipeline tests included
pytest:
	python3 -m pytest tools/tests -q

## the Python tests without the slow offline pipeline tests
pytest-fast:
	python3 -m pytest tools/tests -q -m "not slow and not pipeline"

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
	@# The mod portal wraps its text at about 540 px. The images in
	@# mod-description-long.md are copies at that width, so they line up with
	@# the text.
	mkdir -p docs/preview/portal
	for n in tiling bands-41-3; do \
	  rsvg-convert -w 540 docs/preview/$$n.svg -o docs/preview/portal/$$n.png; \
	done

lint:
	luacheck $(LUA_FILES)

markdown:
	npx --no-install markdownlint-cli2 $(MARKDOWN)

## the links inside the repository. weekly.yml checks the external ones.
links:
	lychee --offline --no-progress $(MARKDOWN)

## the prose in Markdown, locale files and code comments: the humanizer
## checker, cspell in en-GB and no en dashes. .ste-allow lists exceptions.
text:
	python3 -m tools.text_check

## the in-game tests in the Factorio headless server.
## MODE=base or MODE=space-age runs one mode. An empty MODE runs both.
ingame:
	tools/ingame.sh $(MODE)

## after /ste80-humanizer and /simplify: lets an agent commit pass the hook
stamp:
	python3 -m tools.review_stamp stamp

## check that info.json, the changelog and the tag agree
version:
	python3 -m tools.check_version

## build the distributable mod zip
package:
	python3 -m tools.package

## publish wiki/ to the GitHub wiki (first create one page in the web UI)
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
