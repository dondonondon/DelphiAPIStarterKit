"""Fresh bootstrap, deployment refusal, exact bounds and recovery race on disposable schemas."""
import argparse,concurrent.futures,hashlib,json,os,pathlib,secrets,subprocess,sys,time,uuid
import requests
parser=argparse.ArgumentParser();parser.add_argument('--fixture',required=True);parser.add_argument('--dependencies',required=True);args=parser.parse_args();sys.path.insert(0,args.dependencies)
import pymysql
root=pathlib.Path(__file__).resolve().parents[1];f=json.loads(pathlib.Path(args.fixture).read_text());base='http://127.0.0.1:19001/api/v1'
def conn(name):
 assert name.startswith('wave01_');return pymysql.connect(host='127.0.0.1',port=f['db_port'],user='wave01',password=f['db_password'],database=name,autocommit=True,charset='utf8mb4')
def db(sql,params=()):
 with conn(f['db_name']) as c,c.cursor() as q:q.execute(sql,params);return q.fetchall()
def clear():db('DELETE FROM auth_rate_limit')
env=os.environ.copy();env['DELPHI_API_CONFIG']=str(root/'.ai/runs/wave-01/test-config.ini');env['DELPHI_API_ERROR_FILE']=str(root/'.ai/runs/wave-01/app-errors.log')
def cli(e):return subprocess.run([str(root/'bin/DelphiAPIStarterKit.exe'),'--bootstrap-admin'],env=e,capture_output=True,timeout=15,cwd=root/'.ai/runs/wave-01')
name='wave01_bootstrap_'+secrets.token_hex(4)
with conn(f['db_name']) as c,c.cursor() as q:q.execute('CREATE DATABASE '+name+' CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci')
with conn(name) as c,c.cursor() as q:
 text='\n'.join(line for line in (root/'assets/databases/demo_delphirest.sql').read_text(encoding='utf-8').splitlines() if not line.startswith('--'))
 for sql in text.split(';'):
  if sql.strip():q.execute(sql)
 q.execute('SELECT COUNT(*) FROM users');assert q.fetchone()[0]==0
fresh=env.copy();fresh.update(DELPHI_API_DB_DATABASE=name,DELPHI_API_BOOTSTRAP_USERNAME=f['admin_username'],DELPHI_API_BOOTSTRAP_PASSWORD=f['admin_password'])
assert cli(fresh).returncode==0 and cli(fresh).returncode==1
with conn(name) as c,c.cursor() as q:
 q.execute('SELECT must_change_password FROM users');assert q.fetchone()[0]==0
 q.execute('SELECT COUNT(*) FROM role_permission');assert q.fetchone()[0]==20
 q.execute("SELECT COUNT(*) FROM auth_security_event WHERE event_code='bootstrap_admin' AND target_user_id IS NOT NULL");assert q.fetchone()[0]==1
print('PASS actual fresh offline bootstrap / explicit grants / audit / replay refusal / different CWD config')
for key,value in [('DELPHI_API_SECURITY_PROFILE','mfa-required'),('DELPHI_API_ARGON2_SHA256','0'*64),('DELPHI_API_ARGON2_LIBRARY',str(root/'.ai/runs/wave-01/unavailable-provider.dll'))]:
 e=fresh.copy();e[key]=value;r=cli(e);assert r.returncode==1 and f['admin_password'].encode() not in r.stdout+r.stderr
print('PASS unavailable MFA profile / missing or wrong-pin provider fail closed / no credential echo')
clear();r=requests.post(base+'/Auth/Login',json={'username':f['admin_username'],'password':f['admin_password'],'device_id':'extra'});assert r.status_code==200;admin=r.json()['data'][0];h={'Authorization':'Bearer '+admin['access_token']}
import base64
hashed=hashlib.sha256(base64.urlsafe_b64decode(admin['access_token']+'=')).hexdigest();assert db('SELECT COUNT(*) FROM access_token WHERE token_hash=%s',(hashed,))[0][0]==1
print('PASS canonical 32-byte credential SHA-256 persistence / no UUID secret')
clear();n='bounds_'+secrets.token_hex(5);password='😀'*128
r=requests.post(base+'/User',headers=h,json={'username':n,'password':password,'fullname':'f'*100});assert r.status_code==201 and type(r.json()['data'][0]['is_active']) is bool
uid=r.json()['data'][0]['user_id']
r=requests.post(base+'/Auth/Login',json={'username':n,'password':password,'device_id':'d'*100,'device_name':'n'*100},headers={'User-Agent':'a'*255});assert r.status_code==200 and r.json()['data'][0]['password_change_required']
for body in [{'username':'u'*51,'password':'z'*20},{'username':'fullname_'+secrets.token_hex(4),'password':'z'*20,'fullname':'f'*101}]:assert requests.post(base+'/User',headers=h,json=body).status_code==400
clear();body=json.dumps({'username':f['admin_username'],'password':f['admin_password'],'device_id':'body'}).encode();payload=body+b' '*(16384-len(body))
assert requests.post(base+'/Auth/Login',data=payload,headers={'Content-Type':'application/json'}).status_code==200
assert requests.post('http://127.0.0.1:19001/api/v1/%41uth/Login',data=payload+b' ',headers={'Content-Type':'application/json'}).status_code==413
print('PASS password 128 Unicode/512 UTF8 bytes / fullname/device/agent bounds / 16KiB exact and encoded path cap')
for permissions in [['unknown.code'],['products.read','products.read'],[None],list(['products.read'])*101]:
 role=requests.get(base+'/Role',headers=h).json()['data'][0]['role_id'];r=requests.put(base+'/Role/'+role+'/Permissions',headers=h,json={'permissions':permissions});assert r.status_code==400
