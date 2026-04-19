import pytest

from greeting import greet


def test_greet_basic():
    assert greet("World") == "Hello, World!"


def test_greet_with_name():
    assert greet("Alice") == "Hello, Alice!"


def test_greet_with_different_name():
    assert greet("Bob") == "Hello, Bob!"


def test_greet_empty_string():
    assert greet("") == "Hello, !"
