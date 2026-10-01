"""Actual disposable Win64 listener/database audit and error-boundary regression."""
import argparse,json,pathlib,sys,secrets,time,uuid,subprocess,os,concurrent.futures,stat
import requests
p=argparse.ArgumentParser(); p.add_argument('--fixture',required=True); p.add_argument('--dependencies',required=True); p.add_argument('--url',default='http://127.0.0.1:19002/api/v1'); a=p.parse_args()
sys.path.insert(0,a.dependencies); import pymysql
s=json.loads(pathlib.Path(a.fixture).read_text(encoding='utf-8-sig')); root=pathlib.Path(__file__).resolve().parents[1]; run=root/'.ai/runs/wave-02'
assert s['db_name'].startswith('wave02_') and s['db_port']==19308
def connect(user='wave01',password=None):
 return pymysql.connect(host='127.0.0.1',port=s['db_port'],user=user,password=password or s['db_password'],database=s['db_name'],autocommit=True,charset='utf8mb4')
def request(method,path,token=None,body=None,status=200):
 r=requests.request(method,a.url+path,json=body,headers={'Authorization':'Bearer '+token} if token else {},timeout=30)
 assert r.status_code==status,(path,r.status_code)
 j=r.json(); assert j['status']==status and isinstance(j['data'],list) and 'request_detail' not in j
 assert r.headers['Cache-Control']=='no-store' and len(r.headers['X-Correlation-ID'])==36
 if status>=300: assert j['data']==[{}]
 assert 'secret-probe' not in r.text
 return r
with connect() as c,c.cursor() as q:
 q.execute('DELETE FROM auth_rate_limit')
admin=request('POST','/Auth/Login',body=dict(username=s['admin_username'],password=s['admin_password'],device_id=str(uuid.uuid4()))).json()['data'][0]
with connect(s['app_user'],s['app_password']) as c,c.cursor() as q:
 for sql in ['SELECT * FROM auth_security_event','UPDATE auth_security_event SET outcome=outcome','DELETE FROM auth_security_event']:
  try: q.execute(sql); raise AssertionError('App audit grant too broad')
  except pymysql.MySQLError as e: assert e.args[0]==1142
print('PASS app audit INSERT-only / SELECT UPDATE DELETE denied')
with connect() as c,c.cursor() as q:
 q.execute('SELECT event_code,outcome,actor_user_id,session_id,correlation_id,observed_ip_address FROM auth_security_event ORDER BY id DESC LIMIT 1'); event=q.fetchone()
 assert event[0]=='login' and event[1]=='success' and len(event[2])==36 and len(event[4])==36 and event[5]=='127.0.0.1'
 q.execute("CREATE TRIGGER wave02_fail_category BEFORE INSERT ON category FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='password=secret-probe raw payload'")
 try:
  r=request('POST','/Category',admin['access_token'],{'category_name':'failed_'+secrets.token_hex(5)},500)
  cid=r.headers['X-Correlation-ID']
  lines=(run/'logs/server-error.log').read_text(encoding='utf-8-sig').splitlines(); logs=[json.loads(x) for x in lines if x.strip()]
  matches=[x for x in logs if x['correlation_id']==cid]
  assert len(matches)==1 and 'db_kind' in matches[0] and 'db_code_0' in matches[0] and 'secret-probe' not in json.dumps(logs)
  with concurrent.futures.ThreadPoolExecutor(max_workers=20) as pool:
   failures=list(pool.map(lambda i: request('POST','/Category',admin['access_token'],{'category_name':'parallel_'+secrets.token_hex(6)},500),range(200)))
  lines=(run/'logs/server-error.log').read_text(encoding='utf-8-sig').splitlines(); logs=[json.loads(x) for x in lines if x.strip()]
  for failed in failures: assert sum(x['correlation_id']==failed.headers['X-Correlation-ID'] for x in logs)==1
  logfile=run/'logs/server-error.log'; os.chmod(logfile,stat.S_IREAD)
  try: request('POST','/Category',admin['access_token'],{'category_name':'readonly_'+secrets.token_hex(6)},500)
  finally: os.chmod(logfile,stat.S_IREAD|stat.S_IWRITE)
 finally: q.execute('DROP TRIGGER wave02_fail_category')
print('PASS actual CRUD fault200 parallel / one correlated safe diagnostic / read-only sink HTTP500 / no payload echo')
with connect() as c,c.cursor() as q:
 target_name='audit_'+secrets.token_hex(6)
 uid=request('POST','/User',admin['access_token'],dict(username=target_name,password=secrets.token_urlsafe(24),fullname='Before',role_id=2),201).json()['data'][0]['user_id']
 q.execute('SELECT fullname FROM users WHERE user_id=%s',(uid,)); before=q.fetchone()
 q.execute("CREATE TRIGGER wave02_fail_audit BEFORE INSERT ON auth_security_event FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='token=secret-probe'")
 try:
  request('PUT','/User/'+uid,admin['access_token'],{'fullname':'must rollback'},500)
  q.execute('SELECT fullname FROM users WHERE user_id=%s',(uid,)); assert q.fetchone()==before
 finally: q.execute('DROP TRIGGER wave02_fail_audit')
print('PASS required audit failure rolls back security mutation / does not open authorization')
with connect('root',s['root_password']) as c,c.cursor() as q:
 maint='wave02_maintenance'; pwd=secrets.token_urlsafe(24)
 q.execute("CREATE USER IF NOT EXISTS 'wave02_maintenance'@'127.0.0.1' IDENTIFIED BY %s",(pwd,))
 q.execute("ALTER USER 'wave02_maintenance'@'127.0.0.1' IDENTIFIED BY %s",(pwd,))
 q.execute(f"GRANT SELECT,DELETE ON {s['db_name']}.auth_security_event TO 'wave02_maintenance'@'127.0.0.1'")
 target=str(uuid.uuid4()); correlation=str(uuid.uuid4())
 q.execute('INSERT INTO users(user_id,username,password_hash) VALUES(%s,%s,%s)',(target,'cleanup_'+secrets.token_hex(5),'noncredential-test-row'))
 q.execute("INSERT INTO auth_security_event(event_code,outcome,target_user_id,correlation_id,occurred_at) VALUES('user_create','success',%s,%s,UTC_TIMESTAMP()-INTERVAL 91 DAY)",(target,correlation))
 q.execute('DELETE FROM users WHERE user_id=%s',(target,))
 q.execute('SELECT COUNT(*) FROM auth_security_event WHERE correlation_id=%s',(correlation,)); assert q.fetchone()[0]==1
with connect(maint,pwd) as c,c.cursor() as q:
 q.execute('DELETE FROM auth_security_event WHERE occurred_at<UTC_TIMESTAMP()-INTERVAL 90 DAY ORDER BY occurred_at,id LIMIT 100'); assert 1<=q.rowcount<=100
 try: q.execute("UPDATE auth_security_event SET outcome='failure'"); raise AssertionError('Maintenance UPDATE allowed')
 except pymysql.MySQLError as e: assert e.args[0]==1142
print('PASS no audit FK cascade on physical account cleanup / separate SELECT DELETE maintenance retention90d bounded100')
print('PASS logging/audit Win64 MariaDB11.4.9 suite')
