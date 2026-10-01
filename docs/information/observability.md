# Logging dan audit auth-v2

`BFA.Logger` adalah satu authority diagnostic error. `TServerConfig.LogFile` menyelesaikan
`Logging.Root` relatif terhadap lokasi config yang sudah di-resolve; gunakan absolute writable root
di deployment. `ErrorFile`/`DELPHI_API_ERROR_FILE` tetap compatible; relative filename berada di log root.
Binary/config tidak perlu writable. File UTF-8 JSON lines memakai UTC dan correlation UUID server;
`X-Correlation-ID` response sama dengan audit/diagnostic request. Input correlation client tidak dipercaya.

`MaxBytes` default 10 MiB (1024..1073741824), `RetainedFiles` default5 (1..100). Satu lock mengoordinasikan
append dan rotation pada satu process. Tiap instance memakai file berbeda; supervisor/collector mengumpulkan
stderr. File read-only/full/path unavailable menghasilkan fallback stderr tanpa mengubah status/body.
Collector/volume quota, service ACL, multi-instance file naming, stderr retention dan full-volume fault
harus divalidasi pada actual deployment; host test tidak membuktikan gate tersebut.

Log hanya context konstan, class exception, exception address, native DB error codes/kind, correlation
dan class kegagalan rollback. Tidak menyalin exception message, SQL, bind values, HTTP headers/body,
password/token/hash. Address membantu diagnosis bersama binary/source manifest; bukan stack trace lengkap.
Expected unique conflict menjadi409 tanpa diagnostic500. Endpoint menjadi owner log unexpected service
failure; transaction helper menjaga exception awal dan memasukkan secondary rollback class pada event sama.

Audit `Auth.Repository.Audit` memakai event/outcome allowlist dan public actor/target/session UUID,
correlation serta observed origin. Required security mutation rollback bila INSERT audit gagal;
denied audit best-effort tidak mengubah403. Audit tidak mempunyai FK cascade ke akun. Account/session
cleanup tidak menghapus audit. Delivery credential hanya response issuance berwenang no-store;
audit/diagnostic tidak menyimpan credential.

App DB identity diberi **INSERT saja** pada `auth_security_event`, tanpa SELECT/UPDATE/DELETE/DDL.
Table lain diberi privileges kebutuhan repository secara eksplisit, bukan schema-wide ALL yang
secara tidak sengaja memberi audit mutation. Akun maintenance terpisah diberi SELECT/DELETE audit,
tanpa UPDATE. Bootstrap memakai maintenance provisioning saat fresh install dan app INSERT audit.
Sesuaikan nama schema/account di deployment; jangan memasukkan secret ke command line atau repo.

Contoh maintenance policy yang diuji pada clone: 90 hari audit, hapus maksimal100 row per transaction
berurutan `occurred_at,id` melalui retention index. Jalankan SQL parameterized berikut dengan identity
maintenance, bukan melalui endpoint publik atau request app:

```sql
DELETE FROM auth_security_event
WHERE occurred_at < TIMESTAMPADD(DAY, -90, UTC_TIMESTAMP(6))
ORDER BY occurred_at, id LIMIT 100;
```

90 hari adalah contoh clone, bukan approval retention produksi. Operational policy, permissions,
backup/legal retention, schedule dan external collector adalah gate deployment T04/T09/T10.
