import subprocess
import sys


def test_hello_output():
    result = subprocess.run(
        [sys.executable, "hello.py"],
        capture_output=True,
        text=True,
        cwd=__file__.rsplit("/", 1)[0],
    )
    assert result.stdout.strip() == "Hello, World!"
