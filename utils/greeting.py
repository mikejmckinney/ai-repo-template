def greet(name: str) -> str:
    """Return a greeting string for the given name."""
    if not isinstance(name, str):
        raise TypeError(f"name must be a str, got {type(name).__name__}")
    return f"Hello, {name}!"
