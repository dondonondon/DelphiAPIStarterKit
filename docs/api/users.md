# Users API — auth-v2

Base path `/api/v1/User`. Access actor selalu berasal dari credential resolver; public UUID bukan permission.
Envelope, credential headers, limits dan recovery lifecycle mengikuti [Auth](auth.md).

| Endpoint | Required permission / policy | Request / hasil |
|---|---|---|
| GET /User | users.read | limit 1–100 default 50, offset 0–100000; user belum deleted |
| GET /User/{user_id} | users.read | UUID lowercase; 404 jika tidak ada |
| POST /User | users.create; role assignment juga users.assign_role + recent + delegation | username required; password optional; fullname optional; is_active integer 0/1 default 1; role_id positive integer/null optional. 201 public user DTO |
| PUT /User/{user_id} | users.update + target boundary; status/role juga recent; role juga users.assign_role + delegation | fullname string maksimal 100, is_active integer 0/1, role_id positive integer/null. Minimal satu field; unknown/password fields 400. 200 authoritative readback |
| DELETE /User/{user_id} | users.delete + recent + target boundary | Soft-delete + full session/access/refresh/recovery revoke atomik, 200 data:[] |
| POST /User/ChangePassword | Own actor, old password verification | old_password/new_password; restricted session boleh memakai ini. 200 data:[], revoke current juga; login kembali |
| POST /User/{user_id}/ResetPassword | users.reset_password + recent + target boundary | confirm_reset:true; one-time reset_token/public user_id/expires_in, 200. Tidak temporary_password dan tidak mengubah password/session sebelum redemption |

User DTO: user_id, username, fullname, role_id integer/null, role_code, is_active dan must_change_password boolean.
Integer legacy role_id dipertahankan; lookup melalui GET /Role legacy_role_id, URL Role memakai UUID berbeda.
New password 15–128 Unicode codepoints, whitespace dipertahankan; credential tidak di-echo. Initial password memberi restricted session.
Jika password tidak diberikan, source menyimpan hash random password yang tidak diketahui dan mengembalikan setup_token sekali + expires_in integer;
redeem melalui CompletePasswordReset, lalu login. Tidak ada saluran email/registration semu. Token diserahkan melalui verified controlled channel/HTTPS.

Permission absent/null/inactive/deleted role atau inactive mapping deny by default. is_superadmin bukan bypass.
Actor hanya dapat mengelola target dengan effective permissions subset actor, dan memberi role dengan permissions subset actor.
Administrative self mutation ditolak 403; self password/session memakai endpoint khusus. Status/role mutation mencabut seluruh credentials/recovery target.
Admin terakhir berarti active/nondeleted/nonrestricted user dengan tujuh permission administrasi aktif
(users.read/create/update/delete/reset_password/assign_role, roles.manage). Policy lock membuat protection atomik terhadap request konkuren.
Username tetap reserved setelah soft-delete. Invalid reference role 400; unique conflict 409; missing target 404.

| Actor / action | Hasil baseline |
|---|---|
| Ordinary tanpa users.* / list/detail/create/update/delete/reset, termasuk own UUID | 403, user/role/credential state tidak berubah |
| Actor dengan permission action + target/delegation/recent yang sesuai | Action dilanjutkan ke validation/transaction |
| Missing/expired/revoked/inactive user credential | 401 |
| Restricted initial password / Me/Sessions/business/admin | 403 |
| Restricted / ChangePassword atau credential-specific Logout | Diperbolehkan setelah validation |

Intentional client cutover: generic PUT password ditolak; reset response berubah menjadi one-time credential; auth expiry integer;
flags DTO typed boolean; no request_detail; refresh/logout lama berbasis session_id/device_id ditolak. Jangan deploy SQL tanpa source/client cutover.
[Hasil dan blocker](../bugs/wave-01-result.md) memisahkan Win64/DB proof dari Linux/production/client gates.
