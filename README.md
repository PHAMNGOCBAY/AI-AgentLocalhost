# Ollama Smart Router v4

Hệ thống tự động chọn model Ollama tối ưu dựa trên nội dung prompt.

## Yêu cầu hệ thống

### Cấu hình tối thiểu

| Thành phần | Tối thiểu | Khuyến nghị | Máy tác giả |
|------------|-----------|-------------|-------------|
| **OS** | Windows 10 64-bit | Windows 11 | Windows 11 Home |
| **CPU** | 4 cores / 8 threads | 8 cores / 16 threads | Intel i7-11800H (8C/16T) |
| **RAM** | 16 GB | 32 GB | 32 GB DDR4 |
| **GPU** | NVIDIA 8 GB VRAM | NVIDIA 12-16 GB VRAM | RTX 3080 Laptop 16 GB |
| **CUDA** | CUDA 11.8+ | CUDA 12.x | CUDA 11.8 (Driver 610.88) |

> ⚠️ **GPU bắt buộc phải là NVIDIA** với driver CUDA. AMD/Intel GPU không hỗ trợ Ollama tốt.

### Dung lượng ổ cứng

| Thành phần | Dung lượng | Ghi chú |
|------------|-----------|---------|
| Python 3.12 | ~150 MB | Cài vào `AppData` |
| Ollama | ~500 MB | Cài vào `AppData` |
| **Ollama Models** | | Lưu tại `%USERPROFILE%\.ollama\models` |
| ├─ Gemma4 E4B | ~5.5 GB | Nhanh, task đơn giản |
| ├─ Gemma4 26B | ~16 GB | Task tổng quát phức tạp |
| ├─ Qwen 2.5 Coder 32B | ~20 GB | Code, debug, refactor |
| └─ Nemotron 3.5 Lightning | ~25 GB | Toán, logic, suy luận |
| **Tổng models (4)** | **~66.5 GB** | |
| Python Libraries | ~8 GB | Bao gồm PyTorch CUDA |
| IDE Extensions | ~500 MB | 35 extensions |
| **Tổng cộng** | **~76 GB** | Cần ít nhất **80 GB trống** |

### Gói cài theo nhu cầu

Nếu không đủ dung lượng hoặc VRAM, chọn gói phù hợp:

| Gói | Models | VRAM cần | Ổ cứng | Phù hợp |
|-----|--------|----------|--------|---------|
| 🟢 **Lite** | Gemma4 E4B | 10 GB | ~15 GB | GPU 8 GB, laptop phổ thông |
| 🔵 **Standard** | E4B + Qwen Coder 32B | 16 GB | ~35 GB | GPU 12-16 GB, lập trình viên |
| 🟣 **Full** | Cả 4 models | 16+ GB | ~76 GB | GPU 16+ GB, kỹ sư đa ngành |

> 💡 **Lưu ý**: Ollama tự động swap model in/out khỏi GPU. Không cần VRAM chứa tất cả cùng lúc — chỉ cần đủ cho model lớn nhất đang dùng (Nemotron ~25 GB sẽ dùng cả RAM nếu VRAM không đủ).

---

## Models

| Model | Task Type | Params | VRAM | Context |
|-------|-----------|--------|------|---------|
| **Gemma4 E4B** | `quick` | 8B | 9.6 GB | 131K |
| **Gemma4 26B** | `general` | 25.8B | 17 GB | 262K |
| **Qwen 2.5 Coder 32B** | `code` | 32B | 20 GB | 128K |
| **Nemotron 3.5 Lightning** | `reasoning` | 42B | 25 GB | 128K |

---

## Cài đặt

### Cách 1: Chạy installer (khuyến khích)

```
1. Mở folder ollama-smart-router
2. Double-click install.bat
3. Chọn gói models + thư viện theo nhu cầu
4. Restart Antigravity IDE
```

Installer tự động: Python → Ollama → MCP → Models → Python Libs → Extensions.

### Cách 2: Cài thủ công

```powershell
# 1. Copy MCP server
copy ollama_mcp.py  %USERPROFILE%\.gemini\antigravity\ollama_mcp.py

# 2. Copy skills
copy skills\ollama-models\SKILL.md  %USERPROFILE%\.gemini\config\skills\ollama-models\SKILL.md
copy skills\ollama-mcp-troubleshooting\SKILL.md  %USERPROFILE%\.gemini\config\skills\ollama-mcp-troubleshooting\SKILL.md

# 3. Thêm vào mcp_config.json (xem mcp_config_sample.json)

# 4. Pull models (chọn theo nhu cầu)
ollama pull gemma4:e4b              #  5.5 GB
ollama pull gemma4:26b              # 16   GB
ollama pull qwen2.5-coder:32b      # 20   GB
ollama pull nemotron-3.5-lightning  # 25   GB

# 5. Cài Python libs
pip install -r requirements.txt
```

---

## Cách dùng

Viết prompt bình thường — agent tự chọn model:

```
"Viết hàm Python sort array"         → Qwen Coder    (code)
"Tính sức chịu tải cọc D1000"        → Nemotron      (reasoning)
"Tóm tắt báo cáo địa chất"          → Gemma 26B     (general)
"SPT là gì?"                        → Gemma E4B     (quick)
```

Override thủ công: thêm `@gemma`, `@qwen`, hoặc `@nemotron` trước prompt.

---

## Cấu trúc folder

```
ollama-smart-router/
├── README.md                 ← File này
├── install.bat               ← Installer tự động (8 bước)
├── ollama_mcp.py             ← MCP server Smart Router v4
├── requirements.txt          ← Python dependencies (10 nhóm)
├── extensions.txt            ← IDE extensions (35 cái)
├── mcp_config_sample.json    ← Config mẫu
└── skills/
    ├── ollama-models/
    │   └── SKILL.md          ← Smart Router routing rules
    └── ollama-mcp-troubleshooting/
        └── SKILL.md          ← Hướng dẫn sửa lỗi
```

---

## Yêu cầu phần mềm

| Phần mềm | Phiên bản | Installer tự cài? |
|-----------|-----------|-------------------|
| [Python](https://python.org) | 3.10+ | ✅ |
| [Ollama](https://ollama.com) | Latest | ✅ |
| [Antigravity IDE](https://cloud.google.com/antigravity) | 2.5+ | ❌ (cài trước) |
| NVIDIA Driver | 525+ (CUDA 11.8) | ❌ (cài trước) |
