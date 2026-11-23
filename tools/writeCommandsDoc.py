"""Writes the command reference in docs/commands.md from the server's command list (B-4).

Only the text between the commands:start and commands:end markers is replaced; the rest of
the document is written by hand. Needs `lupa` (see tools/runTests.py). Run from anywhere:
    python tools/writeCommandsDoc.py
"""
import os
import re

from lupa import lua53

DOC_PATH = os.path.join("docs", "commands.md")

LOAD_SECTION = r'''
package.path = "./?.lua;Resources/Server/VRacerMP/?.lua;" .. package.path
local function findSharedModule(moduleName)
  local prefix = "vracerMP/shared/"
  if moduleName:sub(1, #prefix) ~= prefix then return nil end
  return loadfile("shared/" .. moduleName:sub(#prefix + 1) .. ".lua")
end
table.insert(package.searchers, 2, findSharedModule)
Util = { LogDebug = print, LogInfo = print, LogWarn = print, LogError = print }
return require("vracerMP/commands/commandsDoc").buildCommandSection()
'''


def main():
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    section = lua53.LuaRuntime().execute(LOAD_SECTION)
    with open(DOC_PATH, encoding="utf-8") as doc_file:
        document = doc_file.read()
    pattern = re.compile(r"<!-- commands:start.*?<!-- commands:end -->", re.DOTALL)
    if not pattern.search(document):
        raise SystemExit("markers not found in " + DOC_PATH)
    document = pattern.sub(lambda _: section, document)
    with open(DOC_PATH, "w", encoding="utf-8", newline="\n") as doc_file:
        doc_file.write(document)
    print("updated", DOC_PATH)


if __name__ == "__main__":
    main()
