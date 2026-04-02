from quark.dbapi import connect


def main():
    conn = None
    cursor = None
    try:
        conn = connect(
            host="YOUR_HOST",
            port=10000,
            auth_mechanism="NOSASL",
        )
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        for row in cursor.fetchall():
            print(row)
    finally:
        if cursor is not None:
            cursor.close()
        if conn is not None:
            conn.close()


if __name__ == "__main__":
    main()
