#!/usr/bin/env python3
import os
import socket
import subprocess
import sys


BLOCKED_AUDIT_PREFIXES = (
    "socket.",
    "subprocess.",
    "os.exec",
    "os.posix_spawn",
    "os.spawn",
    "os.system",
)


def deny_external_operations(event: str, _args: tuple[object, ...]) -> None:
    if event.startswith(BLOCKED_AUDIT_PREFIXES):
        raise PermissionError(f"blocked audit event: {event}")


def probe_socket(host: str, port: str) -> int:
    try:
        socket.create_connection((host, int(port)), timeout=1)
    except PermissionError:
        print("socket access blocked inside isolation")
        return 1
    except OSError as exc:
        print(f"socket probe failed inside isolation: {type(exc).__name__}")
        return 1
    print("socket access unexpectedly succeeded inside isolation")
    return 2


def probe_subprocess() -> int:
    try:
        subprocess.run(["true"], check=True)
    except PermissionError:
        print("child process blocked inside isolation")
        return 1
    print("child process unexpectedly succeeded inside isolation")
    return 2


def main() -> int:
    sys.addaudithook(deny_external_operations)
    if len(sys.argv) >= 2 and sys.argv[1] == "--probe-socket":
        if len(sys.argv) != 4:
            raise SystemExit("usage: --probe-socket HOST PORT")
        return probe_socket(sys.argv[2], sys.argv[3])
    if sys.argv[1:] == ["--probe-subprocess"]:
        return probe_subprocess()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    sys.path.insert(0, script_dir)
    from preflight import run_preflight

    if len(sys.argv) > 2 and sys.argv[1] == "--fixtures":
        from preflight import run_fixture_suite

        return run_fixture_suite(sys.argv[2:])

    fixture = None
    if len(sys.argv) == 3 and sys.argv[1] == "--fixture":
        fixture = sys.argv[2]
    elif len(sys.argv) != 1:
        raise SystemExit("usage: run-preflight.sh [--fixture PATH | --fixtures PATH ...]")
    return run_preflight(fixture)


if __name__ == "__main__":
    raise SystemExit(main())
