from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Dict, List


@dataclass
class BatchContext:
    batch_id: str
    local_dir: Path
    hdfs_dir: str
    table_name: str
    start_key: int
    end_key: int


class BatchGenerationController:
    """批量文件模式的最小主控骨架。"""

    def __init__(
        self,
        manifest_path: Path,
        generator: Callable[[BatchContext], Dict[str, int]],
        uploader: Callable[[BatchContext], None],
        upload_verifier: Callable[[BatchContext], None],
        cleanup_enabled: bool = True,
    ) -> None:
        self.manifest_path = manifest_path
        self.generator = generator
        self.uploader = uploader
        self.upload_verifier = upload_verifier
        self.cleanup_enabled = cleanup_enabled
        self._manifest = self._load_manifest()

    def _load_manifest(self) -> Dict[str, List[Dict[str, object]]]:
        if self.manifest_path.exists():
            return json.loads(self.manifest_path.read_text(encoding="utf-8"))
        return {"batches": []}

    def checkpoint(self, batch_ctx: BatchContext, status: str, **extra: object) -> None:
        record = {
            "batch_id": batch_ctx.batch_id,
            "table_name": batch_ctx.table_name,
            "local_path": str(batch_ctx.local_dir),
            "hdfs_path": batch_ctx.hdfs_dir,
            "status": status,
            **extra,
        }
        self._manifest["batches"].append(record)
        self.manifest_path.write_text(
            json.dumps(self._manifest, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    def run_batch(self, batch_ctx: BatchContext) -> None:
        stats = self.generator(batch_ctx)
        self.checkpoint(batch_ctx, "generated", **stats)
        self.uploader(batch_ctx)
        self.upload_verifier(batch_ctx)
        self.checkpoint(batch_ctx, "uploaded", **stats)
        if self.cleanup_enabled:
            self.cleanup_local(batch_ctx)
            self.checkpoint(batch_ctx, "cleaned", **stats)

    def cleanup_local(self, batch_ctx: BatchContext) -> None:
        for file_path in batch_ctx.local_dir.glob("*"):
            if file_path.is_file():
                file_path.unlink()

