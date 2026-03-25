---
name: youtube-skill-extractor
description: >
  สกัดความรู้จาก YouTube video → สร้าง Claude Code SKILL.md อัตโนมัติ
  ดึง transcript + ตัด frames (scene detection) → Claude วิเคราะห์ทั้ง text + ภาพ
  → สรุปเป็น step-by-step guide → generate SKILL.md พร้อมใช้งานหรือขายได้
  ใช้เมื่อผู้ใช้พิมพ์: youtube, yt, เรียนรู้จาก youtube, สกัดความรู้, extract skill,
  learn from youtube, video to skill, ดู youtube, สอนจาก youtube, tutorial,
  สร้าง skill จาก video, youtube skill, yt skill, ดึงความรู้จาก video,
  แปลง video เป็น skill
user-invocable: true
argument-hint: "<youtube-url> or playlist <url> or list or validate <video-id>"
---

# YouTube Skill Extractor

> สกัดความรู้จากคนจริงที่สอนบน YouTube → แปลงเป็น Claude Code SKILL.md
> ไม่ใช่แค่อ่าน transcript — **ดูภาพจริง** ว่ากดปุ่มไหน หน้าจอเป็นยังไง

---

## Quick Reference

| Command | What It Does |
|---------|-------------|
| `/youtube-skill-extractor <url>` | สกัดความรู้จาก video → สร้าง SKILL.md |
| `/youtube-skill-extractor extract <url>` | ดึง transcript + frames อย่างเดียว |
| `/youtube-skill-extractor analyze <video-id>` | วิเคราะห์ frames + transcript ที่ดึงไว้แล้ว |
| `/youtube-skill-extractor generate <video-id>` | Generate SKILL.md จากผลวิเคราะห์ |
| `/youtube-skill-extractor batch <url1> <url2>...` | สกัดจากหลาย video → รวมเป็น 1 skill |
| `/youtube-skill-extractor list` | ดู video ที่เคยสกัดแล้ว |
| `/youtube-skill-extractor <url> --force` | สกัดใหม่แม้เคยทำแล้ว (force re-extract) |
| `/youtube-skill-extractor playlist <url>` | สกัดทุก video จาก YouTube playlist |
| `/youtube-skill-extractor validate <video-id>` | ตรวจสอบคุณภาพ SKILL.md |
| `/youtube-skill-extractor <url> --format guide` | สร้าง standalone guide แทน SKILL.md |
| `/youtube-skill-extractor <url> --format cheatsheet` | สร้างสรุปย่อ 1 หน้า |
| `/youtube-skill-extractor <url> --format training` | สร้างเอกสารฝึกอบรม |
| `/youtube-skill-extractor export <video-id>` | Export skill เป็น .zip แชร์ได้ |
| `/youtube-skill-extractor import <file.zip>` | Import skill จาก .zip package |
| `/youtube-skill-extractor check-update <video-id>` | ตรวจว่า video มีการเปลี่ยนแปลงมั้ย |
| `/youtube-skill-extractor check-update --all` | ตรวจทุก video ที่เคย extract |

---

## Architecture

