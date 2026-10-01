"""Concurrent auth-v2 mutations on a disposable test fixture."""
import argparse,concurrent.futures,json,pathlib,secrets,sys
import requests
parser=argparse.ArgumentParser();parser.add_argument('--fixture',required=True);parser.add_argument('--dependencies',required=True);parser.add_argument('--url',default='http://127.0.0.1:19001/api/v1');args=parser.parse_args();sys.path.insert(0,args.dependencies)
import pymysql
f=json.loads(pathlib.Path(args.fixture).read_text(encoding='utf-8-sig'));base=args.url
def db(sql,params=()):
 with pymysql.connect(host='127.0.0.1',port=f['db_port'],user='wave01',password=f['db_password'],database=f['db_name'],autocommit=True,charset='utf8mb4') as c,c.cursor() as q:q.execute(sql,params);return q.fetchall()
def clear():db('DELETE FROM auth_rate_limit')
def login(name,password):
 r=requests.post(base+'/Auth/Login',json={'username':name,'password':password,'device_id':'race'});assert r.status_code==200;return r.json()['data'][0]
clear();admin=login(f['admin_username'],f['admin_password']);headers={'Authorization':'Bearer '+admin['access_token']}
def account():
 name='race_'+secrets.token_hex(5);pwd=secrets.token_urlsafe(24);r=requests.post(base+'/User',headers=headers,json={'username':name,'role_id':2});assert r.status_code==201;row=r.json()['data'][0]
 r=requests.post(base+'/Auth/CompletePasswordReset',json={'reset_token':row['setup_token'],'new_password':pwd});assert r.status_code==200
 return row['user_id'],name,pwd,login(name,pwd)
def parallel(first,second):
 with concurrent.futures.ThreadPoolExecutor(2) as p:
  a=p.submit(first);b=p.submit(second);return a.result(),b.result()
def inactive(sid):return db('SELECT revoked FROM user_session WHERE session_id=%s',(sid,))[0][0]==1
clear();uid,name,pwd,s=account();new=secrets.token_urlsafe(24)
a,b=parallel(lambda:requests.post(base+'/User/ChangePassword',headers={'Authorization':'Bearer '+s['access_token']},json={'old_password':pwd,'new_password':new}),lambda:requests.post(base+'/Auth/Refresh',json={'refresh_token':s['refresh_token']}))
assert a.status_code in (200,401) and b.status_code in (200,401)
if a.status_code==200:
 assert inactive(s['session_id']);login(name,new)
else:
 assert b.status_code==200 and not inactive(s['session_id']);login(name,pwd)
print('PASS password-change versus refresh / serialized revoke or stale-access denial / current hash authoritative')
clear();uid,name,pwd,s=account()
a,b=parallel(lambda:requests.put(base+'/User/'+uid,headers=headers,json={'is_active':0}),lambda:requests.post(base+'/Auth/Refresh',json={'refresh_token':s['refresh_token']}))
assert a.status_code==200 and b.status_code in (200,401) and inactive(s['session_id'])
assert requests.post(base+'/Auth/Refresh',json={'refresh_token':s['refresh_token']}).status_code==401
print('PASS disable versus refresh / committed account and credential state')
clear();uid,name,pwd,s=account();r=requests.post(base+'/User/'+uid+'/ResetPassword',headers=headers,json={'confirm_reset':True});assert r.status_code==200;reset=r.json()['data'][0]['reset_token'];new=secrets.token_urlsafe(24)
a,b=parallel(lambda:requests.post(base+'/Auth/CompletePasswordReset',json={'reset_token':reset,'new_password':new}),lambda:requests.post(base+'/Auth/Login',json={'username':name,'password':pwd,'device_id':'login-race'}))
assert a.status_code==200 and b.status_code in (200,401) and inactive(s['session_id'])
if b.status_code==200:assert inactive(b.json()['data'][0]['session_id'])
login(name,new)
print('PASS reset-redemption versus in-flight old-password login / compare-under-lock / full revoke')
clear();uid,name,pwd,s=account();r=requests.post(base+'/User/'+uid+'/ResetPassword',headers=headers,json={'confirm_reset':True});assert r.status_code==200;reset=r.json()['data'][0]['reset_token'];before=db('SELECT password_hash FROM users WHERE user_id=%s',(uid,))
a,b=parallel(lambda:requests.post(base+'/Auth/CompletePasswordReset',json={'reset_token':reset,'new_password':secrets.token_urlsafe(24)}),lambda:requests.put(base+'/User/'+uid,headers=headers,json={'is_active':0}))
assert a.status_code in (200,401) and b.status_code==200 and inactive(s['session_id'])
if a.status_code==401:assert before==db('SELECT password_hash FROM users WHERE user_id=%s',(uid,))
print('PASS reset-redemption versus disable / linearized outcome or unchanged password on denial')


