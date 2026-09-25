#!/usr/bin/env bash
# Sinh bảng công việc đang làm từ Project board vào profile/README.md (giữa 2 marker).
set -euo pipefail

OWNER=${OWNER:-PTUDW-2026-Nhom2}
PROJECT=${PROJECT:-2}
README=${README:-profile/README.md}
BOARD="https://github.com/orgs/$OWNER/projects/$PROJECT/views/3"
DIR=$(cd "$(dirname "$0")" && pwd)

items=$(gh api graphql --paginate -F org="$OWNER" -F num="$PROJECT" -F query=@"$DIR/project.graphql" \
  -q '.data.organization.projectV2.items.nodes[]
      | select(.content.number)
      | {number: .content.number, title: .content.title, url: .content.url,
         status: (.status.name // "Todo"),
         assignees: [.content.assignees.nodes[].login],
         prs: [.content.closedByPullRequestsReferences.nodes[] | {number, url}]}' | jq -s .)

html=$(jq -r --arg board "$BOARD" --arg now "$(TZ=Asia/Ho_Chi_Minh date '+%d/%m/%Y %H:%M GMT+7')" '
  def esc: gsub("&"; "&amp;") | gsub("->"; "→");
  # Bắt mọi mã trong ngoặc vuông đầu title: FR-, NFR-, FE-, ... (trước đây chỉ khớp N?FR- nên
  # issue FE-* rơi vào nhánh fallback: cột mã hiện "—" và title còn nguyên tiền tố "[FE-...]").
  def fr: . as $t | (($t.title | capture("^\\[(?<c>[^\\]]+)\\]\\s*(?<rest>.*)$")) // {c:"—", rest:$t.title});
  def who: (.assignees | if length == 0 then "⚠️ chưa ai nhận"
            else map("<a href=\"https://github.com/" + . + "\"><img src=\"https://github.com/" + . + ".png\" width=\"24\" height=\"24\"/> @" + . + "</a>") | join("<br/>") end);
  def prs: (if (.prs | length) == 0 then "—"
            else (.prs | map("<a href=\"" + .url + "\">#" + (.number|tostring) + "</a>") | join(" ")) end);

  def bar(p): (((p / 10) | floor) as $f | ("█" * $f) + ("░" * (10 - $f)));
  (map(select(.status == "Done")) | length) as $done
  | (map(select(.status == "In Progress")) | length) as $doing
  | length as $total
  | (if $total > 0 then ($done * 100 / $total | round) else 0 end) as $pct
  | map(select(.status == "In Progress")) as $tasks
  |
  "<h2>🔨 Công việc đang làm</h2>",
  "",
  "<p align=\"center\"><code>\(bar($pct))</code> <b>\($pct)%</b> — ✅ <b>\($done)</b> xong · 🔨 <b>\($doing)</b> đang làm · 📋 <b>\($total - $done - $doing)</b> chờ · tổng <b>\($total)</b> việc</p>",
  "",
  "<p align=\"center\">Tự động cập nhật <b>00:00 (GMT+7)</b> mỗi ngày từ <a href=\"\($board)\"><b>Project board</b></a><br/>Cập nhật lần cuối: <b>\($now)</b></p>",
  "",
  "<div align=\"center\">",
  "<table>",
  "  <thead><tr><th align=\"center\">Issue</th><th align=\"center\">Mã YC</th><th align=\"left\">Công việc</th><th align=\"center\">Người làm</th><th align=\"center\">PR</th></tr></thead>",
  "  <tbody>",
  ($tasks | sort_by(-.number)[] | fr as $f |
  "    <tr><td align=\"center\"><a href=\"\(.url)\">#\(.number)</a></td><td align=\"center\"><code>\($f.c | esc)</code></td><td align=\"left\">\($f.rest | esc)</td><td align=\"center\">\(who)</td><td align=\"center\">\(prs)</td></tr>"),
  "  </tbody>",
  "</table>",
  "</div>"
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
