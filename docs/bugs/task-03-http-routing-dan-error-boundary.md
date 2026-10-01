# T03 — HTTP transport, routing, dan error boundary

Status: **BLOCKED**. Prioritas tertinggi: **P1**. Tanggal pemecahan: **1 Oktober 2026**.

Temuan utama: **F08, F09, F24, F25, F26, F37** (5 CONFIRMED, 1 CONTEXT-DEPENDENT).

Navigasi: [indeks task](review-tasks-windows-linux-2026-10-01.md) · [laporan lengkap](full-review-windows-linux-2026-10-01.md) · [wave-01](wave-01.md).

Baseline: review working tree 1 Oktober 2026, HEAD `358db33b95724f654db00e39fd4f35dc26c0d12c`. Implementasi WAVE-01 dan evidence saat ini tercatat di [hasil wave](wave-01-result.md). Lokasi/nomor baris lampiran adalah snapshot; baca ulang source sebelum perubahan. Build/harness laporan bukan bukti acceptance task ini.

**Revisi auth-v2 (1 Oktober 2026):** spesifikasi dan SQL target telah diperbarui; status di atas adalah status implementasi aplikasi/acceptance, bukan status penulisan schema. Ikuti [kontrak target Auth](auth-production-contract-2026-10-01.md); lampiran temuan tetap bukti baseline historis.

## 1. Tujuan dan cakupan

Pastikan token mencapai guard, route invalid tidak menjalankan business logic, dan exception transport/DB menjadi response standar yang aman.

**Cakupan:** DPR/Indy, App.WebModule, Core.Rest/Helper/Endpoint, Token header helper dan DB.ConnectionFactory. CORS boleh dimiliki proxy bila dibuktikan.

ID di atas dimiliki utama task ini. Dependency merupakan koordinasi; tidak menggandakan owner/status temuan.

## 2. Langkah pengerjaan

- [x] Whitelist route auth-v2 per action: Login dan credential-specific Refresh/Logout/CompletePasswordReset tidak disamaratakan ke access-token-only guard; semua tetap memiliki credential validation. Me/Sessions/LogoutAll/Reauthenticate membutuhkan actor; reset/admin action juga permission/recent auth. ([T03-S1](evidence/wave-01/acceptance.md))
- [x] Tolak legacy session_id/device_id-only Refresh/Logout, extra segments dan conflicting headers. Error auth memakai envelope standar; semua credential response no-store, token tidak dari URL dan request tidak di-echo. ([T03-S2](evidence/wave-01/acceptance.md))

- [x] Pasang Indy Bearer parse hook agar header diteruskan; parsing tidak memberi akses otomatis. Nyatakan precedence/rejection conflicting credential headers. ([T03-S3](evidence/wave-01/acceptance.md))
- [x] Safe boundary mencakup route validation, DB acquisition, parsing dan dispatch. Factory membebaskan connection pada initialization failure; pasang cleanup segera setelah alokasi. ([T03-S4](evidence/wave-01/acceptance.md))
- [x] WebModule OnException serta transport fallback memberi safe 500 tanpa E.Message/path/SQL/vendor internals. Logger failure tidak boleh mengganti response. ([T03-S5](evidence/wave-01/acceptance.md))
- [x] Gunakan non-throwing resource/version lookup sebelum DB bila tidak diperlukan. Whitelist route shape/verb/action/signature; extra segments/unknown action ditolak sebelum mutation dengan 404/405/Allow yang tepat. ([T03-S6](evidence/wave-01/acceptance.md))
- [x] Hapus Content-Encoding utf-8 untuk uncompressed body; kirim actual UTF-8 bytes/charset yang benar, image tetap MIME image. ([T03-S7](evidence/wave-01/acceptance.md))
- [x] Nyatakan app/proxy CORS owner, allowlist origin/method/header dan OPTIONS sebelum resource auth; actual request tetap ber-auth. Update docs/Postman dan setup proxy bila berubah. ([T03-S8](evidence/wave-01/acceptance.md))

## 3. Dependensi dan koordinasi

- [T04](task-04-logging-dan-observability.md) logger tahan failure, [T05](task-05-request-response-json-dan-waktu.md) parser/envelope typed dan [T01](task-01-authorization-dan-permission.md)/[T02](task-02-authentication-password-dan-session.md) actor/credential policy. Jangan menambah response builder kedua.
- Koordinasikan image/stream dengan [T08](task-08-storage-upload-dan-stream.md), readiness DB dengan [T10](task-10-hosting-build-dan-deployment.md) dan route composition dengan [T12](task-12-architecture-dan-centralization.md).

