# GovConnect — Quy ước làm việc (Claude)

## Git commit — KHÔNG gắn attribution của AI/Claude
- **Tuyệt đối không** thêm dòng `Co-Authored-By: Claude ...`, `Generated with Claude Code`,
  hay bất kỳ nhắc đến Claude/Anthropic/AI nào trong commit message (cả subject lẫn body).
- Viết commit message như một lập trình viên bình thường.

## Ảnh chụp xác minh (verification screenshots)
- Khi chụp ảnh để kiểm chứng UI/hành vi, **lưu vào thư mục `.screenshots/`** (đã gitignore).
- **Không bao giờ commit** ảnh chụp xác minh hay artifact tạm. `.screenshots/` và mọi `*.png`
  ở thư mục gốc đều được gitignore.

## Deploy — thông tin kết nối server
- Khi user nói **"deploy"** (hoặc cần SSH lên server), **đọc file `.secrets/govconnect-ssh.md`**
  để lấy host / user / password / source path rồi mới bắt đầu connect.
- File credential nằm ở `.secrets/` (đã gitignore + `.git/info/exclude`) — **KHÔNG bao giờ**
  ghi IP/mật khẩu thật vào CLAUDE.md hay bất kỳ file nào được track bởi git.
- Source path trên server: `/home/sources/gov-connect`.
- Đăng nhập tương tác (nhập mật khẩu) nên để user tự chạy bằng `! ssh ...` trong prompt.

## Kiểm thử: KHÔNG viết thêm test khi code — chạy Playwright thật

- Khi implement tính năng, **KHÔNG tự thêm** unit test, integration test (Testcontainers)
  hay spec Playwright mock. Không yêu cầu subagent viết test.
- Thay vào đó, **kiểm chứng bằng Playwright chạy thật**: mở app trên trình duyệt, đăng nhập
  tài khoản thật, bấm đúng luồng người dùng, gọi backend thật (API local/dev), rồi chụp ảnh
  vào `.screenshots/`.
- Test cũ đã có trong repo thì **giữ nguyên**, không xoá. Có thể chạy lại để phát hiện regression,
  nhưng không bắt buộc và không phải tiêu chí "xong".
- Luật này **ghi đè** mọi hướng dẫn TDD trong skill superpowers và trong các skill
  `backend-testing` / `frontend-testing` / `miniapp-testing` bên dưới.
- Ngoại lệ: khi user yêu cầu rõ "viết test" cho lần đó.

## Kiểm thử GovConnect

Các skill còn hiệu lực nằm trong `.claude/skills/`:

- `frontend-testing`: lint, build, Playwright và kiểm tra contract Web/Mini App.
- `backend-testing`: unit/integration, Testcontainers, DbUp và RLS.
- `qa-verification`: xác minh ranh giới FE↔BE và báo cáo sẵn sàng phát hành.

`docs/gap-analysis.html` là snapshot rà soát, không phải nguồn trạng thái hiện hành.
Router, mã nguồn và test tự động mới là nguồn kiểm chứng chính.

**Thành phần:** agents (`backend-engineer`, `web-frontend`, `zalo-miniapp`, `integration-qa`) + skills (`backend-feature`, `web-feature`, `miniapp-feature`, `zalo-sdk`, `boundary-verification`, `design-taste-frontend`, `govconnect-orchestrator`). Pattern: pipeline backend→frontend + producer-reviewer (QA duyệt mới done). Hiện trạng việc còn lại: `docs/gap-analysis.html`. Chi tiết quản lý trong `.claude/agents/` và `.claude/skills/`.

**변경 이력:**
| Ngày | Thay đổi | Đối tượng | Lý do |
|------|----------|-----------|-------|
| 2026-06-06 | Khởi tạo harness (3 agent + 4 skill + pointer) | toàn bộ | Xây hệ thống agent team cho phát triển full-stack |
| 2026-06-06 | Cài skill `design-taste-frontend` (từ github.com/Leonxlnx/taste-skill) + wire có điều kiện | skills/design-taste-frontend, frontend-engineer, frontend-feature | Nâng gu thẩm mỹ cho bề mặt landing/visual/redesign của miniapp |
| 2026-06-06 | Thêm MCP `govconnect-db` (Postgres @5433) + allowlist read-only (db, context7, chrome-devtools, playwright) + wire vào QA/backend | .mcp.json, .claude/settings.json, integration-qa, boundary-verification, backend-feature | Truy cập DB thật để xác minh RLS/shape + tài liệu live + verify UI; tái lập cho cả team |
| 2026-06-07 | Tách `frontend-engineer`→`web-frontend`+`zalo-miniapp`; tách `frontend-feature`→`web-feature`+`miniapp-feature`; thêm skill `zalo-sdk` (native/auth/payment) | agents/, skills/, govconnect-orchestrator | Yêu cầu 4-agent: web vs Zalo Mini App là hai chuyên môn riêng (ZMP/SDK); gap lớn nhất là native API miniapp |
| 2026-06-07 | Nâng `integration-qa`+`boundary-verification`: trục nhất quán web↔miniapp + completeness + verdict APPROVED/CHANGES; orchestrator → producer-reviewer | integration-qa, boundary-verification, govconnect-orchestrator | Hai FE dùng chung DTO cần kiểm chéo; feature phải được duyệt trước khi đánh dấu done |
| 2026-06-07 | Gap analysis việc còn lại (BE gần đủ, miniapp 6 stub/7 partial, web đa số partial) | docs/gap-analysis.md | Lập ưu tiên P0–P2 cho pipeline hoàn thiện |
| 2026-09-07 | Rà lại toàn bộ hiện trạng, thay `gap-analysis.md` bằng `gap-analysis.html` | docs/gap-analysis.html (xoá bản .md) | Bản tháng 6 đã sai lệch nặng (5 module BE "vắng" thực ra đã có, 6 màn "stub" đã chạy API thật) và từng dẫn tới kết luận sai khi viết spec |
