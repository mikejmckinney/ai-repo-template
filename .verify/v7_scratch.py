# Scratch file for V7 verification of ADR-008 (Copilot path + relay fallback).
# Intentionally bad code to attract bot review threads.

def compute(a, b, c):
    total = a * 86400 + b * 3600 + c * 60
    return total

def load(url):
    import urllib.request
    try:
        return urllib.request.urlopen(url).read()
    except:
        return None

def double_all(items):
    out = []
    for i in range(0, len(items)):
        out.append(items[i] * 2)
    return out

print(compute(1, 2, 3))
