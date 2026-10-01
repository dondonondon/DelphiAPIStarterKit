"""Domain constraints and deterministic real DB lock barriers; disposable clone only."""
import argparse,json,pathlib,sys,time,secrets,uuid,concurrent.futures,threading,decimal
import requests
p=argparse.ArgumentParser(); p.add_argument('--fixture',required=True); p.add_argument('--dependencies',required=True); p.add_argument('--url',default='http://127.0.0.1:19002/api/v1'); a=p.parse_args()
sys.path.insert(0,a.dependencies); import pymysql
s=json.loads(pathlib.Path(a.fixture).read_text(encoding='utf-8-sig')); assert s['db_name'].startswith('wave02_') and s['db_port']==19308
def connect(root=False,autocommit=True):
 return pymysql.connect(host='127.0.0.1',port=s['db_port'],user='root' if root else 'wave01',password=s['root_password'] if root else s['db_password'],database=s['db_name'],charset='utf8mb4',autocommit=autocommit)
def db(sql,params=()):
 with connect() as c,c.cursor() as q: q.execute(sql,params); return q.fetchall()
def req(method,path,body=None,raw=None,status=None):
 r=requests.request(method,a.url+path,json=body,data=raw,headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'},timeout=30)
 if status is not None: assert r.status_code==status,(path,r.status_code)
 j=json.loads(r.content,parse_float=decimal.Decimal)
 assert j['status']==r.status_code and 'request_detail' not in j and r.headers['Cache-Control']=='no-store'
 if r.status_code>=300: assert j['data']==[{}]
 return r,j['data']
db('DELETE FROM auth_rate_limit')
r=requests.post(a.url+'/Auth/Login',json=dict(username=s['admin_username'],password=s['admin_password'],device_id=str(uuid.uuid4())),timeout=30)
assert r.status_code==200; token=r.json()['data'][0]['access_token']
def clear(): db('DELETE FROM auth_rate_limit')
def category(name=None): return req('POST','/Category',{'category_name':name or 'cat_'+secrets.token_hex(6)},status=201)[1][0]['category_id']
def product(cat=None):
 body={'product_name':'product_'+secrets.token_hex(6),'price':12.34,'stock':3}
 if cat: body['category_id']=cat
 return req('POST','/Product',body,status=201)[1][0]['product_id']
def user(name=None,**fields):
 clear(); body=dict(username=name or 'user_'+secrets.token_hex(6),password=secrets.token_urlsafe(24),role_id=2,**fields)
 return req('POST','/User',body,status=201)[1][0]['user_id']
name='reserved_'+secrets.token_hex(5); cid=category(name)
req('POST','/Category',{'category_name':name},status=409); req('DELETE','/Category/'+cid,status=200)
req('POST','/Category',{'category_name':name},status=409)
other=category(); req('PUT','/Category/'+other,{'category_name':name},status=409)
race='duplicate_'+secrets.token_hex(5)
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
 statuses=list(pool.map(lambda _: req('POST','/Category',{'category_name':race})[0].status_code,range(2)))
assert sorted(statuses)==[201,409]
name='reserved_u_'+secrets.token_hex(5); uid=user(name); clear()
req('POST','/User',dict(username=name,password=secrets.token_urlsafe(24)),status=409)
req('PUT','/User/'+uid,{'username':'rename-not-supported'},status=400); req('DELETE','/User/'+uid,status=200); clear()
req('POST','/User',dict(username=name,password=secrets.token_urlsafe(24)),status=409)
clear(); race='dupe_user_'+secrets.token_hex(5); password=secrets.token_urlsafe(24)
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
 statuses=list(pool.map(lambda _: req('POST','/User',dict(username=race,password=password))[0].status_code,range(2)))
assert sorted(statuses)==[201,409]
print('PASS active/deleted names reserved / category rename / concurrent category+user native unique409')

def await_lock(blocking_id,future):
 deadline=time.monotonic()+8
 with connect(root=True) as c,c.cursor() as q:
  while time.monotonic()<deadline:
   q.execute("SELECT trx_query FROM information_schema.innodb_trx "
             "WHERE trx_state='LOCK WAIT' AND trx_mysql_thread_id<>%s",(blocking_id,))
   if any(row[0] and 'FOR UPDATE' in row[0].upper() for row in q.fetchall()): return
   if future.done():
    response=future.result()[0]
    raise AssertionError(('Request completed before the barrier',response.status_code,response.json()['messages']))
   time.sleep(.02)
 raise AssertionError('Expected request lock wait behind the controlled transaction not observed')
for resource,table,key,body,create in [('User','users','user_id',{'fullname':'new'},user),('Product','product','product_id',{'stock':9},product),('Category','category','category_id',{'description':'new'},category),
 ('Customer','customer','customer_id',{'city':'new'},lambda: req('POST','/Customer',{'customer_name':'barrier'},status=201)[1][0]['customer_id'])]:
 rid=create(); db(f'SELECT {key} FROM {table} WHERE {key}=%s',(rid,))
 with connect(autocommit=False) as b,b.cursor() as q,concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
  q.execute(f'UPDATE {table} SET deleted_at=UTC_TIMESTAMP(),is_active=0 WHERE {key}=%s',(rid,))
  future=pool.submit(req,'PUT',f'/{resource}/{rid}',body)
  try: await_lock(b.thread_id(),future)
  finally: b.commit()
  result=future.result(); assert result[0].status_code==404
 print('PASS deterministic SELECT-A / delete-B / actual blocked locked-update-A404',resource)
for resource,rid,body in [('User',user(fullname='same'),{'fullname':'same'}),('Category',category(),{'description':'same'}),('Product',product(),{'stock':3}),
 ('Customer',req('POST','/Customer',{'customer_name':'same'},status=201)[1][0]['customer_id'],{'customer_name':'same'})]:
 first=req('PUT',f'/{resource}/{rid}',body,status=200)[1][0]; second=req('PUT',f'/{resource}/{rid}',body,status=200)[1][0]
 assert first==second
print('PASS identical update valid regardless matched-vs-changed driver outcome')
pid=product()
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
 results=list(pool.map(lambda body:req('PUT','/Product/'+pid,body,status=200)[1][0],[{'stock':7},{'product_name':'after'}]))
final=req('GET','/Product/'+pid,status=200)[1][0]; assert final['stock']==7 and final['product_name']=='after' and final in results
print('PASS concurrent field updates preserve combined stored state / authoritative reply')

username='u'+secrets.token_hex(5)+'a'*39; assert len(username)==50
uid=user(username,fullname='F'*100); state=db('SELECT fullname,role_internal_id FROM users WHERE user_id=%s',(uid,))
for body in [{'fullname':'F'*101},{'fullname':None},{'fullname':123},{'role_id':-1},{'role_id':0},{'role_id':2147483647},{'role_id':'2'},{'role_id':True},{'is_active':None}]:
 req('PUT','/User/'+uid,body,status=400)
assert state==db('SELECT fullname,role_internal_id FROM users WHERE user_id=%s',(uid,))
req('POST','/User',dict(username=username+'x',password=secrets.token_urlsafe(24)),status=400)
roles=[]
with connect() as c,c.cursor() as q:
 for status,deleted in [(0,None),(1,'2026-10-01 00:00:00')]:
  q.execute('INSERT INTO m_role(role_id,role_code,role_name,is_active,deleted_at) VALUES(%s,%s,%s,%s,%s)',(str(uuid.uuid4()),'test_'+secrets.token_hex(5),'Reference '+secrets.token_hex(5),status,deleted)); roles.append(q.lastrowid)
for role in roles: req('PUT','/User/'+uid,{'role_id':role},status=400)
with connect() as c,c.cursor() as q:
 q.execute('INSERT INTO m_role(role_id,role_code,role_name) VALUES(%s,%s,%s)',(str(uuid.uuid4()),'race_'+secrets.token_hex(5),'Race '+secrets.token_hex(5))); role=q.lastrowid
with connect(autocommit=False) as b,b.cursor() as q,concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
 q.execute('UPDATE m_role SET is_active=0 WHERE id=%s',(role,)); future=pool.submit(req,'PUT','/User/'+uid,{'role_id':role})
 try: await_lock(b.thread_id(),future)
 finally: b.commit()
 assert future.result()[0].status_code==400
print('PASS username50/51 fullname100/101 / type/null / role0-negative-missing-inactive-deleted / role concurrent revalidation')

with connect() as c,c.cursor() as q:
 q.execute("SELECT COUNT(*) FROM information_schema.table_constraints WHERE constraint_schema=%s AND constraint_name='ck_product_price_nonnegative'",(s['db_name'],))
 if q.fetchone()[0]==0: q.execute('ALTER TABLE product ADD CONSTRAINT ck_product_price_nonnegative CHECK(price>=0), ADD CONSTRAINT ck_product_stock_nonnegative CHECK(stock>=0)')
 for sql in ['UPDATE product SET price=-1 LIMIT 1','UPDATE product SET stock=-1 LIMIT 1']:
  try:q.execute(sql); raise AssertionError('CHECK constraint not enforced')
  except pymysql.MySQLError as e: assert e.args[0]==4025
for value,expected in [('0',201),('9999999999999.99',201),('10000000000000',400),('-0.01',400),('1.234',400),('1.235',400),('1.2300',201)]:
 raw='{"product_name":"money","price":'+value+'}'
 data=req('POST','/Product',raw=raw.encode(),status=expected)[1]
 if expected==201:
  pid=data[0]['product_id']; read=req('GET','/Product/'+pid,status=200)[1][0]
  assert decimal.Decimal(str(data[0]['price']))==decimal.Decimal(value)==decimal.Decimal(str(read['price']))
  assert db('SELECT price FROM product WHERE product_id=%s',(pid,))[0][0]==decimal.Decimal(value)
print('PASS DECIMAL15,2 0/max/above/negative/1.234/1.235/trailing-zero / exact response GET stored decimal / DB CHECK')
for _ in range(10):
 cid=category()
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
  fs=[pool.submit(req,'POST','/Product',dict(product_name='reference-race',category_id=cid)),pool.submit(req,'DELETE','/Category/'+cid)]
  created,deleted=[x.result() for x in fs]
 assert (created[0].status_code,deleted[0].status_code) in [(201,409),(404,200)]
 assert db('SELECT COUNT(*) FROM product p JOIN category c ON c.id=p.category_internal_id WHERE c.category_id=%s AND p.deleted_at IS NULL AND c.deleted_at IS NOT NULL',(cid,))[0][0]==0
cid=category(); pid=product(cid); req('DELETE','/Category/'+cid,status=409)
req('PUT','/Product/'+pid,{'category_id':None},status=200); req('DELETE','/Category/'+cid,status=200)
assert req('GET','/Product/'+pid,status=200)[1][0]['category_id'] is None
cid=category(); pid=product(cid); db('UPDATE category SET deleted_at=UTC_TIMESTAMP() WHERE category_id=%s',(cid,)); row=req('GET','/Product/'+pid,status=200)[1][0]
assert row['category_id'] is None and row['category_name'] is None
print('PASS category assignment/delete concurrency block-reference policy / explicit detach / legacy deleted-reference masked null')
print('PASS Win64 MariaDB11.4.9 strict-mode domain suite')
