"""Verify auth-v2 fresh and migrated disposable MariaDB schemas; never production."""
import argparse, json, os, pathlib, re, subprocess, sys, time, uuid
parser=argparse.ArgumentParser()
parser.add_argument('--fixture',required=True)
parser.add_argument('--dependencies',required=True)
args=parser.parse_args(); sys.path.insert(0,args.dependencies)
import pymysql, requests
root=pathlib.Path(__file__).resolve().parents[1]
s=json.loads(pathlib.Path(args.fixture).read_text())
def connect(name):
    assert name.startswith('wave01_')
    return pymysql.connect(host='127.0.0.1',port=s['db_port'],user='wave01',password=s['db_password'],database=name,charset='utf8mb4',autocommit=True)
names=['m_role','m_permission','role_permission','users','user_session','access_token','refresh_token','password_reset_token','auth_security_event','auth_rate_limit']
def ddl(c,name):
    with c.cursor() as q:
        q.execute('SHOW CREATE TABLE '+name); v=q.fetchone()[1]
        return re.sub(r' AUTO_INCREMENT=\d+','',v).replace('`v2_','`')
with connect('wave01_baseline') as b, connect('wave01_sample') as c, connect('wave01_clone_numeric') as m:
    for name in names:
        assert ddl(b,name)==ddl(c,name)==ddl(m,name),name+' schema mismatch'
    print('PASS fresh baseline/sample and numeric migrated auth schema equivalent')
    with b.cursor() as q:
        for name in ['users','user_session','access_token','refresh_token','password_reset_token']:
            q.execute('SELECT COUNT(*) FROM '+name); assert q.fetchone()[0]==0
    print('PASS fresh baseline has no seeded user or credentials')
    with c.cursor() as q:
        def reject(sql,params=()):
            try:q.execute(sql,params)
            except pymysql.MySQLError:return
            raise AssertionError('DB constraint was not enforced')
        c.begin()
        try:
            q.execute("INSERT INTO users(user_id,username,password_hash) VALUES(%s,%s,'test-only-invalid-provider-hash')",(str(uuid.uuid4()),'constraint_'+uuid.uuid4().hex))
            user=q.lastrowid
            reject('UPDATE users SET is_active=2 WHERE id=%s',(user,))
            reject('UPDATE users SET role_internal_id=2147483647 WHERE id=%s',(user,))
            reject("INSERT INTO role_permission SELECT role_internal_id,permission_internal_id,created_at FROM role_permission LIMIT 1")
            sessions=[]
            for i in range(2):
                q.execute("INSERT INTO user_session(session_id,user_internal_id,device_id,idle_expires_at,expires_at) VALUES(%s,%s,'constraint',UTC_TIMESTAMP()+INTERVAL 1 DAY,UTC_TIMESTAMP()+INTERVAL 2 DAY)",(str(uuid.uuid4()),user)); sessions.append(q.lastrowid)
            reject('UPDATE user_session SET idle_expires_at=expires_at+INTERVAL 1 DAY WHERE id=%s',(sessions[0],))
            hashes=['a'*64,'b'*64]
            ids=[]
            for i in range(2):
                q.execute('INSERT INTO refresh_token(token_hash,session_internal_id,expires_at) VALUES(%s,%s,UTC_TIMESTAMP()+INTERVAL 1 DAY)',(hashes[i],sessions[i])); ids.append(q.lastrowid)
            reject('UPDATE refresh_token SET replaced_by_internal_id=%s WHERE id=%s',(ids[1],ids[0]))
            reject('INSERT INTO refresh_token(token_hash,session_internal_id,expires_at) VALUES(%s,%s,UTC_TIMESTAMP()+INTERVAL 1 DAY)',(hashes[0],sessions[0]))
            reject('UPDATE refresh_token SET revoked=2 WHERE id=%s',(ids[0],))
            reject('UPDATE refresh_token SET expires_at=created_at WHERE id=%s',(ids[0],))
            reject("INSERT INTO password_reset_token(token_hash,user_internal_id,purpose,expires_at) VALUES(%s,%s,'access',UTC_TIMESTAMP()+INTERVAL 1 DAY)",('c'*64,user))
        finally:c.rollback()
    print('PASS live FK/CHECK/unique/expiry/cross-session successor enforcement')
    renames=[f'{n} TO restore_v2_{n}' for n in names]+[f'legacy_auth_{n} TO {n}' for n in ['m_role','users','user_session','access_token']]
    with m.cursor() as q:
        q.execute('RENAME TABLE '+','.join(renames))
        try:
            q.execute('SELECT COUNT(*) FROM user_session WHERE revoked=0'); assert q.fetchone()[0]==0
            q.execute('SELECT COUNT(*) FROM access_token WHERE revoked=0'); assert q.fetchone()[0]==0
        finally:
            undo=[f'{n} TO legacy_auth_{n}' for n in ['m_role','users','user_session','access_token']]+[f'restore_v2_{n} TO {n}' for n in names]
            q.execute('RENAME TABLE '+','.join(undo))
    print('PASS numeric clone atomic restore/re-cutover preserves invalidated legacy credentials')
