# Wave eksekusi task review — Windows dan Linux

Tanggal: **1 Oktober 2026**. Status semua wave: **BELUM DIMULAI**.

Empat file wave membagi 12 task menjadi tiga task utama per prompt. Seluruh 46 temuan memiliki satu wave utama melalui owner task existing. Detail acceptance tetap di [indeks task](review-tasks-windows-linux-2026-10-01.md) dan task kategori; baseline evidence di [review lengkap](full-review-windows-linux-2026-10-01.md).

**Revisi scope Auth (1 Oktober 2026):** [kontrak auth-v2](auth-production-contract-2026-10-01.md) menambahkan permission catalog,
refresh rotation, one-time recovery, endpoint self-service/session/role, dan bootstrap tanpa credential bawaan.
SQL baseline/sample target sudah diperbarui. T01–T07/T09–T12 mempunyai langkah Auth/dependency tambahan;
status BELUM DIMULAI tetap merujuk implementasi aplikasi/acceptance, bukan penulisan schema.
Jangan menganggap 46 temuan historis telah tertutup atau SQL ini sudah kompatibel dengan Pascal existing.

**Sinkronisasi paket Auth:** seluruh `wave-01.md`–`wave-04.md` dan
`prompt-execute-wave-01.md`–`prompt-execute-wave-04.md` kini memuat kontrak auth-v2 eksplisit,
scope/dependency/gate per wave serta salinan prompt yang sama. Wave-02 menjaga audit/typed IO/domain
transaction; wave-03 menjaga config/security settings/bounded session queries; wave-04 menjaga
readiness/migration/architecture. Status eksekusi dan owner utama 46 temuan tidak berubah.

## 1. Pembagian wave

| Wave | Prompt eksekusi | Task utama | Fokus | Temuan utama | Urutan internal | Status |
|---|---|---|---|---|---|---|
| [wave-01](wave-01.md) | [prompt-execute-wave-01](prompt-execute-wave-01.md) | [T01](task-01-authorization-dan-permission.md), [T02](task-02-authentication-password-dan-session.md), [T03](task-03-http-routing-dan-error-boundary.md) | Authorization, authentication, dan HTTP boundary | 14 | T01 → T02 → T03 | BLOCKED |
| [wave-02](wave-02.md) | [prompt-execute-wave-02](prompt-execute-wave-02.md) | [T04](task-04-logging-dan-observability.md), [T05](task-05-request-response-json-dan-waktu.md), [T06](task-06-database-transaksi-dan-validasi-domain.md) | Logging, typed JSON, dan correctness database | 14 | T04 → T05 → T06 | BELUM DIMULAI |
| [wave-03](wave-03.md) | [prompt-execute-wave-03](prompt-execute-wave-03.md) | [T07](task-07-collection-pagination-dan-kapasitas.md), [T08](task-08-storage-upload-dan-stream.md), [T09](task-09-config-path-dan-persistence.md) | Config, storage, dan collection pagination | 9 | T09 → T08 → T07 | BELUM DIMULAI |
| [wave-04](wave-04.md) | [prompt-execute-wave-04](prompt-execute-wave-04.md) | [T10](task-10-hosting-build-dan-deployment.md), [T11](task-11-schema-migration-dan-kompatibilitas.md), [T12](task-12-architecture-dan-centralization.md) | Hosting, migration, dan architecture consolidation | 9 | T10 → T11 → T12 | BELUM DIMULAI |

## 2. Cara memakai satu shot prompt

Jalankan wave-01 → wave-02 → wave-03 → wave-04, satu permintaan untuk setiap wave. Gunakan file prompt-execute-wave-01.md sampai prompt-execute-wave-04.md pada tabel di atas; masing-masing berisi prompt eksekusi lengkap. File wave tetap memuat scope, dependency/validation gates dan checkpoint. Jika instruksi berubah, sinkronkan file prompt dengan blok prompt bagian 5 file wave terkait.

```text
Eksekusi seluruh instruksi pada D:\Github\DelphiAPIStarterKit\docs\bugs\prompt-execute-wave-01.md sampai seluruh scope yang dapat dikerjakan selesai, setiap acceptance wajib mempunyai evidence atau blocker konkret, status diperbarui dan hasil disimpan sesuai file wave.
```

Untuk wave berikutnya, gunakan prompt-execute-wave-02.md, prompt-execute-wave-03.md atau prompt-execute-wave-04.md. Setiap prompt hanya menjalankan scope wave terkait.

**Satu shot bukan jaminan seluruh external acceptance tersedia.** Source/build/runtime/DB/deployment dilaporkan terpisah. Resource unavailable dicatat BLOCKED dan pekerjaan independen tetap diselesaikan dalam scope.

## 3. Gate dan handoff lintas wave

