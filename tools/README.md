# tools/

Offline pipeline. Not shipped with the mod. Requires Python 3.11+, stdlib only.

    python3 -m tools.emit_lua      # regenerate data/*.lua
    python3 -m tools.export_golden # regenerate spec fixtures
    python3 -m pytest tools/tests  # pipeline tests
