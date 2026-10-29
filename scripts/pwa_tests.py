#!/usr/bin/env python3
"""Cruza los tests de la PWA con los de la app: cada test de la PWA tiene que tener uno en Swift
con el mismo `describe` (@Suite) y el mismo nombre (@Test), o estar en
docs/pwa-tests-no-aplican.tsv con el motivo. Los unitarios se nombran por su fichero
(`dates.test.js`, en tests/unit) y los e2e con su carpeta (`e2e/routine.spec.js`, en tests/e2e).

Uso: scripts/pwa_tests.py <repo de la PWA> [<fichero>...] [--markdown | --check-table]
Sin ficheros, todos los de la PWA (tests/unit/*.test.js y tests/e2e/*.spec.js): un fichero nuevo
de la PWA sale solo.
Sale con error si falta alguno. Con --markdown imprime la tabla de docs/paridad.md; con
--check-table, falla también si esa tabla no es la que sale ahora (hay que regenerarla).
"""
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT_TESTS = [ROOT / "Packages/GymCore/Tests", ROOT / "UITests"]
NOT_APPLICABLE = ROOT / "docs/pwa-tests-no-aplican.tsv"
PARITY = ROOT / "docs/paridad.md"

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
        name = name.replace("\\'", "'").replace('\\"', '"')
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


def pwa_files(pwa):
    """Los ficheros de tests de la PWA: los unitarios por su nombre y los e2e con su carpeta."""
    tests = pwa / "tests"
    return ([p.name for p in sorted((tests / "unit").glob("*.test.js"))]
            + [f"e2e/{p.name}" for p in sorted((tests / "e2e").glob("*.spec.js"))])


def table(rows):
    lines = ["| Test de la PWA | Test nativo | Notas |", "|---|---|---|"]
    for name, describe, test, native, reason in rows:
        label = f"`{name}` › {describe} › {test}".replace("|", "\\|")
        lines.append(f"| {label} | {native if native == '—' else '`' + native.split('/')[-1] + '`'} | {reason.replace('|', '/')} |")
    return lines


def main(argv):
    markdown, check = "--markdown" in argv, "--check-table" in argv
    args = [a for a in argv if a not in ("--markdown", "--check-table")]
    pwa, files = Path(args[0]), args[1:]
    if not files:
        files = pwa_files(pwa)
    ported, skipped = swift_tests(), not_applicable()
    rows, missing = [], []
    for name in files:
        for describe, test in js_tests(pwa / "tests" / (name if "/" in name else "unit/" + name)):
            if (describe, test) in ported:
                rows.append((name, describe, test, ported[(describe, test)], ""))
            elif (name, describe, test) in skipped:
                rows.append((name, describe, test, "—", skipped[(name, describe, test)]))
            else:
                missing.append((name, describe, test))
    if markdown:
        print("\n".join(table(rows)))
    stale = False
    if check:
        current = [l for l in PARITY.read_text().splitlines() if l.startswith("|")]
        stale = current != table(rows)
        if stale:
            print("docs/paridad.md no está al día: regenerar la tabla con --markdown.", file=sys.stderr)
    total = len(rows) + len(missing)
    print(f"\n{len(rows) - sum(1 for r in rows if r[3] == '—')} portados, {sum(1 for r in rows if r[3] == '—')} no aplican, "
          f"{len(missing)} sin portar, de {total}.", file=sys.stderr)
    for name, describe, test in missing:
        print(f"FALTA {name} › {describe} › {test}", file=sys.stderr)
    return 1 if missing or stale else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
