from __future__ import annotations

import pandas as pd
from sdv.metadata import MultiTableMetadata
from sdv.multi_table import HMASynthesizer


def build_metadata(real_data: dict[str, pd.DataFrame]) -> MultiTableMetadata:
    metadata = MultiTableMetadata()

    for table_name, dataframe in real_data.items():
        metadata.detect_table_from_dataframe(table_name=table_name, data=dataframe)

    # 在这里显式补充主外键关系。
    # 示例：
    # metadata.add_relationship(
    #     parent_table_name="customer",
    #     child_table_name="account",
    #     parent_primary_key="customer_id",
    #     child_foreign_key="customer_id",
    # )

    metadata.validate()
    return metadata


def main() -> None:
    real_data = {
        "customer": pd.read_csv("customer_sample.csv"),
        "account": pd.read_csv("account_sample.csv"),
        "txn": pd.read_csv("txn_sample.csv"),
    }

    metadata = build_metadata(real_data)
    synthesizer = HMASynthesizer(metadata)
    synthesizer.fit(real_data)

    synthetic_data = synthesizer.sample()

    for table_name, dataframe in synthetic_data.items():
        # 如果场景有硬规则，可在导出前对每张表追加后处理。
        dataframe.to_csv(f"synthetic_{table_name}.csv", index=False, encoding="utf-8-sig")


if __name__ == "__main__":
    main()