#!/usr/bin/env python3

import json
import os
import re
import signal
import subprocess
import sys
import threading
import time
from datetime import datetime, timezone
from pathlib import Path


SENSITIVE_ENV_NAME = re.compile(
    r"(?:^|_)(?:AUTH|CREDENTIAL|KEY|PASSWORD|PAT|SECRET|TOKEN)(?:_|$)",
    re.IGNORECASE,
)
SERVER_NAME = re.compile(r"^[A-Za-z0-9._-]+$")
MAX_LOG_BYTES = 1_048_576
LIFECYCLE_RESERVE_BYTES = 4096
MAX_STDERR_RECORD_BYTES = 8192
LOG_WRITE_LOCK = threading.RLock()


def timestamp() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def write_record(log_fd: int, *, reserve_bytes: int = 0, **fields: object) -> bool:
    record = {"timestamp": timestamp(), **fields}
    data = (json.dumps(record, sort_keys=True) + "\n").encode()
    limit = MAX_LOG_BYTES - reserve_bytes
    with LOG_WRITE_LOCK:
        try:
            if os.fstat(log_fd).st_size + len(data) > limit:
                return False
            view = memoryview(data)
            while view:
                written = os.write(log_fd, view)
                if written == 0:
                    return False
                view = view[written:]
        except OSError:
            return False
    return True


def redactions() -> list[tuple[str, str]]:
    values = [
        (name, value)
        for name, value in os.environ.items()
        if value and SENSITIVE_ENV_NAME.search(name)
    ]
    return sorted(values, key=lambda item: len(item[1]), reverse=True)


def redact(text: str, secrets: list[tuple[str, str]]) -> str:
    for name, value in secrets:
        text = text.replace(value, f"[REDACTED:{name}]")
    return re.sub(
        r"(?i)((?:authorization|api[_-]?key|password|secret|token)\s*[:=]\s*)(?:bearer\s+)?\S+",
        r"\1[REDACTED]",
        text,
    )


def prepare_log(server: str) -> tuple[Path, int]:
    root = Path(
        os.environ.get("MCP_STARTUP_LOG_DIR")
        or Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "ai-repo-mcp"
    )
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    root.chmod(0o700)
    path = root / f"{server}.log"
    if path.exists() and path.stat().st_size > MAX_LOG_BYTES - LIFECYCLE_RESERVE_BYTES:
        previous = path.with_suffix(".log.previous")
        previous.unlink(missing_ok=True)
        path.replace(previous)
        previous.chmod(0o600)
    flags = os.O_APPEND | os.O_CREAT | os.O_WRONLY
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    log_fd = os.open(path, flags, 0o600)
    os.fchmod(log_fd, 0o600)
    return path, log_fd


def log_stderr(stream: object, log_fd: int, server: str, child_pid: int, started: float) -> None:
    secrets = redactions()
    try:
        with stream:
            while raw_line := stream.readline(MAX_STDERR_RECORD_BYTES):
                if len(raw_line) == MAX_STDERR_RECORD_BYTES and not raw_line.endswith(b"\n"):
                    write_record(
                        log_fd,
                        reserve_bytes=LIFECYCLE_RESERVE_BYTES,
                        event="stderr",
                        server=server,
                        pid=child_pid,
                        message=(
                            f"[TRUNCATED: stderr record exceeds {MAX_STDERR_RECORD_BYTES} bytes]"
                        ),
                    )
                    while raw_line and not raw_line.endswith(b"\n"):
                        raw_line = stream.readline(MAX_STDERR_RECORD_BYTES)
                    continue
                write_record(
                    log_fd,
                    reserve_bytes=LIFECYCLE_RESERVE_BYTES,
                    event="stderr",
                    server=server,
                    pid=child_pid,
                    message=redact(raw_line.decode(errors="replace").rstrip("\r\n"), secrets),
                )
    except OSError as error:
        write_record(
            log_fd,
            event="logger_error",
            server=server,
            pid=child_pid,
            message=redact(str(error), secrets),
        )
    finally:
        write_record(
            log_fd,
            event="stderr_closed",
            server=server,
            pid=child_pid,
            elapsed_ms=round((time.monotonic() - started) * 1000),
        )


def main() -> int:
    if len(sys.argv) < 4 or sys.argv[2] != "--":
        print(f"usage: {Path(sys.argv[0]).name} SERVER -- COMMAND [ARG ...]", file=sys.stderr)
        return 2
    server = sys.argv[1]
    command = sys.argv[3:]
    if not SERVER_NAME.fullmatch(server):
        print(f"invalid MCP server name: {server}", file=sys.stderr)
        return 2

    started = time.monotonic()
    try:
        _, log_fd = prepare_log(server)
    except OSError as error:
        print(f"warning: cannot create MCP diagnostic log for {server}: {error}", file=sys.stderr)
        os.execvpe(command[0], command, os.environ)

    try:
        process = subprocess.Popen(
            command,
            stdin=None,
            stdout=None,
            stderr=subprocess.PIPE,
            env=os.environ,
            start_new_session=True,
        )
    except OSError as error:
        write_record(
            log_fd,
            event="exec_error",
            server=server,
            pid=os.getpid(),
            message=f"failed to exec MCP server {server}: {error}",
        )
        os.close(log_fd)
        return 127

    write_record(
        log_fd,
        event="start",
        server=server,
        pid=process.pid,
        parent_pid=os.getpid(),
        cwd=os.getcwd(),
        executable=Path(command[0]).name,
    )

    def forward_signal(signum: int, _frame: object) -> None:
        try:
            os.killpg(process.pid, signum)
        except ProcessLookupError:
            pass
        write_record(
            log_fd,
            event="signal",
            server=server,
            pid=process.pid,
            signal=signal.Signals(signum).name,
            elapsed_ms=round((time.monotonic() - started) * 1000),
        )

    for signum in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM):
        signal.signal(signum, forward_signal)

    assert process.stderr is not None
    stderr_thread = threading.Thread(
        target=log_stderr,
        args=(process.stderr, log_fd, server, process.pid, started),
        name=f"{server}-stderr",
    )
    stderr_thread.start()
    return_code = process.wait()
    stderr_thread.join()
    write_record(
        log_fd,
        event="exit",
        server=server,
        pid=process.pid,
        exit_code=return_code if return_code >= 0 else None,
        signal=signal.Signals(-return_code).name if return_code < 0 else None,
        elapsed_ms=round((time.monotonic() - started) * 1000),
    )
    os.close(log_fd)
    return return_code if return_code >= 0 else 128 - return_code


if __name__ == "__main__":
    raise SystemExit(main())
