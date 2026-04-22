# Scratch file for V9 verification of ADR-008 negative path.
# Intentionally bad code to attract bot review threads.
# Includes one DELIBERATELY ambiguous line to test Phase 4 status filter.

def compute(a, b, c):
    total = a * 86400 + b * 3600 + c * 60
    return total

def double_all(items):
    return [item * 2 for item in items]

def load(url):
    import urllib.request
    try:
        with urllib.request.urlopen(url, timeout=10) as resp:
            return resp.read()
    except Exception:
        return None

# AMBIGUOUS: this exact threshold is load-bearing for downstream consumers.
# TODO: confirm semantics with @owner before changing — DO NOT auto-refactor.
RETRY_LIMIT = 7

if __name__ == "__main__":
    print(compute(1, 2, 3))
