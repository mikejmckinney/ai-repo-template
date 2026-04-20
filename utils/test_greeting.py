from utils.greeting import greet


def test_greet_basic():
    assert greet("World") == "Hello, World!"


def test_greet_name():
    assert greet("Alice") == "Hello, Alice!"


def test_greet_another_name():
    assert greet("Bob") == "Hello, Bob!"
