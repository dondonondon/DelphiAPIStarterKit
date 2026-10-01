"""Run against an isolated auth-v2 MariaDB schema and the actual Windows listener.

Secrets are read from an ignored local fixture; only case names and outcomes are emitted.
"""
import argparse
import concurrent.futures
import json
import pathlib
import secrets
import sys
import time
import uuid

import requests

parser = argparse.ArgumentParser()
parser.add_argument('--fixture', required=True)
parser.add_argument('--dependencies', required=True)
parser.add_argument('--url', default='http://127.0.0.1:19001/api/v1')
args = parser.parse_args()
sys.path.insert(0, args.dependencies)
import pymysql

fixture = json.loads(pathlib.Path(args.fixture).read_text())
passed = []


def check(name, condition):
    if not condition:
        raise AssertionError(name)
    passed.append(name)
    print('PASS', name, flush=True)


def db(sql, params=()):
    connection = pymysql.connect(host='127.0.0.1', port=fixture['db_port'], user='wave01',
                                 password=fixture['db_password'], database=fixture['db_name'],
                                 charset='utf8mb4', autocommit=True)
    try:
        with connection.cursor() as cursor:
            cursor.execute(sql, params)
            return cursor.fetchall()
    finally:
        connection.close()


def request(method, path, token=None, body=None, headers=None, raw=None, expected=None):
    supplied = dict(headers or {})
    if token:
        supplied['Authorization'] = 'Bearer ' + token
    response = requests.request(method, args.url + path, headers=supplied, json=body,
                                data=raw, timeout=25)
    if response.status_code != 204:
        data = response.json()
        assert data['status'] == response.status_code
        assert isinstance(data['servertime'], str) and data['servertime'].isdigit()
        assert abs(int(data['servertime']) - time.time()) < 5
        assert isinstance(data['data'], list)
        assert 'request_detail' not in data
        if not 200 <= response.status_code < 300:
            assert data['data'] == [{}]
        assert response.headers.get('Content-Encoding', '') == ''
        assert response.headers.get('Cache-Control') == 'no-store'
    if expected is not None:
        assert response.status_code == expected, path + ' status ' + str(response.status_code)
    return response


def login(username, password, device=None):
    response = request('POST', '/Auth/Login', body=dict(username=username, password=password,
                                                     device_id=device or str(uuid.uuid4())), expected=200)
    data = response.json()['data'][0]
    assert type(data['expires_in']) is int and type(data['refresh_expires_in']) is int
    assert len(data['access_token']) == 43
    return data


def clear_limits():
    db('DELETE FROM auth_rate_limit')


clear_limits()
admin = login(fixture['admin_username'], fixture['admin_password'])
check('admin login / typed integer / no-store / UTC envelope', True)
for path, method, status in [('/Unknown', 'GET', 404), ('/User/x/a/b', 'POST', 404),
                             ('/User/', 'GET', 404), ('/User//a', 'GET', 404),
                             ('/Auth', 'GET', 404), ('/Auth/Login/x', 'POST', 404),
                             ('/Auth/Login', 'GET', 405), ('/User', 'PATCH', 405),
                             ('/User/ChangePassword/x', 'POST', 404)]:
    response = request(method, path, expected=status)
    if status == 405:
        assert response.headers.get('Allow')
check('route shape / unknown action / unsupported verb / Allow', True)
request('GET', '/Auth/Me', expected=401)
request('GET', '/Auth/Me', headers={'Authorization': 'Basic Zm9vOmJhcg=='}, expected=401)
request('GET', '/Auth/Me', headers={'x-api-token': admin['access_token']}, expected=200)
request('GET', '/Auth/Me', token=admin['access_token'], headers={'x-api-token': 'A' * 43}, expected=400)
request('GET', '/Auth/Me', token=admin['access_token'], headers={'x-api-token': admin['access_token']}, expected=200)
check('Bearer / missing / Basic / custom / dual-header conflict', True)
for origin, status in [('https://wave-client.example', 204), ('https://untrusted.example', 403)]:
    response = request('OPTIONS', '/Auth/Me', headers={'Origin': origin,
                      'Access-Control-Request-Method': 'GET',
                      'Access-Control-Request-Headers': 'Authorization, Content-Type'}, expected=status)
    assert response.headers.get('Access-Control-Allow-Origin') == (origin if status == 204 else None)
