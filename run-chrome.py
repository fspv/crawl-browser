#!/usr/bin/env python3
"""Entrypoint for the crawl-browser container.

Starts supporting services (Xvfb, VNC, D-Bus, socat) and Chrome with
remote debugging.  Handles SIGTERM/SIGINT for clean container shutdown.
"""
from __future__ import annotations

import asyncio
import logging
import os
import shutil
import signal
import sys
import urllib.request
import zipfile
from pathlib import Path
from typing import Optional

CHROME_BINARY = "chrome-for-testing"
DISPLAY = ":1"
USER_DATA_DIR = "/tmp/chrome/user-data"
EXTENSION_DIR = "/tmp/chrome/extensions"
DEFAULT_EXTENSIONS = ("isdcac", "ublock")
SHUTDOWN_TIMEOUT_S = 5

log = logging.getLogger("run-chrome")


def download_extension(url: str, name: str, subdir: str) -> Optional[str]:
    """Download and extract a Chrome extension. Return path or None."""
    ext_dir = Path(EXTENSION_DIR) / name
    zip_path = Path(f"/tmp/{name}.zip")

    log.info("Downloading extension %s from %s", name, url)

    if ext_dir.exists():
        shutil.rmtree(ext_dir)
    ext_dir.mkdir(parents=True)

    try:
        urllib.request.urlretrieve(url, str(zip_path))
    except Exception:
        log.exception("Failed to download extension %s", name)
        zip_path.unlink(missing_ok=True)
        return None

    try:
        with zipfile.ZipFile(zip_path) as zf:
            zf.extractall(ext_dir)
    except Exception:
        log.exception("Failed to extract extension %s", name)
        zip_path.unlink(missing_ok=True)
        return None

    if subdir and (ext_dir / subdir).is_dir():
        for item in (ext_dir / subdir).iterdir():
            shutil.move(str(item), str(ext_dir / item.name))
        (ext_dir / subdir).rmdir()

    zip_path.unlink(missing_ok=True)
    log.info("Successfully installed extension %s", name)
    return str(ext_dir)


def setup_extensions() -> list[str]:
    """Process custom and default extensions, return extension paths."""
    paths: list[str] = []

    chrome_extensions = os.environ.get("CHROME_EXTENSIONS", "")
    if chrome_extensions:
        for ext_spec in chrome_extensions.split(","):
            parts = ext_spec.split("|")
            if len(parts) >= 2:
                name, url = parts[0], parts[1]
                subdir = parts[2] if len(parts) > 2 else ""
                result = download_extension(url, name, subdir)
                if result:
                    paths.append(result)
            else:
                log.warning(
                    "Invalid extension spec: %s (expected: name|url[|subdir])",
                    ext_spec,
                )

    default_paths = [f"{EXTENSION_DIR}/{name}" for name in DEFAULT_EXTENSIONS]
    return default_paths + paths


async def terminate_process(
    proc: asyncio.subprocess.Process,
) -> None:
    """Send SIGTERM to a process, SIGKILL after timeout."""
    if proc.returncode is not None:
        return

    try:
        proc.terminate()
        log.debug("Sent SIGTERM to pid=%d", proc.pid)
    except ProcessLookupError:
        return

    try:
        await asyncio.wait_for(proc.wait(), timeout=SHUTDOWN_TIMEOUT_S)
        log.debug("pid=%d terminated gracefully", proc.pid)
    except asyncio.TimeoutError:
        log.warning("pid=%d did not terminate, sending SIGKILL", proc.pid)
        try:
            proc.kill()
        except ProcessLookupError:
            return
        await proc.wait()


async def terminate_all(
    processes: list[asyncio.subprocess.Process],
) -> None:
    """Terminate all running processes concurrently."""
    await asyncio.gather(
        *(terminate_process(p) for p in processes),
    )


async def start_socat() -> asyncio.subprocess.Process:
    """Start socat to forward external 9222 -> Chrome internal 59222."""
    proc = await asyncio.create_subprocess_exec(
        "socat",
        "TCP-LISTEN:9222,fork,reuseaddr,bind=0.0.0.0",
        "TCP:127.0.0.1:59222",
    )
    log.info("Started socat (pid=%d)", proc.pid)
    return proc


async def start_xvfb() -> asyncio.subprocess.Process:
    """Start Xvfb virtual display."""
    proc = await asyncio.create_subprocess_exec(
        "Xvfb",
        DISPLAY,
        "-screen",
        "0",
        "1024x768x16",
        "-ac",
        "-nolisten",
        "tcp",
        "-nolisten",
        "unix",
    )
    log.info("Started Xvfb (pid=%d)", proc.pid)
    return proc


