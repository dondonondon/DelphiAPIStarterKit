"""Alternative fresh imports and the narrow clone delta, MariaDB test fixture only."""
import argparse,json,pathlib,re,secrets,sys,uuid
p=argparse.ArgumentParser();p.add_argument('--fixture',required=True);p.add_argument('--dependencies',required=True);a=p.parse_args()
sys.path.insert(0,a.dependencies);import pymysql
s=json.loads(pathlib.Path(a.fixture).read_text(encoding='utf-8-sig'))
assert s['db_name'].startswith('wave02_') and s['db_port']==19308
root=pathlib.Path(__file__).resolve().parents[1]
c=pymysql.connect(host='127.0.0.1',port=s['db_port'],user='root',password=s['root_password'],autocommit=True,charset='utf8mb4')
def execute_file(q,path,schema):
 text=path.read_text(encoding='utf-8-sig').replace('demo_delphirest',schema)
 text='\n'.join(line for line in text.splitlines() if not line.lstrip().startswith('--'))
 for statement in text.split(';'):
  if statement.strip():q.execute(statement)
def definitions(q,schema):
 q.execute(f'USE `{schema}`')
 q.execute('SELECT table_name FROM information_schema.tables WHERE table_schema=%s ORDER BY table_name',(schema,));tables=[x[0] for x in q.fetchall()]
 out={}
 for table in tables:
  q.execute(f'SHOW CREATE TABLE `{schema}`.`{table}`');out[table]=re.sub(r' AUTO_INCREMENT=\d+','',q.fetchone()[1])
 return out
with c.cursor() as q:
 q.execute('SELECT VERSION(),@@sql_mode');version,mode=q.fetchone();print('DATABASE',version,'SQL_MODE',mode)
 schemas=['wave02_baseline_'+secrets.token_hex(4),'wave02_sample_'+secrets.token_hex(4)]
 for schema,filename in zip(schemas,['demo_delphirest.sql','demo_delphirest_withdatasample.sql']):
  q.execute(f'CREATE DATABASE `{schema}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');q.execute(f'USE `{schema}`')
  execute_file(q,root/'assets/databases'/filename,schema)
 baseline,sample=(definitions(q,x) for x in schemas);assert baseline==sample and len(baseline)==13
 for schema in schemas:
  for table in ['users','user_session','access_token','refresh_token','password_reset_token']:
   q.execute(f'SELECT COUNT(*) FROM `{schema}`.`{table}`');assert q.fetchone()[0]==0
 print('PASS alternative baseline/sample fresh-empty import / identical13 table DDL / no seeded credentials')
 q.execute(f'USE `{schemas[0]}`')
 q.execute('ALTER TABLE product DROP CONSTRAINT ck_product_price_nonnegative,DROP CONSTRAINT ck_product_stock_nonnegative')
 execute_file(q,root/'assets/databases/wave02-domain-upgrade-20261002.sql',schemas[0])
 assert definitions(q,schemas[0])==sample
 print('PASS narrow WAVE02 clone delta restores identical fresh product CHECK schema')
 q.execute('INSERT INTO product(product_id,product_name) VALUES(%s,%s)',(str(uuid.uuid4()),'constraint-boundary'))
 for mode in ['STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION','STRICT_ALL_TABLES,NO_ENGINE_SUBSTITUTION','']:
  q.execute('SET SESSION sql_mode=%s',(mode,))
  for column in ['price','stock']:
   try:q.execute(f'UPDATE product SET {column}=-1');raise AssertionError('CHECK enforcement missing')
   except pymysql.MySQLError as e:assert e.args[0]==4025
  q.execute('UPDATE product SET price=9999999999999.99');q.execute('SELECT price FROM product');assert str(q.fetchone()[0])=='9999999999999.99'
 print('PASS DB nonnegative CHECK and maximum decimal under strict-trans / strict-all / permissive modes')
c.close()
