# ถอดฟีเจอร์ `example`

ฟีเจอร์นี้ถูกสร้างขึ้นมาเพื่อถูกลบ — มันมีไว้พิสูจน์ว่าสถาปัตยกรรมถอดได้สะอาดจริง

ทำตาม `docs/superpowers/UNINSTALL-template.md` โดยแทน `<id>` = `example` และ `<Id>` = `Example`

สิ่งที่ฟีเจอร์นี้เป็นเจ้าของ:

| ของ | ชื่อ |
|---|---|
| Postgres schema | `f_example` (ตาราง `note`) |
| โฟลเดอร์ในเครื่อง | `Application Support/Features/example/last-visit.txt` |
| คีย์ UserDefaults | `f.example.showsUUID` |
| Storage bucket | ไม่มี |

ไม่ต้อง export อะไรก่อนลบ ข้อมูลในนั้นเป็นข้อความทดสอบ
