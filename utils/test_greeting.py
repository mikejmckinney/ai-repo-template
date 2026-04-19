import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from utils.greeting import greet


def test_greet_name():
    assert greet("World") == "Hello, World!"


def test_greet_different_name():
    assert greet("Alice") == "Hello, Alice!"


def test_greet_empty_string():
    assert greet("") == "Hello, !"
