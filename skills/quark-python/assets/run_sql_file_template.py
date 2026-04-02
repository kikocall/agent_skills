from pathlib import Path

import pandas as pd
import yaml
from quark.dbapi import connect


BASE_DIR = Path(__file__).resolve().parents[1]
CONFIG_PATH = BASE_DIR / "config" / "quark.yaml"
SQL_PATH = BASE_DIR / "sql" / "query.sql"
OUTPUT_PATH = BASE_DIR / "output" / "query_result.csv"


def load_config():
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def load_sql():
    return SQL_PATH.read_text(encoding="utf-8")


def main():
    config = load_config()
    sql = load_sql()

    conn = None
    cursor = None
    try:
        conn = connect(
            host=config["host"],
            port=config["port"],
            database=config.get("database"),
            auth_mechanism=config.get("auth_mechanism", "NOSASL"),
            user=config.get("user"),
            password=config.get("password"),
            kerberos_service_name=config.get("kerberos_service_name", "hive"),
        )
        cursor = conn.cursor()
        cursor.execute(sql)

        columns = [desc[0] for desc in cursor.description]
        rows = cursor.fetchall()
        df = pd.DataFrame(rows, columns=columns)

        OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
        df.to_csv(OUTPUT_PATH, index=False, encoding="utf-8-sig")
        print(f"saved to {OUTPUT_PATH}")
    finally:
        if cursor is not None:
            cursor.close()
        if conn is not None:
            conn.close()


if __name__ == "__main__":
    main()
