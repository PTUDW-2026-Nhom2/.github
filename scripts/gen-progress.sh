#!/usr/bin/env bash
# Sinh bảng phân chia công việc từ Project board vào README.md (giữa 2 marker).
set -euo pipefail

OWNER=${OWNER:-PTUDW-2026-Nhom2}
PROJECT=${PROJECT:-2}
README=${README:-profile/README.md}
BOARD="https://github.com/orgs/$OWNER/projects/$PROJECT"

items=$(gh project item-list "$PROJECT" --owner "$OWNER" --limit 500 --format json)

members='[
  {"login":"ChuChoaChan131019","name":"Trần Thị Phương Trang","scope":"recipes · jobs"},
  {"login":"minnhi09","name":"Đinh Thị Mai Lành","scope":"categories · search"},
  {"login":"dopaemon","name":"Trần Nguyễn Tuấn Anh","scope":"auth · docker"},
  {"login":"minhtai05","name":"Trần Minh Tài","scope":"media · recipes"}
]'

html=$(jq -r --argjson m "$members" --arg board "$BOARD" --arg owner "$OWNER" --arg now "$(TZ=Asia/Ho_Chi_Minh date '+%d/%m/%Y %H:%M GMT+7')" '
  def bar(p): (((p/10)|floor) as $f | ("█" * $f) + ("░" * (10 - $f)));
  .items as $all
  | ($m | map(. + (.login as $l | ($all | map(select(.assignees // [] | index($l)))) as $mine | {
      done:  ($mine | map(select(.status == "Done")) | length),
      doing: ($mine | map(select(.status == "In Progress")) | length),
      todo:  ($mine | map(select(.status == "Todo" or .status == null)) | length),
      total: ($mine | length)
    }))) as $rows
  | ($all | map(select(.status == "In Progress"))) as $doing
  | "<h2>📊 Phân chia công việc — tiến độ trực tiếp</h2>",
    "",
    "<p><sub>Tự động cập nhật <b>00:00 (GMT+7)</b> mỗi ngày từ <a href=\"\($board)\">Project board</a> · cập nhật lần cuối: <b>\($now)</b></sub></p>",
    "",
    "<div align=\"center\">",
    "<table>",
    "  <thead>",
    "    <tr>",
    "      <th align=\"center\">Thành viên</th>",
    "      <th align=\"center\">Scope</th>",
    "      <th align=\"center\">Tiến độ</th>",
    "      <th align=\"center\">✅ Xong</th>",
    "      <th align=\"center\">🔨 Đang làm</th>",
    "      <th align=\"center\">📋 Chờ</th>",
    "    </tr>",
    "  </thead>",
    "  <tbody>",
    ($rows[] | (if .total > 0 then (.done * 100 / .total | round) else 0 end) as $p |
    "    <tr>",
    "      <td align=\"center\"><img src=\"https://github.com/\(.login).png\" width=\"36\" height=\"36\"/><br/>\(.name)<br/><sub><a href=\"https://github.com/\(.login)\">@\(.login)</a></sub></td>",
    "      <td align=\"center\"><code>\(.scope)</code></td>",
    "      <td align=\"center\"><code>\(bar($p))</code> \($p)%</td>",
    "      <td align=\"center\">\(.done)</td>",
    "      <td align=\"center\">\(.doing)</td>",
    "      <td align=\"center\">\(.todo)</td>",
    "    </tr>"),
    "  </tbody>",
    "</table>",
    "</div>",
    "",
    "<details>",
    "<summary><b>🔨 Đang làm (\($doing | length))</b></summary>",
    "",
    "<table>",
    "  <thead><tr><th align=\"center\">Issue</th><th align=\"left\">Tiêu đề</th><th align=\"center\">Người làm</th></tr></thead>",
    "  <tbody>",
    ($doing[] |
    "    <tr><td align=\"center\"><a href=\"https://github.com/\($owner)/CulinaryBlog/issues/\(.content.number)\">#\(.content.number)</a></td><td align=\"left\">\(.title)</td><td align=\"center\">\(.assignees // [] | map("@" + .) | join(", "))</td></tr>"),
    "  </tbody>",
    "</table>",
    "",
    "</details>"
' <<<"$items")

HTML_BLOCK="$html" python3 - "$README" <<'PY'
import re, sys, io, os
path = sys.argv[1]
body = io.open(path, encoding="utf-8").read()
block = "<!-- PROGRESS:START -->\n" + os.environ["HTML_BLOCK"] + "\n<!-- PROGRESS:END -->"
if "<!-- PROGRESS:START -->" in body:
    body = re.sub(r"<!-- PROGRESS:START -->.*?<!-- PROGRESS:END -->", lambda _: block, body, flags=re.S)
else:
    anchor = "<h2>👥 Thành viên nhóm"
    i = body.index(anchor)
    body = body[:i] + block + "\n\n" + body[i:]
io.open(path, "w", encoding="utf-8").write(body)
PY
