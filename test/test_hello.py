import os
import subprocess
import sys


def test_hello_output():
    result = subprocess.run(
        [sys.executable, "hello.py"],
        capture_output=True,
        text=True,
        cwd=os.path.dirname(__file__),
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == "Hello, World!"
