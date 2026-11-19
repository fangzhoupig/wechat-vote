"""检查已截止且登记了邮箱的投票，把结果发邮件。由 GitHub Actions 定时运行。

需要的环境变量：
  SUPABASE_URL, SUPABASE_SECRET_KEY      数据库地址和管理员钥匙（secret / service_role key）
  SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS  发件邮箱的 SMTP 设置
  SITE_URL                                投票网页地址
"""
import json, os, smtplib, sys, urllib.parse, urllib.request
from datetime import datetime, timezone, timedelta
from email.mime.text import MIMEText
from email.header import Header
from email.utils import formataddr

URL = os.environ["SUPABASE_URL"].rstrip("/") + "/rest/v1/"
KEY = os.environ["SUPABASE_SECRET_KEY"]
SITE = os.environ.get("SITE_URL", "").rstrip("/") + "/"
CST = timezone(timedelta(hours=8))

H = {"apikey": KEY, "Content-Type": "application/json"}
if not KEY.startswith("sb_"):  # 旧版 service_role JWT
    H["Authorization"] = "Bearer " + KEY


def api(path, method="GET", body=None):
    req = urllib.request.Request(URL + path, method=method, headers=H,
                                 data=json.dumps(body).encode() if body is not None else None)
    with urllib.request.urlopen(req, timeout=30) as r:
        txt = r.read().decode()
        return json.loads(txt) if txt else None


def q(v):
    return urllib.parse.quote(str(v), safe="")


def parse_ts(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def build_mail(poll, votes):
    counts = [[] for _ in poll["options"]]
    for v in votes:
        for i in v["choices"]:
            if 0 <= i < len(counts):
                counts[i].append(v["name"])
    order = sorted(range(len(counts)), key=lambda i: -len(counts[i]))
    end = parse_ts(poll["ends_at"]).astimezone(CST).strftime("%m月%d日 %H:%M")
    lines = [f"📊 {poll['title']}（{'多选' if poll['multi'] else '单选'}）",
             f"截止时间：{end}（北京时间）", f"投票人数：{len(votes)}", ""]
    for rank, i in enumerate(order):
        mark = "🏆 " if rank == 0 and counts[i] else "   "
        lines.append(f"{mark}{poll['options'][i]}：{len(counts[i])} 票")
        if counts[i]:
            lines.append("      " + "、".join(counts[i]))
    lines += ["", f"查看详情：{SITE}?id={poll['id']}"]
    return f"【投票结果】{poll['title']}", "\n".join(lines)


def send(to, subject, body):
    msg = MIMEText(body, "plain", "utf-8")
    msg["Subject"] = Header(subject, "utf-8")
    msg["From"] = formataddr((str(Header("群投票", "utf-8")), os.environ["SMTP_USER"]))
    msg["To"] = to
    port = int(os.environ.get("SMTP_PORT") or 465)
    cls = smtplib.SMTP_SSL if port == 465 else smtplib.SMTP
    with cls(os.environ["SMTP_HOST"], port, timeout=30) as s:
        if port != 465:
            s.starttls()
        s.login(os.environ["SMTP_USER"], os.environ["SMTP_PASS"])
        s.sendmail(os.environ["SMTP_USER"], [to], msg.as_string())


def main():
    now = datetime.now(timezone.utc)
    pending = api("poll_notify?sent_at=is.null&select=poll_id,email")
    print(f"待处理 {len(pending)} 条")
    failed = 0
    for n in pending:
        rows = api(f"polls?id=eq.{q(n['poll_id'])}&select=*")
        if not rows or not rows[0].get("ends_at") or parse_ts(rows[0]["ends_at"]) > now:
            continue
        poll = rows[0]
        votes = api(f"votes?poll_id=eq.{q(poll['id'])}&select=name,choices&order=created_at")
        try:
            send(n["email"], *build_mail(poll, votes))
            api(f"poll_notify?poll_id=eq.{q(poll['id'])}", "PATCH", {"sent_at": now.isoformat()})
            print(f"已发送：{poll['id']}")
        except Exception as e:
            failed += 1
            print(f"发送失败：{poll['id']}：{e}", file=sys.stderr)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
