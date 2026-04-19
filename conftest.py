# Root conftest.py — anchors pytest's rootdir to the repo root so that
# package imports like `from utils.greeting import greet` resolve without
# any sys.path manipulation in test files.