```
youtube-skill-extractor/
├── SKILL.md                    ← Orchestrator (this file)
├── scripts/
│   ├── extract.sh              ← yt-dlp + ffmpeg extraction
│   ├── batch-extract.sh        ← Batch extraction (multiple URLs)
│   ├── playlist-extract.sh     ← Playlist extraction
│   ├── list-videos.sh          ← List extracted videos
│   ├── validate-skill.sh       ← Quality validation
│   ├── export-skill.sh         ← Export skill เป็น .zip package
│   ├── import-skill.sh         ← Import skill จาก .zip package
│   └── check-update.sh         ← ตรวจสอบ video updates
├── templates/
│   ├── skill-template.md       ← Template สำหรับ SKILL.md
│   ├── guide-template.md       ← Template สำหรับ standalone guide
│   ├── cheatsheet-template.md  ← Template สำหรับ cheat sheet
│   └── training-template.md    ← Template สำหรับเอกสารฝึกอบรม
└── output/                     ← Extracted data per video
    └── <video-id>/
        ├── metadata.json       ← Title, channel, duration
        ├── transcript_th.txt   ← Thai transcript
        ├── transcript_en.txt   ← English transcript
        ├── transcript_timestamps.json ← Timestamp mapping for transcript
        ├── frames/             ← Scene-change screenshots
        │   ├── scene_0001.jpg
        │   ├── scene_0002.jpg
        │   └── ...
        ├── frame_index.json    ← Frame metadata
        ├── analysis.md         ← Claude's visual + text analysis
        └── SKILL.md            ← Generated skill (output)
```

**Dependencies:** `yt-dlp`, `ffmpeg`, `python3` (via Homebrew)

---

## Workflow

### Full Pipeline: `/youtube-skill-extractor <url>`

ทำทุกอย่างอัตโนมัติ 5 ขั้นตอน:

#### Step 1: Extract (ดึงข้อมูลจาก YouTube)

```bash
# Run extraction script
~/.claude/skills/youtube-skill-extractor/scripts/extract.sh "<youtube-url>"
```

ผลลัพธ์:
- `metadata.json` — ข้อมูล video (title, channel, duration)
- `transcript_*.txt` — Transcript ภาษาไทย/อังกฤษ
- `frames/*.jpg` — Screenshots จาก scene detection
- `frame_index.json` — Index ของทุก frame

**กฎ scene detection:**
- ใช้ ffmpeg `select='gt(scene,0.3)'` — จับเฉพาะตอนหน้าจอเปลี่ยน
- ถ้าได้ < 10 frames → เสริมด้วย interval (ทุก 15 วินาที)
- ถ้าได้ > 80 frames → เลือก 80 frames กระจายสม่ำเสมอ
- เป้าหมาย: 20-80 frames ต่อ video

#### Step 2: Read Transcript

อ่าน transcript ทั้งหมด:
```
Read: output/<video-id>/transcript_th.txt
Read: output/<video-id>/transcript_en.txt
```

สรุป transcript เป็นหัวข้อหลัก:
1. ระบุ **หัวข้อ/topics** ที่สอนในวิดีโอ
2. จัดลำดับขั้นตอนตาม timeline
3. จับ **keywords/terms** เฉพาะทาง

#### Step 3: Visual Analysis (หัวใจสำคัญ)

**อ่านทุก frame ด้วย Read tool** — Claude จะ "ดู" ภาพจริง:

```
Read: output/<video-id>/frames/scene_0001.jpg
Read: output/<video-id>/frames/scene_0002.jpg
...
```

**วิเคราะห์แต่ละภาพ:**
1. **UI Elements** — ปุ่มไหน, เมนูไหน, อยู่ตรงไหนของหน้าจอ
2. **Screen Flow** — ลำดับการนำทาง (navigate ยังไง)
3. **Data Entry** — กรอกข้อมูลอะไร, field ไหน, format อะไร
4. **Settings/Config** — ตั้งค่าอะไรบ้าง, ค่าเริ่มต้นเท่าไหร่
5. **Error/Warning** — มี error อะไรที่ต้องระวัง
6. **Tips/Tricks** — เทคนิคพิเศษที่ผู้สอนแสดง

**กฎ:**
- อ่าน frames ทีละ 10 ภาพ (ไม่อ่านทั้งหมดพร้อมกัน ป้องกัน context overflow)
- จด note สำคัญจากแต่ละ batch ก่อนอ่าน batch ถัดไป
- เชื่อม visual + transcript เข้าด้วยกัน

**เขียนผลวิเคราะห์:**
```
Write: output/<video-id>/analysis.md
```