request('GET', '/Auth/Me', headers={'Origin': 'https://wave-client.example'}, expected=401)
request('OPTIONS', '/Auth/Me', headers={'Origin': 'https://wave-client.example',
        'Access-Control-Request-Method': 'GET', 'Access-Control-Request-Headers': 'X-Untrusted'}, expected=403)
check('actual CORS preflight allowlist / actual request still authenticated', True)

clear_limits()
username = 'ordinary_' + secrets.token_hex(4)
password = '  ' + secrets.token_urlsafe(20) + '  '
response = request('POST', '/User', token=admin['access_token'],
                   body={'username': username, 'password': password, 'fullname': 'Pengguna 😀', 'role_id': 2}, expected=201)
user_id = response.json()['data'][0]['user_id']
assert password not in response.text
ordinary = login(username, password)
check('Unicode user create / no password echo / restricted initial login', ordinary['password_change_required']
      and ordinary['refresh_expires_in'] == 0 and 'refresh_token' not in ordinary)
request('GET', '/Product', token=ordinary['access_token'], expected=403)
request('GET', '/Auth/Me', token=ordinary['access_token'], expected=403)
request('POST', '/User/ChangePassword', token=ordinary['access_token'],
        body={'old_password': password + 'x', 'new_password': secrets.token_urlsafe(20)}, expected=401)
new_password = secrets.token_urlsafe(24)
response = request('POST', '/User/ChangePassword', token=ordinary['access_token'],
                   body={'old_password': password, 'new_password': new_password}, expected=200)
assert response.json()['data'] == [] and password not in response.text and new_password not in response.text
request('GET', '/Product', token=ordinary['access_token'], expected=401)
ordinary = login(username, new_password)
check('self password old verification / no echo / full revoke / login again', not ordinary['password_change_required'])
request('GET', '/Product', token=ordinary['access_token'], expected=200)
before = db('SELECT fullname,is_active,role_internal_id,password_hash FROM users WHERE user_id=%s', (user_id,))
for method, path, body in [('GET', '/User', None), ('GET', '/User/' + user_id, None),
                         ('POST', '/User', {'username': 'forbidden', 'password': secrets.token_urlsafe(20)}),
                         ('PUT', '/User/' + user_id, {'role_id': 1}),
                         ('DELETE', '/User/' + user_id, None),
                         ('POST', '/User/' + user_id + '/ResetPassword', {'confirm_reset': True})]:
    request(method, path, ordinary['access_token'], body=body, expected=403)
check('ordinary admin/self/other mutations denied / stored state unchanged',
      before == db('SELECT fullname,is_active,role_internal_id,password_hash FROM users WHERE user_id=%s', (user_id,)))
request('PUT', '/User/' + user_id, admin['access_token'], body={'password': secrets.token_urlsafe(20)}, expected=400)
request('PUT', '/User/' + user_id, admin['access_token'], body={'role_id': 0}, expected=400)
request('PUT', '/User/' + user_id, admin['access_token'], body={'role_id': 999999}, expected=400)
check('generic password PUT / numeric role bounds and reference', True)
response = request('PUT', '/User/' + user_id, admin['access_token'], body={'fullname': 'Indonesia 😀'}, expected=200)
assert response.json()['data'][0]['fullname'] == 'Indonesia 😀'
check('actual UTF-8 bytes / emoji authoritative readback',
      json.loads(response.content.decode('utf-8'))['data'][0]['fullname'] == 'Indonesia 😀')

mine = request('GET', '/Auth/Sessions', ordinary['access_token'], expected=200).json()['data']
assert all(x['session_id'] != admin['session_id'] for x in mine)
request('DELETE', '/Auth/Sessions/' + admin['session_id'], ordinary['access_token'], expected=404)
check('session ownership / other session opaque 404 / bounded query', True)
request('GET', '/Auth/Sessions?limit=101', ordinary['access_token'], expected=400)
request('POST', '/Auth/Refresh', body={'session_id': ordinary['session_id'], 'device_id': 'test'}, expected=400)
request('POST', '/Auth/Logout', body={'session_id': ordinary['session_id'], 'device_id': 'test'}, expected=400)
check('legacy session-id/device-only refresh and logout denied', True)

