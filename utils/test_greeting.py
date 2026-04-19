import importlib.util
from pathlib import Path

_GREETING_PATH = Path(__file__).with_name("greeting.py")
_GREETING_SPEC = importlib.util.spec_from_file_location("greeting", _GREETING_PATH)
_GREETING_MODULE = importlib.util.module_from_spec(_GREETING_SPEC)
assert _GREETING_SPEC is not None and _GREETING_SPEC.loader is not None
_GREETING_SPEC.loader.exec_module(_GREETING_MODULE)
greet = _GREETING_MODULE.greet


def test_greet_name():
    assert greet("World") == "Hello, World!"


def test_greet_different_name():
    assert greet("Alice") == "Hello, Alice!"


def test_greet_empty_string():
    assert greet("") == "Hello, World!"
