#!/usr/bin/env bash
# Sinh bảng phân chia công việc từ Project board vào profile/README.md (giữa 2 marker).
set -euo pipefail

OWNER=${OWNER:-PTUDW-2026-Nhom2}
PROJECT=${PROJECT:-2}
REPO=${REPO:-CulinaryBlog}
README=${README:-profile/README.md}
BOARD="https://github.com/orgs/$OWNER/projects/$PROJECT"
DIR=$(cd "$(dirname "$0")" && pwd)

items=$(gh api graphql --paginate -F org="$OWNER" -F num="$PROJECT" -F query=@"$DIR/project.graphql" \
  -q '.data.organization.projectV2.items.nodes[] | select(.content.number)
      | {number: .content.number, title: .content.title, url: .content.url,
         status: (.status.name // "Todo"),
         assignees: [.content.assignees.nodes[].login],
         prs: [.content.closedByPullRequestsReferences.nodes[] | {number, url, state}]}' | jq -s .)

members='[
  {"login":"ChuChoaChan131019","name":"Trần Thị Phương Trang","role":"🧭 Trưởng nhóm","scope":"recipes · jobs","block":"FR-RCP-001→007 · FR-JOB"},
  {"login":"minnhi09","name":"Đinh Thị Mai Lành","role":"Thành viên","scope":"categories · search","block":"FR-CAT · FR-SRCH"},
  {"login":"dopaemon","name":"Trần Nguyễn Tuấn Anh","role":"Thành viên","scope":"auth · docker","block":"FR-AUTH · FR-OBS"},
  {"login":"minhtai05","name":"Trần Minh Tài","role":"Thành viên","scope":"media · recipes","block":"FR-RCP-008,009,010 · FR-FILE"}
]'

html=$(jq -r --argjson m "$members" --arg board "$BOARD" --arg owner "$OWNER" --arg repo "$REPO" \
  --arg now "$(TZ=Asia/Ho_Chi_Minh date '+%d/%m/%Y %H:%M GMT+7')" '
  def bar(p): (((p/10)|floor) as $f | ("█" * $f) + ("░" * (10 - $f)));
  def badge: {"In Progress":"🔨 Đang làm","Done":"✅ Xong","Todo":"📋 Chờ"}[.] // ("📋 " + .);
  def order: {"In Progress":0,"Done":1,"Todo":2}[.] // 3;
  def fr: . as $t | (($t.title | capture("^\\[(?<c>[A-Z-]+-[0-9]+)\\]\\s*(?<rest>.*)$")) // {c:"—", rest:$t.title});
  def prs: (if (.prs | length) == 0 then "—"
            else (.prs | map("<a href=\"" + .url + "\">#" + (.number|tostring) + "</a>") | join(" ")) end);

  . as $all
  | ($m | map(. + (.login as $l | ($all | map(select(.assignees | index($l)))) as $mine | {
      tasks: $mine,
      done:  ($mine | map(select(.status == "Done")) | length),
      doing: ($mine | map(select(.status == "In Progress")) | length),
      todo:  ($mine | map(select(.status == "Todo")) | length),
      total: ($mine | length)
    }))) as $rows
  | ($all | map(select(.status == "Done")) | length) as $tDone
  | ($all | map(select(.status == "In Progress")) | length) as $tDoing
  | ($all | map(select(.status == "Todo")) | length) as $tTodo

  | "<h2>📋 Phân chia công việc</h2>",
    "",
    "<p><sub>Tự động cập nhật <b>00:00 (GMT+7)</b> mỗi ngày từ <a href=\"\($board)\">Project board</a> · cập nhật lần cuối: <b>\($now)</b></sub></p>",
    "",
    "<p>Mỗi thành viên phụ trách <b>trọn một khối tính năng</b> — từ database, API backend đến giao diện frontend.</p>",
    "",
    "<div align=\"center\">",
    "<table>",
    "  <thead><tr><th align=\"center\">Thành viên</th><th align=\"center\">Khối phụ trách</th><th align=\"center\">Tiến độ</th><th align=\"center\">✅</th><th align=\"center\">🔨</th><th align=\"center\">📋</th></tr></thead>",
    "  <tbody>",
    ($rows[] | (if .total > 0 then (.done * 100 / .total | round) else 0 end) as $p |
    "    <tr><td align=\"center\"><img src=\"https://github.com/\(.login).png\" width=\"32\" height=\"32\"/><br/><b>\(.name)</b><br/><sub><a href=\"https://github.com/\(.login)\">@\(.login)</a></sub></td><td align=\"center\"><code>\(.block)</code><br/><sub><code>\(.scope)</code></sub></td><td align=\"center\"><code>\(bar($p))</code> \($p)%</td><td align=\"center\">\(.done)</td><td align=\"center\">\(.doing)</td><td align=\"center\">\(.todo)</td></tr>"),
    "  </tbody>",
    "</table>",
    "</div>",
    "",
    ($rows[] |
      "<details open>",
      "<summary><b>\(.name)</b> — \(.block) <sub>(\(.doing) đang làm · \(.done)/\(.total) xong)</sub></summary>",
      "",
      "<table>",
      "  <thead><tr><th align=\"center\">Issue</th><th align=\"center\">Mã FR</th><th align=\"left\">Công việc</th><th align=\"center\">Trạng thái</th><th align=\"center\">PR</th></tr></thead>",
      "  <tbody>",
      (.tasks | sort_by((.status | order), -.number)[] | fr as $f |
      "    <tr><td align=\"center\"><a href=\"\(.url)\">#\(.number)</a></td><td align=\"center\"><code>\($f.c)</code></td><td align=\"left\">\($f.rest)</td><td align=\"center\">\(.status | badge)</td><td align=\"center\">\(prs)</td></tr>"),
      "  </tbody>",
      "</table>",
      "",
      "</details>",
      ""
    ),
    "<p align=\"center\"><sub>Tổng: <b>\($all | length)</b> đầu việc · ✅ \($tDone) xong · 🔨 \($tDoing) đang làm · 📋 \($tTodo) chờ · <a href=\"https://github.com/\($owner)/\($repo)/issues\">tất cả issue</a></sub></p>"
' <<<"$items")

HTML_BLOCK="$html" python3 - "$README" <<'PY'
import re, sys, io, os
path = sys.argv[1]
body = io.open(path, encoding="utf-8").read()
block = "<!-- PROGRESS:START -->\n" + os.environ["HTML_BLOCK"] + "\n<!-- PROGRESS:END -->"
if "<!-- PROGRESS:START -->" in body:
    body = re.sub(r"<!-- PROGRESS:START -->.*?<!-- PROGRESS:END -->", lambda _: block, body, flags=re.S)
else:
    i = body.index("<h2>👥 Thành viên nhóm")
    body = body[:i] + block + "\n\n" + body[i:]
io.open(path, "w", encoding="utf-8").write(body)
PY
