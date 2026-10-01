# T10 — Hosting, build, dan deployment Windows/Linux

Status: **BERJALAN**. Prioritas tertinggi: **P2**. Tanggal pemecahan: **1 Oktober 2026**.

Temuan utama: **F29, F30, F31, F32, F33, F34, F41** (6 CONFIRMED, 1 CONTEXT-DEPENDENT).

Navigasi: [indeks task](review-tasks-windows-linux-2026-10-01.md) · [laporan lengkap](full-review-windows-linux-2026-10-01.md) · [wave-04](wave-04.md).

Baseline: review working tree 1 Oktober 2026, HEAD `358db33b95724f654db00e39fd4f35dc26c0d12c`. Slice minimum WAVE-01 telah diterapkan; sisa task belum dieksekusi. Lokasi/nomor baris lampiran adalah snapshot; baca ulang source sebelum perubahan. Build/harness laporan bukan bukti acceptance task ini.

## 1. Tujuan dan cakupan

Build aman terhadap process lain, lifecycle host terkelola, artifact/native dependencies konsisten untuk Win32/Win64/Linux64.

**Cakupan:** compile.bat/CloseApp.bat/dproj events/outputs, DPR/uDM bootstrap/pool/driver, README/README.id/Postman dan deployment examples.

ID di atas dimiliki utama task ini. Dependency merupakan koordinasi; tidak menggandakan owner/status temuan.

## 2. Langkah pengerjaan

**Dependency Auth:** [kontrak auth-v2](auth-production-contract-2026-10-01.md); schema target tidak menutup acceptance aplikasi.

- [ ] Auth-v2 readiness memeriksa trusted/pinned Argon2/RNG provider, typed TTL/admission/proxy/security config dan schema/cutover version compatibility. Missing provider tidak fallback ke HMAC cepat; native dependencies dipaketkan sesuai OS/bitness.
- [ ] Validasi profile MFA dan client token storage yang dipilih, permission/audit/limiter grants/retention serta bootstrap/cutover maintenance; readiness tidak dianggap lulus dari SQL target atau cross-build.

- [x] T10.a — sebelum build task lain: hapus default image-name force-kill atau gunakan jalur build yang terbukti menonaktifkannya. Stop dev opt-in mengikat absolute executable/PID dan graceful stop.
- [ ] Pisahkan output platform/config/package staging dengan dependency manifest; perbarui deployment references agar exe/DLL stale atau salah bitness tidak terpilih.
- [ ] Validate required/placeholder config, port/pool, readable config, writable data/log dan driver sebelum ready; pilih DB fail-fast atau readiness-false/recovery. Liveness bukan readiness.
- [ ] Exit nonzero untuk startup fatal dan log aman; normal stop policy eksplisit. Stop event: OS handler memberi sinyal minimal, main loop stop admission/listener, drain timeout, close pool/resources.
- [ ] Satukan configurable port/bind/default runtime/README/Postman. Optional VendorLib/VendorHome sebelum first connection; normal system search bila unset.
- [ ] Dokumentasikan native client compatible/bitness/vendor source, service identity, systemd WorkingDirectory, read-only binary/writable data, stop/restart policy. Actual provider MySQL/MariaDB tetap scope.

## 3. Dependensi dan koordinasi

- T10.a adalah safety gate build semua task code; sisa hosting tidak harus selesai sebelum containment P0/P1.
- [T09](task-09-config-path-dan-persistence.md) config/path, [T04](task-04-logging-dan-observability.md) sink, [T08](task-08-storage-upload-dan-stream.md) storage/ownership, [T03](task-03-http-routing-dan-error-boundary.md) listener/error boundary dan [T02](task-02-authentication-password-dan-session.md) required security settings.
- [T11](task-11-schema-migration-dan-kompatibilitas.md) schema provider target; FireDAC reusable bukan bukti operational Firebird/SQL Server support.

## 4. Acceptance dan validasi kategori

