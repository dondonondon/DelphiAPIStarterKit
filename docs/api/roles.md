# Role API — auth-v2

Base path `/api/v1`. Semua request memerlukan access credential. `role_id` pada URL/katalog adalah UUID publik;
`legacy_role_id` adalah integer yang dikirim sebagai `role_id` pada User DTO. `is_superadmin` hanya metadata.

| Endpoint | Policy | Request / hasil |
|---|---|---|
| GET /Role | roles.read | limit default 50, maksimum 100; offset 0–100000. Katalog role yang belum deleted, beserta permission aktif, role_code, role_name dan legacy_role_id integer |
| PUT /Role/{role_id}/Permissions | roles.manage, users.assign_role, recent authentication | `{"permissions":["products.read","roles.read"]}`. Maksimum 100 kode string unik, masing-masing maksimal 100 karakter; kode harus aktif dan dikenal. Empty array diperbolehkan bila admin terakhir tetap tersedia. Success 200 data:[] |

Grant target dan permission baru harus berada dalam effective permissions actor. Actor tidak dapat memberi permission yang tidak dimilikinya.
Transaksi mengunci authority policy sebelum user/session/credential. Perubahan mencabut semua credential dan recovery outstanding
user pada role tersebut. Pemeriksaan admin terakhir dilakukan setelah perubahan dalam transaksi yang sama; kegagalan 409 rollback seluruh perubahan.
Tidak ada CRUD role baru melalui HTTP pada baseline ini; katalog diprovision melalui seed/offline schema policy.

Error 400 input/reference invalid; 401 credential invalid; 403 permission/delegation/recent authentication; 404 role tidak ditemukan;
409 admin terakhir; 500 safe internal error. Envelope dan header mengikuti [Auth](auth.md). Role inactive/deleted tidak memberi permission.
