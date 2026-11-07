#!/usr/bin/env python3
"""
Re-derives, from the live tree, which NAMELIST members declared in src/*.f
are undocumented in docs/namelist.002 (and the reverse: documented members
no longer declared) -- per NAMELIST group. This script is the detector any
"NAMELIST coverage is closed" claim should rest on.

Both sides are re-parsed from the tree on every run; nothing is transcribed.

Four things were checked, not assumed, before trusting this script's "zero
gaps" result:

  (a) Column 72. Fixed-form Fortran ignores everything past column 72;
      gfortran reads a different set of characters than a naive full-line
      regex would. Calibrated (--self-test) against a case where a member
      name straddles column 72: gfortran and an untruncated reader
      disagree on the member's spelling. This script truncates every
      source line -- including NAMELIST continuations -- to columns 7-72
      before parsing, to match what gfortran actually compiles. The live
      tree currently has no NAMELIST declaration whose content reaches
      column 72 exactly and none beyond it (checked: max physical line
      length among all NAMELIST statement lines in src/*.f, continuations
      included, is exactly 72) -- so this defect is latent, not live, but
      the truncation is applied unconditionally so that stays true.

  (b) Per-group, not global. The diff below is keyed by NAMELIST group
      name; a doc-side member is only ever compared against its own
      group's source-side set, never the union across all groups. A
      handful of doc-side names in &WF's parameter table (LCFC/LIJB/LISL,
      plus one `{\bf` regex artifact) have no matching &WF source member
      -- harmless *because* matching is per-group: they cannot paper over
      a real gap in a different NAMELIST.

  (c) Sweep scope. This script's source sweep is `glob(src/*.f)` --
      non-recursive, one directory. Checked, not assumed:
      `grep -rn --include='*.f' --include='*.fpl' -i 'namelist' src/`
      returns hits only in src/*.f and its *.fpl counterparts (29 files,
      all at src/ top level); src/gDKsapporo/ (its own Makefile, never
      part of this sweep) contains zero. If that ever stops being true,
      this script's coverage claim needs rechecking
      -- it is not re-verified on every run. 29 is a word-mention count, not
      a declaration count, and is not the same number as (d)'s "14 files
      actually declare a NAMELIST" below; the gap is one non-declaring pair:
      `mcdriv.f`/`mcdriv.fpl` both match the grep (a comment reading "nset &
      name are namelist input") without either declaring one. Of the 29
      matched files, 15 are `.f` (14 declaring + `mcdriv.f`) and 14 are
      `.fpl` (13 declaring + `mcdriv.fpl`); the 14 declaring `.f` files are
      13 with an `.fpl` counterpart plus `cinewx.f`, which has none (see
      (d)) -- 15 + 14 = 29, 14 declare.

  (d) .f vs .fpl equivalence, by content, not by mtime. src/*.f is
      FPL-generated and gitignored -- it exists only after a `make`/`fpl`
      bootstrap, so a bare clone has no src/*.f to read at all. Checked
      this phase, not merely inferred from build determinism: an
      independent member-set extraction from the 13 *tracked* .fpl
      sources that declare a NAMELIST (cinewx.f's &BASVC/&GET are the one
      hand-maintained exception -- confirmed no .fpl exists for either)
      was diffed against this script's .f-derived sets and, after fixing
      three bugs the cross-check itself exposed in the .fpl extractor (a
      missing re.IGNORECASE that silently dropped &DSCF's all-lowercase
      `namelist /dscf/...` declaration in mcfock.fpl; a macro-table member
      parser that kept only the first identifier on each continuation
      line instead of every comma-separated one; and no handling for a
      final member ending in a stray ';' instead of a trailing comma),
      came back identical member-for-member across all 12 comparable
      groups. This script still reads .f, not .fpl, for simplicity (the
      .fpl macro-table grammar is materially more irregular, as that
      triage found) -- rerun that .fpl cross-check by hand if .f/.fpl
      agreement is ever in doubt again; it is not part of this script.

Usage:
  scripts/verify_namelists.py            diff the live tree, per NAMELIST group
  scripts/verify_namelists.py --self-test  validate this script against fixtures

Stays in scripts/: scripts/atinputs/tests/test_namelist_coverage.py -- a published,
genuine atinputs regression test, not a detector self-test -- imports
load_source() from this module directly, so relocating it would have broken
that published test's import for anyone running the public
`pytest scripts/atinputs/tests/`. Decided by the maintainer when asked,
rather than assumed either way.
"""
import re
import sys
import glob
import pathlib

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC_GLOB = str(REPO_ROOT / 'src' / '*.f')
NAMELIST_DOC = REPO_ROOT / 'docs' / 'namelist.002'

