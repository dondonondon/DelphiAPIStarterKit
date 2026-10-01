# T09 — Config path, load/save, dan secret persistence

Status: **BERJALAN**. Prioritas tertinggi: **P1**. Tanggal pemecahan: **1 Oktober 2026**.

Temuan utama: **F13, F28, F39, F46** (3 CONFIRMED, 1 CONTEXT-DEPENDENT).

Navigasi: [indeks task](review-tasks-windows-linux-2026-10-01.md) · [laporan lengkap](full-review-windows-linux-2026-10-01.md) · [wave-03](wave-03.md).

Baseline: review working tree 1 Oktober 2026, HEAD `358db33b95724f654db00e39fd4f35dc26c0d12c`. Slice minimum WAVE-01 telah diterapkan; sisa task belum dieksekusi. Lokasi/nomor baris lampiran adalah snapshot; baca ulang source sebelum perubahan. Build/harness laporan bukan bukti acceptance task ini.

## 1. Tujuan dan cakupan

Satu authority config reader/writer dan config/data/log/executable paths yang konsisten serta bebas ketergantungan CWD.

**Cakupan:** DB.ConnectionFactory config/env, Core.Config, Strings HMAC/config/storage helpers, example config dan tracked runtime config.

ID di atas dimiliki utama task ini. Dependency merupakan koordinasi; tidak menggandakan owner/status temuan.

## 2. Langkah pengerjaan

**Dependency Auth:** [kontrak auth-v2](auth-production-contract-2026-10-01.md); schema target tidak menutup acceptance aplikasi.

- [ ] Typed auth-v2 snapshot memvalidasi TTL access 900s/session absolute 604800s/idle 86400s/recovery 900s/recent-auth 300s, Argon2 provider/parameters, limiter/admission/proxy/security profile. Reconcile minimum config slice wave-01; tidak membuat resolver/key authority tandingan.
- [ ] Legacy HMAC key hanya verifier migration, optional password pepper/MFA secrets distinct; new token hash SHA-256 tidak membutuhkan HMAC key. Preserve secret bytes/path/trust boundary; invalid KDF/config fail closed tanpa insecure fallback.

- [ ] Inventarisasi DB CWD/config.ini, HMAC/base config.ini, setting Dir/base config.ini, setting biasa/base/files/other/config.ini serta storage/log paths.
- [ ] Absolute config resolver dengan precedence eksplisit dan typed immutable startup snapshot; opsi DELPHI_API_CONFIG_FILE adalah usulan baru, bukan setting existing.
- [ ] Pisahkan config/data/log/executable; resolve/read tidak membuat directory atau mengubah secret. Rename binary/CWD tidak menggeser storage tanpa config eksplisit.
- [ ] Typed secret reader preserve whitespace; bedakan env unset dari explicitly empty sesuai policy. Facade load/save lama mendelegasikan resolver yang sama.
- [ ] Putuskan runtime save didukung atau read-only. Jika didukung: writer lock/version/atomic replace, error result, backup/permissions dan explicit snapshot reload; config tidak di upload root.
- [ ] Pada implementasi keluarkan bin/config.ini dari Git index sambil mempertahankan file lokal. Example/provisioning tetap tracked dan repository guard mencegah real config/secret kembali masuk.
- [ ] Dokumentasikan Windows service/Linux systemd path/default/env precedence dan legacy path migration, dengan resolved-path diagnostic tanpa secret.

## 3. Dependensi dan koordinasi

- [T10](task-10-hosting-build-dan-deployment.md) readiness/host/library memakai snapshot; [T04](task-04-logging-dan-observability.md)/[T08](task-08-storage-upload-dan-stream.md) memakai log/data roots; [T02](task-02-authentication-password-dan-session.md) memakai secret reader.
- [T12](task-12-architecture-dan-centralization.md) merapikan facade/dependency, bukan prasyarat satu authority. F39 belum punya active save callsite; Linux TIniFile AutoSave=True berarti bukan missing-UpdateFile bug.

## 4. Acceptance dan validasi kategori

- [ ] Auth-v2 invalid/missing provider/TTL/limiter/trusted-proxy/env/secret paths diuji Windows/Linux, CWD/rename/restart tidak mengubah policy atau expose credential; handoff readiness ke T10.