Format ของ analysis.md:
```markdown
# Video Analysis: <title>
**Channel:** <channel>
**Duration:** <duration>
**Topic:** <main topic>

## Key Concepts Learned
1. ...
2. ...

## Step-by-Step Procedure
### Step 1: <action>
- **Visual:** [อธิบายสิ่งที่เห็นในภาพ]
- **Location:** [ตำแหน่งบน UI — เมนูไหน, ปุ่มไหน]
- **Action:** [สิ่งที่ต้องทำ]
- **Note:** [ข้อควรระวัง]
- **Frame:** scene_0003.jpg

### Step 2: <action>
...

## Settings & Configuration
| Setting | Value | Why |
|---------|-------|-----|
| ... | ... | ... |

## Common Mistakes & Solutions
| Mistake | Solution |
|---------|----------|
| ... | ... |

## Pro Tips from Instructor
1. ...
```

#### Step 4: Generate SKILL.md

ใช้ analysis.md + template → สร้าง SKILL.md:

```
Read: templates/skill-template.md
Read: output/<video-id>/analysis.md
Write: output/<video-id>/SKILL.md
```

**SKILL.md ต้องมี:**
1. **Frontmatter** — name, description, trigger keywords
2. **Quick Reference** — commands table
3. **Knowledge Base** — ความรู้ทั้งหมดที่สกัดได้
4. **Step-by-Step Workflows** — ขั้นตอนการทำงานจริง
5. **UI Navigation Guide** — ไปที่เมนูไหน กดปุ่มไหน
6. **Common Issues** — ปัญหาที่พบบ่อยและวิธีแก้
7. **Pro Tips** — เทคนิคจากผู้สอน
8. **Source Attribution** — credit video ต้นทาง

#### Step 5: Install Skill (Optional)

ถาม user ว่าจะติดตั้ง skill เลยมั้ย:
```bash
# Copy to skills directory
cp output/<video-id>/SKILL.md ~/.claude/skills/<skill-name>/SKILL.md
```

---

## Batch Mode: `/youtube-skill-extractor batch`

สกัดจากหลาย video แล้วรวมเป็น 1 skill:

```
/youtube-skill-extractor batch <url1> <url2> <url3>
```

**Workflow:**
1. Extract ทุก video (ใช้ Agent tool รัน parallel)
2. วิเคราะห์แต่ละ video
3. **Merge knowledge** — รวมความรู้จากทุก video:
   - ตัด duplicate content
   - เรียงลำดับจากง่าย → ยาก
   - รวม tips/tricks จากทุกคน
   - Note ความแตกต่างระหว่างผู้สอน
4. Generate 1 comprehensive SKILL.md

---

## Smart Features

### Language Detection
- ตรวจสอบภาษาของ transcript อัตโนมัติ
- video ภาษาไทย → SKILL.md ภาษาไทย
- video ภาษาอังกฤษ → SKILL.md ภาษาอังกฤษ
- ผสม → ใช้ภาษาหลักของ video

### Skill Category Detection
วิเคราะห์ content แล้วจัด category อัตโนมัติ:

| Category | Keywords |
|----------|----------|
| `accounting` | บัญชี, FlowAccount, ภาษี, VAT, invoice |
| `programming` | code, API, git, deploy, database |
| `design` | Figma, Canva, UI, UX, ออกแบบ |
| `marketing` | SEO, ads, social media, content |
| `business` | ธุรกิจ, กลยุทธ์, management, startup |
| `it-ops` | server, cloud, AWS, Docker, network |
| `data` | Excel, SQL, dashboard, analytics |
| `other` | ไม่เข้า category ข้างบน |

### Context-Aware Frame Analysis
- **Software Tutorial:** จับ UI elements, menu paths, button locations
- **Presentation/Slide:** จับ text content, diagrams, key points
- **Whiteboard/Drawing:** จับ diagrams, flowcharts, concepts
- **Terminal/Code:** จับ commands, code snippets, output
- **Talking Head:** จับ key points จาก transcript (ไม่เน้นภาพ)

