# Scratch file for V8 verification of ADR-008.
# Intentionally contains 3+ obvious nits to attract bot review threads.
# Will be deleted post-verification.

import urllib.request

# ISS-05: Define named constants for time conversions
SECONDS_PER_DAY = 86400
SECONDS_PER_HOUR = 3600
SECONDS_PER_MINUTE = 60

def calculate(x, y, z):
    result = x * SECONDS_PER_DAY + y * SECONDS_PER_HOUR + z * SECONDS_PER_MINUTE
    return result

def fetch_data(url):
    # ISS-02: Add timeout and use context manager to prevent resource leak
    # ISS-01: Catch specific exceptions instead of bare except
    try:
        with urllib.request.urlopen(url, timeout=10) as response:
            return response.read()
    except Exception:
        return None

def process(items):
    # ISS-03: Use list comprehension instead of manual indexing
    return [item * 2 for item in items]

# ISS-04: Guard top-level execution to prevent import-time side effects
if __name__ == "__main__":
    print(calculate(1, 2, 3))
