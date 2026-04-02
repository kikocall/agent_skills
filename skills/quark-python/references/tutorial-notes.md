# Quark Python Tutorial Notes

This reference distills the provided DOCX tutorial about connecting Python to Quark.

## Dependencies Mentioned In The Tutorial

- Python `2.7+` or `3.5+`
- `six`
- `bitarray`
- `thrift==0.16.0`
- `thrift_sasl==0.4.3`
- Optional:
  - `kerberos>=1.3.0`
  - `pandas`
  - `sqlalchemy`

Tutorial installation example:

```bash
pip install quark_python-0.0.1-py2.py3-none-any.whl
```

Kerberos-related packages from the tutorial:

```bash
sudo yum install krb5-devel -y
pip install pykerberos
```

## Connection Modes Shown In The Tutorial

### 1. No security

```python
conn = connect(
    host='YOUR_HOST',
    port=10000,
)
```

### 2. Kerberos after manual `kinit`

```python
conn = connect(
    host='YOUR_HOST',
    port=10000,
    auth_mechanism='GSSAPI',
    kerberos_service_name='hive',
)
```

### 3. LDAP

```python
conn = connect(
    host='YOUR_HOST',
    port=10000,
    auth_mechanism='LDAP',
    user='YOUR_USER',
    password='YOUR_PASSWORD',
)
```

## Query Pattern Shown In The Tutorial

- Connect
- Create cursor
- Execute DDL or DML
- Execute `SELECT`
- Use `fetchall()`
- Iterate rows or turn them into a DataFrame
- Close cursor and connection

## Kerberos Automation Pattern

The tutorial includes a production-style wrapper that:

- stores host/port/auth config in constants
- uses `krbcontext` with `using_keytab=True`
- authenticates with `principal`, `keytab_file`, and `ccache_file`
- creates the Quark connection inside the Kerberos context
- retries once after a failed query
- returns `pandas.DataFrame`

## Multiprocess Pattern

The tutorial's multiprocess examples follow these rules:

- call `multiprocessing.set_start_method('spawn', force=True)`
- create the connection inside each worker process
- use `ProcessPoolExecutor`
- for keytab-based Kerberos, generate a unique credential cache path per PID

## Important Practical Takeaways

- If the user already does `kinit`, do not add keytab logic unless asked.
- If the script must run unattended, prefer a keytab flow.
- If the user wants pandas output, build columns from `cursor.description`.
- For production code, wrap connection lifecycle in a small class or helper instead of inlining everything.
