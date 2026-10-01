# T05 — Request/response JSON, tipe data, dan waktu

Status: **BERJALAN**. Prioritas tertinggi: **P1**. Tanggal pemecahan: **1 Oktober 2026**.

Temuan utama: **F02, F11, F15, F16, F17, F22, F27** (7 CONFIRMED, 0 CONTEXT-DEPENDENT).

Navigasi: [indeks task](review-tasks-windows-linux-2026-10-01.md) · [laporan lengkap](full-review-windows-linux-2026-10-01.md) · [wave-02](wave-02.md).

Baseline: review working tree 1 Oktober 2026, HEAD `358db33b95724f654db00e39fd4f35dc26c0d12c`. Slice minimum WAVE-01 telah diterapkan; sisa task belum dieksekusi. Lokasi/nomor baris lampiran adalah snapshot; baca ulang source sebelum perubahan. Build/harness laporan bukan bukti acceptance task ini.

**Revisi auth-v2 (1 Oktober 2026):** spesifikasi dan SQL target telah diperbarui; status di atas adalah status implementasi aplikasi/acceptance, bukan status penulisan schema. Ikuti [kontrak target Auth](auth-production-contract-2026-10-01.md); lampiran temuan tetap bukti baseline historis.

## 1. Tujuan dan cakupan

Hentikan secret echo dan pastikan parsing/serialization menjaga tipe/nilai, envelope, field publik serta timestamp.

**Cakupan:** Core.Response/Rest/Request, shared Dataset/Validator/Strings, DTO/validator/service mapper Users/Auth/Product/Customer dan kontrak waktu.

ID di atas dimiliki utama task ini. Dependency merupakan koordinasi; tidak menggandakan owner/status temuan.

## 2. Langkah pengerjaan

- [ ] Auth-v2 response memakai typed access_token/refresh_token/session_id strings, expires_in/refresh_expires_in integers, password_change_required Boolean dan token_type Bearer. Empty success []; error [{}]; no request_detail; no-store.
- [ ] ResetPassword response hanya one-time reset_token sesuai delivery policy, bukan temporary_password. Secret scan membolehkan credential baru hanya pada issuance yang berwenang; ChangePassword/Logout/Me/Sessions dan error bebas password/token/hash.
- [ ] Catat intentional client cutover untuk legacy string expires_in, session_id/device_id refresh/logout, generic PUT password dan temporary_password. API docs/Postman diubah saat implementasi endpoint; target kontrak sekarang tidak dianggap runtime tersedia.

- [ ] Containment F02: ChangePassword tidak menyerialisasi request dataset; hapus request_detail echo atau metadata allowlist. Logout memakai payload eksplisit dan credential responses no-store.
- [ ] Parse sekali dengan structured result; single-record menerima object, bukan batch. Verifikasi Content-Type dan limit bytes/depth/fields/rows; invalid input dihentikan sebelum business work.
- [ ] Pertahankan token types string/Boolean/integer/decimal/null sebelum validator; jangan universal AsString/Double. Serialize Field.DataType/typed DTO; strings tetap TJSONString dan numbers invariant.
- [ ] Jika array helper dipertahankan, bangun schema menurut nama dan policy union/missing/null/type conflict; order property tidak memengaruhi mapping.
- [ ] GET Users memakai role_id sesuai API integer existing dan nullable contract; jangan mengganti ke UUID tanpa versioned migration.
- [ ] Satu clock UTC untuk servertime; tetapkan DATETIME/_unix/date-only policy sebelum konversi, jangan mengonversi timestamp UTC sebagai local.
- [ ] Update docs/Postman terkait payload/type/null/role/time serta 400/413/415; nested JSON hanya dari field bertipe eksplisit.

## 3. Dependensi dan koordinasi

- F02 diselesaikan cepat tanpa menunggu parser penuh. [T01](task-01-authorization-dan-permission.md)/[T02](task-02-authentication-password-dan-session.md) memiliki permission/lifecycle password.
- [T03](task-03-http-routing-dan-error-boundary.md) HTTP boundary, [T06](task-06-database-transaksi-dan-validasi-domain.md) domain bounds/money policy dan [T07](task-07-collection-pagination-dan-kapasitas.md) fetch/pagination; sepakat satu parser/serializer agar perubahan tidak saling menimpa.
- [T04](task-04-logging-dan-observability.md) memakai clock/redaction, [T12](task-12-architecture-dan-centralization.md) merapikan facade setelah behavior stabil.

## 4. Acceptance dan validasi kategori

- [ ] Auth-v2 typed response integer expiry/Boolean flag, intentional one-time credential allowlist, empty success [], no-store/no-echo dan client cutover terdokumentasi serta diuji.

