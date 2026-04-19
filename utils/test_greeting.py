from greeting import greet


def test_greet_basic():
    assert greet("World") == "Hello, World!"


def test_greet_name():
    assert greet("Alice") == "Hello, Alice!"


def test_greet_empty_string():
    assert greet("") == "Hello, !"


def test_greet_returns_string():
    result = greet("Bob")
    assert isinstance(result, str)
