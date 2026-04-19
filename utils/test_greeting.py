import pytest

from greeting import greet


@pytest.mark.parametrize("name,expected", [
    ("World", "Hello, World!"),
    ("Alice", "Hello, Alice!"),
    ("Bob", "Hello, Bob!"),
    ("", "Hello, !"),
])
def test_greet(name, expected):
    assert greet(name) == expected
