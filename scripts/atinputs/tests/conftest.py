import os
import pathlib

import pytest
from hypothesis import HealthCheck, settings

REPO_ROOT = pathlib.Path(__file__).resolve().parents[3]

# The property-based differential sweep (test_property_sweep.py):
# each hypothesis example shells out to a real atgen subprocess, so
# max_examples is kept low by default -- 'ci' is meant for routine runs.
# 'extended' is for a deliberate longer local sweep
# (ATINPUTS_HYPOTHESIS_PROFILE=extended), not for default CI. 'ci' uses
# derandomize=True so it's reproducible without depending on a persisted
# .hypothesis/ example database (normally not committed/available in CI);
# 'extended' stays randomized so repeated local runs explore fresh
# territory, and any new failure hypothesis finds gets shrunk and saved to
# the local database for replay.
settings.register_profile(
    'ci', max_examples=25, derandomize=True, deadline=None,
    suppress_health_check=[HealthCheck.too_slow])
settings.register_profile(
    'extended', max_examples=2000, derandomize=False, deadline=None,
    suppress_health_check=[HealthCheck.too_slow])
settings.load_profile(os.environ.get('ATINPUTS_HYPOTHESIS_PROFILE', 'ci'))


@pytest.fixture
def repo_root():
    return REPO_ROOT


@pytest.fixture
def samples_dir(repo_root):
    return repo_root / 'samples' / 'native'


@pytest.fixture
def atinputs_dir(repo_root):
    return repo_root / 'samples' / 'atinputs'


@pytest.fixture
def reference_dir(atinputs_dir):
    return atinputs_dir / 'reference'