- [ ] Provider missing/wrong bitness, invalid security config, wrong schema/cutover dan required MFA provider unavailable menghasilkan readiness/exit aman; actual auth-v2 integrated runtime dibuktikan kedua OS.

- [ ] Build tidak menghentikan process lain; Linux cross-build tidak membunuh Windows instance. Win32/Win64 outputs berdampingan dengan manifest tepat.
- [ ] Missing required security config/provider (legacy HMAC hanya bila migration verifier aktif), invalid port/pool, unwritable roots, driver missing dan DB down menghasilkan readiness/exit sesuai policy pada dua OS.
- [ ] Missing config/occupied port exit nonzero; supervisor restart staging bekerja. Ctrl+C Windows/SIGTERM Linux saat long request memberi bounded drain/no admission/cleanup dan stable repeated start-stop.
- [ ] Fresh setup mengikuti README/Postman port/bind; different CWD tetap memakai config/data/library yang benar.
- [ ] Native bitness/package/TLS dan SQL runtime diuji pada actual staging Windows/Linux; cross-compile bukan Linux runtime proof. F33 ditutup dengan actual library resolution.

## 5. Checklist penutupan temuan

- [ ] **F29 (P2, CONFIRMED)** — Ready diumumkan sebelum dependensi tervalidasi. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F30 (P2, CONFIRMED)** — Exit code startup failure terlihat sukses. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F31 (P2, CONFIRMED)** — Shutdown belum terkelola. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F32 (P2, CONFIRMED)** — Port dokumentasi berbeda dari server. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F33 (P2, CONTEXT-DEPENDENT)** — Native library path terlalu spesifik. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [x] **F34 (P2, CONFIRMED)** — Build script mematikan process berdasarkan nama. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F41 (P3, CONFIRMED)** — Artifact Windows dapat saling tertimpa. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.

## 6. Definition of done dan catatan hasil

- [ ] Acceptance per temuan/kategori memiliki evidence; CONTEXT-DEPENDENT diselesaikan lewat consumer/deployment/policy actual, bukan asumsi.
- [ ] Jika code berubah, build target relevan sesuai aturan repo. Amankan T10.a sebelum `compile.bat`; catat platform/config/toolchain/hasil.
- [ ] Runtime Windows/Linux, DB/memory/supervisor acceptance relevan mempunyai hasil tersendiri; compiler pass bukan penggantinya.
- [ ] API docs/Postman di-update bila contract berubah; README/config/schema/project mapping hanya bila terdampak.
- [ ] Unrelated dirty work dipertahankan dan tidak ada password/key/token actual di commit/log/evidence.
- [ ] Files changed, hasil regression, compatibility/migration, residual risk dan blocker dicatat. BLOCKED tidak dihitung selesai.

**Catatan hasil WAVE-01 (2026-10-01):** T10.a/F34 removed image-name force kill from compile.bat; CloseApp.bat harmless; dproj event calls harmless wrapper. Startup Argon2 self-test/config validation/nonzero failure, VendorLib configurable and port9000 docs aligned.

E6 three builds + E9 own same-name executable survived; F34 CLOSED. Remaining readiness/schema probe/TLS/native production packages/stop-drain/artifact isolation/supervisor; F29/F30/F31/F32/F33/F41 not globally closed. Owner tetap T10; status BERJALAN, bukan SELESAI. Gunakan implementation ini pada wave berikutnya. Detail [hasil WAVE-01](wave-01-result.md) dan [evidence](evidence/wave-01/acceptance.md).

## 7. Temuan sumber lengkap

Isi severity, label, lokasi, risiko, rekomendasi dan acceptance dipertahankan dari master. Relative source links tetap valid karena folder sama. Matrix lintas kategori dan bukti build/harness awal tersedia pada bagian 2–7 laporan lengkap.

### F29 — P2 — CONFIRMED — Ready diumumkan sebelum dependensi tervalidasi

