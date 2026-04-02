# Quark Python Driver Notes

This reference is based on the provided `quark_python-0.0.1-py2.py3-none-any.whl`.

## Package Facts

- Package name: `quark-python`
- Version: `0.0.1`
- Main import path: `quark`
- DBAPI entry point: `from quark.dbapi import connect`

## Declared Dependencies In Metadata

- Required:
  - `six`
  - `bitarray<3`
  - `thrift`
  - `thrift_sasl`
- Optional Kerberos extra:
  - non-Windows: `kerberos>=1.3.0`
  - Windows: `winkerberos`

## DBAPI Signature Highlights

`quark.dbapi.connect(...)` accepts these notable arguments:

- `host='localhost'`
- `port=21050`
- `database=None`
- `timeout=None`
- `use_ssl=False`
- `ca_cert=None`
- `auth_mechanism='PLAIN'`
- `user=None`
- `password=None`
- `kerberos_service_name='quark'`
- `use_ldap=None`
- `ldap_user=None`
- `ldap_password=None`
- `use_kerberos=None`
- `krb_host=None`
- `retries=3`

Supported auth values in code:

- `NOSASL`
- `PLAIN`
- `GSSAPI`
- `LDAP`
- `JWT`

## Important Mismatch To Call Out

The tutorial shows a no-auth example that omits `auth_mechanism`, but the wheel's `connect()` default is `auth_mechanism='PLAIN'`.

When generating code for an unsecured connection, prefer one of these:

```python
conn = connect(host='YOUR_HOST', port=10000, auth_mechanism='NOSASL')
```

or, if the user's environment has a wrapper/config that truly works without the argument, mention that this behavior may be environment-specific.

## SQLAlchemy Support

The wheel registers a `quark` SQLAlchemy dialect from `quark.sqlalchemy`.

Use this form when the user asks for SQLAlchemy:

```python
from sqlalchemy import create_engine

engine = create_engine(
    "quark://USER:PASSWORD@YOUR_HOST:10000/YOUR_DB?auth_mechanism=LDAP"
)
```

For Kerberos, pass query parameters such as `auth_mechanism=GSSAPI` and `kerberos_service_name=hive`.

## DataFrame Conversion Pattern

The tutorial's pattern is compatible with the driver:

```python
cursor.execute(sql)
columns = [desc[0] for desc in cursor.description]
rows = cursor.fetchall()
df = pd.DataFrame(rows, columns=columns)
```

## Threading And Process Notes

- `threadsafety = 1`
- Treat connections as process-local and do not share live connection objects across workers.
