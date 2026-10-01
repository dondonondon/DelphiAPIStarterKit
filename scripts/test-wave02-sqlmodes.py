"""Restart the owned WAVE02 listener against the disposable DB to verify inherited SQL modes."""
import argparse,json,pathlib,subprocess,sys
p=argparse.ArgumentParser();p.add_argument('--fixture',required=True);p.add_argument('--dependencies',required=True);a=p.parse_args()
sys.path.insert(0,a.dependencies);import pymysql
s=json.loads(pathlib.Path(a.fixture).read_text(encoding='utf-8-sig'));assert s['db_name'].startswith('wave02_') and s['db_port']==19308
root=pathlib.Path(__file__).resolve().parents[1];run=root/'.ai/runs/wave-02'
c=pymysql.connect(host='127.0.0.1',port=s['db_port'],user='root',password=s['root_password'],autocommit=True)
def stop():subprocess.run(['powershell.exe','-NoProfile','-File',str(run/'stop-listener.ps1')],check=True,cwd=root,stdout=subprocess.DEVNULL)
def start():subprocess.run([sys.executable,str(run/'start-listener.py')],check=True,cwd=root,stdout=subprocess.DEVNULL)
with c.cursor() as q:
 q.execute('SELECT @@GLOBAL.sql_mode');original=q.fetchone()[0]
 try:
  for mode in ['STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION','STRICT_ALL_TABLES,NO_ENGINE_SUBSTITUTION','']:
   stop();q.execute('SET GLOBAL sql_mode=%s',(mode,));start()
   result=subprocess.run([sys.executable,str(root/'scripts/test-wave02-domain.py'),'--fixture',a.fixture,'--dependencies',a.dependencies],cwd=root,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8')
   print('SQL_MODE',mode or '(permissive)',flush=True);print(result.stdout,flush=True);assert result.returncode==0
 finally:
  stop();q.execute('SET GLOBAL sql_mode=%s',(original,));start()
c.close();print('PASS all three inherited SQL modes / original test-server mode restored')
