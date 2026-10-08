# ---
# Module: Hopper Bot Homework Plugin
# Description: Declarative homework stats and missing list plugin for AstrBot
# Scope: Host
# ---

{ pkgs, ... }:
let
  pluginDir = "/var/lib/astrbot/data/plugins/astrbot_plugin_gmail_homework";
  metadataYaml = pkgs.writeText "metadata.yaml" ''
    name: astrbot_plugin_gmail_homework
    desc: Gmail 附件收作业自动统计与催交通知插件
    author: DotRedstone
    version: 1.0.0
    repo: ""
  '';
  mainPy = pkgs.writeText "main.py" ''
    import json
    import urllib.request
    import urllib.parse
    from astrbot.api.event import filter, AstrMessageEvent
    from astrbot.api.star import register, Star

    TA_STUDENT_ID = "240809010505"  # 明航宇（助教本人豁免）
    TA_NAME = "明航宇"
    API_BASE = "http://127.0.0.1:8080"
    DEFAULT_ASSIGNMENT = "parallel_computing_lab1"

    def api_get(endpoint):
        url = f"{API_BASE}{endpoint}"
        req = urllib.request.Request(url, headers={"User-Agent": "AstrBot"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read().decode("utf-8"))

    @register("gmail_homework", "DotRedstone", "Gmail 自动收作业与催交插件", "1.0.0")
    class HomeworkPlugin(Star):
        def __init__(self, context):
            super().__init__(context)

        @filter.command("查作业")
        async def status_cmd(self, event: AstrMessageEvent):
            """查询当前作业提交总体进度"""
            try:
                data = api_get(f"/api/assignments/{DEFAULT_ASSIGNMENT}/status")
                msg = (
                    f"📊【{data['assignment_name']}】提交统计\n"
                    f"━━━━━━━━━━━━━━━\n"
                    f"✅ 实交人数：{data['submitted_count']} / {data['total_expected']}\n"
                    f"📈 提交比例：{data['submission_rate']}\n"
                    f"⚠️ 迟交人数：{data['late_count']} 人\n"
                    f"⏳ 截止时间：{data['deadline'][:16].replace('T', ' ')}"
                )
                yield event.plain_result(msg)
            except Exception as e:
                yield event.plain_result(f"❌ 查询作业状态失败: {e}")

        @filter.command("未交")
        async def missing_cmd(self, event: AstrMessageEvent):
            """查询未交学生名单"""
            try:
                data = api_get(f"/api/assignments/{DEFAULT_ASSIGNMENT}/missing")
                missing = data.get("missing_list", [])
                real_missing = [s for s in missing if s.get("student_id") != TA_STUDENT_ID and s.get("name") != TA_NAME]
                
                if not real_missing:
                    yield event.plain_result(f"🎉 太棒了！【{data['assignment_name']}】除助教本人外，全班同学已全部提交完毕！")
                    return

                lines = [f"📢【{data['assignment_name']}】未交名单（共 {len(real_missing)} 人）："]
                for idx, s in enumerate(real_missing, 1):
                    lines.append(f"{idx}. {s['name']}（{s['student_id']}，{s['class_name']}）")
                lines.append("\n💡 请以上同学抓紧整理源码与实验报告并发送至邮箱！")
                yield event.plain_result("\n".join(lines))
            except Exception as e:
                yield event.plain_result(f"❌ 查询未交名单失败: {e}")

        @filter.command("查收")
        async def check_student(self, event: AstrMessageEvent, query: str = ""):
            """自助查询个人作业是否收到：/查收 张三 或 /查收 24080901xxxx"""
            query = query.strip()
            if not query:
                yield event.plain_result("💡 用法：/查收 <姓名或学号>，例如：/查收 张三")
                return

            try:
                data = api_get(f"/api/assignments/{DEFAULT_ASSIGNMENT}/missing")
                missing = data.get("missing_list", [])
                is_missing = any(s.get("student_id") == query or s.get("name") == query for s in missing)
                
                if query in [TA_STUDENT_ID, TA_NAME]:
                    yield event.plain_result(f"👑 {TA_NAME} 为课程助教，无需提交作业。")
                    return

                if is_missing:
                    yield event.plain_result(f"⚠️ 未检索到 [{query}] 的有效作业提交，请确认邮件主题与附件命名规范是否正确。")
                else:
                    yield event.plain_result(f"✅ [{query}] 的作业已成功接收并归档！")
            except Exception as e:
                yield event.plain_result(f"❌ 查询失败: {e}")
  '';
in
{
  systemd.tmpfiles.rules = [
    "d ${pluginDir} 0755 root root -"
    "L+ ${pluginDir}/metadata.yaml - - - - ${metadataYaml}"
    "L+ ${pluginDir}/main.py - - - - ${mainPy}"
  ];
}
