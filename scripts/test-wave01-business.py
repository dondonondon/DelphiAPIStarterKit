"""Positive business permission matrix on the disposable WAVE-01 listener."""
import argparse,json,pathlib,secrets,sys
import requests
p=argparse.ArgumentParser();p.add_argument('--fixture',required=True);p.add_argument('--dependencies',required=True);a=p.parse_args();sys.path.insert(0,a.dependencies)
import pymysql
f=json.loads(pathlib.Path(a.fixture).read_text());base='http://127.0.0.1:19001/api/v1'
with pymysql.connect(host='127.0.0.1',port=f['db_port'],user='wave01',password=f['db_password'],database=f['db_name'],autocommit=True) as c,c.cursor() as q:q.execute('DELETE FROM auth_rate_limit')
r=requests.post(base+'/Auth/Login',json={'username':f['admin_username'],'password':f['admin_password'],'device_id':'business-matrix'});assert r.status_code==200;h={'Authorization':'Bearer '+r.json()['data'][0]['access_token']}
for resource,idfield,namefield,table in [('Category','category_id','category_name','category'),('Customer','customer_id','customer_name','customer'),('Product','product_id','product_name','product')]:
 name='wave_positive_'+secrets.token_hex(5);r=requests.post(base+'/'+resource,headers=h,json={namefield:name});assert r.status_code==201,(resource,r.status_code);ident=r.json()['data'][0][idfield]
 assert requests.get(base+'/'+resource+'/'+ident,headers=h).status_code==200
 changed=name+'_updated';r=requests.put(base+'/'+resource+'/'+ident,headers=h,json={namefield:changed});assert r.status_code==200,(resource,r.status_code,r.json()['messages'])
 assert requests.get(base+'/'+resource+'/'+ident,headers=h).json()['data'][0][namefield]==changed
 assert requests.delete(base+'/'+resource+'/'+ident,headers=h).status_code==200
 assert requests.get(base+'/'+resource+'/'+ident,headers=h).status_code==404
 with pymysql.connect(host='127.0.0.1',port=f['db_port'],user='wave01',password=f['db_password'],database=f['db_name'],autocommit=True) as c,c.cursor() as q:
  q.execute('SELECT '+namefield+',deleted_at FROM '+table+' WHERE '+idfield+'=%s',(ident,));row=q.fetchone();assert row[0]==changed and row[1] is not None
 print('PASS '+resource+' effective create/read/update/delete grants / authoritative state / soft delete')
print('TOTAL PASS positive business 3 groups')
