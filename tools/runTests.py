"""Runs tests/runAll.lua on Lua 5.3 (BeamMP server) and LuaJIT (BeamNG client).

Needs the `lupa` package, which bundles both Lua versions:
    python -m pip install --user lupa
Run from anywhere:
    python tools/runTests.py
"""
import importlib
import os
import sys

RUNTIMES = [
    ("Lua 5.3 (server)", "lupa.lua53"),
    ("LuaJIT (client)", "lupa.luajit21"),
]


def run_on_runtime(label, module_name):
    print(f"=== {label} ===", flush=True)
    runtime = importlib.import_module(module_name).LuaRuntime()
    runtime.execute("RUNNING_FROM_PYTHON = true")
    failures = runtime.execute('return dofile("tests/runAll.lua")')
    sys.stdout.flush()
    return int(failures or 0)


def main():
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    total_failures = sum(run_on_runtime(label, module) for label, module in RUNTIMES)
    print("ALL PASSED" if total_failures == 0 else f"{total_failures} FAILURES")
    return 0 if total_failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