- [ ] Recursive response scan membuktikan old_password/new_password/hash tidak ada di data/request_detail; credential baru hanya muncul pada allowlist issuance berwenang dalam kontrak auth-v2, tanpa request echo. Docs/Postman cocok.
- [ ] Strict parser untuk +628123, 123/00123/1e2 sebagai string, string {} dan [], Unicode/emoji/null; tipe string sama di GET/POST/PUT.
- [ ] Invalid syntax/scalar/[1]/multiobject/wrong type/null/media type/oversize/deep body menghasilkan 400/415/413 tanpa business execution.
- [ ] 9007199254740993 dan batas Int64 tepat atau ditolak eksplisit; decimal tidak melalui Double. en-US/id-ID/Linux default menghasilkan nilai identik.
- [ ] Array helper reorder/optional/additional/duplicate/null-first/mixed/empty/scalar mengikuti contract; single-record API tetap menolak batch unsupported.
- [ ] GET/POST/PUT role_id name/type/null konsisten. Instant yang sama UTC/Jakarta menghasilkan epoch sama; DATETIME/date-only/DST relevan tidak dikonversi ganda.

## 5. Checklist penutupan temuan

- [x] **F02 (P1, CONFIRMED)** — Password plaintext muncul pada response. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F11 (P1, CONFIRMED)** — Response JSON invalid dan tipe string berubah. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F15 (P2, CONFIRMED)** — JSON invalid tidak ditolak pada boundary. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F16 (P2, CONFIRMED)** — Presisi number request hilang. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F17 (P2, CONFIRMED)** — Array schema mengikuti posisi property. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F22 (P2, CONFIRMED)** — Nama field role berbeda antar-operasi. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F27 (P2, CONFIRMED)** — Unix time bergeser sesuai timezone host. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.

## 6. Definition of done dan catatan hasil

- [ ] Acceptance per temuan/kategori memiliki evidence; CONTEXT-DEPENDENT diselesaikan lewat consumer/deployment/policy actual, bukan asumsi.
- [ ] Jika code berubah, build target relevan sesuai aturan repo. Amankan T10.a sebelum `compile.bat`; catat platform/config/toolchain/hasil.
- [ ] Runtime Windows/Linux, DB/memory/supervisor acceptance relevan mempunyai hasil tersendiri; compiler pass bukan penggantinya.
- [ ] API docs/Postman di-update bila contract berubah; README/config/schema/project mapping hanya bila terdampak.
- [ ] Unrelated dirty work dipertahankan dan tidak ada password/key/token actual di commit/log/evidence.
- [ ] Files changed, hasil regression, compatibility/migration, residual risk dan blocker dicatat. BLOCKED tidak dihitung selesai.

**Catatan hasil WAVE-01 (2026-10-01):** One typed Auth/User/Role JSON parser in Core.Request, typed JSONArray response overload, no request_detail, no password echo, no-store, Unix UTC string. F02 closed by empty ChangePassword/Logout and response tests.

E1/E2/E3 + E10 secret scan. Remaining generic dataset number/string/array serializer/parser and full clock/date-only locale matrix; F11/F15/F16/F17/F22/F27 not globally closed. Owner tetap T05; status BERJALAN, bukan SELESAI. Gunakan implementation ini pada wave berikutnya. Detail [hasil WAVE-01](wave-01-result.md) dan [evidence](evidence/wave-01/acceptance.md).

## 7. Temuan sumber lengkap

Isi severity, label, lokasi, risiko, rekomendasi dan acceptance dipertahankan dari master. Relative source links tetap valid karena folder sama. Matrix lintas kategori dan bukti build/harness awal tersedia pada bagian 2–7 laporan lengkap.

### F02 — P1 — CONFIRMED — Password plaintext muncul pada response