import uuid
clear()
def role(codes):
 public=str(uuid.uuid4());key='race_role_'+secrets.token_hex(5)
 db('INSERT INTO m_role(role_id,role_code,role_name) VALUES(%s,%s,%s)',(public,key,key))
 ident=db('SELECT id FROM m_role WHERE role_id=%s',(public,))[0][0]
 for code in codes:db('INSERT INTO role_permission(role_internal_id,permission_internal_id) SELECT %s,id FROM m_permission WHERE permission_code=%s',(ident,code))
 return public,ident
delegate_public,delegate_id=role(['users.assign_role','roles.manage','products.read']);target_public,target_id=role([])
name='race_delegate_'+secrets.token_hex(5);pwd=secrets.token_urlsafe(24)
r=requests.post(base+'/User',headers=headers,json={'username':name,'role_id':delegate_id});assert r.status_code==201
r=requests.post(base+'/Auth/CompletePasswordReset',json={'reset_token':r.json()['data'][0]['setup_token'],'new_password':pwd});assert r.status_code==200
delegate=login(name,pwd)
a,b=parallel(lambda:requests.put(base+'/Role/'+target_public+'/Permissions',headers={'Authorization':'Bearer '+delegate['access_token']},json={'permissions':['products.read']}),lambda:requests.put(base+'/Role/'+delegate_public+'/Permissions',headers=headers,json={'permissions':['users.assign_role','roles.manage']}))
assert a.status_code in (200,401,403) and b.status_code==200 and inactive(delegate['session_id'])
assert db('SELECT COUNT(*) FROM role_permission rp JOIN m_permission p ON p.id=rp.permission_internal_id WHERE rp.role_internal_id=%s AND p.permission_code=%s',(delegate_id,'products.read'))[0][0]==0
if a.status_code!=200:assert db('SELECT COUNT(*) FROM role_permission WHERE role_internal_id=%s',(target_id,))[0][0]==0
print('PASS delegation grant versus actor privilege removal / serialized grant or denial / session revocation')
clear();uid,name,pwd,ordinary=account();prefix='wave_bound_'+secrets.token_hex(5)+'_'
existing=db('SELECT COUNT(*) FROM role_permission WHERE role_internal_id=2')[0][0]
try:
 for index in range(101-existing):
  code=prefix+str(index);db('INSERT INTO m_permission(permission_code,description) VALUES(%s,%s)',(code,code))
  db('INSERT INTO role_permission(role_internal_id,permission_internal_id) SELECT 2,id FROM m_permission WHERE permission_code=%s',(code,))
 r=requests.get(base+'/Auth/Me',headers={'Authorization':'Bearer '+ordinary['access_token']});assert r.status_code==403 and r.json()['data']==[{}]
 assert requests.post(base+'/User',headers=headers,json={'username':'overflow_'+secrets.token_hex(5),'role_id':2}).status_code==403
finally:
 db('DELETE rp FROM role_permission rp JOIN m_permission p ON p.id=rp.permission_internal_id WHERE p.permission_code LIKE %s',(prefix+'%',))
 db('DELETE FROM m_permission WHERE permission_code LIKE %s',(prefix+'%',))
print('PASS permission bound 101 fails closed at actor resolution and delegation / no truncated grants')
print('TOTAL PASS race 6 groups')
