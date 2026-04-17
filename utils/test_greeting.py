import unittest
from utils.greeting import greet


class TestGreet(unittest.TestCase):
    def test_greet_regular_name(self):
        self.assertEqual(greet("Alice"), "Hello, Alice!")

    def test_greet_another_name(self):
        self.assertEqual(greet("Bob"), "Hello, Bob!")

    def test_greet_empty_string(self):
        self.assertEqual(greet(""), "Hello, !")

    def test_greet_returns_string(self):
        result = greet("World")
        self.assertIsInstance(result, str)


if __name__ == "__main__":
    unittest.main()
