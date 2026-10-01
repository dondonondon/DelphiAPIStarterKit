# T08 — Storage, upload/download, dan stream ownership

Status: **BERJALAN**. Prioritas tertinggi: **P1**. Tanggal pemecahan: **1 Oktober 2026**.

Temuan utama: **F07, F14, F38** (2 CONFIRMED, 1 CONTEXT-DEPENDENT).

Navigasi: [indeks task](review-tasks-windows-linux-2026-10-01.md) · [laporan lengkap](full-review-windows-linux-2026-10-01.md) · [wave-03](wave-03.md).

Baseline: review working tree 1 Oktober 2026, HEAD `358db33b95724f654db00e39fd4f35dc26c0d12c`. Slice minimum WAVE-01 telah diterapkan; sisa task belum dieksekusi. Lokasi/nomor baris lampiran adalah snapshot; baca ulang source sebelum perubahan. Build/harness laporan bukan bukti acceptance task ini.

## 1. Tujuan dan cakupan

Tutup double-free image dan storage abuse; file helper mempunyai ownership/containment/limit/failure policy eksplisit.

**Cakupan:** App.WebModule image/test routes, Core.Request.SaveFile dan Strings path/file/base64/download. Downloader belum dibuktikan dipakai route aktif.

ID di atas dimiliki utama task ini. Dependency merupakan koordinasi; tidak menggandakan owner/status temuan.

## 2. Langkah pengerjaan

- [ ] Perbaiki F07 cepat dengan satu stream owner: transfer ke response lalu kosongkan local pointer, atau borrowed dengan detach/cleanup konsisten. Audit normal/error/disconnect.
- [ ] Nonaktifkan /test production atau upload feature ber-auth/permission, frequency/quota/total size serta MIME/signature allowlist. Periksa SaveFile result dan JSON/status.
- [ ] Tetapkan /image public/private/owner policy; filename validation bukan permission melihat data.
- [ ] Validasi nil/index/empty/size, server-generated names dan normalized containment. Windows reserved names/ADS/separators serta Linux traversal/symlink mengikuti deployment policy.
- [ ] Temporary write/atomic replace sesuai filesystem/overwrite policy dan cleanup partial failure. Limit ingress/file/base64 sebelum unlimited allocation.
- [ ] Outbound downloader mempunyai destination/redirect/IP policy, timeout dan streaming byte limit sebelum menerima URL client. Dokumentasikan quota/path/permissions/MIME dan cross-volume replace limits.

## 3. Dependensi dan koordinasi

- [T09](task-09-config-path-dan-persistence.md) absolute data root; [T01](task-01-authorization-dan-permission.md) permission, [T03](task-03-http-routing-dan-error-boundary.md) HTTP/MIME/stream boundary, [T05](task-05-request-response-json-dan-waktu.md) envelope upload.
- [T10](task-10-hosting-build-dan-deployment.md) writable readiness/stop/drain; F07 tidak perlu menunggu upload refactor penuh.

## 4. Acceptance dan validasi kategori

- [ ] Repeated/concurrent image, send exception/disconnect bebas invalid-pointer/double-free/leak dengan memory-manager evidence; bytes identik.
- [ ] Unauthorized/oversize/wrong MIME-signature/frequency-quota abuse ditolak; SaveFile failure bukan 200 palsu dan tidak meninggalkan partial file.
- [ ] Traversal/absolute/reserved/ADS/nil/index-invalid/empty/collision/symlink serta disk-full/partial/cancel diuji pada OS/filesystem actual; tidak menulis di luar root.
- [ ] Jika downloader dipakai, protected destination/redirect/unlimited content ditolak. Jika belum, F38 adalah helper contract hardening, bukan klaim active SSRF.
- [ ] Identity runtime Windows/Linux menghasilkan storage/image access policy sesuai docs; source review bukan bukti uploaded file mempunyai execution path.

## 5. Checklist penutupan temuan

- [ ] **F07 (P1, CONFIRMED)** — Double free pada pengiriman gambar. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F14 (P1, CONFIRMED)** — Upload `/test` aktif tanpa autentikasi/quota. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F38 (P2, CONTEXT-DEPENDENT)** — Helper file/path/download belum aman sebagai API umum. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.

## 6. Definition of done dan catatan hasil

- [ ] Acceptance per temuan/kategori memiliki evidence; CONTEXT-DEPENDENT diselesaikan lewat consumer/deployment/policy actual, bukan asumsi.
- [ ] Jika code berubah, build target relevan sesuai aturan repo. Amankan T10.a sebelum `compile.bat`; catat platform/config/toolchain/hasil.
- [ ] Runtime Windows/Linux, DB/memory/supervisor acceptance relevan mempunyai hasil tersendiri; compiler pass bukan penggantinya.
- [ ] API docs/Postman di-update bila contract berubah; README/config/schema/project mapping hanya bila terdampak.
- [ ] Unrelated dirty work dipertahankan dan tidak ada password/key/token actual di commit/log/evidence.
- [ ] Files changed, hasil regression, compatibility/migration, residual risk dan blocker dicatat. BLOCKED tidak dihitung selesai.

**Catatan hasil WAVE-01 (2026-10-01):** WMimageAction transfers ContentStream once and nils local ownership; image MIME/raw bytes/no Content-Encoding verified.

E3 actual PNG equality + file handle release. F07 remains PARTIAL: concurrent/disconnect image memory-manager acceptance not executed. Remaining /test unauthenticated upload F14 and general storage/path/download F38. Owner tetap T08; status BERJALAN, bukan SELESAI. Gunakan implementation ini pada wave berikutnya. Detail [hasil WAVE-01](wave-01-result.md) dan [evidence](evidence/wave-01/acceptance.md).