---

## Playlist Mode: `/youtube-skill-extractor playlist`

สกัดทุก video จาก YouTube playlist อัตโนมัติ:

```
/youtube-skill-extractor playlist https://www.youtube.com/playlist?list=PLxxxxx
```

**Workflow:**
1. ดึงรายชื่อ video ทั้งหมดจาก playlist ด้วย `yt-dlp --flat-playlist`
2. Extract ทุก video ตามลำดับ
3. ถ้า video ไหนเคย extract แล้ว จะข้ามอัตโนมัติ (ใช้ `--force` เพื่อบังคับ)
4. สรุปผลลัพธ์: สำเร็จกี่ video, ล้มเหลวกี่ video

**Tips:**
- ใช้ร่วมกับ batch mode ได้: extract playlist ก่อน แล้ว batch analyze ทีหลัง
- Playlist ขนาดใหญ่ (>20 video) อาจใช้เวลานาน

---

## Duplicate Detection & Resume

### Duplicate Detection
ถ้า video เคย extract แล้ว script จะแจ้งเตือนและข้าม:
```
⚠️ Video dQw4w9WgXcQ was already extracted.
   Output: ~/.claude/skills/youtube-skill-extractor/output/dQw4w9WgXcQ
   Use --force to re-extract.
```

ใช้ `--force` เพื่อบังคับ extract ใหม่:
```
/youtube-skill-extractor https://youtube.com/watch?v=xxxxx --force
```

### Resume (ทำต่อจากที่ค้าง)
ถ้า extract ค้างกลางทาง (เช่น internet หลุด) สามารถรันใหม่ได้:
- Script จะข้าม step ที่ทำเสร็จแล้ว (เช่น metadata, transcript)
- เริ่มต่อจาก step ที่ยังไม่เสร็จ
- ประหยัดเวลาไม่ต้องดาวน์โหลดซ้ำ

---

## Timestamp Mapping

นอกจาก transcript text แล้ว ยังสร้าง `transcript_timestamps.json` ที่เชื่อม text กับ timestamp:

```json
[
  {"start": 0.0, "end": 3.5, "text": "สวัสดีครับ วันนี้จะสอน..."},
  {"start": 3.5, "end": 7.2, "text": "เริ่มจากเปิดโปรแกรม..."}
]
```

**ประโยชน์:**
- Claude เชื่อม frame กับ transcript ได้แม่นยำขึ้น (รู้ว่า frame ที่ timestamp 5.0 ตรงกับคำพูดอะไร)
- สร้าง step-by-step ที่ sync กับ timeline จริง
- ช่วยในการ batch merge: ต่อ timeline จากหลาย video ได้

---

## Quality Validation: `/youtube-skill-extractor validate`

ตรวจสอบ SKILL.md ที่ generate แล้วว่าผ่านเกณฑ์:

```
/youtube-skill-extractor validate <video-id>
```

**เกณฑ์ที่ตรวจ:**

| หมวด | ตรวจอะไร |
|------|---------|
| Frontmatter | มี name, description |
| Required Sections | Quick Reference, Knowledge Base, Workflows, UI Nav, Issues, Tips, Attribution |
| Actionability | มี step-by-step, มี UI location references |
| Attribution | มี YouTube link, มี channel credit |
| Completeness | ความยาวเพียงพอ, มี tables |

ถ้าไม่ผ่าน Claude จะแก้ไข SKILL.md ให้อัตโนมัติ แล้วรัน validate อีกรอบ

---

## Skill Marketplace (Export/Import)

### Export Skill
สร้าง .zip package จาก skill ที่ generate แล้ว พร้อมแชร์หรือขาย:

```
/youtube-skill-extractor export <video-id>
```

**Options:**
- `--include-frames` — รวม screenshots ใน package ด้วย (ไฟล์ใหญ่ขึ้น)

