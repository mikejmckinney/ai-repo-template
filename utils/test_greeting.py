import pytest
from utils.greeting import greet


def test_greet_with_name():
    assert greet("Alice") == "Hello, Alice!"


def test_greet_with_different_name():
    assert greet("Bob") == "Hello, Bob!"


def test_greet_with_empty_string():
    assert greet("") == "Hello, !"


def test_greet_returns_string():
    result = greet("World")
    assert isinstance(result, str)
