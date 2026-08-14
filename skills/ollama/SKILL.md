---
name: ollama
description: Bắt buộc Agent gửi yêu cầu của người dùng vào Ollama Smart Router (ask_auto) để tự động chọn model.
---

# Ollama Smart Router Trigger

Khi người dùng sử dụng skill này bằng cách gọi `@ollama`, bạn **BẮT BUỘC** phải tuân thủ các quy tắc sau:

1. **Không tự trả lời:** Bạn không được tự suy luận hay trả lời câu hỏi của người dùng bằng AI của chính mình.
2. **Sử dụng Smart Router:** Bạn phải lấy **toàn bộ nội dung prompt** của người dùng (nằm sau chữ `@ollama`) và gửi nó trực tiếp vào MCP Tool `ask_auto`.
3. **Để Router tự quyết định:** KHÔNG GỌI trực tiếp `ask_qwen` hay `ask_gemma` v.v. Bạn phải gọi `ask_auto` để mã Python nội bộ tự động phân tích từ khóa/độ dài và điều hướng prompt đến đúng mô hình.
4. **Thực thi nhiệm vụ triệt để (Action-Oriented):** Đây là điều quan trọng nhất. Sau khi nhận được kết quả từ `ask_auto`:
   - Nếu kết quả chứa mã code (Python, Shell, v.v.), bạn **KHÔNG ĐƯỢC** chỉ in ra màn hình. Bạn phải tạo file và dùng `run_command` để chạy đoạn code đó nhằm xuất ra kết quả cuối cùng (ví dụ: tạo ảnh đồ thị, báo cáo).
   - Nếu kết quả là hướng dẫn thực thi (ví dụ: mở phần mềm Midas Civil NX, tạo thư mục), bạn phải tìm mọi cách sử dụng tool hệ thống của mình (PowerShell, `run_command`) để **thực sự làm việc đó** thay cho người dùng.
   - Tóm lại: Hãy coi kết quả trả về từ Ollama là "Bản hướng dẫn/Bản nháp", và BẠN (Agent) có trách nhiệm phải **THỰC THI** bản hướng dẫn đó trên máy tính cho đến khi công việc hoàn thành 100%, tuyệt đối không được chỉ trả lời suông như một chatbot thông thường.
