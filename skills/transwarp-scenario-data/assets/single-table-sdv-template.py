from __future__ import annotations

import pandas as pd
from sdv.metadata import SingleTableMetadata
from sdv.single_table import GaussianCopulaSynthesizer


def build_metadata(df: pd.DataFrame) -> SingleTableMetadata:
    metadata = SingleTableMetadata()
    metadata.detect_from_dataframe(data=df)

    # 当领域知识比自动识别更可靠时，在这里修正字段类型。
    # 示例：
    # metadata.update_column(column_name="customer_id", sdtype="id")
    # metadata.update_column(column_name="trade_time", sdtype="datetime")

    metadata.validate()
    return metadata


def main() -> None:
    source_path = "INPUT_SAMPLE.csv"
    output_path = "synthetic_single_table.csv"
    target_rows = 100000

    real_data = pd.read_csv(source_path)
    metadata = build_metadata(real_data)

    synthesizer = GaussianCopulaSynthesizer(metadata=metadata)
    synthesizer.fit(real_data)

    synthetic_data = synthesizer.sample(num_rows=target_rows)

    # 如果场景存在硬规则，在这里追加规则后处理。
    synthetic_data.to_csv(output_path, index=False, encoding="utf-8-sig")


if __name__ == "__main__":
    main()