## 7. Temuan sumber lengkap

Isi severity, label, lokasi, risiko, rekomendasi dan acceptance dipertahankan dari master. Relative source links tetap valid karena folder sama. Matrix lintas kategori dan bukti build/harness awal tersedia pada bagian 2–7 laporan lengkap.

### F07 — P1 — CONFIRMED — Double free pada pengiriman gambar

**Lokasi:** [App.WebModule.pas](../../sources/app/App.WebModule.pas#L161), 161–175.

Stream dibuat lokal, diberikan ke `Response.ContentStream`, lalu setelah `SendResponse` properti di-set `nil` dan local stream dibebaskan lagi di `finally`. RTL `Web.HTTPApp.pas` 1755–1761 menetapkan `FreeContentStream=True`; setter pada 1798–1804 membebaskan stream lama ketika pointer diganti. Override `TIdHTTPAppResponse.SetContentStream` pada `IdHTTPWebBrokerBridge.pas` 853–856 memanggil inherited.

**Pemicu:** GET `/image?filename=<gambar_yang_ada>`; penetapan `ContentStream := nil` sudah membebaskan stream, lalu `FreeAndNil(LStream)` memakai pointer yang sudah dibebaskan. Jika send melempar exception, `finally` membebaskan stream sementara response masih memiliki pointer; destructor response juga berisiko membebaskan lagi.

**Dampak:** invalid pointer operation, access violation, heap corruption, atau crash request/process tergantung memory manager.

**Perbaikan:** pilih **satu owner**. Serahkan ownership ke response dan kosongkan local pointer setelah assignment, atau gunakan borrowed stream dengan `FreeContentStream=False` dan detach dalam cleanup yang selalu berjalan. Jangan campur kedua pola.

**Acceptance:** repeated image requests, concurrent reads, dan client disconnect tidak menghasilkan invalid pointer/leak; lakukan memory-manager validation. Kepemilikan stream sesuai [TWebResponse.FreeContentStream](https://docwiki.embarcadero.com/Libraries/Athens/en/Web.HTTPApp.TWebResponse.FreeContentStream).

### F14 — P1 — CONFIRMED — Upload `/test` aktif tanpa autentikasi/quota

**Lokasi:** [App.WebModule.dfm](../../sources/app/App.WebModule.dfm#L19), 19–22; [App.WebModule.pas](../../sources/app/App.WebModule.pas#L179), 179–199; [BFA.Core.Request.pas](../../sources/core/BFA.Core.Request.pas#L153), 153–191.

POST `/test` menyimpan file memakai UUID plus extension client. Route tidak melewati authenticated endpoint helper. Ukuran per file dibatasi 4 MiB pada helper setelah body telah diterima, tetapi tidak ada total quota, frequency limit, atau kebijakan extension/content. Boolean hasil SaveFile diabaikan; sukses maupun file oversized dapat tetap HTTP 200 dan body kosong/pesan biasa.

**Dampak:** remote client dapat mengisi disk dengan banyak file. Ini bukan bukti uploaded executable otomatis dieksekusi; source tidak menyediakan jalur eksekusi tersebut. Risiko utama adalah storage abuse dan kontrak upload yang menyesatkan.

**Perbaikan:** nonaktifkan route contoh pada production atau pindahkan menjadi upload feature dengan auth/permission, quota, allowlist MIME+signature, ingress limit, status 201/400/413, dan cleanup file parsial. Tetapkan `/image` public/private sesuai jenis data; sekarang route image publik juga tidak mempunyai akses per owner.

**Acceptance:** untrusted upload ditolak sebelum write; limit jumlah/ukuran ditegakkan; tidak ada file parsial setelah failure; setiap hasil cocok dengan status JSON; hanya jenis file yang dimaksud dapat disimpan/disajikan.

### F38 — P2 — CONTEXT-DEPENDENT — Helper file/path/download belum aman sebagai API umum

**Lokasi:** [BFA.Helper.Strings.pas](../../sources/shared/helpers/BFA.Helper.Strings.pas#L88), 88–94/162–203/270–291; [BFA.Core.Request.pas](../../sources/core/BFA.Core.Request.pas#L153), 153–191.

`LoadFile/BuildStoragePath` tidak memverifikasi basename/canonical containment; `Base64ToFile` menerima output path langsung; SaveFile tidak mengecek request nil/index range/stream nil seperti dua helper upload lainnya. SaveFile memakai fmCreate sehingga existing file ditimpa, dan write tidak atomic. `DownloadFile` menerima arbitrary URL, mem-buffer semua content di memory, dan memakai path helper tanpa size/final URL policy.

**Batas klaim:** `/image` sudah memeriksa basename dan allowlist extension; `/test` membuat nama server-side dan memakai index 0 setelah count check. Tidak ada active DownloadFile/SaveSetting callsite yang ditemukan. Jadi review tidak mengklaim traversal/SSRF langsung pada route yang ada; risiko muncul bila helper dipakai dengan input client atau overload yang tidak valid.

**Perbaikan:** boundary helper memvalidasi nil/index/size, server-generated filename, normalized containment, Windows reserved name/ADS/separator dan Linux traversal/symlink policy; write temporary file lalu atomic replace bila dibutuhkan. Outbound HTTP helper menentukan destination allowlist, redirect/IP policy, timeout dan streaming byte limit jika URL berasal dari client. File/base64 conversion juga perlu limit.

**Acceptance:** traversal/absolute path, nil/index-invalid/empty stream, collision, disk full, partial write, symlink dan redirect diuji sesuai deployment; tidak ada write di luar data root; downloader tidak mengakses protected destination atau mengalokasikan unlimited content.
