"""Versioned numeric auth migration for explicitly named disposable clones.

Connection values come from environment. Legacy tables remain for offline rollback.
No default credentials, production execution, SQL hash conversion, or FK suppression.
"""
import argparse
import json
import os
import pathlib
import re
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--database', required=True)
parser.add_argument('--source-time-zone', required=True)
parser.add_argument('--policy', type=pathlib.Path, required=True)
parser.add_argument('--dependencies', required=True)
args = parser.parse_args()
if not re.fullmatch(r'wave01_clone_[a-z0-9_]+', args.database):
    raise SystemExit('Only an explicitly named wave01_clone_* database is permitted.')
if not re.fullmatch(r'[+-](?:0[0-9]|1[0-3]):[0-5][0-9]', args.source_time_zone):
    raise SystemExit('Source timezone must be an explicit verified UTC offset.')
sys.path.insert(0, args.dependencies)
import pymysql

catalog = ['users.read', 'users.create', 'users.update', 'users.delete', 'users.reset_password', 'users.assign_role',
           'roles.read', 'roles.manage', 'products.read', 'products.create', 'products.update', 'products.delete',
           'customers.read', 'customers.create', 'customers.update', 'customers.delete',
           'category.read', 'category.create', 'category.update', 'category.delete']
policy = json.loads(args.policy.read_text())
if not isinstance(policy, dict) or any(not key.isdecimal() or not isinstance(values, list) or
                                     len(set(values)) != len(values) or any(code not in catalog for code in values)
                                     for key, values in policy.items()):
    raise SystemExit('An explicit numeric role-to-permission plan is required.')
connection = pymysql.connect(host=os.environ['WAVE01_DB_HOST'], port=int(os.environ['WAVE01_DB_PORT']),
                             user=os.environ['WAVE01_DB_USER'], password=os.environ['WAVE01_DB_PASSWORD'],
                             database=args.database, charset='utf8mb4', autocommit=True)
auth_names = ['m_role', 'm_permission', 'role_permission', 'users', 'user_session', 'access_token',
              'refresh_token', 'password_reset_token', 'auth_security_event', 'auth_rate_limit']
legacy_names = ['m_role', 'users', 'user_session', 'access_token']
with connection.cursor() as cursor:
    cursor.execute('SET SESSION time_zone=%s', ('+00:00',))
    cursor.execute('SELECT VERSION()')
    version = cursor.fetchone()[0]
    cursor.execute('SHOW TABLES')
    existing = {row[0] for row in cursor.fetchall()}
    if not set(legacy_names).issubset(existing) or any(name in existing for name in auth_names if name not in legacy_names):
        raise SystemExit('Unsupported origin: expected legacy numeric auth, without auth-v2 tables.')
    if any(name.startswith(('auth_v2_', 'legacy_auth_')) for name in existing):
        raise SystemExit('Prior migration state exists; inspect before retry.')
    for table in ['m_role', 'users']:
        cursor.execute('SHOW COLUMNS FROM ' + table)
        columns = {row[0]: row[1] for row in cursor.fetchall()}
        if 'unsigned' not in columns['id'] or not columns['id'].startswith(('bigint', 'int')):
            raise SystemExit('Unsupported origin primary key type.')
    checks = [
        "SELECT COUNT(*) FROM users WHERE id>=9223372036854775808 OR is_active NOT IN (0,1) "
        "OR CHAR_LENGTH(username)>50 OR username NOT REGEXP '^[A-Za-z0-9_.-]+$' "
        "OR password_hash NOT REGEXP '^[a-fA-F0-9]{64}$'",
        "SELECT COUNT(*) FROM m_role WHERE id>2147483647 OR is_active NOT IN (0,1) OR is_superadmin NOT IN (0,1)",
        "SELECT COUNT(*) FROM users u LEFT JOIN m_role r ON r.id=u.role_internal_id "
        "WHERE u.role_internal_id IS NOT NULL AND r.id IS NULL",
        "SELECT COUNT(*) FROM users WHERE BINARY user_id NOT REGEXP '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'",
        "SELECT COUNT(*) FROM m_role WHERE BINARY role_id NOT REGEXP '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'",
    ]
    for index, sql in enumerate(checks):
        cursor.execute(sql)
        if cursor.fetchone()[0]:
            raise SystemExit('Preflight rejected invalid legacy data, check ' + str(index))
    cursor.execute('SELECT id FROM m_role')
    if not set(int(key) for key in policy).issubset(row[0] for row in cursor.fetchall()):
        raise SystemExit('Policy plan references an unknown role.')
    shadow = pathlib.Path(__file__).resolve().parents[1] / 'assets/databases/auth-v2-upgrade-numeric-20261001.sql'
    text = '\n'.join(line for line in shadow.read_text().splitlines() if not line.startswith('--'))
    for sql in text.split(';'):
        if sql.strip():
            cursor.execute(sql)
    cursor.execute("INSERT INTO auth_v2_m_role(id,role_id,role_code,role_name,description,is_active,is_superadmin,created_at,updated_at,deleted_at) "
                   "SELECT id,role_id,CONCAT('legacy_role_',id),role_name,description,is_active,is_superadmin,"
                   "CONVERT_TZ(created_at,%s,'+00:00'),CONVERT_TZ(updated_at,%s,'+00:00'),CONVERT_TZ(deleted_at,%s,'+00:00') FROM m_role",
                   (args.source_time_zone,) * 3)
    cursor.execute("INSERT INTO auth_v2_users(id,user_id,username,password_hash,password_changed_at,must_change_password,fullname,is_active,role_internal_id,created_at,updated_at,deleted_at) "
                   "SELECT id,user_id,username,password_hash,UTC_TIMESTAMP(6),1,fullname,is_active,role_internal_id,"
                   "CONVERT_TZ(created_at,%s,'+00:00'),CONVERT_TZ(updated_at,%s,'+00:00'),CONVERT_TZ(deleted_at,%s,'+00:00') FROM users",
                   (args.source_time_zone,) * 3)
    for code in catalog:
        cursor.execute('INSERT INTO auth_v2_m_permission(permission_code) VALUES(%s)', (code,))
    for role, codes in policy.items():
        for code in codes:
            cursor.execute('INSERT INTO auth_v2_role_permission(role_internal_id,permission_internal_id) '
                           'SELECT %s,id FROM auth_v2_m_permission WHERE permission_code=%s', (int(role), code))
    for table in ['m_role', 'users']:
        cursor.execute('SELECT COUNT(*) FROM ' + table)
        old = cursor.fetchone()[0]
        cursor.execute('SELECT COUNT(*) FROM auth_v2_' + table)
        if cursor.fetchone()[0] != old:
            raise SystemExit('Backfill count mismatch; maintenance must remain active.')
    connection.begin()
    try:
        cursor.execute('UPDATE access_token SET revoked=1 WHERE revoked=0')
        cursor.execute('UPDATE user_session SET revoked=1 WHERE revoked=0')
        connection.commit()
    except BaseException:
        connection.rollback()
        raise
    renames = [f'{name} TO legacy_auth_{name}' for name in legacy_names]
    renames += [f'auth_v2_{name} TO {name}' for name in auth_names]
    cursor.execute('RENAME TABLE ' + ', '.join(renames))
    cursor.execute('SELECT COUNT(*) FROM access_token')
    assert cursor.fetchone()[0] == 0
    cursor.execute('SELECT COUNT(*) FROM user_session')
    assert cursor.fetchone()[0] == 0
    print('PASS auth-v2 numeric clone migration; provider', version,
          '; users/roles preserved; legacy credentials revoked; new credentials empty; legacy tables retained.')
connection.close()