clear_limits()
rotate = login(username, new_password)
rotated = request('POST', '/Auth/Refresh', body={'refresh_token': rotate['refresh_token']}, expected=200).json()['data'][0]
request('GET', '/Auth/Me', rotate['access_token'], expected=401)
request('POST', '/Auth/Refresh', body={'refresh_token': rotate['refresh_token']}, expected=401)
request('GET', '/Auth/Me', rotated['access_token'], expected=401)
request('POST', '/Auth/Refresh', body={'refresh_token': rotated['refresh_token']}, expected=401)
check('refresh rotation / old access revoke / reuse COMMIT family revoke', True)

clear_limits()
parallel = login(username, new_password)
with concurrent.futures.ThreadPoolExecutor(2) as pool:
    responses = list(pool.map(lambda _: request('POST', '/Auth/Refresh', body={'refresh_token': parallel['refresh_token']}), range(2)))
assert sorted(r.status_code for r in responses) == [200, 401]
successful = next(r for r in responses if r.status_code == 200).json()['data'][0]
request('GET', '/Auth/Me', successful['access_token'], expected=401)
check('parallel refresh single chain / second request reuse revocation committed', True)

clear_limits()
recovery_session = login(username, new_password)
pre_hash = db('SELECT password_hash FROM users WHERE user_id=%s', (user_id,))
reset = request('POST', '/User/' + user_id + '/ResetPassword', admin['access_token'],
                body={'confirm_reset': True}, expected=200).json()['data'][0]
assert 'temporary_password' not in reset and type(reset['expires_in']) is int
assert pre_hash == db('SELECT password_hash FROM users WHERE user_id=%s', (user_id,))
request('GET', '/Auth/Me', recovery_session['access_token'], expected=200)
replacement = secrets.token_urlsafe(24)
response = request('POST', '/Auth/CompletePasswordReset', body={'reset_token': reset['reset_token'],
                    'new_password': replacement}, expected=200)
assert response.json()['data'] == []
request('GET', '/Auth/Me', recovery_session['access_token'], expected=401)
request('POST', '/Auth/CompletePasswordReset', body={'reset_token': reset['reset_token'],
                    'new_password': secrets.token_urlsafe(24)}, expected=401)
login(username, replacement)
check('reset issuance keeps password/sessions / redemption full revoke / one-use / no auto-login', True)

clear_limits()
setup_name = 'setup_' + secrets.token_hex(4)
setup = request('POST', '/User', admin['access_token'], body={'username': setup_name}, expected=201).json()['data'][0]
setup_password = secrets.token_urlsafe(24)
request('POST', '/Auth/CompletePasswordReset', body={'reset_token': setup['setup_token'], 'new_password': setup_password}, expected=200)
setup_session = login(setup_name, setup_password)
check('one-time account setup / no random temporary password / no role deny default',
      not setup_session['password_change_required'])
request('GET', '/Product', setup_session['access_token'], expected=403)
db('UPDATE m_role SET is_active=0 WHERE id=2')
ordinary = login(username, replacement)
request('GET', '/Product', ordinary['access_token'], expected=403)
db('UPDATE m_role SET is_active=1 WHERE id=2')
db("UPDATE m_permission SET is_active=0 WHERE permission_code='products.read'")
request('GET', '/Product', ordinary['access_token'], expected=403)
db("UPDATE m_permission SET is_active=1 WHERE permission_code='products.read'")
check('null role / inactive role / inactive permission deny default', True)

for value in [None, 7, [], {}]:
    request('POST', '/Auth/Login', body={'username': fixture['admin_username'], 'password': value, 'device_id': 'bounds'}, expected=400)
for extra in [{'ip_address': '8.8.8.8'}, {'user_agent': 'spoof'}]:
    request('POST', '/Auth/Login', body={'username': fixture['admin_username'], 'password': fixture['admin_password'],
            'device_id': 'bounds', **extra}, expected=400)
request('POST', '/Auth/Login', body={'username': fixture['admin_username'], 'password': fixture['admin_password'], 'device_id': 'x' * 101}, expected=400)
request('POST', '/Auth/Login', raw='{"username":"a","username":"b"}', headers={'Content-Type': 'application/json'}, expected=400)
request('POST', '/Auth/Login', raw='{"username":"a"} garbage', headers={'Content-Type': 'application/json'}, expected=400)
request('POST', '/Auth/Login', raw='{"username":"a"}', headers={'Content-Type': 'text/plain'}, expected=415)
check('typed input / bounds / duplicate / trailing JSON / media / metadata spoof rejected', True)
clear_limits()
statuses = [request('POST', '/Auth/Login', body={'username': 'missinguser', 'password': 'incorrect', 'device_id': 'limit'}).status_code for _ in range(11)]
check('account throttle N/N+1 / generic credential failures', statuses == [401] * 10 + [429])