async def start_fluxbox(
    env: dict[str, str],
) -> asyncio.subprocess.Process:
    """Start fluxbox window manager."""
    proc = await asyncio.create_subprocess_exec(
        "fluxbox",
        env=env,
    )
    log.info("Started fluxbox (pid=%d)", proc.pid)
    return proc


async def start_x11vnc(
    env: dict[str, str],
) -> asyncio.subprocess.Process:
    """Start x11vnc VNC server."""
    proc = await asyncio.create_subprocess_exec(
        "x11vnc",
        "-nopw",
        "-forever",
        "-localhost",
        "-shared",
        "-rfbport",
        "5900",
        "-rfbportv6",
        "5900",
        env=env,
    )
    log.info("Started x11vnc (pid=%d)", proc.pid)
    return proc


async def start_websockify(
    env: dict[str, str],
) -> asyncio.subprocess.Process:
    """Start websockify noVNC web bridge."""
    proc = await asyncio.create_subprocess_exec(
        "websockify",
        "--web=/usr/share/novnc",
        "7900",
        "localhost:5900",
        env=env,
    )
    log.info("Started websockify (pid=%d)", proc.pid)
    return proc


async def start_dbus() -> str:
    """Start D-Bus daemon and return session address."""
    dbus_proc = await asyncio.create_subprocess_exec(
        "dbus-daemon",
        "--nopidfile",
        "--nosyslog",
        "--system",
        "--fork",
        "--print-address",
        "1",
        stdout=asyncio.subprocess.PIPE,
    )
    stdout, _ = await dbus_proc.communicate()
    dbus_address = stdout.decode().strip()
    log.info("D-Bus address: %s", dbus_address)
    return dbus_address


async def start_chrome(
    env: dict[str, str],
    extension_paths: list[str],
    extra_args: list[str],
) -> asyncio.subprocess.Process:
    """Start Chrome with remote debugging."""
    chrome_args = [
        CHROME_BINARY,
        "--disable-gpu",
        "--disable-vulkan",
        "--disable-software-rasterizer",
        "--disable-gpu-compositing",
        "--no-default-browser-check",
        "--no-first-run",
        "--disable-3d-apis",
        "--disable-dev-shm-usage",
        "--disable-features=DisableLoadExtensionCommandLineSwitch",
        f"--load-extension={','.join(extension_paths)}",
        "--remote-debugging-address=0.0.0.0",
        "--remote-debugging-port=59222",
        "--remote-allow-origins=*",
        f"--user-data-dir={USER_DATA_DIR}",
        *extra_args,
    ]

    proc = await asyncio.create_subprocess_exec(
        *chrome_args,
        env=env,
    )
    log.info("Started Chrome (pid=%d)", proc.pid)
    return proc


async def main() -> int:
    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )

    extra_args = sys.argv[1:]
    processes: list[asyncio.subprocess.Process] = []
    shutdown = asyncio.Event()

    def on_signal(sig: int) -> None:
        log.info("Received %s, shutting down", signal.Signals(sig).name)
        shutdown.set()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, on_signal, sig)

    env = os.environ.copy()
    display_env = {**env, "DISPLAY": DISPLAY}

    processes.append(await start_socat())
    processes.append(await start_xvfb())
    processes.append(await start_fluxbox(display_env))
    processes.append(await start_x11vnc(display_env))
    processes.append(await start_websockify(display_env))

    dbus_address = await start_dbus()

    # Prepare Chrome user data
    user_data = Path(USER_DATA_DIR)
    if user_data.exists():
        shutil.rmtree(user_data)
    user_data.mkdir(parents=True)

    extension_paths = setup_extensions()

    chrome_env = {**display_env, "DBUS_SESSION_BUS_ADDRESS": dbus_address}
    chrome_proc = await start_chrome(chrome_env, extension_paths, extra_args)
    processes.append(chrome_proc)

    # Wait for shutdown signal or Chrome exit
    chrome_task = asyncio.create_task(chrome_proc.wait())
    shutdown_task = asyncio.create_task(shutdown.wait())

    done, _ = await asyncio.wait(
        [chrome_task, shutdown_task],
        return_when=asyncio.FIRST_COMPLETED,
    )

    if chrome_task in done:
        log.warning("Chrome exited with code %d", chrome_proc.returncode)

    log.info("Shutting down all processes")
    await terminate_all(processes)
    log.info("Shutdown complete")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
