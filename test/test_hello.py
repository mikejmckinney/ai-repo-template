import subprocess
import sys
from pathlib import Path

import pytest

HELLO_SCRIPT = Path(__file__).parent / "hello.py"


@pytest.fixture(scope="module")
def hello_result():
    return subprocess.run(
        [sys.executable, str(HELLO_SCRIPT)],
        capture_output=True,
        text=True,
        timeout=30,
    )


def test_hello_output(hello_result):
    assert hello_result.stdout.strip() == "Hello, World!"


def test_hello_exit_code(hello_result):
    assert hello_result.returncode == 0