- [ ] DB/HMAC/helper read/save memakai file sama pada different CWD, absolute override, renamed binary dan runtime kedua OS.
- [ ] Secret whitespace/env-config-default/unset-empty diuji identik tanpa mencetak value; read-only resolve tidak membuat directory.
- [ ] Save yang didukung: concurrent dua-key tidak kehilangan perubahan, failed save tidak sukses, reload/restart final state, replace/backup menjaga permissions.
- [ ] Runtime config tetap lokal tetapi untracked; edit bukan candidate commit dan fresh clone memakai example/provisioning tanpa credential di evidence.
- [ ] F39 ditutup dengan actual save protection atau enforced read-only scope; jangan mengklaim actual production-credential leak yang tidak dibuktikan review.

## 5. Checklist penutupan temuan

- [ ] **F13 (P1, CONFIRMED)** — Path config/load/save tidak tunggal. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F28 (P2, CONFIRMED)** — Config reader mengubah secret. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F39 (P2, CONTEXT-DEPENDENT)** — Config save dapat kehilangan perubahan concurrent. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F46 (P2, CONFIRMED)** — Ignore rule belum melindungi runtime config yang sudah tracked. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.

## 6. Definition of done dan catatan hasil

- [ ] Acceptance per temuan/kategori memiliki evidence; CONTEXT-DEPENDENT diselesaikan lewat consumer/deployment/policy actual, bukan asumsi.
- [ ] Jika code berubah, build target relevan sesuai aturan repo. Amankan T10.a sebelum `compile.bat`; catat platform/config/toolchain/hasil.
- [ ] Runtime Windows/Linux, DB/memory/supervisor acceptance relevan mempunyai hasil tersendiri; compiler pass bukan penggantinya.
- [ ] API docs/Postman di-update bila contract berubah; README/config/schema/project mapping hanya bila terdampak.
- [ ] Unrelated dirty work dipertahankan dan tidak ada password/key/token actual di commit/log/evidence.
- [ ] Files changed, hasil regression, compatibility/migration, residual risk dan blocker dicatat. BLOCKED tidak dihitung selesai.

**Catatan hasil WAVE-01 (2026-10-01):** TServerConfig.FileName absolute DELPHI_API_CONFIG or executable-adjacent INI; same authority env/INI raw secret reader used by DB, HMAC verifier and existing helper load/save. Provider absolute pin and typed TTL/rate/profile/login timeout.

E3 different-CWD bootstrap/provider pin/profile refusal; E5 legacy effective-key migration. Remaining concurrent save, platform/deployment paths, ACL, configured compromised dictionary and tracked bin/config.ini F46; F13/F28/F39/F46 not globally closed. Owner tetap T09; status BERJALAN, bukan SELESAI. Gunakan implementation ini pada wave berikutnya. Detail [hasil WAVE-01](wave-01-result.md) dan [evidence](evidence/wave-01/acceptance.md).

## 7. Temuan sumber lengkap

Isi severity, label, lokasi, risiko, rekomendasi dan acceptance dipertahankan dari master. Relative source links tetap valid karena folder sama. Matrix lintas kategori dan bukti build/harness awal tersedia pada bagian 2–7 laporan lengkap.

### F13 — P1 — CONFIRMED — Path config/load/save tidak tunggal