**Package ประกอบด้วย:**
- `SKILL.md` — ไฟล์ skill หลัก
- `metadata.json` — ข้อมูล video ต้นทาง
- `analysis.md` — ผลวิเคราะห์
- `manifest.json` — ข้อมูล package (version, date, contents)
- `frames/` — screenshots (ถ้าใช้ `--include-frames`)

### Import Skill
นำเข้า skill จาก .zip package:

```
/youtube-skill-extractor import <file.skill.zip>
/youtube-skill-extractor import <file.skill.zip> --install   ← ติดตั้งเลย
```

ถ้าไม่ใส่ `--install` จะแสดงข้อมูล package ให้ดูก่อน

---

## Auto-Update Detection

ตรวจสอบว่า video ที่เคย extract มีการเปลี่ยนแปลงมั้ย:

```
/youtube-skill-extractor check-update <video-id>
/youtube-skill-extractor check-update --all
```

**ตรวจสอบอะไร:**
- Title เปลี่ยนมั้ย
- Duration เปลี่ยนมั้ย (อาจ re-upload)
- Views เพิ่มขึ้นเท่าไหร่

ถ้าพบการเปลี่ยนแปลง จะแนะนำให้ re-extract ด้วย `--force`

---

## Interactive Preview

ก่อนติดตั้ง skill Claude จะแสดง preview ให้ดู:

1. **สรุปสิ่งที่สกัดได้** — กี่ step, กี่ sections, กี่ tips
2. **ตัวอย่าง content** — แสดง 2-3 steps แรก
3. **Quality score** — ผล validate (pass/fail/warnings)
4. **ถามยืนยัน** — จะติดตั้งเลย, แก้ไขก่อน, หรือยกเลิก

Preview เปิดอัตโนมัติใน full pipeline (`/youtube-skill-extractor <url>`)
ข้าม preview ด้วย `--no-preview`

---

## OCR Enhancement

สำหรับ video ที่มี text บนหน้าจอ (UI, terminal, slide) Claude ใช้ multimodal vision อ่าน text จากภาพโดยตรง

**วิธีทำงาน:**
1. Claude อ่าน frame ด้วย vision → จับ text ที่เห็นในภาพ
2. เปรียบเทียบ text ในภาพกับ transcript → หา context
3. ระบุ text สำคัญลงใน analysis (เช่น menu labels, button text, error messages)

**ไม่ต้องติดตั้ง OCR library เพิ่ม** — ใช้ Claude vision ที่มีอยู่แล้ว

**เหมาะกับ:**
- Software tutorial ที่มี UI text
- Terminal/CLI ที่มี commands บนจอ
- Presentation ที่มี text content บน slides

---

## Audio Analysis (Fallback)

สำหรับ video ที่ไม่มี subtitle/auto-caption:

**กลยุทธ์:**
1. ลอง transcript ปกติก่อน (Thai → English → any language)
2. ถ้าไม่มี transcript → Claude วิเคราะห์จากภาพอย่างเดียว (visual-only mode)
3. Visual-only mode: เพิ่มจำนวน frames (interval ทุก 10 วินาที) เพื่อชดเชย

**Visual-Only Mode ทำอะไรต่าง:**
- ตัด frames ถี่ขึ้น (ทุก 10 วินาที แทน 15)
- เน้นวิเคราะห์ UI elements จากภาพ
- สร้าง SKILL.md จาก visual analysis เป็นหลัก
- Note ใน SKILL.md ว่า "สกัดจากภาพเท่านั้น ไม่มี transcript"

**ข้อจำกัด:**
- ผลลัพธ์อาจไม่ละเอียดเท่า video ที่มี transcript
- เหมาะกับ software tutorial มากกว่า talking head

---

## Quality Standards

SKILL.md ที่ generate ต้องผ่านเกณฑ์:

