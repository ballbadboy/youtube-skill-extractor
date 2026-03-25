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
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent, WebFetch, WebSearch
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

---

## Architecture

```
youtube-skill-extractor/
├── SKILL.md                    ← Orchestrator (this file)
├── scripts/
│   └── extract.sh              ← yt-dlp + ffmpeg extraction
├── templates/
│   └── skill-template.md       ← Template สำหรับ generate SKILL.md
└── output/                     ← Extracted data per video
    └── <video-id>/
        ├── metadata.json       ← Title, channel, duration
        ├── transcript_th.txt   ← Thai transcript
        ├── transcript_en.txt   ← English transcript
        ├── frames/             ← Scene-change screenshots
        │   ├── scene_0001.jpg
        │   ├── scene_0002.jpg
        │   └── ...
        ├── frame_index.json    ← Frame metadata
        ├── analysis.md         ← Claude's visual + text analysis
        └── SKILL.md            ← Generated skill (output)
```

**Dependencies:** `yt-dlp`, `ffmpeg` (via Homebrew)

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

นอกจาก SKILL.md ยังสร้างได้:

| Format | Use Case |
|--------|----------|
| `SKILL.md` | ใช้ใน Claude Code (default) |
| `guide.md` | คู่มือ step-by-step แบบ standalone |
| `cheatsheet.md` | สรุปย่อ 1 หน้า |
| `training.md` | เอกสารฝึกอบรมสำหรับทีม |

เพิ่ม `--format <type>` เพื่อเลือก:
```
/youtube-skill-extractor <url> --format training
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

## Auto-Evolution Protocol (MANDATORY)

**This skill participates in the agency-wide self-learning system.**
**Follow `~/.claude/skills/_evolution/auto-learn.md` for the full protocol.**

### BEFORE starting work:
1. Read `~/.claude/skills/_evolution/memory.md` — apply Critical Rules
2. Read `~/.claude/skills/_evolution/patterns/what-works.md` — use proven patterns
3. Read `~/.claude/skills/_evolution/patterns/anti-patterns.md` — avoid known failures

### AFTER completing work:
1. Update `~/.claude/skills/_evolution/engagement-counter.md` — increment counter
2. If bugs/lessons/patterns discovered → append to appropriate file
3. If counter hits 10-interval → auto-generate mini-retrospective
4. If counter hits 30-interval → propose self-improvement to user