**Lokasi:** [User.Service.pas](../../sources/modules/users/User.Service.pas#L128), 128; [BFA.Core.Response.pas](../../sources/core/BFA.Core.Response.pas#L434), 434–450; [users.md](../api/users.md#L285), 285–293.

`ChangePassword` sukses memberi `FData` sebagai **data response**, sehingga dataset request yang berisi `old_password` dan `new_password` diserialisasi ke response HTTP 200. Dokumentasi menjanjikan data kosong. Overload response dengan request dataset juga menambahkan `request_detail` secara generik pada 443–446; tidak ada allowlist/redaction field sensitif.

**Pemicu:** successful ChangePassword dengan kedua password. GET yang memakai overload `(response dataset, request dataset)` juga dapat menggemakan body request melalui `request_detail`.

**Dampak:** credential berpotensi tersalin ke response-body logging/APM, tracing client, cache/debug response, atau penyimpanan aplikasi. Access log biasa yang tidak merekam body tidak otomatis menangkap password. HTTPS tidak menghapus risiko penggandaan secret di response.

**Perbaikan:** response perubahan password berisi payload yang sengaja ditentukan, tanpa request echo. Hapus request echo otomatis atau gunakan metadata allowlist yang tidak memuat secret. Tambahkan `Cache-Control: no-store` pada response autentikasi/credential. `Logout` juga perlu payload eksplisit; saat ini baris 196 [Auth.Service.pas](../../sources/modules/auth/Auth.Service.pas#L196) menggemakan session/device request dan berbeda dari contoh data kosong.

**Acceptance:** recursive scan semua response sukses/gagal membuktikan password lama/baru tidak muncul di `data`, `request_detail`, atau field lain; dokumentasi dan Postman cocok dengan payload final.

### F11 — P1 — CONFIRMED — Response JSON invalid dan tipe string berubah

**Lokasi:** [BFA.Core.Response.pas](../../sources/core/BFA.Core.Response.pas#L181), 181–214, 277–289, 373–383, 595–601; [Customer.Service.pas](../../sources/modules/customers/Customer.Service.pas#L123), alur GET dataset.

`JSONValueFromString` menebak tipe dari isi teks. String numerik menjadi number; string yang menyerupai JSON menjadi object/array. `TryStrToFloat` juga menerima tanda `+`, sedangkan `TJSONNumber.Create(AValue)` mempertahankan teks tersebut. Akibatnya string `+628123` menjadi number literal `+628123`, yang **invalid dalam JSON**.

**Bukti runtime harness:** username `123` menjadi JSON number `123`; name `{"flag":true}` menjadi object; phone `+628123` menjadi literal tanpa kutip. Ini sudah direproduksi memakai unit saat ini, tanpa DB/server.

**Dampak:** GET Customer dengan phone internasional dapat tidak dapat diparse; nama/username/postal code tidak mempertahankan tipe; client menganggap string menjadi number/object. Customer DTO create/update mengutip string secara eksplisit, sedangkan GET dataset memakai helper generik sehingga antar-operasi tidak konsisten.

**Perbaikan:** gunakan tipe `TField.DataType` atau explicit typed DTO sebagai authority. String harus tetap `TJSONString` meskipun berisi angka atau JSON text. Nested JSON harus field bertipe eksplisit; angka diserialisasi memakai formatter JSON invariant, bukan string heuristics.

**Acceptance:** parse response dengan parser strict untuk `+628123`, `123`, `00123`, `1e2`, `{}`, `[]`, Unicode; tipe semua string tetap string; GET/POST/PUT konsisten. Aturan number mengikuti [RFC 8259 §6](https://www.rfc-editor.org/rfc/rfc8259.html#section-6).

### F15 — P2 — CONFIRMED — JSON invalid tidak ditolak pada boundary

**Lokasi:** [BFA.Core.Rest.pas](../../sources/core/BFA.Core.Rest.pas#L157), 157–165 dan 209–217; [BFA.Helper.Dataset.pas](../../sources/shared/helpers/BFA.Helper.Dataset.pas#L51), 51–99 dan 343–351; [App.WebModule.pas](../../sources/app/App.WebModule.pas#L82), 82–84.

Boolean hasil `LoadFromJSON` diabaikan. Helper kadang mengubah parsing failure menjadi error dataset, kadang melempar exception sebelum inner catch. Array `[1]` ditolak saat CreateDataset dan menjadi HTTP 500, padahal input client invalid. GET tidak memakai validator payload sehingga false parsing result tidak selalu menghentikan operation.

JSON body dengan `text/plain` dapat diteruskan seperti JSON. Tidak ada limit ingress JSON bytes/depth/field count/row count; `MAX_FILE_SIZE` hanya upload helper. Generic string validator membaca `AsString`, bukan memastikan tipe token JSON.

**Perbaikan:** parse satu kali pada HTTP boundary dengan hasil/error terstruktur. Wajib object untuk kontrak single request; reject multiple records jika bukan batch API. Content-Type diverifikasi case-insensitive sesuai kebutuhan; malformed/type-invalid body 400, media type unsupported 415, body terlalu besar 413. Tetapkan limit sebelum mengalokasikan dataset/menyimpan seluruh body sebisa mungkin pada bridge/proxy.

**Acceptance:** invalid syntax, scalar root, `[1]`, array multiobject, wrong field type, null, wrong media type, oversized/deep payload ditolak konsisten tanpa business execution; tidak ada raw sensitive payload pada log/response.

### F16 — P2 — CONFIRMED — Presisi number request hilang

**Lokasi:** [BFA.Helper.Dataset.pas](../../sources/shared/helpers/BFA.Helper.Dataset.pas#L477), 477–485 dan 529–554; [Product.Validator.pas](../../sources/modules/products/Product.Validator.pas#L84), 84–106.

Semua `TJSONNumber` dipetakan ke `ftFloat`; selanjutnya value ditulis melalui string ke field float. JSON integer `9007199254740993` tidak dapat direpresentasikan tepat sebagai Double.

**Bukti harness:** field type 6 (`ftFloat`), `AsLargeInt` menjadi `9007199254740992`. Perubahan nilai terjadi sebelum validator/service. Money juga melewati floating point dan konversi `AsString`, sehingga ketepatan/format tidak berasal dari token JSON aslinya. Locale Windows/Linux dapat memperbesar perbedaan parsing.

**Perbaikan:** typed DTO parser dengan integer Int64/UInt64 range yang jelas, Decimal/BCD/Currency sesuai kontrak, dan invariant JSON number parsing. Public UUID tetap string. Jangan memakai Double sebagai perantara universal.

**Acceptance:** integer batas aman dan Int64 diterima/reject tanpa perubahan nilai; money tepat; locale en-US/id-ID dan Linux default menghasilkan value yang sama; null dibedakan dari nol/empty.

### F17 — P2 — CONFIRMED — Array schema mengikuti posisi property

**Lokasi:** [BFA.Helper.Dataset.pas](../../sources/shared/helpers/BFA.Helper.Dataset.pas#L319), 319–385 dan 417–427.

Jumlah field diambil dari object pertama. Setiap row memperbarui `ArrFields[Index].Name/type/size` berdasarkan posisi property. Nama field dapat tertimpa oleh row berikut; field tambahan dibuang saat jumlahnya melewati array awal; type/size lintas-row tercampur menurut posisi.

**Bukti harness:** `[{"a":"x","b":"y"},{"b":"z"}]` menimbulkan `EDatabaseError: Duplicate name 'b' in TFieldDefs`. Reorder object dengan jumlah field sama tidak selalu gagal, tetapi tidak membuktikan schema inference benar untuk optional/heterogeneous fields.

**Perbaikan:** jika arrays diperlukan, build schema berdasarkan nama, tentukan union/missing/null/type conflict rules, dan isi row berdasarkan nama. Untuk REST single-record request, lebih sederhana dan aman menolak arrays dengan 400.

**Acceptance:** object field order berbeda tidak memengaruhi value/type; optional field hilang, tambahan field, duplicate property, null-first row, mixed types, empty array, scalar item mengikuti kontrak; error client bukan 500.

### F22 — P2 — CONFIRMED — Nama field role berbeda antar-operasi

**Lokasi:** [User.Repository.pas](../../sources/modules/users/User.Repository.pas#L172), 172–181; [User.DTO.pas](../../sources/modules/users/User.DTO.pas#L78), 78; [users.md](../api/users.md#L53), kontrak GET/POST/PUT.

GET memilih `role_internal_id` tanpa alias; DTO POST/PUT menghasilkan `role_id`. Master role sendiri memiliki internal `id` dan public UUID `role_id`, sehingga penggunaan nama API integer yang sama juga memerlukan penjelasan yang jelas.

**Perbaikan minimum kompatibel:** alias field GET sesuai kontrak publik saat ini, misalnya `role_internal_id AS role_id`; jangan mengganti tipe integer menjadi UUID tanpa versioned migration. Dokumentasikan role identifier yang digunakan API lama.

**Acceptance:** GET/POST/PUT konsisten nama, tipe, dan nullable representation; `role_internal_id` tidak muncul sebagai kebocoran nama schema internal.

### F27 — P2 — CONFIRMED — Unix time bergeser sesuai timezone host

**Lokasi:** [BFA.Core.Response.pas](../../sources/core/BFA.Core.Response.pas#L70), 70/228/232; [BFA.Core.Rest.pas](../../sources/core/BFA.Core.Rest.pas#L140), 140; [BFA.Helper.Strings.pas](../../sources/shared/helpers/BFA.Helper.Strings.pas#L326), 326.

`DateTimeToUnix(Now)` memakai waktu lokal, tetapi default `AInputIsUTC=True` pada RTL DateUtils 364. Implementasi 2227–2234 hanya mengonversi lokal ke UTC jika parameter False. Pada host Asia/Jakarta, Unix servertime akan maju tujuh jam; pada host UTC defect dapat tersamarkan.

**Perbaikan:** clock helper UTC yang konsisten atau `DateTimeToUnix(Now, False)` untuk nilai lokal. Untuk kolom DATETIME, tetapkan timezone database/application lebih dulu; jangan menerapkan konversi lokal secara membabi buta pada nilai yang sudah UTC. Field tanggal tanpa waktu perlu kontrak sendiri, bukan otomatis instant UTC.

**Acceptance:** host UTC/Jakarta timezone menghasilkan epoch sama untuk instant yang sama; time service, log, dan `_unix` dataset mengikuti kebijakan; uji DST untuk target deployment relevan.
