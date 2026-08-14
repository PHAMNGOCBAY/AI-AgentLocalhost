---
name: ollama
description: Bắt buộc Agent gửi yêu cầu của người dùng vào Ollama Smart Router (ask_auto) để tự động chọn model.
---

# Ollama Smart Router Trigger

Khi người dùng sử dụng skill này bằng cách gọi `@ollama`, bạn **BẮT BUỘC** phải tuân thủ các quy tắc sau:

1. **Không tự trả lời:** Bạn không được tự suy luận hay trả lời câu hỏi của người dùng bằng AI của chính mình.
2. **Sử dụng Smart Router:** Bạn phải lấy **toàn bộ nội dung prompt** của người dùng (nằm sau chữ `@ollama`) và gửi nó trực tiếp vào MCP Tool `ask_auto`.
3. **Để Router tự quyết định:** KHÔNG GỌI trực tiếp `ask_qwen` hay `ask_gemma` v.v. Bạn phải gọi `ask_auto` để mã Python nội bộ tự động phân tích từ khóa/độ dài và điều hướng prompt đến đúng mô hình.
4. **Trả kết quả:** Sau khi `ask_auto` trả lời, hãy hiển thị chính xác kết quả đó (bao gồm cả dòng Header `[Router: task=..., model=...]`) cho người dùng.
