# YouTube Skill Extractor

> สกัดความรู้จาก YouTube video แปลงเป็น Claude Code SKILL.md อัตโนมัติ
> ไม่ใช่แค่อ่าน transcript — **ดูภาพจริง** ว่ากดปุ่มไหน หน้าจอเป็นยังไง

---

## สารบัญ

- [YouTube Skill Extractor](#youtube-skill-extractor)
  - [ทำอะไรได้?](#ทำอะไรได้)
  - [ติดตั้ง](#ติดตั้ง)
    - [1. ติดตั้ง Dependencies](#1-ติดตั้ง-dependencies)
    - [2. ติดตั้ง Skill](#2-ติดตั้ง-skill)
    - [3. ตรวจสอบการติดตั้ง](#3-ตรวจสอบการติดตั้ง)
  - [วิธีใช้งาน](#วิธีใช้งาน)
    - [คำสั่งทั้งหมด](#คำสั่งทั้งหมด)
    - [1. สกัดความรู้แบบเต็ม (Full Pipeline)](#1-สกัดความรู้แบบเต็ม-full-pipeline)
    - [2. ดึงข้อมูลอย่างเดียว (Extract Only)](#2-ดึงข้อมูลอย่างเดียว-extract-only)
    - [3. วิเคราะห์ข้อมูลที่ดึงไว้แล้ว (Analyze)](#3-วิเคราะห์ข้อมูลที่ดึงไว้แล้ว-analyze)
    - [4. สร้าง SKILL.md จากผลวิเคราะห์ (Generate)](#4-สร้าง-skillmd-จากผลวิเคราะห์-generate)
    - [5. สกัดจากหลาย Video (Batch Mode)](#5-สกัดจากหลาย-video-batch-mode)
    - [6. ดูรายการ Video ที่เคยสกัด (List)](#6-ดูรายการ-video-ที่เคยสกัด-list)
    - [7. เลือก Output Format](#7-เลือก-output-format)
  - [การทำงานเบื้องหลัง (Pipeline 5 ขั้นตอน)](#การทำงานเบื้องหลัง-pipeline-5-ขั้นตอน)
    - [Step 1: Extract — ดึงข้อมูลจาก YouTube](#step-1-extract--ดึงข้อมูลจาก-youtube)
    - [Step 2: Read Transcript — อ่านและสรุป Transcript](#step-2-read-transcript--อ่านและสรุป-transcript)
    - [Step 3: Visual Analysis — วิเคราะห์ภาพ (หัวใจสำคัญ)](#step-3-visual-analysis--วิเคราะห์ภาพ-หัวใจสำคัญ)
    - [Step 4: Generate SKILL.md](#step-4-generate-skillmd)
    - [Step 5: Install Skill (Optional)](#step-5-install-skill-optional)
  - [โครงสร้างโปรเจกต์](#โครงสร้างโปรเจกต์)
  - [โครงสร้าง Output ต่อ Video](#โครงสร้าง-output-ต่อ-video)
  - [ระบบอัจฉริยะ (Smart Features)](#ระบบอัจฉริยะ-smart-features)
    - [ตรวจจับภาษาอัตโนมัติ](#ตรวจจับภาษาอัตโนมัติ)
    - [จัดหมวดหมู่ Skill อัตโนมัติ](#จัดหมวดหมู่-skill-อัตโนมัติ)
    - [วิเคราะห์ Frame ตามบริบท](#วิเคราะห์-frame-ตามบริบท)
    - [Scene Detection อัจฉริยะ](#scene-detection-อัจฉริยะ)
  - [มาตรฐานคุณภาพ](#มาตรฐานคุณภาพ)
  - [ความปลอดภัยและจริยธรรม](#ความปลอดภัยและจริยธรรม)
  - [แก้ไขปัญหา (Troubleshooting)](#แก้ไขปัญหา-troubleshooting)
  - [ตัวอย่างการใช้งานจริง](#ตัวอย่างการใช้งานจริง)

---

## ทำอะไรได้?

YouTube Skill Extractor เปลี่ยน video tutorial จาก YouTube ให้กลายเป็นไฟล์ SKILL.md สำหรับ Claude Code โดย:

1. **ดึง transcript** — ทั้งภาษาไทยและอังกฤษ พร้อม deduplicate ข้อความซ้ำ
2. **ตัด screenshots** — ใช้ scene detection จับตอนหน้าจอเปลี่ยน (เช่น กดเมนู, เปลี่ยนหน้า)
3. **Claude วิเคราะห์ภาพ + ข้อความ** — ดูภาพจริงว่ากดปุ่มไหน อยู่ตรงไหนของหน้าจอ
4. **สร้าง SKILL.md** — สรุปเป็น step-by-step guide พร้อม UI navigation, tips, และ common issues
5. **ติดตั้งใช้งานได้ทันที** — copy ไปไว้ใน `~/.claude/skills/` แล้วเรียกใช้ผ่าน Claude Code

### ใช้ได้กับ Video แบบไหน?

| ประเภท Video | ตัวอย่าง | ผลลัพธ์ |
|-------------|---------|---------|
| Software Tutorial | สอนใช้ FlowAccount, Figma, Excel | SKILL.md พร้อม UI paths + ปุ่มที่ต้องกด |
| Programming Tutorial | สอน React, Python, Docker | SKILL.md พร้อม code snippets + commands |
| Presentation / Slide | สอน marketing, business | SKILL.md พร้อม key concepts + frameworks |
| Terminal / CLI | สอน git, AWS CLI, Docker | SKILL.md พร้อม commands + flags |

---

## ติดตั้ง

### 1. ติดตั้ง Dependencies

ต้องมีโปรแกรมเหล่านี้ในเครื่อง:

```bash
# macOS (Homebrew)
brew install yt-dlp ffmpeg python3

# Ubuntu / Debian
sudo apt install ffmpeg python3
pip install yt-dlp

# ตรวจสอบว่าติดตั้งครบ
yt-dlp --version
ffmpeg -version
python3 --version
```

| Dependency | ทำหน้าที่ | ติดตั้งผ่าน |
|-----------|---------|-----------|
| `yt-dlp` | ดาวน์โหลด video, transcript, metadata จาก YouTube | `brew install yt-dlp` |
| `ffmpeg` | ตัด frames จาก video (scene detection) | `brew install ffmpeg` |
| `ffprobe` | อ่านข้อมูล video (duration) — มาพร้อม ffmpeg | มากับ ffmpeg |
| `python3` | แปลง VTT → text, สร้าง frame index, จัดการ metadata | `brew install python3` |

### 2. ติดตั้ง Skill

```bash
# Clone repository
git clone <repo-url> ~/.claude/skills/youtube-skill-extractor

# หรือ copy ไฟล์เอง
mkdir -p ~/.claude/skills/youtube-skill-extractor
cp -r . ~/.claude/skills/youtube-skill-extractor/

# ทำให้ script รันได้
chmod +x ~/.claude/skills/youtube-skill-extractor/scripts/extract.sh
```

### 3. ตรวจสอบการติดตั้ง

เปิด Claude Code แล้วพิมพ์:

```
/youtube-skill-extractor list
```

ถ้าเห็นข้อความตอบกลับ (แม้จะว่างเปล่า) แสดงว่า skill ถูกโหลดสำเร็จ

---

## วิธีใช้งาน

### คำสั่งทั้งหมด

| คำสั่ง | รายละเอียด |
|--------|-----------|
| `/youtube-skill-extractor <url>` | สกัดความรู้จาก video ทำทุกขั้นตอนอัตโนมัติ |
| `/youtube-skill-extractor extract <url>` | ดึง transcript + frames อย่างเดียว (ไม่วิเคราะห์) |
| `/youtube-skill-extractor analyze <video-id>` | วิเคราะห์ frames + transcript ที่ดึงไว้แล้ว |
| `/youtube-skill-extractor generate <video-id>` | สร้าง SKILL.md จากผลวิเคราะห์ |
| `/youtube-skill-extractor batch <url1> <url2>...` | สกัดจากหลาย video รวมเป็น 1 skill |
| `/youtube-skill-extractor list` | ดู video ที่เคยสกัดแล้ว |

---

### 1. สกัดความรู้แบบเต็ม (Full Pipeline)

วิธีที่ง่ายที่สุด — ใส่ URL แล้วรอ:

```
/youtube-skill-extractor https://www.youtube.com/watch?v=xxxxx
```

Claude จะ:
1. ดาวน์โหลด transcript + ตัด screenshots อัตโนมัติ
2. อ่านและสรุป transcript
3. ดูทุก frame ด้วย multimodal vision
4. สร้าง SKILL.md จาก template
5. ถามว่าจะติดตั้ง skill เลยหรือไม่

**ใช้เวลาประมาณ:** ขึ้นกับความยาว video
- Video 10 นาที → ~2-5 นาที
- Video 30 นาที → ~5-10 นาที
- Video 60+ นาที → ~10-20 นาที

---

### 2. ดึงข้อมูลอย่างเดียว (Extract Only)

ถ้าต้องการดึง transcript + frames มาดูก่อนโดยยังไม่ต้องวิเคราะห์:

```
/youtube-skill-extractor extract https://www.youtube.com/watch?v=xxxxx
```

ผลลัพธ์จะอยู่ใน:
```
~/.claude/skills/youtube-skill-extractor/output/<video-id>/
```

ใช้กรณี:
- ต้องการดู frames ก่อนว่าถูกต้องมั้ย
- ต้องการแก้ transcript ก่อนวิเคราะห์
- ต้องการรัน extract หลาย video แล้วค่อยวิเคราะห์ทีหลัง

---

### 3. วิเคราะห์ข้อมูลที่ดึงไว้แล้ว (Analyze)

หลังจาก extract แล้ว สั่งวิเคราะห์แยก:

```
/youtube-skill-extractor analyze dQw4w9WgXcQ
```

ใส่ **video ID** (ไม่ใช่ URL เต็ม) — เป็นรหัส 11 ตัวอักษรที่อยู่หลัง `v=` ใน URL

Claude จะ:
1. อ่าน transcript ทุกภาษา
2. ดูทุก frame (ทีละ 10 ภาพ ป้องกัน context overflow)
3. เขียนผลวิเคราะห์ลงในไฟล์ `analysis.md`

---

### 4. สร้าง SKILL.md จากผลวิเคราะห์ (Generate)

หลังจากมี `analysis.md` แล้ว:

```
/youtube-skill-extractor generate dQw4w9WgXcQ
```

Claude จะ:
1. อ่าน `analysis.md` + `skill-template.md`
2. สร้าง SKILL.md ที่มีโครงสร้างครบ:
   - Frontmatter (name, description, triggers)
   - Quick Reference table
   - Knowledge Base
   - Step-by-Step Workflows พร้อมระบุตำแหน่ง UI
   - Common Issues & Solutions
   - Pro Tips จากผู้สอน
   - Source Attribution

---

### 5. สกัดจากหลาย Video (Batch Mode)

รวมความรู้จากหลาย video เรื่องเดียวกันเป็น 1 skill:

```
/youtube-skill-extractor batch https://youtube.com/watch?v=aaa https://youtube.com/watch?v=bbb https://youtube.com/watch?v=ccc
```

**Batch Mode ทำอะไรพิเศษ:**
- Extract ทุก video พร้อมกัน (parallel)
- วิเคราะห์แต่ละ video แยก
- **รวมความรู้ (merge):** ตัด content ซ้ำ, เรียงจากง่าย → ยาก
- รวม tips/tricks จากทุกผู้สอน
- Note ความแตกต่างระหว่างผู้สอน (ถ้ามี)
- สร้าง 1 SKILL.md ที่ครอบคลุมทุก video

**ใช้เมื่อ:**
- มี tutorial หลายคลิปจากช่องเดียวกัน (เช่น playlist)
- ต้องการเปรียบเทียบวิธีสอนจากหลายช่อง
- ต้องการ skill ที่ครอบคลุมหัวข้อกว้าง

---

### 6. ดูรายการ Video ที่เคยสกัด (List)

```
/youtube-skill-extractor list
```

แสดงรายการ video ทั้งหมดที่เคยดึงข้อมูลมาแล้ว พร้อมสถานะ:
- มี transcript หรือไม่
- จำนวน frames
- มี analysis แล้วหรือยัง
- มี SKILL.md แล้วหรือยัง

---

### 7. เลือก Output Format

นอกจาก SKILL.md (default) ยังเลือก format อื่นได้:

```
/youtube-skill-extractor <url> --format training
```

| Format | คำอธิบาย | เหมาะกับ |
|--------|---------|---------|
| `SKILL.md` | Claude Code skill file (default) | ใช้กับ Claude Code โดยตรง |
| `guide.md` | คู่มือ step-by-step แบบ standalone | แชร์ให้ทีมอ่านเอง |
| `cheatsheet.md` | สรุปย่อ 1 หน้า | ปริ้นติดข้างจอ |
| `training.md` | เอกสารฝึกอบรม | ใช้สอนคนในทีม |

---

## การทำงานเบื้องหลัง (Pipeline 5 ขั้นตอน)

### Step 1: Extract — ดึงข้อมูลจาก YouTube

Script `extract.sh` ทำงาน 4 ขั้นตอนย่อย:

**1.1 ดึง Metadata**
```
yt-dlp --dump-json → metadata.json
```
ได้: title, channel, duration, views, tags, upload date

**1.2 ดึง Transcript (Subtitle)**
```
yt-dlp --write-auto-sub → VTT files → clean text
```
- พยายามดึงภาษาไทยก่อน → อังกฤษ → ภาษาอื่น
- แปลง VTT format เป็น plain text
- ตัดข้อความซ้ำ (YouTube auto-subtitle มักซ้ำมาก)

**1.3 ดาวน์โหลด Video + ตัด Frames**
```
yt-dlp → video.mp4 (720p max)
ffmpeg scene detection → scene_XXXX.jpg
```

กลยุทธ์ scene detection:
- ใช้ `ffmpeg select='gt(scene,0.3)'` — จับเฉพาะตอนหน้าจอเปลี่ยนจริงๆ
- ถ้าได้ < 10 frames → เสริมด้วย interval (ทุก 15 วินาที, หรือ 30 วินาทีสำหรับ video > 30 นาที)
- ถ้าได้ > 80 frames → เลือก 80 frames กระจายสม่ำเสมอ
- เป้าหมาย: **20-80 frames** ต่อ video
- ลบ video.mp4 หลัง extract เสร็จ (ประหยัดพื้นที่)

**1.4 สร้าง Frame Index**
```
frame_index.json — รายชื่อ + ขนาดไฟล์ของทุก frame
```

---

### Step 2: Read Transcript — อ่านและสรุป Transcript

Claude อ่าน transcript ทั้งหมดแล้วสรุป:
1. ระบุ **หัวข้อหลัก (topics)** ที่สอนใน video
2. จัดลำดับขั้นตอนตาม timeline
3. จับ **keywords/terms** เฉพาะทาง

---

### Step 3: Visual Analysis — วิเคราะห์ภาพ (หัวใจสำคัญ)

จุดที่ทำให้ tool นี้ต่างจากแค่อ่าน transcript:

**Claude ดูทุก frame ด้วย multimodal vision:**
- อ่านทีละ **10 ภาพ** (ป้องกัน context overflow)
- จด note สำคัญจากแต่ละ batch ก่อนอ่าน batch ถัดไป
- เชื่อม visual + transcript เข้าด้วยกัน

**สิ่งที่วิเคราะห์จากแต่ละภาพ:**

| หัวข้อ | ดูอะไร |
|--------|-------|
| UI Elements | ปุ่มไหน, เมนูไหน, อยู่ตรงไหนของหน้าจอ |
| Screen Flow | ลำดับการ navigate (จากหน้าไหนไปหน้าไหน) |
| Data Entry | กรอกข้อมูลอะไร, field ไหน, format อะไร |
| Settings/Config | ตั้งค่าอะไร, ค่า default เท่าไหร่ |
| Error/Warning | มี error อะไรที่ต้องระวัง |
| Tips/Tricks | เทคนิคพิเศษที่ผู้สอนแสดงให้ดู |

**ผลลัพธ์:** ไฟล์ `analysis.md` ที่มี:
- Key Concepts Learned
- Step-by-Step Procedure พร้อมระบุ frame ที่เกี่ยวข้อง
- Settings & Configuration table
- Common Mistakes & Solutions
- Pro Tips from Instructor

---

### Step 4: Generate SKILL.md

ใช้ `analysis.md` + `skill-template.md` → สร้าง SKILL.md ที่มีโครงสร้างครบ:

1. **Frontmatter** — name, description, trigger keywords
2. **Quick Reference** — ตาราง commands
3. **Knowledge Base** — core concepts + key terms
4. **Step-by-Step Workflows** — ขั้นตอนละเอียด พร้อมระบุ: ไปที่เมนูไหน, กดปุ่มไหน, กรอกอะไร
5. **UI Navigation Guide** — menu structure + common paths
6. **Settings & Configuration** — recommended values + เหตุผล
7. **Common Issues & Solutions** — ปัญหาที่พบบ่อยและวิธีแก้
8. **Pro Tips** — เทคนิคจากผู้สอน
9. **Source Attribution** — credit video ต้นทาง

---

### Step 5: Install Skill (Optional)

Claude จะถามว่าต้องการติดตั้ง skill เลยหรือไม่:

```bash
# Copy ไปยัง skills directory
cp output/<video-id>/SKILL.md ~/.claude/skills/<skill-name>/SKILL.md
```

หลังติดตั้ง สามารถเรียกใช้ skill ใหม่ได้ทันทีจาก Claude Code

---

## โครงสร้างโปรเจกต์

```
youtube-skill-extractor/
├── README.md                   ← คู่มือการใช้งาน (ไฟล์นี้)
├── SKILL.md                    ← Orchestrator — Claude อ่านไฟล์นี้เพื่อรู้วิธีทำงาน
├── .gitignore                  ← ไม่ track output/ ใน git
├── scripts/
│   └── extract.sh              ← Shell script สำหรับดึงข้อมูลจาก YouTube
├── templates/
│   └── skill-template.md       ← Template สำหรับสร้าง SKILL.md
└── output/                     ← ข้อมูลที่ดึงมา (สร้างอัตโนมัติ)
    └── <video-id>/             ← folder ต่อ video
```

---

## โครงสร้าง Output ต่อ Video

หลังจากรัน extract จะได้ folder แบบนี้:

```
output/<video-id>/
├── metadata.json               ← ข้อมูล video (title, channel, duration, views)
├── transcript_th.txt           ← Transcript ภาษาไทย (ถ้ามี)
├── transcript_en.txt           ← Transcript ภาษาอังกฤษ (ถ้ามี)
├── subs.th.vtt                 ← ไฟล์ subtitle ต้นฉบับ (VTT format)
├── subs.en.vtt                 ← ไฟล์ subtitle ต้นฉบับ
├── frames/                     ← Screenshots จาก scene detection
│   ├── scene_0001.jpg          ← Frame จาก scene change
│   ├── scene_0002.jpg
│   ├── ...
│   ├── interval_0001.jpg       ← Frame จาก interval (ถ้า scene change น้อยเกินไป)
│   └── scene_timestamps.txt    ← Timestamps ของแต่ละ scene change
├── frame_index.json            ← Index ของทุก frame (ชื่อไฟล์ + ขนาด)
├── analysis.md                 ← ผลวิเคราะห์จาก Claude (สร้างใน Step 3)
└── SKILL.md                    ← Skill ที่ generate ได้ (สร้างใน Step 4)
```

### ตัวอย่าง metadata.json

```json
{
  "title": "สอนใช้ FlowAccount ออกใบกำกับภาษี",
  "channel": "FlowAccount Official",
  "duration": 845,
  "duration_string": "14:05",
  "description": "วิธีออกใบกำกับภาษีใน FlowAccount...",
  "view_count": 15234,
  "upload_date": "20240315",
  "language": "th",
  "tags": ["flowaccount", "ใบกำกับภาษี", "บัญชี"],
  "categories": ["Education"]
}
```

---

## ระบบอัจฉริยะ (Smart Features)

### ตรวจจับภาษาอัตโนมัติ

- Video ภาษาไทย → SKILL.md ภาษาไทย
- Video ภาษาอังกฤษ → SKILL.md ภาษาอังกฤษ
- Video ผสม → ใช้ภาษาหลักของ video
- Transcript ดึงได้ทั้งไทยและอังกฤษพร้อมกัน (ถ้ามี)

### จัดหมวดหมู่ Skill อัตโนมัติ

วิเคราะห์ content แล้วจัด category:

| Category | ตัวอย่าง Keywords ที่จับ |
|----------|------------------------|
| `accounting` | บัญชี, FlowAccount, ภาษี, VAT, invoice |
| `programming` | code, API, git, deploy, database |
| `design` | Figma, Canva, UI, UX, ออกแบบ |
| `marketing` | SEO, ads, social media, content |
| `business` | ธุรกิจ, กลยุทธ์, management, startup |
| `it-ops` | server, cloud, AWS, Docker, network |
| `data` | Excel, SQL, dashboard, analytics |

### วิเคราะห์ Frame ตามบริบท

Claude ปรับวิธีวิเคราะห์ตามประเภท video:

| ประเภท Content | วิธีวิเคราะห์ |
|---------------|-------------|
| **Software Tutorial** | จับ UI elements, menu paths, button locations |
| **Presentation/Slide** | จับ text content, diagrams, key points |
| **Whiteboard/Drawing** | จับ diagrams, flowcharts, concepts |
| **Terminal/Code** | จับ commands, code snippets, output |
| **Talking Head** | จับ key points จาก transcript (ไม่เน้นภาพ) |

### Scene Detection อัจฉริยะ

ไม่ได้ตัด frame ทุก X วินาทีแบบ dump — ใช้ scene detection จาก ffmpeg:

```
ffmpeg -vf "select='gt(scene,0.3)'" → จับเฉพาะตอนหน้าจอเปลี่ยน
```

- ได้ frame ตอนกดเมนู, เปลี่ยนหน้า, เปิด dialog
- ไม่ได้ frame ซ้ำๆ ตอนผู้สอนพูดหน้าเดิม
- ถ้า video มีการเปลี่ยนหน้าจอน้อย (เช่น talking head) → เสริมด้วย interval ทุก 15 วินาที
- Video ยาว > 30 นาที → interval 30 วินาที
- จำกัดสูงสุด 80 frames (เลือกกระจายสม่ำเสมอ)

---

## มาตรฐานคุณภาพ

SKILL.md ที่ generate ออกมาต้องผ่านเกณฑ์:

| เกณฑ์ | คำอธิบาย |
|-------|---------|
| **Actionable** | ทุกขั้นตอนต้องทำตามได้จริง ไม่ใช่แค่ทฤษฎี |
| **Complete** | ครบทุก step ไม่ขาดตอน ไม่ข้ามขั้นตอน |
| **Visual-Aware** | ระบุตำแหน่ง UI เสมอ — เมนูไหน, ปุ่มไหน, อยู่ตรงไหน |
| **Error-Handled** | มี common issues + solutions สำหรับปัญหาที่พบบ่อย |
| **Attributed** | Credit ผู้สอนต้นทางเสมอ พร้อม link กลับ video |

### Tone & Style

- เขียนเหมือน **คนสอนงานจริง** ไม่ใช่คู่มือแห้งๆ
- ใช้ภาษาเดียวกับผู้สอนใน video
- เน้น "ทำยังไง" ไม่ใช่ "ทฤษฎี"
- ระบุ **ตำแหน่งบนหน้าจอ** เสมอ (ซ้ายบน, เมนูที่ 3, แถบด้านข้าง)

---

## ความปลอดภัยและจริยธรรม

| หัวข้อ | นโยบาย |
|--------|--------|
| **Attribution** | ต้อง credit ผู้สอนต้นทางเสมอ พร้อม link ไป video |
| **Copyright** | Skill ที่สร้างเป็น "knowledge extraction" ไม่ใช่ copy content ทั้งหมด |
| **Video files** | ลบ video.mp4 อัตโนมัติหลัง extract frames เสร็จ (ประหยัดพื้นที่) |
| **Privacy** | ไม่เก็บข้อมูลส่วนตัวจาก video |
| **URL Validation** | รับเฉพาะ YouTube URL เท่านั้น (youtube.com, youtu.be, m.youtube.com) |

### รูปแบบ Attribution ใน SKILL.md ที่ generate

```markdown
## Source Attribution
| Field | Value |
|-------|-------|
| Video | [ชื่อ Video](https://youtube.com/watch?v=xxxxx) |
| Channel | ชื่อ Channel |
| Instructor | ชื่อผู้สอน |
| Extracted | วันที่สกัด |

> ความรู้ในเอกสารนี้สกัดจาก video ต้นทาง สงวนสิทธิ์ตามกฎหมายลิขสิทธิ์
```

---

## แก้ไขปัญหา (Troubleshooting)

### ปัญหาที่พบบ่อย

| ปัญหา | สาเหตุ | วิธีแก้ |
|-------|--------|--------|
| `Required command 'yt-dlp' not found` | ยังไม่ได้ติดตั้ง yt-dlp | `brew install yt-dlp` |
| `Required command 'ffmpeg' not found` | ยังไม่ได้ติดตั้ง ffmpeg | `brew install ffmpeg` |
| `URL does not appear to be a YouTube URL` | URL ไม่ใช่ YouTube | ตรวจสอบว่าเป็น youtube.com หรือ youtu.be |
| `Cannot extract video ID from URL` | URL format ไม่รู้จัก | ใช้ format: `youtube.com/watch?v=xxxxx` |
| `Failed to create metadata.json` | Video อาจถูกลบ, เป็น private, หรือ age-restricted | ตรวจสอบว่าเปิด video ใน browser ได้ |
| `Failed to download video` | Video อาจถูก block ในประเทศ | ลอง VPN หรือตรวจสอบ yt-dlp version |
| `No subtitles available` | Video ไม่มี subtitle/auto-caption | จะใช้ visual analysis อย่างเดียว (ผลลัพธ์อาจไม่ดีเท่า) |
| Scene detection ได้ frames น้อยมาก | Video เป็น talking head ไม่ค่อยเปลี่ยนฉาก | ระบบจะเสริม interval frames อัตโนมัติ |
| Scene detection ได้ frames มากเกินไป | Video มีการตัดฉากบ่อย | ระบบจะ cap ที่ 80 frames อัตโนมัติ |

### อัพเดท yt-dlp

yt-dlp ต้องอัพเดทบ่อยเพราะ YouTube เปลี่ยน API:

```bash
# อัพเดทผ่าน Homebrew
brew upgrade yt-dlp

# หรือผ่าน pip
pip install -U yt-dlp
```

### ตรวจสอบ Video ก่อน Extract

```bash
# ดู metadata โดยไม่ต้องดาวน์โหลด
yt-dlp --dump-json --no-download "https://www.youtube.com/watch?v=xxxxx" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'Title: {d[\"title\"]}')
print(f'Duration: {d[\"duration\"]}s')
print(f'Subtitles: {list(d.get(\"subtitles\", {}).keys())}')
print(f'Auto-captions: {list(d.get(\"automatic_captions\", {}).keys())[:5]}')
"
```

---

## ตัวอย่างการใช้งานจริง

### ตัวอย่าง 1: สกัดความรู้จาก Tutorial สอนใช้ซอฟต์แวร์

```
/youtube-skill-extractor https://www.youtube.com/watch?v=abc123xyz99
```

ผลลัพธ์: SKILL.md ที่มี step-by-step ละเอียดว่าต้องไปเมนูไหน กดปุ่มไหน กรอกอะไร

### ตัวอย่าง 2: รวมความรู้จาก Playlist

```
/youtube-skill-extractor batch \
  https://www.youtube.com/watch?v=video1 \
  https://www.youtube.com/watch?v=video2 \
  https://www.youtube.com/watch?v=video3
```

ผลลัพธ์: 1 SKILL.md ที่รวมความรู้จากทุก video ตัด content ซ้ำแล้ว

### ตัวอย่าง 3: สร้างเอกสารฝึกอบรมจาก Video

```
/youtube-skill-extractor https://www.youtube.com/watch?v=abc123xyz99 --format training
```

ผลลัพธ์: `training.md` ที่เหมาะสำหรับแจกทีม

### ตัวอย่าง 4: Extract ก่อน แล้วค่อยวิเคราะห์ทีหลัง

```
# ขั้นที่ 1: ดึงข้อมูล
/youtube-skill-extractor extract https://www.youtube.com/watch?v=abc123xyz99

# ขั้นที่ 2: ดู frames ก่อน
# (เปิดดูไฟล์ใน output/<video-id>/frames/)

# ขั้นที่ 3: วิเคราะห์
/youtube-skill-extractor analyze abc123xyz99

# ขั้นที่ 4: สร้าง SKILL.md
/youtube-skill-extractor generate abc123xyz99
```

---

## รูปแบบ URL ที่รองรับ

| รูปแบบ | ตัวอย่าง |
|--------|---------|
| Standard | `https://www.youtube.com/watch?v=dQw4w9WgXcQ` |
| Short | `https://youtu.be/dQw4w9WgXcQ` |
| Mobile | `https://m.youtube.com/watch?v=dQw4w9WgXcQ` |
| Shorts | `https://www.youtube.com/shorts/dQw4w9WgXcQ` |
| With params | `https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=120` |

---

## License

ความรู้ที่สกัดจาก YouTube video เป็นลิขสิทธิ์ของผู้สร้าง video ต้นทาง
Tool นี้ใช้เพื่อ "knowledge extraction" สำหรับการศึกษาและการทำงานเท่านั้น
