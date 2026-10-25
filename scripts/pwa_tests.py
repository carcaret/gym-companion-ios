#!/usr/bin/env python3
"""Cruza los tests unitarios de la PWA con los de la app: cada test de la PWA tiene que tener
uno en Swift con el mismo `describe` (@Suite) y el mismo nombre (@Test), o estar en
docs/pwa-tests-no-aplican.tsv con el motivo.

Uso: scripts/pwa_tests.py <repo de la PWA> [<fichero>...] [--markdown]
Los ficheros, relativos a tests/unit/ o, con carpeta, a tests/ (p. ej. e2e/sync-ui.spec.js).
Sin ficheros, los de docs/pwa-tests-ficheros.txt.
Sale con error si falta alguno. Con --markdown imprime la tabla para el PR.
"""
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT_TESTS = [ROOT / "Packages/GymCore/Tests", ROOT / "UITests", ROOT / "AppTests"]
NOT_APPLICABLE = ROOT / "docs/pwa-tests-no-aplican.tsv"
PORTED_FILES = ROOT / "docs/pwa-tests-ficheros.txt"

JS_BLOCK = re.compile(r"^(\s*)(test\.describe|describe|test|it)\(\s*(['\"`])(.*?)\3\s*,")
SWIFT_SUITE = re.compile(r'@Suite\("((?:[^"\\]|\\.)*)"')
SWIFT_TEST = re.compile(r'@Test\("((?:[^"\\]|\\.)*)"')
SWIFT_TYPE = re.compile(r"^\s*(?:private |fileprivate )?struct (\w+)")


def js_tests(path):
    """[(describe, test)] del fichero; el describe es el más cercano con menos sangría."""
    stack, out = [], []
    for line in path.read_text().splitlines():
        m = JS_BLOCK.match(line)
        if not m:
            continue
        indent, kind, name = len(m.group(1)), m.group(2), m.group(4)
        stack = [(i, n) for i, n in stack if i < indent]
        if kind.endswith("describe"):
            stack.append((indent, name))
        else:
            out.append((stack[-1][1] if stack else "", name))
    return out


def swift_tests():
    """{(suite, test): "Fichero.swift: Tipo"}."""
    found = {}
    for base in SWIFT_TESTS:
        for path in sorted(base.rglob("*.swift")) if base.exists() else []:
            suite = None
            for line in path.read_text().splitlines():
                if m := SWIFT_SUITE.search(line):
                    suite = m.group(1).replace('\\"', '"')
                elif m := SWIFT_TEST.search(line):
                    found.setdefault((suite, m.group(1).replace('\\"', '"')), f"{path.relative_to(ROOT)}")
    return found


def not_applicable():
    if not NOT_APPLICABLE.exists():
        return {}
    with NOT_APPLICABLE.open() as f:
        return {(r["fichero"], r["describe"], r["test"]): r["motivo"] for r in csv.DictReader(f, delimiter="\t")}


def main(argv):
    markdown = "--markdown" in argv
    args = [a for a in argv if a != "--markdown"]
    pwa, files = Path(args[0]), args[1:]
    if not files:
        files = [l.strip() for l in PORTED_FILES.read_text().splitlines() if l.strip() and not l.startswith("#")]
    ported, skipped = swift_tests(), not_applicable()
    rows, missing = [], []
    for name in files:
        for describe, test in js_tests(pwa / "tests" / (name if "/" in name else f"unit/{name}")):
            if (describe, test) in ported:
                rows.append((name, describe, test, ported[(describe, test)], ""))
            elif (name, describe, test) in skipped:
                rows.append((name, describe, test, "—", skipped[(name, describe, test)]))
            else:
                missing.append((name, describe, test))
    if markdown:
        print("| Test de la PWA | Test nativo | Notas |\n|---|---|---|")
        for name, describe, test, native, reason in rows:
            label = f"`{name}` › {describe} › {test}".replace("|", "\\|")
            print(f"| {label} | {native if native == '—' else '`' + native.split('/')[-1] + '`'} | {reason.replace('|', '/')} |")
    total = len(rows) + len(missing)
    print(f"\n{len(rows) - sum(1 for r in rows if r[3] == '—')} portados, {sum(1 for r in rows if r[3] == '—')} no aplican, "
          f"{len(missing)} sin portar, de {total}.", file=sys.stderr)
    for name, describe, test in missing:
        print(f"FALTA {name} › {describe} › {test}", file=sys.stderr)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
