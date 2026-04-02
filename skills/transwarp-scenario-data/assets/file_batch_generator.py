from __future__ import annotations

import csv
from pathlib import Path
from random import Random
from typing import Dict, Iterable, List


def generate_dimension_batch(config: Dict[str, object], batch_ctx) -> List[Dict[str, object]]:
    rng = Random(config.get("seed", 20260328))
    rows: List[Dict[str, object]] = []
    for idx in range(batch_ctx.start_key, batch_ctx.end_key):
        rows.append(
            {
                "dim_id": idx,
                "dim_name": f"dim_{idx}",
                "status_cd": rng.choice(["A", "I"]),
            }
        )
    return rows


def generate_fact_batch(config: Dict[str, object], batch_ctx) -> List[Dict[str, object]]:
    rng = Random(config.get("seed", 20260328) + batch_ctx.start_key)
    rows: List[Dict[str, object]] = []
    for idx in range(batch_ctx.start_key, batch_ctx.end_key):
        rows.append(
            {
                "txn_id": idx,
                "customer_id": idx % int(config.get("customer_mod", 1000000)),
                "merchant_id": idx % int(config.get("merchant_mod", 50000)),
                "amt": round(rng.uniform(1, 50000), 2),
                "biz_date": config.get("biz_date", "2026-03-28"),
            }
        )
    return rows


def write_batch_files(
    records: Iterable[Dict[str, object]],
    output_dir: Path,
    file_name: str,
    fieldnames: List[str],
) -> Dict[str, int]:
    output_dir.mkdir(parents=True, exist_ok=True)
    file_path = output_dir / file_name
    row_count = 0
    with file_path.open("w", encoding="utf-8", newline="") as fp:
        writer = csv.DictWriter(fp, fieldnames=fieldnames)
        writer.writeheader()
        for record in records:
            writer.writerow(record)
            row_count += 1
    return {"row_count": row_count, "file_count": 1, "bytes": file_path.stat().st_size}

