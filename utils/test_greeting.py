import pytest

from utils.greeting import greet


@pytest.mark.parametrize("name, expected", [
    ("World", "Hello, World!"),
    ("Alice", "Hello, Alice!"),
    ("Bob", "Hello, Bob!"),
])
def test_greet_output(name, expected):
    assert greet(name) == expected


def test_greet_returns_string():
    assert isinstance(greet("Charlie"), str)
