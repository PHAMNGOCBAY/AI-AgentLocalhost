---
name: ollama-mcp-troubleshooting
description: Chẩn đoán và sửa lỗi Ollama MCP Server (context deadline exceeded, model not found, encoding, missing tools)
---

# Sửa lỗi Ollama MCP Server

Skill này hướng dẫn chẩn đoán và khắc phục các lỗi thường gặp khi kết nối Ollama MCP Server với Antigravity IDE.

## Thông tin cấu hình

- **MCP Config**: `C:\Users\bayng\.gemini\config\mcp_config.json`
- **MCP Script**: `C:\Users\bayng\.gemini\antigravity\ollama_mcp.py`
- **Python**: `C:\Users\bayng\AppData\Local\Programs\Python\Python312\python.exe`
- **Ollama API**: `http://localhost:11434`

## Quy trình chẩn đoán

### Bước 1: Kiểm tra Ollama đang chạy

```powershell
ollama list
```

Nếu không có output hoặc lỗi → Ollama chưa khởi động. Chạy `ollama serve` hoặc mở Ollama app.

### Bước 2: Kiểm tra model đã tải

```powershell
ollama list
```

So sánh tên model trong output với tên khai báo trong `ollama_mcp.py` (biến `MODELS`). Tên phải khớp chính xác, bao gồm cả tag (ví dụ: `gemma4:26b` chứ không phải `gemma`).

### Bước 3: Test handshake MCP

```powershell
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | python "C:\Users\bayng\.gemini\antigravity\ollama_mcp.py"
```

Phải trả về JSON response với `protocolVersion` và `serverInfo`. Nếu không → script bị lỗi cú pháp hoặc encoding.

### Bước 4: Test đầy đủ luồng MCP

```powershell
@('{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}', '{"jsonrpc":"2.0","method":"notifications/initialized"}', '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}') -join "`n" | python "C:\Users\bayng\.gemini\antigravity\ollama_mcp.py"
```

Phải trả về 2 dòng JSON: initialize response + tools list.

---

## Lỗi thường gặp và cách sửa

### 1. "Error: context deadline exceeded"

**Nguyên nhân**: Script MCP không phản hồi đúng luồng handshake.

**Kiểm tra**: MCP client gửi 3 bước:
1. `initialize` → script phải trả JSON response
2. `notifications/initialized` → script phải **bỏ qua** (không trả response)
3. `tools/list` → script phải trả danh sách tools

**Sửa**: Đảm bảo script có handler cho `notifications/initialized`:

```python
if method == "notifications/initialized":
    continue  # Bỏ qua, KHÔNG trả response
```

> **QUAN TRỌNG**: `notifications/initialized` là notification (không có `id`), script KHÔNG ĐƯỢC gửi response. Nếu gửi response hoặc crash khi gặp method này → timeout → "context deadline exceeded".

### 2. Model không tìm thấy

**Nguyên nhân**: Tên model trong script không khớp với tên trong `ollama list`.

**Sửa**: Cập nhật biến `MODELS` trong `ollama_mcp.py` cho khớp:

```python
MODELS = {
    "gemma":       {"primary": "gemma4:26b",                   "fallback": None},
    "qwen":     {"primary": "qwen3.5:latest", "fallback": None},
    "nemotron": {"primary": "nemotron-3.5-lightning:latest", "fallback": None},
}
```

Chạy `ollama list` để lấy tên chính xác.

### 3. Chuỗi tiếng Việt bị mojibake

**Nguyên nhân**: File không được lưu UTF-8 hoặc thiếu `ensure_ascii=False`.

**Sửa**:
- Đầu file: `# -*- coding: utf-8 -*-`
- Khi ghi file qua PowerShell: `Set-Content -Encoding UTF8`
- Khi serialize JSON response: `json.dumps(obj, ensure_ascii=False)`

### 4. Thiếu tool (chỉ có ask_gemma, thiếu ask_qwen / ask_nemotron)

**Sửa**: Thêm đầy đủ 3 tool vào `TOOL_DEFINITIONS` và mapping `TOOL_TO_MODEL`:

```python
TOOL_DEFINITIONS = [
    {"name": "ask_gemma",    "description": "...", "inputSchema": {...}},
    {"name": "ask_qwen",     "description": "...", "inputSchema": {...}},
    {"name": "ask_nemotron", "description": "...", "inputSchema": {...}},
]

TOOL_TO_MODEL = {
    "ask_gemma":    "gemma",
    "ask_qwen":     "qwen",
    "ask_nemotron": "nemotron",
}
```

### 5. Ollama API timeout khi sinh text

**Nguyên nhân**: Model lớn (26B+) cần thời gian dài để inference.

**Sửa**: Tăng `timeout` trong `urllib.request.urlopen`:

```python
with urllib.request.urlopen(req, timeout=300) as resp:  # 5 phút
```

---

## Sau khi sửa script

1. Lưu file `ollama_mcp.py`
2. Trong Antigravity IDE → panel **Installed MCP Servers** → tắt/bật toggle của **ollama** hoặc nhấn **Refresh**
3. Chờ trạng thái chuyển từ đỏ sang xanh
4. Test bằng cách gõ `@gemma xin chào` trong chat

---

## Tham chiếu file

| File | Mục đích |
|------|----------|
| `C:\Users\bayng\.gemini\config\mcp_config.json` | Cấu hình MCP servers |
| `C:\Users\bayng\.gemini\antigravity\ollama_mcp.py` | Script MCP server chính |
| `C:\Users\bayng\.gemini\config\skills\ollama-models\SKILL.md` | Skill routing @gemma/@qwen/@nemotron |
