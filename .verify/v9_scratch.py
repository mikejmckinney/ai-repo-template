# Scratch file for V9 verification of ADR-008 negative path.
# Intentionally bad code to attract bot review threads.
# Includes one DELIBERATELY ambiguous line to test Phase 4 status filter.

def compute(a, b, c):
    total = a * 86400 + b * 3600 + c * 60
    return total

def double_all(items):
    out = []
    for i in range(0, len(items)):
        out.append(items[i] * 2)
    return out

def load(url):
    import urllib.request
    try:
        return urllib.request.urlopen(url).read()
    except:
        return None

# AMBIGUOUS: this exact threshold is load-bearing for downstream consumers.
# TODO: confirm semantics with @owner before changing — DO NOT auto-refactor.
RETRY_LIMIT = 7

print(compute(1, 2, 3))
