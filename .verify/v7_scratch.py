# Scratch file for V7 verification of ADR-008 (Copilot path + relay fallback).
# Intentionally bad code to attract bot review threads.

SECONDS_PER_DAY = 86400
SECONDS_PER_HOUR = 3600
SECONDS_PER_MINUTE = 60

def compute(a, b, c):
    total = a * SECONDS_PER_DAY + b * SECONDS_PER_HOUR + c * SECONDS_PER_MINUTE
    return total

def load(url):
    import urllib.request
    try:
        return urllib.request.urlopen(url, timeout=10).read()
    except Exception:
        return None

def double_all(items):
    return [i * 2 for i in items]

print(compute(1, 2, 3))
