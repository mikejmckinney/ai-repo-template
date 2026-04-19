import subprocess
import sys
from pathlib import Path


def test_hello_output():
    script_path = Path(__file__).with_name("hello.py")
    result = subprocess.run(
        [sys.executable, str(script_path)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"Script exited with {result.returncode}: {result.stderr}"
    assert result.stdout.strip() == "Hello, World!"
