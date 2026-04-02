import atexit
import multiprocessing
import os
import time
from concurrent.futures import ProcessPoolExecutor

import pandas as pd
from krbcontext import krbcontext
from quark.dbapi import connect

try:
    from loguru import logger
except ImportError:  # pragma: no cover
    import logging

    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger(__name__)


multiprocessing.set_start_method("spawn", force=True)

QUARK_HOST = "YOUR_HOST"
QUARK_PORT = 10000
DATABASE = "YOUR_DATABASE"
AUTH_MECHANISM = "GSSAPI"
KERBEROS_SERVICE_NAME = "hive"
KEYTAB_PATH = "YOUR_KEYTAB_PATH"
USER_PRINCIPAL = "YOUR_PRINCIPAL"


class Connect:
    def __init__(self):
        self.conn = None
        self.cur = None
        self.db_connect()
        atexit.register(self.close)

    def db_connect(self):
        unique_ccache_path = f"/tmp/krb5cc_quark_{os.getpid()}"
        with krbcontext(
            using_keytab=True,
            principal=USER_PRINCIPAL,
            keytab_file=KEYTAB_PATH,
            ccache_file=unique_ccache_path,
        ):
            self.conn = connect(
                host=QUARK_HOST,
                port=QUARK_PORT,
                database=DATABASE,
                auth_mechanism=AUTH_MECHANISM,
                kerberos_service_name=KERBEROS_SERVICE_NAME,
            )
        self.cur = self.conn.cursor()

    def data_get_single(self, sql: str) -> pd.DataFrame:
        self.cur.execute(sql)
        columns = [desc[0] for desc in self.cur.description]
        rows = self.cur.fetchall()
        return pd.DataFrame(rows, columns=columns)

    def data_get(self, sql: str) -> pd.DataFrame:
        try:
            return self.data_get_single(sql)
        except Exception as exc:
            logger.error("Query failed, reconnecting once: %s", exc)
            time.sleep(1)
            self.close()
            self.db_connect()
            return self.data_get_single(sql)

    def close(self):
        try:
            if self.cur is not None:
                self.cur.close()
            if self.conn is not None:
                self.conn.close()
        except Exception:
            pass


def query_worker(query_sql: str) -> pd.DataFrame:
    conn = Connect()
    return conn.data_get(query_sql)


if __name__ == "__main__":
    if not os.path.exists(KEYTAB_PATH):
        raise FileNotFoundError(f"Keytab file not found: {KEYTAB_PATH}")

    sql_list = [
        "SELECT * FROM your_table LIMIT 1",
        "SELECT * FROM your_table LIMIT 2",
        "SELECT * FROM your_table LIMIT 3",
    ]

    results = []
    with ProcessPoolExecutor(max_workers=3) as executor:
        for data_frame in executor.map(query_worker, sql_list):
            if not data_frame.empty:
                results.append(data_frame)

    print(f"Finished, got {len(results)} result DataFrames")
