#!/usr/bin/env python3
"""Moves Korean string literals out of Swift sources and into a JSON language pack.

Run once to migrate, and again after adding new Korean literals; it is idempotent, since
already-extracted strings no longer appear as literals.

Keys are `<fileSlug>.<sha1(template)[:8]>`. Hashing the *template* rather than using a positional
index means a key survives code moving around, and changing the wording deliberately produces a
new key — a changed sentence needs a re-translation anyway.

Swift interpolations become `%@` placeholders and are passed as arguments, so translators can
reorder text around a value without touching code.
"""
import hashlib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCES = ROOT / "Sources/Pawprint"
PACK_DIR = SOURCES / "Resources/Localization"
HANGUL = re.compile(r"[가-힣]")

# Files that must not be rewritten: the localization runtime itself, and debug-only tooling whose
# output is developer-facing.
SKIP = {"Localization.swift", "DebugSnapshot.swift"}


def split_interpolations(body: str):
    """Returns (template with %@ placeholders, [swift expressions])."""
    template, args = "", []
    i = 0
    while i < len(body):
        if body.startswith("\\(", i):
            depth, j = 1, i + 2
            while j < len(body) and depth:
                if body[j] == "(":
                    depth += 1
                elif body[j] == ")":
                    depth -= 1
                elif body[j] == '"':          # skip nested string literals
                    j += 1
                    while j < len(body) and body[j] != '"':
                        j += 2 if body[j] == "\\" else 1
                j += 1
            args.append(body[i + 2:j - 1])
            template += "%@"
            i = j
        else:
            template += body[i]
            i += 1
    return template, args


def find_literals(text: str):
    """Yields (start, end, inner) for every double-quoted literal outside comments.

    Comments matter: documentation quotes Korean examples, and rewriting those into `L10n.t`
    calls silently destroys the prose while still compiling.
    """
    i = 0
    while i < len(text):
        if text.startswith("//", i):
            nl = text.find("\n", i)
            i = len(text) if nl < 0 else nl + 1
            continue
        if text.startswith("/*", i):
            close = text.find("*/", i + 2)
            i = len(text) if close < 0 else close + 2
            continue
        if text[i] == '"':
            # Multi-line literals are left alone; none of them carry UI copy.
            if text.startswith('"""', i):
                end = text.find('"""', i + 3)
                i = len(text) if end < 0 else end + 3
                continue
            j, depth = i + 1, 0
            while j < len(text):
                c = text[j]
                if c == "\\":
                    j += 2
                    if text[j - 1] == "(":
                        depth += 1
                    continue
                if depth:
                    if c == "(":
                        depth += 1
                    elif c == ")":
                        depth -= 1
                elif c == '"':
                    break
                elif c == "\n":
                    break
                j += 1
            if j < len(text) and text[j] == '"':
                yield i, j + 1, text[i + 1:j]
                i = j + 1
                continue
        i += 1


def main(apply: bool):
    pack = {}
    if (PACK_DIR / "ko.json").exists():
        pack = json.loads((PACK_DIR / "ko.json").read_text())

    changed_files = 0
    for path in sorted(SOURCES.rglob("*.swift")):
        if path.name in SKIP:
            continue
        text = path.read_text()
        slug = path.stem[0].lower() + path.stem[1:]
        pieces, last, count = [], 0, 0

        for start, end, inner in find_literals(text):
            if not HANGUL.search(inner):
                continue
            template, args = split_interpolations(inner)
            key = f"{slug}.{hashlib.sha1(template.encode()).hexdigest()[:8]}"
            pack[key] = template
            call = f'L10n.t("{key}"' + "".join(f", {a}" for a in args) + ")"
            pieces.append(text[last:start])
            pieces.append(call)
            last = end
            count += 1

        if count:
            pieces.append(text[last:])
            if apply:
                path.write_text("".join(pieces))
            changed_files += 1
            print(f"  {count:4d}  {path.relative_to(SOURCES)}")

    print(f"\n{len(pack)} keys across {changed_files} files")
    if apply:
        # The script is idempotent, so a second run finds no literals. Without this guard that
        # would overwrite a complete pack with an empty one — which is exactly what happened once.
        if not pack:
            print("refusing to write an empty pack (nothing left to extract)")
            return
        PACK_DIR.mkdir(parents=True, exist_ok=True)
        (PACK_DIR / "ko.json").write_text(
            json.dumps(pack, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
        )
        print(f"wrote {PACK_DIR / 'ko.json'}")


if __name__ == "__main__":
    main(apply="--apply" in sys.argv)
