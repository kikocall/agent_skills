from __future__ import annotations

from pathlib import Path
import shutil


def probe_disk(target_dir: Path) -> dict[str, int]:
    usage = shutil.disk_usage(target_dir)
    return {
        "total_bytes": usage.total,
        "used_bytes": usage.used,
        "free_bytes": usage.free,
    }


def suggest_batch_size(free_bytes: int, reserve_bytes: int, ratio: float) -> int:
    safe_free = max(free_bytes - reserve_bytes, 256 * 1024 * 1024)
    ratio_bound = int(free_bytes * ratio)
    return max(256 * 1024 * 1024, min(safe_free, ratio_bound))


if __name__ == "__main__":
    target = Path(".").resolve()
    snapshot = probe_disk(target)
    suggested = suggest_batch_size(snapshot["free_bytes"], 150 * 1024 ** 3, 0.2)
    print(snapshot)
    print({"suggested_batch_bytes": suggested})
