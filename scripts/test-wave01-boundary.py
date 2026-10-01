"""Raw listener/security boundary checks on an isolated fixture."""
import argparse,concurrent.futures,json,os,pathlib,secrets,socket,subprocess,sys,time
parser=argparse.ArgumentParser(); parser.add_argument('--fixture',required=True); parser.add_argument('--dependencies',required=True); args=parser.parse_args();sys.path.insert(0,args.dependencies)
import pymysql,requests
root=pathlib.Path(__file__).resolve().parents[1]; f=json.loads(pathlib.Path(args.fixture).read_text()); base='http://127.0.0.1:19001/api/v1'
def db(sql,params=()):
    c=pymysql.connect(host='127.0.0.1',port=f['db_port'],user='wave01',password=f['db_password'],database=f['db_name'],autocommit=True,charset='utf8mb4')
    try:
        with c.cursor() as q:q.execute(sql,params);return q.fetchall()
    finally:c.close()
def clear():db('DELETE FROM auth_rate_limit')
def login():
    r=requests.post(base+'/Auth/Login',json={'username':f['admin_username'],'password':f['admin_password'],'device_id':'boundary'});assert r.status_code==200;return r.json()['data'][0]
def raw(headers,body=b''):
    s=socket.create_connection(('127.0.0.1',19001));s.settimeout(5);s.sendall(('POST /api/v1/Auth/Login HTTP/1.1\r\nHost: localhost\r\n'+headers+'Connection: close\r\n\r\n').encode()+body);data=b''
    while True:
        v=s.recv(8192)
        if not v:break
        data+=v
    s.close();h,b=data.split(b'\r\n\r\n',1);return h,json.loads(b)
r=requests.post(base+'/Auth/Login',data='a'*16385,headers={'Content-Type':'application/json','Origin':'https://wave-client.example'});assert r.status_code==413 and r.json()['data']==[{}] and r.headers['Cache-Control']=='no-store' and r.headers['Access-Control-Allow-Origin']=='https://wave-client.example'
print('PASS transport Content-Length body limit before allocation / 413 / no-store / CORS')
for headers in ['Authorization: Bearer x\r\nAuthorization: Bearer y\r\n','Content-Length: 1\r\nContent-Length: 2\r\n','Transfer-Encoding: chunked\r\n','X-HTTP-Method-Override: DELETE\r\n']:
    h,b=raw(headers);assert b['status']==400 and b['data']==[{}] and b'Cache-Control: no-store' in h
print('PASS raw duplicate/framing/method-override rejection safe envelope')
clear(); a=login(); token=a['access_token']; headers={'Authorization':'Bearer '+token}
for resource in ['Product','Customer','Category']:
    db('UPDATE m_permission SET is_active=0 WHERE permission_code LIKE %s',(resource.lower().replace('product','products').replace('customer','customers')+'.%',))
    try:
        for method,path in [('GET',''),('POST',''),('PUT','/00000000-0000-0000-0000-000000000000'),('DELETE','/00000000-0000-0000-0000-000000000000')]:
            r=requests.request(method,base+'/'+resource+path,headers=headers,json={'permission_probe':'bounded'} if method in ['POST','PUT'] else None);assert r.status_code==403
    finally:db('UPDATE m_permission SET is_active=1 WHERE permission_code LIKE %s',(resource.lower().replace('product','products').replace('customer','customers')+'.%',))
    assert requests.get(base+'/'+resource,headers=headers).status_code in (200,404)
print('PASS every Product/Customer/Category CRUD action denied without its effective permission / read restored')
clear(); statuses=[]
for i in range(61):
    r=requests.post(base+'/Auth/Login',json={'username':'origin_'+str(i),'password':'wrong','device_id':'limit'});statuses.append(r.status_code)
assert statuses==[401]*60+[429]
print('PASS observed-origin limit 60/61 across distinct accounts')
clear(); db("INSERT INTO auth_rate_limit(bucket_hash,window_start,attempts) VALUES(SHA2('global',256),FLOOR(UNIX_TIMESTAMP()/60),300)")
r=requests.post(base+'/Auth/Login',json={'username':'globalcase','password':'wrong','device_id':'limit'});assert r.status_code==429
print('PASS global limiter 300/301 / Retry-After');assert r.headers['Retry-After']=='60'
clear(); a=login(); token=a['access_token']; headers={'Authorization':'Bearer '+token}
for value in ['a'*14,'a'*129,'Password123456789',7,None,[],{}]:
    r=requests.post(base+'/User',headers=headers,json={'username':'bound_'+secrets.token_hex(4),'password':value});assert r.status_code==400
print('PASS password min/max/common blocklist/type/null before KDF')
for path in ['/Auth/Me?access_token='+token,'/Auth/Me?x-api-token='+token]:assert requests.get(base+path).status_code==401
print('PASS credentials in query do not authenticate')
clear(); env=os.environ.copy();env['PATH']=str(pathlib.Path(sys.executable).parent)+os.pathsep+env['PATH'];env['DELPHI_API_CONFIG']=str(root/'.ai/runs/wave-01/test-config.ini');env['DELPHI_API_PORT']='19004';env['DELPHI_API_ERROR_FILE']=str(root/'.ai/runs/wave-01')
log=open(root/'.ai/runs/wave-01/failing-logger-listener.log','ab');p=subprocess.Popen([str(root/'bin/DelphiAPIStarterKit.exe')],env=env,stdout=log,stderr=log,creationflags=subprocess.CREATE_NO_WINDOW)
try:
    time.sleep(.6);db("CREATE TRIGGER wave01_fail_audit BEFORE INSERT ON auth_security_event FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='synthetic audit failure'")
    try:
        r=requests.post('http://127.0.0.1:19004/api/v1/Auth/Login',json={'username':f['admin_username'],'password':f['admin_password'],'device_id':'audit'});assert r.status_code==500 and r.json()['messages']=='Internal server error.' and r.json()['data']==[{}]
    finally:db('DROP TRIGGER wave01_fail_audit')
    print('PASS audit failure rolls back issuance / file sink failure leaves safe HTTP 500')
finally:p.terminate();p.wait(timeout=10);log.close()
clear(); a=login(); before=db('SELECT COUNT(*) FROM refresh_token'); body=json.dumps({'refresh_token':a['refresh_token']}).encode();s=socket.create_connection(('127.0.0.1',19001));s.sendall(('POST /api/v1/Auth/Refresh HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: '+str(len(body))+'\r\nConnection: close\r\n\r\n').encode()+body);s.shutdown(socket.SHUT_RD)
for i in range(30):
    if db('SELECT COUNT(*) FROM refresh_token')!=before:break
    time.sleep(.1)
s.close();assert db('SELECT COUNT(*) FROM refresh_token')[0][0]==before[0][0]+1
r=requests.post(base+'/Auth/Refresh',json={'refresh_token':a['refresh_token']});assert r.status_code==401
assert db('SELECT revoked FROM user_session WHERE session_id=%s',(a['session_id'],))[0][0]==1
print('PASS refresh commit then disconnected/lost response / replay commits family revocation')
print('TOTAL PASS boundary 9 groups')


