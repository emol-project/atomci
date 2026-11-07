import pytest

from ..basis import BasisError, read_basis


def test_f_bas_matches_frozen_deck(samples_dir):
    basis = read_basis(str(samples_dir / 'f.bas'))
    assert basis.nsym == 4
    assert basis.nbf == [13, 11, 6, 5]
    assert basis.nob == [13, 11, 6, 5]
    assert basis.mpob[0] == list(range(13, 0, -1))
    assert basis.mpob[1] == list(range(11, 0, -1))
    assert basis.mpob[2] == list(range(6, 0, -1))
    assert basis.mpob[3] == list(range(5, 0, -1))


def test_disabled_lines_are_not_counted(tmp_path):
    p = tmp_path / 'x.bas'
    p.write_text(
        '  S  1  1.0    1.0    1.0\n'
        '" S  1  1.0    2.0    1.0\n'   # disabled: leading "
        '# S  1  1.0    3.0    1.0\n'   # disabled: leading #
        '  S  1  1.0    4.0    1.0\n'
        ' ))\n'
    )
    basis = read_basis(str(p))
    assert basis.nbf == [2]


def test_contraction_counts_as_one_basis_function(tmp_path):
    p = tmp_path / 'x.bas'
    p.write_text(
        '  S  3  1.0\n'
        '    10.0 5.0 2.5\n'
        '    0.20 0.50 0.30\n'
        '  S  1  1.0  1.5  1.0\n'
        ' ))\n'
    )
    basis = read_basis(str(p))
    assert basis.nbf == [2]


def test_unknown_letter_is_error(tmp_path):
    # 'J' is conventionally skipped in spectroscopic notation and is NOT in
    # ANGULAR_MOMENTUM_LETTERS -- unlike e.g. 'X', which IS a valid (if
    # exotic) letter and would instead trip the "missing lower symmetry"
    # check. Picking a letter that's merely unlikely, rather than one that's
    # actually absent from the alphabet, would make this test pass for the
    # wrong reason.
    p = tmp_path / 'x.bas'
    p.write_text('  J  1  1.0  1.0  1.0\n ))\n')
    with pytest.raises(BasisError, match='unknown angular-momentum letter'):
        read_basis(str(p))


def test_missing_lower_symmetry_is_error(tmp_path):
    # a P shell with no S shell at all: NSYM would be 2 but symmetry 1 is empty
    p = tmp_path / 'x.bas'
    p.write_text('  P  1  1.0  1.0  1.0\n ))\n')
    with pytest.raises(BasisError, match='no shells but a higher one does'):
        read_basis(str(p))


def test_truncated_shell_header_is_error(tmp_path):
    # a shell letter with no NTERM/scale following it at all
    p = tmp_path / 'x.bas'
    p.write_text('  S\n')
    with pytest.raises(BasisError, match='truncated shell header'):
        read_basis(str(p))


def test_non_numeric_nterm_is_error(tmp_path):
    p = tmp_path / 'x.bas'
    p.write_text('  S  three  1.0  1.0  1.0\n ))\n')
    with pytest.raises(BasisError, match='expected primitive count'):
        read_basis(str(p))


def test_no_shells_found_is_error(tmp_path):
    p = tmp_path / 'x.bas'
    p.write_text(' ))\n')
    with pytest.raises(BasisError, match='no shells found'):
        read_basis(str(p))


def test_missing_basis_file_is_oserror(tmp_path):
    with pytest.raises(OSError):
        read_basis(str(tmp_path / 'does-not-exist.bas'))


def test_missing_terminator_is_tolerated(tmp_path):
    # no ')' terminator token at all; the reader just stops at end-of-tokens
    # rather than erroring -- a deliberate leniency, not a native-atgen fact
    p = tmp_path / 'x.bas'
    p.write_text('  S  1  1.0  1.0  1.0\n')
    basis = read_basis(str(p))
    assert basis.nbf == [1]