**Lokasi:** [uDM.pas](../../uDM.pas#L33), 33–37; [DB.ConnectionFactory.pas](../../sources/infrastructure/database/DB.ConnectionFactory.pas#L68), 68–97; [DelphiAPIStarterKit.dpr](../../DelphiAPIStarterKit.dpr#L205), 205–220; [BFA.Helper.Strings.pas](../../sources/shared/helpers/BFA.Helper.Strings.pas#L206), 206–209.

Initialize membuat connection definition tanpa menguji koneksi. Startup menelan exception storage/vendor setup, lalu listener aktif dan menulis Server started. Missing HMAC diketahui pada penggunaan pertama. `ForceDirectories` Boolean tidak diperiksa. Pool settings string diterima tanpa explicit range validation; sample secret placeholder hanya dianggap nonempty.

**Perbaikan:** validasi required/placeholder security config, numeric range pool/listener, readable config, writable data/log, dan library configuration sebelum listener. Pilih fail-fast DB atau readiness false yang terdokumentasi jika DB boleh pulih setelah startup; liveness tidak sama dengan readiness. Jangan mengumumkan ready hanya berdasarkan socket berhasil dibuka.

**Acceptance:** HMAC missing/placeholder, bad pool values, storage unwritable, driver missing, dan DB down ditangani sesuai kebijakan; probe readiness benar-benar memeriksa dependency yang dibutuhkan tanpa mengungkap secret.

### F30 — P2 — CONFIRMED — Exit code startup failure terlihat sukses

**Lokasi:** [DelphiAPIStarterKit.dpr](../../DelphiAPIStarterKit.dpr#L233), 233–242.

Exception startup hanya ditulis dan tidak menetapkan ExitCode gagal. Supervisor yang memakai restart-on-failure dapat membaca penghentian normal walaupun listener tidak pernah berhasil aktif.

**Perbaikan:** nonzero exit untuk fatal startup, log aman dan jelas; graceful stop normal boleh zero. Semantics restart dijelaskan dokumentasi sumber [systemd.service](https://github.com/systemd/systemd/blob/main/man/systemd.service.xml).

**Acceptance:** missing config/occupied port memberi exit nonzero; normal SIGTERM terkelola mengikuti exit policy; restart-on-failure staging benar-benar memulai ulang failure yang dimaksud.

### F31 — P2 — CONFIRMED — Shutdown belum terkelola

**Lokasi:** [DelphiAPIStarterKit.dpr](../../DelphiAPIStarterKit.dpr#L58), 58–60, 119–132, 222–229.

`TerminateThreads` kosong; active loop selalu Sleep tanpa exit condition. Tidak ditemukan Windows console control atau Linux signal handling pada source aktif. Cleanup `finally` ada tetapi tidak ada jalur normal untuk keluar loop. Command functions lama tidak dipakai RunServer aktif.

**Dampak:** close/terminate melalui supervisor tidak mempunyai request draining/lifecycle terkelola. Review tidak menyatakan data pasti korup; DB dapat rollback koneksi terputus, tetapi operasi in-flight dan response completion tidak dikoordinasikan aplikasi.

**Perbaikan:** event stop lintas-platform; OS handler memberi sinyal minimal; main loop menghentikan listener, drain request dengan timeout, menutup pool/resource, lalu exit. Service wrapper Windows dan systemd harus memakai jalur ini.

**Acceptance:** Ctrl+C/console stop dan SIGTERM selama transaksi/request panjang menghasilkan drain/timeout terukur; tidak menerima request baru; tidak meninggalkan transaction/resource; start-stop berulang stabil.

### F32 — P2 — CONFIRMED — Port dokumentasi berbeda dari server

**Lokasi:** [DelphiAPIStarterKit.dpr](../../DelphiAPIStarterKit.dpr#L237), 237; [README.md](../../README.md#L282), 282/296/302; [README.id.md](../../README.id.md#L273), 273/287/293; [Postman](../api/postman.collection.json#L1360), 1360.

Runtime memanggil `RunServer(9000)`, quickstart/Postman menggunakan 9381, dan contoh config tidak memiliki listener setting.

**Perbaikan:** configurable validated port/bind address; satu default konsisten pada runtime/docs/Postman. Read-only production config tidak perlu diedit oleh API hanya untuk menyimpan default.

**Acceptance:** setup baru mengikuti README persis dan request berhasil sampai listener; invalid port gagal dengan exit nonzero; bind address sesuai reverse-proxy policy.

### F33 — P2 — CONTEXT-DEPENDENT — Native library path terlalu spesifik

**Lokasi:** [DelphiAPIStarterKit.dpr](../../DelphiAPIStarterKit.dpr#L207), 207–211; [README.md](../../README.md#L212), 212–222; [DB.ConnectionFactory.pas](../../sources/infrastructure/database/DB.ConnectionFactory.pas#L87), 87–92.

Linux `VendorHome` dipaksa `/www/server/mysql/`; Windows memakai CWD. Library distro/bitness/dependency berbeda dapat tidak cocok dengan asumsi tersebut. Ini tidak membuktikan semua deployment Linux gagal karena installed library dan fallback resolution berbeda.

**Perbaikan:** `VendorLib/VendorHome` configurable sebelum first connection; gunakan normal system search ketika tidak diset, dengan deployment dependency yang eksplisit. Pisahkan package Win32/Win64/Linux64; pilih client versi compatible dan sumber vendor resmi. FireDAC pattern reusable tetapi aplikasi sekarang **MySQL/MariaDB**, bukan implementasi Firebird/SQL Server.

**Acceptance:** Win32/Win64 memakai client architecture sesuai; Linux standar package-manager library bekerja tanpa edit source; test SQL runtime dan TLS connection pada server staging, bukan hanya compiler link. Referensi: [FireDAC MySQL connectivity](https://docwiki.embarcadero.com/RADStudio/en/Connect_to_MySQL_Server_%28FireDAC%29).

### F34 — P2 — CONFIRMED — Build script mematikan process berdasarkan nama

**Lokasi:** [compile.bat](../../compile.bat#L25), 25–28; [CloseApp.bat](../../CloseApp.bat#L2), 2–4; [DelphiAPIStarterKit.dproj](../../DelphiAPIStarterKit.dproj#L217), 217–218 dan release-specific properties.

Build menjalankan force kill untuk semua process bernama DelphiAPIStarterKit.exe. Script juga melakukannya ketika BUILD_PLATFORM=Linux64. Instance dari workspace/deployment lain dengan nama sama dapat dihentikan; pending request terputus.

**Perbaikan:** tidak force-kill secara default; jika development membutuhkan stop, opt-in dengan identity executable absolute/PID dan graceful shutdown terlebih dulu. Output build terpisah mengurangi kebutuhan kill.

**Acceptance:** build tidak menghentikan instance lain; Linux cross-build tidak menghentikan process Windows. Review ini memakai compiler project langsung dengan build events dinonaktifkan, lihat bagian validasi.

### F41 — P3 — CONFIRMED — Artifact Windows dapat saling tertimpa

**Lokasi:** [DelphiAPIStarterKit.dproj](../../DelphiAPIStarterKit.dproj#L195), 195/201/213/221.

Debug/Release Win32/Win64 seluruhnya menulis `bin/DelphiAPIStarterKit.exe`. Build berikut menimpa artifact architecture/config sebelumnya, menyulitkan packaging native DLL dan pemilihan executable yang benar.

**Perbaikan:** output per platform/config atau release package staging terpisah; sesuaikan deployment references. Ini tidak memerlukan perubahan struktur module source.

**Acceptance:** semua artifact berdampingan dengan manifest platform/config/dependency yang jelas; packaging tidak memakai executable stale atau DLL architecture lain.
