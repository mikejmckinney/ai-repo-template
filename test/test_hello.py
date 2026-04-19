import io
import sys

from hello import main


def test_hello_output(capsys):
    main()
    captured = capsys.readouterr()
    assert captured.out == "Hello, World!\n"
