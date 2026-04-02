from __future__ import annotations

from pathlib import Path
from typing import Iterable, List


def build_validation_steps(scene_name: str) -> List[str]:
    return [
        f"[{scene_name}] 生成小批维表和事实表样本",
        f"[{scene_name}] 上传小批文件到 HDFS 测试路径",
        f"[{scene_name}] 建外表或导入测试内表",
        f"[{scene_name}] 执行读回 SQL 和核心任务 SQL",
        f"[{scene_name}] 校验行数、空值、主外键和结果规模",
    ]


def save_validation_plan(output_path: Path, steps: Iterable[str]) -> None:
    output_path.write_text("\n".join(steps) + "\n", encoding="utf-8")


if __name__ == "__main__":
    plan = build_validation_steps("sample_scene")
    save_validation_plan(Path("validation_plan.txt"), plan)
