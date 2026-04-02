from quark.dbapi import connect
import pandas as pd


def query_as_dataframe(sql: str) -> pd.DataFrame:
    conn = None
    cursor = None
    try:
        conn = connect(
            host="YOUR_HOST",
            port=10000,
            auth_mechanism="GSSAPI",
            kerberos_service_name="hive",
            database="YOUR_DATABASE",
        )
        cursor = conn.cursor()
        cursor.execute(sql)
        columns = [desc[0] for desc in cursor.description]
        rows = cursor.fetchall()
        return pd.DataFrame(rows, columns=columns)
    finally:
        if cursor is not None:
            cursor.close()
        if conn is not None:
            conn.close()


if __name__ == "__main__":
    # Run `kinit` successfully before launching this script.
    df = query_as_dataframe("SELECT * FROM your_table LIMIT 10")
    print(df.head())
