import pytest
from utils.greeting import greet


def test_greet_basic():
    assert greet("World") == "Hello, World!"


def test_greet_with_name():
    assert greet("Alice") == "Hello, Alice!"


def test_greet_empty_string():
    assert greet("") == "Hello, !"


def test_greet_numeric_string():
    assert greet("42") == "Hello, 42!"
