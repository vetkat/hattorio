# busted for Lua 5.2 is installed as a rock, not on PATH.
BUSTED := /usr/lib/luarocks/rocks-5.2/busted/2.3.0-1/bin/busted
LUA    := lua5.2

.PHONY: all test pytest lint data check

all: check

## run the Lua test suite under Lua 5.2 (the version Factorio embeds)
test:
	$(LUA) $(BUSTED) --lua=$(LUA)

## run the offline pipeline tests
pytest:
	python3 -m pytest tools/tests -q

## regenerate data/*.lua and spec fixtures
data:
	python3 -m tools.emit_lua
	python3 -m tools.export_golden

## lint
lint:
	luacheck hat spec || true

## everything
check: pytest test lint