**Lokasi:** [DB.ConnectionFactory.pas](../../sources/infrastructure/database/DB.ConnectionFactory.pas#L55), 55–58; [BFA.Helper.Strings.pas](../../sources/shared/helpers/BFA.Helper.Strings.pas#L228), 228–267, 294–318, 352–374.

DB membaca `<CWD>/config.ini`. Windows storage base adalah CWD; Linux base `/var/lib/<nama_binary>`. HMAC dan `*SettingStringDir` memakai base/config.ini. Helper `LoadSettingString`/`SaveSettingString` memakai `LoadFile('config.ini')`, sehingga menuju base/files/other/config.ini.

**Pemicu:** Linux binary di `/opt/DelphiAPIStarterKit` dengan config gabungan di direktori itu. DB menemukan config tetapi HMAC mencari file lain di `/var/lib`. Config di `/var/lib` tidak ditemukan DB jika CWD berbeda. Pada Windows, task scheduler/service wrapper/terminal dengan CWD berbeda mengubah lokasi data/config/DLL.

**Dampak:** startup/auth/runtime memakai konfigurasi yang berbeda; save helper menulis file yang tidak dibaca DB/HMAC; data terlihat hilang setelah CWD atau nama binary berubah. Environment variables dapat menutupi defect tetapi tidak memperbaiki fallback file.

**Perbaikan:** satu absolute config resolver dan typed startup snapshot; misalnya opsi eksplisit `DELPHI_API_CONFIG_FILE` sebagai desain baru. Pisahkan config/data/log/executable path. Jangan menciptakan directory ketika hanya menyelesaikan path atau membaca secret. Pertahankan helper lama sebagai delegator ke policy yang sama.

**Acceptance:** seluruh reader/writer memakai file yang sama pada Windows/Linux walaupun CWD berbeda; rename executable tidak memindahkan storage tanpa konfigurasi eksplisit; startup menampilkan resolved path secara aman, tanpa nilai secret.

### F28 — P2 — CONFIRMED — Config reader mengubah secret

**Lokasi:** [DB.ConnectionFactory.pas](../../sources/infrastructure/database/DB.ConnectionFactory.pas#L99), 99–116 dan 80.

`Trim` diberlakukan pada semua value environment/INI termasuk password database. Password valid dengan leading/trailing whitespace berubah sebelum dikirim ke DB. HMAC secret juga di-trim, sehingga format secret harus didefinisikan dan diperlakukan konsisten.

**Perbaikan:** typed reader membedakan identifiers/numeric settings dari secret bytes/string. Preserve password apa adanya; bedakan variable unset dari explicitly empty bila override kosong didukung. Password request juga tidak boleh berubah melalui generic string normalization.

**Acceptance:** password dengan whitespace awal/akhir dibaca identik; precedence env/config/default diuji tanpa memunculkan nilai secret di output.

### F39 — P2 — CONTEXT-DEPENDENT — Config save dapat kehilangan perubahan concurrent

**Lokasi:** [BFA.Helper.Strings.pas](../../sources/shared/helpers/BFA.Helper.Strings.pas#L352), 352–374.

Setiap pemanggilan membuat instance INI terpisah tanpa lock/version/atomic update. Di Linux TIniFile memakai TMemIniFile, sehingga dua writer yang membaca snapshot lama dan auto-save dapat saling menimpa update. Multi-process coordination juga tidak ada. Helper ini belum mempunyai active callsite yang ditemukan.

**Catatan penting:** **tidak ada bukti SaveSettingString gagal hanya karena tidak memanggil UpdateFile**. RTL Studio 37 `System.IniFiles.pas` 1411–1415 menyetel `AutoSave=True` pada non-Windows TIniFile; destructor TMemIniFile menyimpan modified content. Perilaku ini cocok dengan [dokumentasi TIniFile](https://docwiki.embarcadero.com/Libraries/Alexandria/en/System.IniFiles.TIniFile).

**Perbaikan:** tentukan apakah runtime memang boleh mengubah config. Jika boleh, satu writer/persistence abstraction dengan lock/version/atomic replacement, permissions dan backup; snapshot config runtime diperbarui secara eksplisit. Jangan menyimpan secret ke path umum file upload atau memutasi config environment-managed.

**Acceptance:** concurrent write dua key tidak kehilangan perubahan; save error tidak dilaporkan sukses; reload membaca file final yang sama; restart mempertahankan values; permission config tetap terbatas.

### F46 — P2 — CONFIRMED — Ignore rule belum melindungi runtime config yang sudah tracked

**Lokasi:** [.gitignore](../../.gitignore#L42), rule config.ini; Git index entry `bin/config.ini`; [config.example.ini](../../bin/config.example.ini).

`git ls-files` menunjukkan `bin/config.ini` masih berada dalam index. `git check-ignore --no-index` menunjukkan file tersebut cocok aturan ignore; ignore tidak otomatis mengeluarkan file yang sebelumnya sudah tracked. Perubahan local runtime config tetap dapat masuk commit berikutnya.

**Batas paparan saat ini:** pemeriksaan hanya mencatat section/key serta Boolean kecocokan dengan template, tanpa mencetak value. Seluruh key yang ditemukan cocok dengan `bin/config.example.ini`; HMAC masih placeholder dan password DB kosong. Jadi **tidak ada bukti credential production saat ini bocor**. Defect-nya adalah boundary repository untuk konfigurasi mutable belum sesuai maksud ignore policy.

**Perbaikan:** pada pekerjaan implementasi berikut, keluarkan runtime config dari index sambil mempertahankan file lokal; hanya example tetap tracked. Tambahkan pemeriksaan repository/CI agar real config/secret files tidak kembali masuk commit. Jangan menghapus config lokal atau melakukan rewrite history hanya berdasarkan risiko hipotetis ini. Jika historical secret nyata ditemukan pada audit terpisah, rotasi credential dan cleanup history harus direncanakan sesuai evidence.

**Acceptance:** file config runtime tetap tersedia lokal tetapi tidak ada dalam tracked-files inventory; edit lokal tidak muncul sebagai candidate commit; fresh clone menggunakan example/provisioning yang terdokumentasi; tidak ada credential value dalam log/check report.