clear_limits()
role_catalog = request('GET', '/Role', admin['access_token'], expected=200).json()['data']
role_admin = next(row['role_id'] for row in role_catalog if row['legacy_role_id'] == 1)
role_user = next(row['role_id'] for row in role_catalog if row['legacy_role_id'] == 2)
user_permissions = ['roles.read', 'products.read', 'customers.read', 'category.read']
ordinary = login(username, replacement)
request('GET', '/Role', ordinary['access_token'], expected=200)
request('PUT', '/Role/' + role_user + '/Permissions', ordinary['access_token'], body={'permissions': ['users.read']}, expected=403)
request('PUT', '/Role/' + role_user + '/Permissions', admin['access_token'],
        body={'permissions': user_permissions + ['users.read']}, expected=200)
request('GET', '/Auth/Me', ordinary['access_token'], expected=401)
ordinary = login(username, replacement)
request('GET', '/User', ordinary['access_token'], expected=200)
request('PUT', '/Role/' + role_user + '/Permissions', admin['access_token'],
        body={'permissions': user_permissions}, expected=200)
request('GET', '/Auth/Me', ordinary['access_token'], expected=401)
request('PUT', '/Role/' + role_admin + '/Permissions', admin['access_token'], body={'permissions': []}, expected=409)
check('role catalog / explicit grants / privilege mutation revoke / last-admin rollback', True)

delegate_role = str(uuid.uuid4())
db("INSERT INTO m_role(role_id,role_code,role_name) VALUES(%s,%s,%s)", (delegate_role, 'delegate_'+secrets.token_hex(4), 'Delegate '+secrets.token_hex(4)))
delegate_id = db('SELECT id FROM m_role WHERE role_id=%s', (delegate_role,))[0][0]
for code in ['users.create', 'users.assign_role', 'roles.read']:
    db('INSERT INTO role_permission(role_internal_id,permission_internal_id) SELECT %s,id FROM m_permission WHERE permission_code=%s',
       (delegate_id, code))
delegate_name, delegate_password = 'delegate_' + secrets.token_hex(4), secrets.token_urlsafe(24)
request('POST', '/User', admin['access_token'], body={'username': delegate_name, 'password': delegate_password,
        'role_id': delegate_id}, expected=201)
delegate = login(delegate_name, delegate_password)
delegate_new = secrets.token_urlsafe(24)
request('POST', '/User/ChangePassword', delegate['access_token'],
        body={'old_password': delegate_password, 'new_password': delegate_new}, expected=200)
delegate = login(delegate_name, delegate_new)
request('POST', '/User', delegate['access_token'], body={'username': 'escalation_' + secrets.token_hex(3),
        'password': secrets.token_urlsafe(20), 'role_id': 1}, expected=403)
check('delegation cannot grant permissions outside actor boundary', True)

expiry_before = db('SELECT expires_at FROM user_session WHERE session_id=%s', (admin['session_id'],))
db('UPDATE user_session SET authenticated_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 600 SECOND) WHERE session_id=%s', (admin['session_id'],))
request('POST', '/User/' + user_id + '/ResetPassword', admin['access_token'], body={'confirm_reset': True}, expected=403)
request('POST', '/Auth/Reauthenticate', admin['access_token'], body={'password': 'incorrect'}, expected=401)
response = request('POST', '/Auth/Reauthenticate', admin['access_token'], body={'password': fixture['admin_password']}, expected=200)
assert response.json()['data'] == []
check('recent-auth gate / current-password reauth / absolute TTL unchanged',
      expiry_before == db('SELECT expires_at FROM user_session WHERE session_id=%s', (admin['session_id'],)))

clear_limits()
other = login(username, replacement)
ordinary = login(username, replacement)
request('DELETE', '/Auth/Sessions/' + other['session_id'], ordinary['access_token'], expected=200)
request('DELETE', '/Auth/Sessions/' + other['session_id'], ordinary['access_token'], expected=200)
request('GET', '/Auth/Me', other['access_token'], expected=401)
request('POST', '/Auth/LogoutAll', ordinary['access_token'], expected=200)
request('GET', '/Auth/Me', ordinary['access_token'], expected=401)
request('POST', '/Auth/Logout', token=ordinary['access_token'], expected=200)
request('POST', '/Auth/Logout', token=ordinary['access_token'], expected=200)
check('own session revoke idempotent / LogoutAll / known logout idempotent', True)

