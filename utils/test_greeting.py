from utils.greeting import greet


def test_greet_simple_name():
    assert greet("Alice") == "Hello, Alice!"


def test_greet_another_name():
    assert greet("Bob") == "Hello, Bob!"


def test_greet_empty_string():
    assert greet("") == "Hello, !"


def test_greet_name_with_spaces():
    assert greet("John Doe") == "Hello, John Doe!"