## 4. Acceptance dan validasi kategori

- [x] Route/method/credential matrix auth-v2 diuji pada listener; legacy session_id/device_id-only flow ditolak, allowed issuance no-store, error envelope strict dan permission routing tidak dapat dilewati. ([T03-A1](evidence/wave-01/acceptance.md))

- [ ] Listener Win32/Win64/Linux64 menguji valid/invalid/missing Bearer, custom header, Basic dan dual-header conflict sesuai policy/envelope. ([T03-A2](evidence/wave-01/acceptance.md))
- [x] Ratusan request DB down/pool exhausted tidak menaikkan live connection/allocation; safe 500 dapat diparse strict dan recovery bekerja. ([T03-A3](evidence/wave-01/acceptance.md))
- [x] Unknown resource/version, route 3/4/5/6+ segments, slash/action+ID/unknown action/unsupported verb tidak memutasi DB; 404/405/Allow konsisten. ([T03-A4](evidence/wave-01/acceptance.md))
- [x] Raw headers/bytes bebas Content-Encoding utf-8, Unicode/emoji round-trip dan image bytes identik. ([T03-A5](evidence/wave-01/acceptance.md))
- [x] Allowed/disallowed origin, OPTIONS serta failure paths diuji via app/proxy actual; actual request tetap membutuhkan auth dan credentials tidak memakai wildcard origin. ([T03-A6](evidence/wave-01/acceptance.md))
- [ ] F37 ditutup dengan implementation evidence atau scope/deployment evidence yang menunjukkan preflight tidak diperlukan/ditangani proxy. ([T03-A7](evidence/wave-01/acceptance.md))

## 5. Checklist penutupan temuan

- [ ] **F08 (P1, CONFIRMED)** — Bearer token tidak melewati transport. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik. ([T03-F1](evidence/wave-01/acceptance.md))
- [x] **F09 (P1, CONFIRMED)** — DB exception keluar ke HTTP dan connection bocor. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik. ([T03-F2](evidence/wave-01/acceptance.md))
- [x] **F24 (P2, CONFIRMED)** — Unknown route class menjadi 500. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik. ([T03-F3](evidence/wave-01/acceptance.md))
- [x] **F25 (P2, CONFIRMED)** — Route shape tidak dibatasi ketat. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik. ([T03-F4](evidence/wave-01/acceptance.md))
- [x] **F26 (P2, CONFIRMED)** — Content-Encoding bukan charset. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik. ([T03-F5](evidence/wave-01/acceptance.md))
- [ ] **F37 (P2, CONTEXT-DEPENDENT)** — Browser preflight/CORS belum tersedia. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik. ([T03-F6](evidence/wave-01/acceptance.md))

## 6. Definition of done dan catatan hasil

- [ ] Acceptance per temuan/kategori memiliki evidence; CONTEXT-DEPENDENT diselesaikan lewat consumer/deployment/policy actual, bukan asumsi. ([T03-D1](evidence/wave-01/acceptance.md))
- [x] Jika code berubah, build target relevan sesuai aturan repo. Amankan T10.a sebelum `compile.bat`; catat platform/config/toolchain/hasil. ([T03-D2](evidence/wave-01/acceptance.md))
- [ ] Runtime Windows/Linux, DB/memory/supervisor acceptance relevan mempunyai hasil tersendiri; compiler pass bukan penggantinya. ([T03-D3](evidence/wave-01/acceptance.md))
- [x] API docs/Postman di-update bila contract berubah; README/config/schema/project mapping hanya bila terdampak. ([T03-D4](evidence/wave-01/acceptance.md))
- [x] Unrelated dirty work dipertahankan dan tidak ada password/key/token actual di commit/log/evidence. ([T03-D5](evidence/wave-01/acceptance.md))
- [x] Files changed, hasil regression, compatibility/migration, residual risk dan blocker dicatat. BLOCKED tidak dihitung selesai. ([T03-D6](evidence/wave-01/acceptance.md))

