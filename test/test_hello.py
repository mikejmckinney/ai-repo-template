import subprocess
import sys
from pathlib import Path


def test_hello_output():
    hello_script = Path(__file__).with_name("hello.py")
    result = subprocess.run(
        [sys.executable, str(hello_script)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == "Hello, World!"