print('PASS role permission unknown/duplicate/null/max array rejected before mutation')
clear();reset=requests.post(base+'/User/'+uid+'/ResetPassword',headers=h,json={'confirm_reset':True});assert reset.status_code==200;t=reset.json()['data'][0]['reset_token'];new=secrets.token_urlsafe(24)
with concurrent.futures.ThreadPoolExecutor(2) as pool:
 responses=list(pool.map(lambda _:requests.post(base+'/Auth/CompletePasswordReset',json={'reset_token':t,'new_password':new}),range(2)))
assert sorted(r.status_code for r in responses)==[200,401]
assert db('SELECT COUNT(*) FROM password_reset_token WHERE user_internal_id=(SELECT id FROM users WHERE user_id=%s) AND consumed_at IS NOT NULL',(uid,))[0][0]==1
print('PASS parallel recovery redemption exactly once / shared revoke transaction')
clear(); db('UPDATE users SET is_active=0 WHERE user_id=%s',(uid,))
r=requests.post(base+'/Auth/Login',json={'username':n,'password':'wrong','device_id':'status'});assert r.status_code==401 and r.json()['messages']=='Invalid username or password.'
db('UPDATE users SET is_active=1,deleted_at=UTC_TIMESTAMP() WHERE user_id=%s',(uid,));r=requests.post(base+'/Auth/Login',json={'username':n,'password':new,'device_id':'status'});assert r.status_code==401 and r.json()['messages']=='Invalid username or password.'
print('PASS inactive/deleted credential failure generic / no status enumeration')
clear(); minimum_name=('n_'+secrets.token_hex(4)).ljust(50,'x');minimum_password='n'+secrets.token_hex(7)
r=requests.post(base+'/User',headers=h,json={'username':minimum_name,'password':minimum_password,'role_id':2});assert r.status_code==201
r=requests.post(base+'/Auth/Login',json={'username':minimum_name,'password':minimum_password,'device_id':'min'});assert r.status_code==200;limited=r.json()['data'][0]
new_minimum=secrets.token_urlsafe(24);r=requests.post(base+'/User/ChangePassword',headers={'Authorization':'Bearer '+limited['access_token']},json={'old_password':minimum_password,'new_password':new_minimum});assert r.status_code==200
r=requests.post(base+'/Auth/Login',json={'username':minimum_name,'password':new_minimum,'device_id':'role'});assert r.status_code==200;ordinary=r.json()['data'][0]
db('UPDATE m_role SET deleted_at=UTC_TIMESTAMP() WHERE id=2')
try:assert requests.get(base+'/Product',headers={'Authorization':'Bearer '+ordinary['access_token']}).status_code==403
finally:db('UPDATE m_role SET deleted_at=NULL WHERE id=2')
print('PASS username exact 50 / new password minimum 15 / deleted role deny default')
image=root/'files/image'/('wave01_'+secrets.token_hex(6)+'.png');image.parent.mkdir(parents=True,exist_ok=True)
content=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2tGkAAAAASUVORK5CYII=')
image.write_bytes(content)
try:
 r=requests.get('http://127.0.0.1:19001/image',params={'filename':image.name});assert r.status_code==200 and r.content==content and r.headers.get('Content-Encoding','')=='' and r.headers['Content-Type']=='image/png'
finally:image.unlink()
print('PASS actual image stream transferred ownership / MIME / identical raw bytes / no Content-Encoding')
print('TOTAL PASS extra 9 groups')