**Catatan hasil:** Implementation serial T03 selesai untuk resource yang tersedia; mandatory Win32/Linux/deployment gates BLOCKED. Lihat [hasil](wave-01-result.md), [matrix seluruh predicate](evidence/wave-01/acceptance.md) dan [checkpoint](wave-01.md#7-catatan-eksekusi). Checkbox tidak mencakup gate platform lain yang belum diuji. Tidak ada commit baru; HEAD baseline tetap 358db33b95724f654db00e39fd4f35dc26c0d12c.

## 7. Temuan sumber lengkap

Isi severity, label, lokasi, risiko, rekomendasi dan acceptance dipertahankan dari master. Relative source links tetap valid karena folder sama. Matrix lintas kategori dan bukti build/harness awal tersedia pada bagian 2–7 laporan lengkap.

### F08 — P1 — CONFIRMED — Bearer token tidak melewati transport

**Lokasi:** [DelphiAPIStarterKit.dpr](../../DelphiAPIStarterKit.dpr#L192), 192–218; [BFA.Security.Token.pas](../../sources/infrastructure/security/BFA.Security.Token.pas#L19), 19–32.

Token extractor mendukung `Authorization: Bearer`, tetapi `TIdHTTPWebBrokerBridge` tidak diisi `OnParseAuthentication`. Source Indy terpasang `IdCustomHTTPServer.pas` 921–941 hanya mengenali Basic pada default handler; 1452–1458 menolak skema yang tidak diparse, lalu 1477–1491 mengirim 401/Basic challenge sebelum WebBroker endpoint.

**Pemicu:** request memakai Bearer token yang valid. Menambahkan `x-api-token` di request yang masih memiliki header Bearer tidak menghindari reject transport.

**Dampak:** kontrak autentikasi yang didokumentasikan gagal; response berasal dari Indy dan tidak memakai envelope JSON aplikasi. Client yang menggunakan custom header mungkin bekerja, sehingga bug mudah terlewat.

**Perbaikan:** configure parse hook Bearer di host agar header diteruskan dengan benar, kemudian lakukan validasi token dan authorization pada resolver terpusat. Hook parsing tidak boleh otomatis menganggap token valid. Definisikan precedence jika dua header token berbeda diberikan.

**Acceptance:** valid/invalid/missing Bearer diuji di listener sebenarnya pada Win32/Win64/Linux64; semua failure sesuai envelope; Basic tidak menjadi fallback yang memberi akses; custom header tetap compatible bila masih didukung.

### F09 — P1 — CONFIRMED — DB exception keluar ke HTTP dan connection bocor

**Lokasi:** [App.WebModule.pas](../../sources/app/App.WebModule.pas#L75), 75–91; [DB.ConnectionFactory.pas](../../sources/infrastructure/database/DB.ConnectionFactory.pas#L60), 60–65.

`GetConnection` membuat `TFDConnection` lalu membuka koneksi tanpa cleanup jika open gagal. Caller membuka connection **sebelum** memasuki `try`, sehingga boundary endpoint/core belum aktif saat exception dilempar. Jalur WebBroker default menangkap exception pada `Web.WebReq.pas` 228–229; tanpa WebModule OnException, `Web.HTTPApp.pas` 2716–2737 membentuk response internal error menggunakan `E.Message` dan request path. Bila exception keluar dari WebBroker, source Indy `IdCustomHTTPServer.pas` 1493–1497 juga mengisi response 500 dengan `E.Message`. DFM tidak memasang OnException dan host tidak memasang boundary OnCommandError khusus.

**Pemicu:** DB down, wrong credential, missing native library, invalid definition, atau pool habis.

**Dampak:** database/vendor/config/path detail berpotensi terkirim sebagai HTTP body nonstandar; setiap open failure meninggalkan object yang dialokasikan. Jika `TClassHelper.Create` gagal setelah connection diperoleh, connection juga belum berada dalam scope cleanup.

**Perbaikan:** factory membebaskan `Result` sebelum re-raise pada initialization failure. WebModule memiliki top-level `try/except` yang meliputi route validation, connection acquisition, parsing, dan dispatch; cleanup dibentuk segera setelah setiap alokasi. WebModule OnException dan final transport boundary juga harus memberi 500 yang aman; hanya menambah OnCommandError belum cukup jika WebBroker lebih dulu mengirim response default.

**Acceptance:** ratusan request ketika DB unavailable tidak menaikkan live allocation; HTTP 500 memakai `status/messages/servertime/data:[{}]`; tidak ada SQL/path/credential/vendor internals pada body; recovery setelah DB kembali berhasil.

### F24 — P2 — CONFIRMED — Unknown route class menjadi 500

**Lokasi:** [BFA.Core.Rest.pas](../../sources/core/BFA.Core.Rest.pas#L169), 169–175 dan 222–239.

`ResolveAPIClass` memakai `FindClass`, lalu menguji Assigned seolah class yang tidak ditemukan menghasilkan nil. RTL `System.Classes.pas` 4205–4208 menunjukkan `FindClass` melempar exception jika `GetClass` nil. Catch dispatch memetakan exception menjadi 500.

**Pemicu:** `/api/v1/UnknownResource` dengan kondisi koneksi tersedia sehingga dispatch tercapai.

**Perbaikan:** lookup yang tidak melempar (`GetClass` atau explicit route registry) dan 404 standar untuk resource tidak dikenal. Normalisasi case sesuai kontrak dan batasi version/resource yang terdaftar.

**Acceptance:** unknown resource/version/case policy menghasilkan 404 yang terdokumentasi; tidak memerlukan class-not-found exception log sebagai internal failure.

### F25 — P2 — CONFIRMED — Route shape tidak dibatasi ketat

**Lokasi:** [BFA.Core.Helper.pas](../../sources/core/BFA.Core.Helper.pas#L132), 132–166; [BFA.Core.Endpoint.pas](../../sources/core/BFA.Core.Endpoint.pas#L63), 63–84.

Length 4/5 ditangani khusus; length di atas 5 jatuh ke `HTTPMethodToCrudAction`. Misalnya POST `/api/v1/User/x/a/b` dapat menjalankan Insert ketika body dan token valid. Custom action ditemukan melalui RTTI method-name lookup tanpa route metadata yang menyatakan verb/shape/signature; post-only action list sekarang membantu tetapi tetap tersebar.

**Perbaikan:** whitelist route template, method, service action, dan signature secara eksplisit. Reject trailing/extra path segments sebelum business logic. Jangan menjadikan setiap method service yang cocok nama otomatis sebagai API pada pengembangan berikutnya.

**Acceptance:** route 3/4/5/6+ segments, extra slash, unknown action, unsupported verb, action+ID kombinasi diuji; malformed route tidak memutasi data; 404/405 dan Allow header sesuai kontrak.

### F26 — P2 — CONFIRMED — Content-Encoding bukan charset

**Lokasi:** [App.WebModule.pas](../../sources/app/App.WebModule.pas#L62), 62–64 dan 130–132.

`Response.ContentEncoding := 'utf-8'` dipakai untuk response JSON dan image. Installed `IdHTTPWebBrokerBridge.pas` 748 meneruskannya ke HTTP `Content-Encoding`, bukan parameter charset atau pilihan encoding body.

**Dampak:** server mengiklankan content coding yang tidak diterapkan; image juga diberi coding UTF-8. Client yang strict dapat gagal decoding, dan byte encoding JSON belum otomatis menjadi UTF-8 hanya karena property ini.

**Perbaikan:** kosongkan Content-Encoding untuk uncompressed body; kirim JSON dengan actual UTF-8 bytes melalui mekanisme bridge yang benar; content type image tetap MIME image. Content coding digunakan untuk gzip/br ketika benar-benar diterapkan. Semantics ini dijelaskan [RFC 9110 §8.4](https://www.rfc-editor.org/rfc/rfc9110.html#section-8.4).

**Acceptance:** inspeksi raw HTTP header dan bytes; Unicode Indonesia/emoji bisa round-trip; tidak ada `Content-Encoding: utf-8`; gambar identik secara bytes dengan file sumber.

### F37 — P2 — CONTEXT-DEPENDENT — Browser preflight/CORS belum tersedia

**Lokasi:** [App.WebModule.pas](../../sources/app/App.WebModule.pas#L53), 53–93; [BFA.Core.Helper.pas](../../sources/core/BFA.Core.Helper.pas#L78), 78–85; [BFA.Core.Endpoint.pas](../../sources/core/BFA.Core.Endpoint.pas#L58), auth sebelum route/action resolution.

Tidak ditemukan handling CORS/OPTIONS terpusat pada active source. Browser lintas origin yang memakai Authorization/custom header mengirim preflight tanpa application credential; flow dapat mengembalikan 401/405 dan tidak memiliki CORS headers. `ACheckHeader` pada SendToCoreAPI tidak digunakan.

**Dampak:** native/non-browser client bisa bekerja, browser cross-origin tidak. Reverse proxy mungkin sudah menangani ini; konfigurasi proxy tidak tersedia sehingga jangan klaim bypass/security weakness dari wildcard yang tidak ada di source.

**Perbaikan:** CORS policy configurable untuk origin/verb/header yang diizinkan; preflight sebelum resource auth, tanpa membuka akses resource actual; error response juga mengikuti policy; proxy/app ownership jelas.

**Acceptance:** allowed/disallowed origin dan OPTIONS tested; request actual tetap memerlukan auth; tidak ada unconditional wildcard credentials; frontend staging bisa menyelesaikan login/request sesuai policy.
