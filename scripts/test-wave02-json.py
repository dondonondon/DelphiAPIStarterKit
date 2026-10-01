"""Typed IO regressions on an actual disposable auth-v2 listener."""
import argparse,json,pathlib,sys,time,secrets,uuid
import requests
p=argparse.ArgumentParser(); p.add_argument('--fixture',required=True); p.add_argument('--dependencies',required=True); p.add_argument('--url',default='http://127.0.0.1:19002/api/v1'); a=p.parse_args()
sys.path.insert(0,a.dependencies); import pymysql
s=json.loads(pathlib.Path(a.fixture).read_text(encoding='utf-8-sig')); assert s['db_name'].startswith('wave02_')
def db(sql,params=()):
 c=pymysql.connect(host='127.0.0.1',port=s['db_port'],user='wave01',password=s['db_password'],database=s['db_name'],charset='utf8mb4',autocommit=True)
 try:
  with c.cursor() as q: q.execute(sql,params); return q.fetchall()
 finally: c.close()
def req(method,path,body=None,raw=None,media='application/json',expected=200,token=None):
 headers={'Content-Type':media}
 if token: headers['Authorization']='Bearer '+token
 r=requests.request(method,a.url+path,json=body,data=raw,headers=headers,timeout=30)
 assert r.status_code==expected,(path,r.status_code)
 j=json.loads(r.content); assert j['status']==r.status_code and isinstance(j['servertime'],str) and abs(int(j['servertime'])-time.time())<5
 assert 'request_detail' not in j and isinstance(j['data'],list) and r.headers['Cache-Control']=='no-store'
 if expected>=300: assert j['data']==[{}]
 for secret in [s['admin_password'],'secret-probe','old_password','new_password','password_hash']: assert secret not in r.text
 return j['data']
db('DELETE FROM auth_rate_limit')
admin=req('POST','/Auth/Login',dict(username=s['admin_username'],password=s['admin_password'],device_id=str(uuid.uuid4())))[0]; token=admin['access_token']
assert type(admin['expires_in']) is int and type(admin['refresh_expires_in']) is int and type(admin['password_change_required']) is bool
for field in ['access_token','refresh_token','session_id','token_type']: assert type(admin[field]) is str
print('PASS typed auth-v2 issuance / no-store / UTC / no echo')
for value in ['123','00123','1e2','{}','[]','Unicode 😀']:
 created=req('POST','/Customer',dict(customer_name=value,phone_number='+628123',postal_code='00123'),expected=201,token=token)[0]; cid=created['customer_id']
 read=req('GET','/Customer/'+cid,token=token)[0]; updated=req('PUT','/Customer/'+cid,dict(customer_name=value,phone_number='+628123'),token=token)[0]
 for row in [created,read,updated]:
  assert row['customer_name']==value and type(row['customer_name']) is str and row['phone_number']=='+628123' and row['postal_code']=='00123', ('string mismatch',[(k,type(row[k]).__name__,repr(row[k])) for k in ['customer_name','phone_number','postal_code']])
  assert type(row['is_active']) is bool
print('PASS business GET POST PUT string types / +phone / leading zeros / JSON-looking strings / Unicode')
before=db('SELECT (SELECT COUNT(*) FROM category),(SELECT COUNT(*) FROM product),(SELECT COUNT(*) FROM customer),(SELECT COUNT(*) FROM users)')
bad=['{','1','null','"scalar"','[1]','[{},{}]','{"category_name":1}','{"category_name":null}',
 '{"category_name":true}','{"category_name":"x","category_name":"y"}','{"category_name":"x","extra":1}',
 '{"category_name":{"a":{"b":{"c":{"d":1}}}}}',r'{"category_name":"\uD800"}',r'{"category_name":"\u0000"}',
 '{"category_name":"x"}{}','{"category_name":"x",}','{"category_name":"x","is_active":+1}',
 '{"category_name":"x","is_active":01}','{"category_name":"x","is_active":1.0}']
for raw in bad: req('POST','/Category',raw=raw.encode(),expected=400,token=token)
req('POST','/Category',raw=b'{"category_name":"x"}',media='text/plain',expected=415,token=token)
req('POST','/Category',raw=(' {"category_name":"'+('x'*17000)+'"}').encode(),expected=413,token=token)
req('GET','/Category',raw=b'[1]',expected=400,token=token)
assert before==db('SELECT (SELECT COUNT(*) FROM category),(SELECT COUNT(*) FROM product),(SELECT COUNT(*) FROM customer),(SELECT COUNT(*) FROM users)')
print('PASS strict invalid/type/null/batch/duplicate/media415/body413/depth / no business mutation')
for raw in ['{"product_name":"precision","stock":9007199254740993}','{"product_name":"precision","stock":9223372036854775808}',
 '{"product_name":"precision","price":1e2}','{"product_name":"precision","stock":"123"}']:
 req('POST','/Product',raw=raw.encode(),expected=400,token=token)
created=req('POST','/Product',raw=b'{"product_name":"00123","price":1234567890123.45,"stock":123}',expected=201,token=token)[0]
read=req('GET','/Product/'+created['product_id'],token=token)[0]
assert created['price']==read['price'] and type(created['product_name']) is str and created['category_id'] is None and read['category_id'] is None
print('PASS explicit Int64/domain overflow rejection / decimal exact readback / nullable reference')
username='typed_'+secrets.token_hex(5); password=secrets.token_urlsafe(24)
created=req('POST','/User',dict(username=username,password=password,role_id=2),expected=201,token=token)[0]; uid=created['user_id']
restricted=req('POST','/Auth/Login',dict(username=username,password=password,device_id=str(uuid.uuid4())))[0]
assert restricted['password_change_required'] is True and 'refresh_token' not in restricted and restricted['refresh_expires_in']==0
req('GET','/Product',token=restricted['access_token'],expected=403)
req('PUT','/User/'+uid,dict(password=secrets.token_urlsafe(24)),token=token,expected=400)
for role in [2,None]:
 updated=req('PUT','/User/'+uid,dict(role_id=role),token=token)[0]; read=req('GET','/User/'+uid,token=token)[0]
 for row in [updated,read]: assert row['role_id']==role and 'role_internal_id' not in row
assert created['role_id']==2 and type(created['role_id']) is int
print('PASS role_id consistent integer/null / restricted no refresh / generic password bypass rejected')
print('PASS Win64 typed IO suite')
