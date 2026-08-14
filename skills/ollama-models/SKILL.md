---
name: ollama-models
description: Route @gemma, @qwen and @nemotron prompts to local Ollama models via MCP
---

# Smart Router — Điều hướng thông minh tới mô hình Ollama cục bộ

## Inventory mô hình

| Model | Params | VRAM | Context | Thế mạnh |
|-------|--------|------|---------|----------|
| **Gemma4 26B** | 25.8B | 17 GB | 262K | Suy luận tổng quát phức tạp, phân tích tài liệu dài, báo cáo, hỏi đáp ngắn |
| **Qwen 2.5 Coder 32B** | 32B | 20 GB | 128K | Viết code, debug, refactor, code review, SQL, regex, unit test |
| **Nemotron 3.5 Lightning** | 42B | 25 GB | 128K | Toán, logic, suy luận phức tạp, phân tích địa kỹ thuật, kết cấu |

---

## Chế độ 1: Người dùng chỉ định rõ model

- `@gemma` → `ollama/ask_gemma` → Gemma4 26B
- `@qwen` → `ollama/ask_qwen` → Qwen 2.5 Coder 32B
- `@nemotron` → `ollama/ask_nemotron` → Nemotron 3.5 Lightning

---

## Chế độ 2: Smart Router (Cross-Check Multi-Agent)

Khi người dùng **KHÔNG** chỉ định `@model`, hệ thống sẽ tự động thực hiện **quy trình 2 bước (Cross-Check)**:
1. Phân loại câu hỏi bằng từ khóa (keyword matching) để giao cho chuyên gia (Primary Model) tạo bản nháp.
2. Tự động giao cho Gemma4 26B làm người phản biện (Reviewer Model) để kiểm tra, sửa lỗi và chốt kết quả cuối cùng trước khi trả về. (Nếu bản thân chuyên gia đã là Gemma, bước này được bỏ qua).

### Bảng phân loại task → model

| task_type | Model | Khi nào dùng |
|-----------|-------|--------------|
| `code` | **Qwen 2.5 Coder 32B** | Viết/sửa code, debug, refactor, code review, API, script, SQL, regex, unit test, chuyển đổi ngôn ngữ |
| `reasoning` | **Nemotron 3.5 Lightning** | Toán, logic, suy luận nhiều bước, phân tích dữ liệu số, so sánh phương án, địa kỹ thuật, kết cấu, tính toán kỹ thuật |
| `general` | **Gemma4 26B** | Phân tích tài liệu dài, viết báo cáo, tóm tắt phức tạp, soạn email chuyên nghiệp, dịch, hỏi đáp |
| `quick` | **Gemma4 26B** | Dịch 1-2 câu, định nghĩa thuật ngữ, hỏi đáp đơn giản, câu hỏi yes/no, prompt ≤200 ký tự |

### Quy tắc phân loại

1. Prompt chứa **code block**, **tên hàm/class**, **import**, **syntax lỗi** → `code`
2. Prompt yêu cầu **tính toán**, **chứng minh**, **so sánh phương án**, **phân tích số liệu** → `reasoning`
3. Prompt chứa các lệnh giao tiếp, hỏi đáp đơn giản (dịch, nghĩa là, là gì, hello) → `quick`
4. Các prompt còn lại → `general`
5. Không còn xét dựa trên độ dài chuỗi ký tự. Bất kể độ dài, hệ thống chỉ tập trung vào ngữ nghĩa và từ khóa. Mọi kết quả từ `code` và `reasoning` đều sẽ phải qua `Gemma` kiểm tra lại.

### Ví dụ phân loại

```
"Viết hàm Python tính diện tích đa giác"             → code     → Qwen Coder
"Debug lỗi TypeError trong script này"                → code     → Qwen Coder
"Tính sức chịu tải cọc khoan nhồi D1000"              → reasoning → Nemotron
"So sánh 3 phương án móng cọc cho nền đất yếu"        → reasoning → Nemotron
"Phân tích báo cáo khảo sát địa chất 50 trang"        → general  → Gemma4 26B
"Viết báo cáo tóm tắt kết quả thí nghiệm SPT"        → general  → Gemma4 26B
"Dịch: Hello world"                                   → quick    → Gemma4 26B
"BIM là gì?"                                          → quick    → Gemma4 26B
```

### Cách gọi

```
ollama/ask_auto  →  prompt: "<nội dung>", task_type: "code" | "reasoning" | "general" | "quick"
```

Nếu bỏ trống `task_type`, server tự phân loại bằng keyword matching + độ dài prompt.

---

## Danh sách tools

| Tool | Model | Dùng khi |
|------|-------|----------|
| `ask_auto` | Tự chọn | Mặc định cho mọi prompt không có `@model` |
| `ask_gemma` | Gemma4 26B | `@gemma` hoặc cần phân tích dài |

| `ask_qwen` | Qwen 2.5 Coder 32B | `@qwen` hoặc task code |
| `ask_nemotron` | Nemotron 3.5 | `@nemotron` hoặc task reasoning |