1. **Actionable** — ทุกขั้นตอนต้องทำตามได้จริง
2. **Complete** — ครบทุก step ไม่ขาดตอน
3. **Visual-Aware** — ระบุตำแหน่ง UI (เมนูไหน, ปุ่มไหน)
4. **Error-Handled** — มี common issues + solutions
5. **Attributed** — credit ผู้สอนต้นทางเสมอ

### Attribution Format
```markdown
---
## Source
- **Video:** [<title>](<youtube-url>)
- **Channel:** <channel-name>
- **Instructor:** <instructor-name>
- **Extracted:** <date>
- **Note:** ความรู้ในเอกสารนี้สกัดจาก video ต้นทาง สงวนสิทธิ์ตามกฎหมายลิขสิทธิ์
---
```

---

## Output Formats

เลือก format ด้วย `--format`:
```
/youtube-skill-extractor <url> --format <type>
```

| Format | Template | Use Case | ลักษณะ |
|--------|----------|----------|--------|
| `skill` | `skill-template.md` | ใช้ใน Claude Code (default) | Frontmatter + orchestration instructions |
| `guide` | `guide-template.md` | คู่มือ step-by-step แบบ standalone | อ่านเองได้ ไม่ต้องมี Claude |
| `cheatsheet` | `cheatsheet-template.md` | สรุปย่อ 1 หน้า | Dense, ปริ้นติดข้างจอ |
| `training` | `training-template.md` | เอกสารฝึกอบรมสำหรับทีม | มี exercises + assessment |

**ตัวอย่าง:**
```
/youtube-skill-extractor https://youtube.com/watch?v=xxxxx --format training
/youtube-skill-extractor https://youtube.com/watch?v=xxxxx --format cheatsheet
```

**Generate หลาย format จาก video เดียว:**
```
# Extract ครั้งเดียว แล้ว generate หลาย format
/youtube-skill-extractor extract https://youtube.com/watch?v=xxxxx
/youtube-skill-extractor generate xxxxx --format skill
/youtube-skill-extractor generate xxxxx --format guide
/youtube-skill-extractor generate xxxxx --format cheatsheet
```

---

## Tone & Style

- เขียน SKILL.md เหมือน **คนสอนงานจริง** ไม่ใช่คู่มือแห้งๆ
- ใช้ภาษาเดียวกับผู้สอนใน video
- เน้น "ทำยังไง" ไม่ใช่ "ทฤษฎี"
- ระบุ **ตำแหน่งบนหน้าจอ** เสมอ (ซ้ายบน, เมนูที่ 3, แถบด้านข้าง)

---

## Safety & Ethics

1. **Attribution:** ต้อง credit ผู้สอนต้นทางเสมอ
2. **Copyright:** skill ที่สร้างเป็น "knowledge extraction" ไม่ใช่ copy content
3. **Video files:** ลบ video.mp4 หลัง extract frames เสร็จ (ประหยัดพื้นที่)
4. **Privacy:** ไม่เก็บข้อมูลส่วนตัวจาก video

---

## Auto-Evolution Protocol (OPTIONAL)

**This skill participates in the agency-wide self-learning system.**
**If `~/.claude/skills/_evolution/auto-learn.md` exists, follow the full protocol.**

### BEFORE starting work (if evolution files exist):
1. Read `~/.claude/skills/_evolution/memory.md` — apply Critical Rules
2. Read `~/.claude/skills/_evolution/patterns/what-works.md` — use proven patterns
3. Read `~/.claude/skills/_evolution/patterns/anti-patterns.md` — avoid known failures

### AFTER completing work (if evolution files exist):
1. Update `~/.claude/skills/_evolution/engagement-counter.md` — increment counter
2. If bugs/lessons/patterns discovered → append to appropriate file
3. If counter hits 10-interval → auto-generate mini-retrospective
4. If counter hits 30-interval → propose self-improvement to user