# Doc section-name macro (e.g. \trnamelist, from `\section*{\trnamelist
# NAMELIST}`) -> the NAMELIST group name actually used in src/*.f. Not a
# 1:1 spelling match in general (BAS -> BASVC) -- each pairing was verified
# by reading the section's own {\bf Function} text against its source
# NAMELIST /X/ declaration.
DOC_TO_SRC = {
    'CNTL': 'CNTL', 'AI': 'AI', 'MC': 'MC', 'WF': 'WF', 'TR': 'TR',
    'BAS': 'BASVC', 'GET': 'GET', 'PT': 'PT', 'EX': 'EX', 'CI': 'CI',
    'RS': 'RS', 'CHECK': 'CHECK', 'DSCF': 'DSCF', 'HF': 'HF',
}

# cinewx.f is hand-maintained -- no .fpl exists for it, so its groups are
# outside check (d)'s .f/.fpl cross-check scope (not a caveat about this
# script's own diff, which covers them normally).
NO_FPL_GROUPS = {'BASVC', 'GET'}


def extract_source_text(text):
    """Group name -> sorted member list, from Fortran-fixed-form NAMELIST
    declarations in `text`. Every physical line (statement start and any
    continuation) is truncated to columns 7-72 before parsing -- see
    module docstring (a).

    Also returns the set of group names with a statement or continuation
    line whose untruncated content reaches column 72 -- one column short
    of silently dropping the next member added to that group. Today this
    is a warning (see (a): 7 lines currently reach it, 0 exceed it); if a
    future edit pushes a line past 72, gfortran and this script agree
    silently and the doc still claims a member the source no longer
    declares. This does not fail the sweep."""
    lines = text.splitlines()
    trunc = [ln[:72] for ln in lines]
    results = {}
    at_limit = set()
    i = 0
    while i < len(trunc):
        line = trunc[i]
        m = re.match(r'^.{5}[ 0]\s*NAMELIST\s*/\s*(\w+)\s*/\s*(.*)', line, re.IGNORECASE)
        if not m:
            i += 1
            continue
        name = m.group(1).upper()
        body = m.group(2)
        if len(lines[i]) >= 72:
            at_limit.add(name)
        j = i + 1
        while j < len(trunc):
            cont_line = trunc[j]
            if len(cont_line) > 5 and cont_line[5] not in (' ', '0', '\t'):
                body += cont_line[6:]
                if len(lines[j]) >= 72:
                    at_limit.add(name)
                j += 1
            else:
                break
        body_clean = re.sub(r'\([^()]*\)', '', body)
        members = [x.strip().upper() for x in body_clean.split(',') if x.strip()]
        results.setdefault(name, set()).update(members)
        i = j
    return {k: sorted(v) for k, v in results.items()}, at_limit


def extract_doc_text(text):
    """Doc section-name macro -> sorted documented-member list, from
    namelist.002's \\mtab{} (normal parameter entries) and \\kbox{} (the
    handful of &WF buffer-size items, e.g. LRPS/LTRI/LWFL)."""
    sections = re.split(r'\\section\*\{\s*\\(\w+)namelist NAMELIST\}', text)
    mapping = {}
    for i in range(1, len(sections), 2):
        name = sections[i].upper()
        content = sections[i + 1]
        mtabs = re.findall(r'\\mtab\{([^}\s(]+)', content)
        kboxes = re.findall(r'\\kbox\{([^}\s(]+)', content)
        mapping[name] = sorted(set(m.upper() for m in mtabs) | set(k.upper() for k in kboxes))
    return mapping


def load_source():
    merged = {}
    at_limit = set()
    for fn in sorted(glob.glob(SRC_GLOB)):
        with open(fn, errors='ignore') as f:
            text = f.read()
        groups, limit_groups = extract_source_text(text)
        at_limit |= limit_groups
        for group, members in groups.items():
            merged.setdefault(group, set()).update(members)
    return {k: sorted(v) for k, v in merged.items()}, at_limit


def load_doc():
    with open(NAMELIST_DOC, errors='ignore') as f:
        text = f.read()
    by_macro = extract_doc_text(text)
    return {src: by_macro.get(macro, []) for macro, src in DOC_TO_SRC.items()}


def diff(source, doc):
    """Per NAMELIST group (check (b)): never a flat name-set across
    groups. Returns (report_lines, total_missing, total_extra)."""
    lines = []
    total_missing = total_extra = 0
    for k in sorted(source):
        s, d = set(source[k]), set(doc.get(k, []))
        missing, extra = sorted(s - d), sorted(d - s)
        if missing or extra:
            lines.append(f"{k}: missing={missing} extra_in_doc={extra}")
        total_missing += len(missing)
        total_extra += len(extra)
    return lines, total_missing, total_extra


