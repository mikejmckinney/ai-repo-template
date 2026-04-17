import subprocess
import sys


def test_hello_output():
    result = subprocess.run(
        [sys.executable, "test/hello.py"],
        capture_output=True,
        text=True,
    )
    assert result.stdout.strip() == "Hello, World!"
    assert result.returncode == 0
