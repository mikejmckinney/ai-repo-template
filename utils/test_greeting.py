import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from utils.greeting import greet


def test_greet_basic():
    assert greet("World") == "Hello, World!"


def test_greet_with_name():
    assert greet("Alice") == "Hello, Alice!"


def test_greet_with_another_name():
    assert greet("Bob") == "Hello, Bob!"


def test_greet_returns_string():
    result = greet("Charlie")
    assert isinstance(result, str)