clear_limits()
expired = login(username, replacement)
db('UPDATE user_session SET created_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 2 DAY),'
   'idle_expires_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 SECOND) WHERE session_id=%s', (expired['session_id'],))
request('GET', '/Auth/Me', expired['access_token'], expected=401)
request('POST', '/Auth/Refresh', body={'refresh_token': expired['refresh_token']}, expected=401)
absolute = login(username, replacement)
db('UPDATE user_session SET created_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 2 DAY),'
   'expires_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 SECOND),idle_expires_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 2 SECOND) '
   'WHERE session_id=%s', (absolute['session_id'],))
request('POST', '/Auth/Refresh', body={'refresh_token': absolute['refresh_token']}, expected=401)
check('idle and absolute session expiry deny access/refresh', True)

clear_limits()
race = login(username, replacement)
with concurrent.futures.ThreadPoolExecutor(2) as pool:
    refresh_future = pool.submit(request, 'POST', '/Auth/Refresh', body={'refresh_token': race['refresh_token']})
    logout_future = pool.submit(request, 'POST', '/Auth/Logout', token=race['access_token'])
    refresh_response, logout_response = refresh_future.result(), logout_future.result()
assert logout_response.status_code == 200 and refresh_response.status_code in (200, 401)
assert db('SELECT revoked FROM user_session WHERE session_id=%s', (race['session_id'],))[0][0] == 1
if refresh_response.status_code == 200:
    request('GET', '/Auth/Me', refresh_response.json()['data'][0]['access_token'], expected=401)
check('logout-refresh linearizable race / no credential remains active', True)

clear_limits()
ordinary = login(username, replacement)
before_hash = db('SELECT password_hash FROM users WHERE user_id=%s', (user_id,))
db("CREATE TRIGGER wave01_revoke_failure BEFORE UPDATE ON user_session FOR EACH ROW "
   "BEGIN IF NEW.revoked=1 AND OLD.revoked=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='test revoke failure'; END IF; END")
try:
    request('POST', '/User/ChangePassword', ordinary['access_token'],
            body={'old_password': replacement, 'new_password': secrets.token_urlsafe(24)}, expected=500)
finally:
    db('DROP TRIGGER wave01_revoke_failure')
assert before_hash == db('SELECT password_hash FROM users WHERE user_id=%s', (user_id,))
request('GET', '/Auth/Me', ordinary['access_token'], expected=200)
check('password mutation and credential revoke rollback together after actual DB error', True)

old_reset = request('POST', '/User/' + user_id + '/ResetPassword', admin['access_token'],
                    body={'confirm_reset': True}, expected=200).json()['data'][0]
new_reset = request('POST', '/User/' + user_id + '/ResetPassword', admin['access_token'],
                    body={'confirm_reset': True}, expected=200).json()['data'][0]
request('POST', '/Auth/CompletePasswordReset', body={'reset_token': old_reset['reset_token'],
        'new_password': secrets.token_urlsafe(24)}, expected=401)
db('UPDATE password_reset_token SET created_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 100 SECOND),'
   'expires_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 SECOND) WHERE user_internal_id='
   '(SELECT id FROM users WHERE user_id=%s) AND consumed_at IS NULL', (user_id,))
request('POST', '/Auth/CompletePasswordReset', body={'reset_token': new_reset['reset_token'],
        'new_password': secrets.token_urlsafe(24)}, expected=401)
request('POST', '/Auth/CompletePasswordReset', body={'reset_token': ordinary['access_token'],
        'new_password': secrets.token_urlsafe(24)}, expected=401)
check('superseded/expired recovery and wrong credential purpose rejected', True)

request('PUT', '/User/' + user_id, admin['access_token'], body={'is_active': 0}, expected=200)
request('GET', '/Auth/Me', ordinary['access_token'], expected=401)
request('POST', '/Auth/Refresh', body={'refresh_token': ordinary['refresh_token']}, expected=401)
response = request('POST', '/Auth/Login', body={'username': username, 'password': replacement, 'device_id': 'disabled'}, expected=401)
assert response.json()['messages'] == 'Invalid username or password.'
request('PUT', '/User/' + user_id, admin['access_token'], body={'is_active': 1}, expected=200)
ordinary = login(username, replacement)
db('UPDATE m_role SET is_superadmin=1 WHERE id=2')
request('GET', '/User', ordinary['access_token'], expected=403)
db('UPDATE m_role SET is_superadmin=0 WHERE id=2')
check('disable revokes credential / generic status / is_superadmin metadata has no bypass', True)

