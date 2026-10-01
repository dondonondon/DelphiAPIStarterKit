"""Run only after the PID/path-verified disposable MariaDB process is stopped."""
import argparse,concurrent.futures,json,pathlib,subprocess,time
import requests
parser=argparse.ArgumentParser();parser.add_argument('--fixture',required=True);args=parser.parse_args();root=pathlib.Path(__file__).resolve().parents[1];f=json.loads(pathlib.Path(args.fixture).read_text());base='http://127.0.0.1:19001/api/v1'
try:
    def failed(_):
        r=requests.get(base+'/Auth/Me',headers={'Origin':'https://wave-client.example'},timeout=90)
        assert r.status_code==500 and r.json()['status']==500 and r.json()['messages']=='Internal server error.' and r.json()['data']==[{}]
        assert set(r.json())=={'status','messages','servertime','data'} and r.headers['Cache-Control']=='no-store'
        assert r.headers['Access-Control-Allow-Origin']=='https://wave-client.example'
        return True
    with concurrent.futures.ThreadPoolExecutor(10) as pool:assert all(pool.map(failed,range(300)))
    assert requests.get(base+'/Unknown').status_code==404
    print('PASS actual DB stopped / 300 HTTP safe 500 / allowed CORS / no internals / unknown route remains 404',flush=True)
finally:
    directory=root/'.ai/cache/mariadb-11.4.9-winx64';out=open(root/'.ai/runs/wave-01/db-recovery-output.log','ab')
    p=subprocess.Popen([str(directory/'bin/mariadbd.exe'),'--no-defaults','--basedir='+str(directory),'--datadir='+str(root/'.ai/runs/wave-01/database'),'--port='+str(f['db_port']),'--bind-address=127.0.0.1','--skip-name-resolve','--console'],stdout=out,stderr=out,creationflags=subprocess.CREATE_NO_WINDOW);(root/'.ai/runs/wave-01/db.pid').write_text(str(p.pid));out.close()
for attempt in range(50):
    time.sleep(.3);r=requests.post(base+'/Auth/Login',json={'username':f['admin_username'],'password':f['admin_password'],'device_id':'recovery'})
    if r.status_code==200:break
assert r.status_code==200
print('PASS same listener recovers after disposable MariaDB restarts / successful login',flush=True)