- **Build:** T10.a/F34 diperiksa/diperbaiki sebelum build pertama sejak wave-01, walaupun owner utama T10 berada pada wave-04. Tidak menutup T10 keseluruhan hanya karena build script sudah aman.
- **Wave-01:** actor/auth/HTTP dapat membutuhkan minimum logger T04, parser/no-echo T05, role/mutation T06, config/secret reader T09 dan auth schema notes T11. Hanya slice necessary, bukan seluruh task dependency.
- **Wave-02:** sempurnakan slice logger/parser/domain yang sudah disentuh; pakai kembali policy/session/error boundary dan catat schema delta untuk migration akhir.
- **Wave-03:** urutan T09 → T08 → T07 mengutamakan roots/config sebelum storage lalu collection. Pertahankan typed serializer, logger dan auth contracts.
- **Wave-04:** reconcile early F34, tuntaskan host/native runtime dan migration clone, lalu architecture extraction setelah regression behavior tersedia.
- Prerequisite yang ditutup lebih awal dicatat pada task/finding owner asal dengan evidence; partial task tetap BERJALAN. Wave utama berikutnya menyelesaikan sisanya tanpa duplicate implementation.
- Dependency contracts diverifikasi actual. Status BLOCKED wave sebelumnya tidak otomatis memblokir scope independen, tetapi mandatory evidence yang belum ada tetap tidak dihitung lulus.
- Tabel tahap prioritas pada indeks task tetap panduan risiko/subpekerjaan; nomor tahap di sana berbeda dari empat file wave ini.

## 4. Definition of done bersama

- [ ] Semua task/finding scope mempunyai acceptance evidence; CONTEXT-DEPENDENT diputuskan dengan actual consumer/deployment/policy.
- [ ] Jalur build aman dan code changes diuji target relevan; Linux cross-build dipisahkan dari Linux runtime proof.
- [ ] Regression behavior/state risiko terkait, API/config/schema/mapping updates serta compatibility/migration dicatat.
- [ ] Unrelated dirty work, feature-first structure, local runtime config dan read-only temp-file terjaga; no actual secrets dalam artefacts.
- [ ] Status task/indeks/wave konsisten, checkpoint mencatat concrete next action, dan result report memiliki evidence/blocker/handoff.

SELESAI memerlukan semua acceptance wajib scope terpenuhi. BLOCKED tidak dihitung sebagai selesai; implementasi independent tetap dilanjutkan. Public readiness memerlukan seluruh gate master bagian 7.1, bukan sekadar empat prompt pernah dijalankan.

## 5. Matrix cakupan

| Task | Wave owner utama | Finding owner |
|---|---|---|
| [T01](task-01-authorization-dan-permission.md) | [wave-01](wave-01.md) | F01 |
| [T02](task-02-authentication-password-dan-session.md) | [wave-01](wave-01.md) | F03, F04, F05, F06, F43, F44, F45 |
| [T03](task-03-http-routing-dan-error-boundary.md) | [wave-01](wave-01.md) | F08, F09, F24, F25, F26, F37 |
| [T04](task-04-logging-dan-observability.md) | [wave-02](wave-02.md) | F10, F23 |
| [T05](task-05-request-response-json-dan-waktu.md) | [wave-02](wave-02.md) | F02, F11, F15, F16, F17, F22, F27 |
| [T06](task-06-database-transaksi-dan-validasi-domain.md) | [wave-02](wave-02.md) | F18, F19, F20, F21, F42 |
| [T07](task-07-collection-pagination-dan-kapasitas.md) | [wave-03](wave-03.md) | F12, F36 |
| [T08](task-08-storage-upload-dan-stream.md) | [wave-03](wave-03.md) | F07, F14, F38 |
| [T09](task-09-config-path-dan-persistence.md) | [wave-03](wave-03.md) | F13, F28, F39, F46 |
| [T10](task-10-hosting-build-dan-deployment.md) | [wave-04](wave-04.md) | F29, F30, F31, F32, F33, F34, F41 |
| [T11](task-11-schema-migration-dan-kompatibilitas.md) | [wave-04](wave-04.md) | F35 |
| [T12](task-12-architecture-dan-centralization.md) | [wave-04](wave-04.md) | F40 |

## 6. Catatan paket

File wave/prompt baru disiapkan; belum ada task, build, database migration atau deployment yang dieksekusi oleh pembuatan paket ini. Laporan dan acceptance task existing dipertahankan; navigasi ditambahkan agar task/wave saling terhubung.

## Handoff WAVE-01

Implementation T01-T03 dan minimum dependency slices tersedia; source/build/Win64/MariaDB evidence tercatat di [hasil wave-01](wave-01-result.md). Mandatory Win32/Linux/provider/client/MFA/deployment gates BLOCKED. Wave-02/03/04 belum dieksekusi sebagai wave; prerequisite slices berstatus BERJALAN pada task owner dan harus direconcile, bukan diimplementasikan ulang.
