"""Class A regression, in CI: every member sugar.py can emit is a real
declared NAMELIST member.

Deliberately narrow. `verify_namelists.load_source()` re-derives the
declared member set per NAMELIST group directly from src/*.f -- reused
here, not forked, matching a prior manual review's own approach. This test only
covers the sugar-derived side (Class A): raw blocks (schema.RawParams) are
open-ended by design, any group/param name, so no static assertion can
bound them.
A gap here would mean sugar.py emits a member src/*.f doesn't declare;
it says nothing about raw &TR/&BASVC/etc. blocks an .inp author writes by
hand.
"""

import verify_namelists

from ..parser import parse_file
from ..schema import validate
from ..sugar import build


def _deck(atinputs_dir, name):
    path = str(atinputs_dir / f'{name}.inp')
    data = validate(parse_file(path), path)
    return build(data, basis_dir=str(atinputs_dir))


def test_sugar_emitted_members_are_all_declared(atinputs_dir):
    # f.inp + fpt.inp together exercise all eight CTRL_STEP_ORDER groups
    # (ai/mc/wf/tr/pt/ex/ci/rs) plus &CNTL/&GET -- f.inp has ai/ci/mc/rs/
    # tr/wf, fpt.inp has ai/ci/ex/pt/rs/tr/wf; boron*.inp is fully raw
    # (sugar contributes only &CNTL) and adds no sugar-side coverage.
    declared, _at_limit = verify_namelists.load_source()

    decks = [_deck(atinputs_dir, 'f'), _deck(atinputs_dir, 'fpt')]

    checked_groups = set()
    for deck in decks:
        for p in deck.passes:
            for block in p.blocks:
                emitted = {name.upper() for name in block.params}
                known = set(declared.get(block.group, []))
                missing = emitted - known
                assert not missing, (
                    f"&{block.group} emits {sorted(missing)}, not a declared "
                    f"member of NAMELIST /{block.group}/ per src/*.f")
                checked_groups.add(block.group)

    # A bound on this test's own coverage, not an assertion of completeness
    # elsewhere: fails loudly if a future CTRL_STEP_ORDER group stops being
    # exercised by f.inp/fpt.inp (e.g. one of them is edited), rather than
    # silently checking fewer groups than intended.
    assert checked_groups >= {'AI', 'MC', 'WF', 'TR', 'GET', 'PT', 'EX', 'CI', 'RS', 'CNTL'}