env=os.environ.copy(); env['PATH']=str(pathlib.Path(sys.executable).parent)+os.pathsep+env['PATH']; env['DELPHI_API_CONFIG']=str(root/'.ai/runs/wave-01/test-config.ini'); env['DELPHI_API_ERROR_FILE']=str(root/'.ai/runs/wave-01/app-errors.log')
r=subprocess.run([str(root/'bin/DelphiAPIStarterKit.exe'),'--bootstrap-admin'],env=env,capture_output=True)
assert r.returncode==1
print('PASS offline bootstrap refuses replay/nonempty user table without default credential')
c=connect(s['db_name'])
with c.cursor() as q:
    q.execute("SELECT id FROM users WHERE username=%s",(s['admin_username'],)); uid=q.fetchone()[0]
    sid=str(uuid.uuid4()); q.execute("INSERT INTO user_session(session_id,user_internal_id,device_id,created_at,idle_expires_at,expires_at) VALUES(%s,%s,'retention',UTC_TIMESTAMP()-INTERVAL 20 DAY,UTC_TIMESTAMP()-INTERVAL 15 DAY,UTC_TIMESTAMP()-INTERVAL 14 DAY)",(sid,uid)); internal=q.lastrowid
    q.execute("SELECT COUNT(*) FROM refresh_token r JOIN user_session s ON s.id=r.session_internal_id WHERE s.expires_at>UTC_TIMESTAMP() AND r.consumed_at IS NOT NULL"); retained=q.fetchone()[0]; assert retained>0
r=subprocess.run([str(root/'bin/DelphiAPIStarterKit.exe'),'--auth-cleanup'],env=env,capture_output=True); assert r.returncode==0
with c.cursor() as q:
    q.execute('SELECT COUNT(*) FROM user_session WHERE id=%s',(internal,)); assert q.fetchone()[0]==0
    q.execute("SELECT COUNT(*) FROM refresh_token r JOIN user_session s ON s.id=r.session_internal_id WHERE s.expires_at>UTC_TIMESTAMP() AND r.consumed_at IS NOT NULL"); assert q.fetchone()[0]==retained
c.close(); print('PASS bounded cleanup removes expired old family and preserves active reuse chain')
legacy=json.loads((root/'.ai/runs/wave-01/clone-secrets.json').read_text())
with connect('wave01_clone_numeric') as c, c.cursor() as q:
    q.execute('UPDATE users u JOIN legacy_auth_users l ON l.user_id=u.user_id SET u.password_hash=l.password_hash,u.must_change_password=1 WHERE u.username=%s',(legacy['username'],))
env['DELPHI_API_DB_DATABASE']='wave01_clone_numeric'; env['DELPHI_API_PORT']='19002'; env['DELPHI_API_HMAC_SECRET']=legacy['key']; env['DELPHI_API_LEGACY_HASH_DEADLINE']=str(int(time.time())+3600)
f=open(root/'.ai/runs/wave-01/clone-listener.log','ab'); p=subprocess.Popen([str(root/'bin/DelphiAPIStarterKit.exe')],env=env,stdout=f,stderr=f,creationflags=subprocess.CREATE_NO_WINDOW)
try:
    time.sleep(.8); base='http://127.0.0.1:19002/api/v1'
    response=requests.post(base+'/Auth/Login',json={'username':legacy['username'],'password':legacy['password'],'device_id':'legacy'},timeout=15); assert response.status_code==200
    token=response.json()['data'][0]; assert token['password_change_required'] and 'refresh_token' not in token
    with connect('wave01_clone_numeric') as c, c.cursor() as q:
        q.execute('SELECT password_hash FROM users WHERE username=%s',(legacy['username'],)); assert q.fetchone()[0].startswith('$argon2id$v=19$m=19456,t=2,p=1$')
    response=requests.get(base+'/Product',headers={'Authorization':'Bearer '+token['access_token']}); assert response.status_code==403
    print('PASS actual numeric-clone legacy HMAC login rehash / version window / restricted cutover')
finally:
    p.terminate(); p.wait(timeout=10); f.close()
print('TOTAL PASS database/cutover 7 groups')