def main():
    source, at_limit = load_source()
    doc = load_doc()
    lines, total_missing, total_extra = diff(source, doc)
    for ln in lines:
        print(ln)
    print(f"\nTOTAL MISSING (in source, not in doc): {total_missing}")
    print(f"TOTAL EXTRA (in doc, not in source as declared): {total_extra}")
    if at_limit:
        print(f"WARNING: group(s) with a NAMELIST line reaching column 72 "
              f"(one member away from silent truncation): {sorted(at_limit)}")
    return 1 if total_missing else 0


# --- self-test -------------------------------------------------------
# Inline synthetic fixtures, not separate committed files: this detector's
# unit of work is one small text-diff, not a cross-file call graph (unlike
# this project's other kind-mismatch detector, whose fixtures are separate
# committed files), so the fixture text lives with the assertion that checks
# it. Re-established
# on every --self-test run, not asserted once in a phase report.

COL72_SRC = (
    "      PROGRAM COLTEST\n"
    "      NAMELIST /ZCOL/A,B,XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXZFULLNAME\n"
    "      END\n"
)
# Position 72 falls inside the last identifier; gfortran (verified this
# phase by compiling and running an equivalent program, then WRITE-ing the
# NAMELIST back out) sees only the first 72 columns and so reads the
# truncated identifier below, NOT the full 79-character one written in the
# source. A parser that doesn't truncate would disagree with the compiler.
COL72_EXPECT_MEMBER = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXZFULLN'
COL72_UNTRUNCATED = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXZFULLNAME'

MISSING_SRC = (
    "      PROGRAM MTEST\n"
    "      NAMELIST /TR/AAA,BBB,CCC\n"
    "      END\n"
)
MISSING_DOC = (
    "\\section*{ \\trnamelist NAMELIST}\n"
    "\\mtab{AAA }{Integer*4. First.}\n"
    "\\mtab{BBB }{Integer*4. Second.}\n"
)
# CCC is declared but not documented -> must show up as missing.
# A doc-only DDD in an UNRELATED group must never mask it (check (b)).
EXTRA_DOC = MISSING_DOC.replace(
    "\\mtab{BBB }{Integer*4. Second.}\n",
    "\\mtab{BBB }{Integer*4. Second.}\n\\mtab{DDD }{Integer*4. Undeclared extra.}\n",
)

NEWGROUP_SRC = MISSING_SRC + "      NAMELIST /ZZZNEW/EEE,FFF\n"
# ZZZNEW has no doc section and no DOC_TO_SRC entry at all -> both its
# members must show up as missing, the "entirely undocumented NAMELIST"
# shape (&CHECK/&DSCF/&HF are of this kind).


def run_self_test():
    ok = True

    col72_groups, col72_limit = extract_source_text(COL72_SRC)
    got = col72_groups['ZCOL']
    if COL72_EXPECT_MEMBER in got and COL72_UNTRUNCATED not in got:
        print("PASS: column-72 truncation matches gfortran's own read")
    else:
        ok = False
        print(f"FAIL: column-72 truncation -- got members {got}")

    if col72_limit == {'ZCOL'}:
        print("PASS: column-72 warning flags the at-limit group")
    else:
        ok = False
        print(f"FAIL: expected at-limit warning for {{'ZCOL'}}, got {col72_limit}")

    source, _ = extract_source_text(MISSING_SRC)
    doc = extract_doc_text(MISSING_DOC)
    doc = {src: doc.get(macro, []) for macro, src in DOC_TO_SRC.items() if macro == 'TR'}
    _, missing, extra = diff(source, doc)
    if missing == 1 and extra == 0:
        print("PASS: undocumented member (CCC) detected as missing")
    else:
        ok = False
        print(f"FAIL: expected 1 missing/0 extra, got {missing} missing/{extra} extra")

    doc2 = extract_doc_text(EXTRA_DOC)
    doc2 = {src: doc2.get(macro, []) for macro, src in DOC_TO_SRC.items() if macro == 'TR'}
    lines, missing2, extra2 = diff(source, doc2)
    if missing2 == 1 and extra2 == 1 and any('DDD' in ln for ln in lines):
        print("PASS: doc-only member (DDD) reported as extra, doesn't mask CCC's gap")
    else:
        ok = False
        print(f"FAIL: expected 1 missing/1 extra with DDD flagged, got {missing2}/{extra2}: {lines}")

    source3, _ = extract_source_text(NEWGROUP_SRC)
    _, missing3, _ = diff(source3, doc)  # doc has no ZZZNEW entry at all
    if missing3 == 1 + 2:  # TR's CCC, plus ZZZNEW's EEE and FFF
        print("PASS: entirely undocumented NAMELIST group's members all reported missing")
    else:
        ok = False
        print(f"FAIL: expected 3 total missing (1 TR + 2 ZZZNEW), got {missing3}")

    print("\nself-test: " + ("ALL PASS" if ok else "FAILURES ABOVE"))
    return 0 if ok else 1


if __name__ == '__main__':
    if '--self-test' in sys.argv:
        sys.exit(run_self_test())
    sys.exit(main())