clear_limits()
shared_password = secrets.token_urlsafe(24)
names = ['salt_' + secrets.token_hex(4) for _ in range(2)]
for name in names:
    request('POST', '/User', admin['access_token'], body={'username': name, 'password': shared_password}, expected=201)
hashes = [db('SELECT password_hash FROM users WHERE username=%s', (name,))[0][0] for name in names]
check('Argon2id versioned PHC / same password different random salt', hashes[0] != hashes[1]
      and all(value.startswith('$argon2id$v=19$m=19456,t=2,p=1$') for value in hashes))
for name in names:
    login(name, shared_password)
    request('POST', '/Auth/Login', body={'username': name, 'password': 'wrong', 'device_id': 'wrong'}, expected=401)
check('actual provider verifies new hashes / wrong password rejected', True)

clear_limits()
observed = request('POST', '/Auth/Login', body={'username': username, 'password': replacement,
        'device_id': 'n' * 100, 'device_name': 'd' * 100}, headers={'X-Forwarded-For': '8.8.8.8', 'User-Agent': 'observed-agent'}, expected=200).json()['data'][0]
assert db('SELECT ip_address,user_agent FROM user_session WHERE session_id=%s', (observed['session_id'],))[0] == ('127.0.0.1', 'observed-agent')
request('POST', '/Auth/Login', body={'username': username, 'password': replacement, 'device_id': 'bounds',
        'device_name': 'd' * 101}, expected=400)
request('POST', '/Auth/Login', body={'username': username, 'password': replacement, 'device_id': 'bounds'},
        headers={'User-Agent': 'a' * 256}, expected=400)
check('N/N+1 metadata bounds / observed peer and header / proxy spoof ignored', True)

clear_limits()
with concurrent.futures.ThreadPoolExecutor(4) as pool:
    responses = list(pool.map(lambda _: request('POST', '/Auth/Login',
        body={'username': 'parallel-missing', 'password': 'wrong', 'device_id': 'rate'}), range(11)))
check('parallel account rate limit counter atomic', sorted(r.status_code for r in responses) == [401] * 10 + [429])
clear_limits()
slots = []
try:
    for index in range(4):
        connection = pymysql.connect(host='127.0.0.1', port=fixture['db_port'], user='wave01',
            password=fixture['db_password'], database=fixture['db_name'], autocommit=True)
        with connection.cursor() as cursor:
            cursor.execute('SELECT GET_LOCK(%s,0)', ('delphi.auth.kdf.' + str(index),))
            assert cursor.fetchone()[0] == 1
        slots.append(connection)
    request('POST', '/Auth/Login', body={'username': username, 'password': replacement, 'device_id': 'admission'}, expected=429)
finally:
    for connection in slots:
        connection.close()
check('shared DB KDF admission slots deny overload before password verification', True)

clear_limits()
other_name, other_password = 'admin_' + secrets.token_hex(4), secrets.token_urlsafe(24)
other_id = request('POST', '/User', admin['access_token'], body={'username': other_name, 'password': other_password,
                   'role_id': 1}, expected=201).json()['data'][0]['user_id']
other_admin = login(other_name, other_password)
other_new = secrets.token_urlsafe(24)
request('POST', '/User/ChangePassword', other_admin['access_token'], body={'old_password': other_password, 'new_password': other_new}, expected=200)
other_admin = login(other_name, other_new)
admin_id = request('GET', '/Auth/Me', admin['access_token'], expected=200).json()['data'][0]['user_id']
with concurrent.futures.ThreadPoolExecutor(2) as pool:
    responses = list(pool.map(lambda pair: request('DELETE', '/User/' + pair[0], pair[1]),
                    [(other_id, admin['access_token']), (admin_id, other_admin['access_token'])]))
assert sorted(r.status_code for r in responses) in ([200, 401], [200, 403])
check('two-admin concurrent deletion keeps a qualified administrator',
      db('SELECT COUNT(*) FROM users WHERE role_internal_id=1 AND is_active=1 AND deleted_at IS NULL AND must_change_password=0')[0][0] >= 1)
db('UPDATE users SET deleted_at=NULL,is_active=1 WHERE user_id IN (%s,%s)', (admin_id, other_id))

print('TOTAL PASS', len(passed), flush=True)
