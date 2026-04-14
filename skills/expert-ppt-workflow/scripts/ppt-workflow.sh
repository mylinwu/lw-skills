#!/bin/bash
set -e

tmp_file=""
cleanup() {
  if [ -n "$tmp_file" ] && [ -f "$tmp_file" ]; then
    rm -f "$tmp_file"
  fi
}
trap cleanup EXIT

phase="${1:-all}"
topic="${2:-}"
page_count="${3:-}"
audience="${4:-}"
purpose="${5:-}"

echo "为阶段生成专家PPT工作流提示包: $phase" >&2

if command -v python3 >/dev/null 2>&1; then
  py_cmd="python3"
elif command -v python >/dev/null 2>&1; then
  py_cmd="python"
elif command -v py >/dev/null 2>&1; then
  py_cmd="py -3"
else
  echo "Error: Python 3 is required but was not found on PATH" >&2
  exit 3
fi

$py_cmd - "$phase" "$topic" "$page_count" "$audience" "$purpose" <<'PY'
import json
import sys

phase, topic, page_count, audience, purpose = sys.argv[1:6]

context = {
    "topic": topic or "[TOPIC]",
    "page_count": page_count or "[PAGE_COUNT]",
    "audience": audience or "[AUDIENCE]",
    "purpose": purpose or "[PURPOSE]",
}

packets = {
    "discovery": f"""担任高级演示文稿顾问。主题是 {context['topic']}。
在起草前仅询问缺失的高影响力问题：受众、目的、交付场景、
页数、语气、来源约束、必须包含的要点和输出格式。返回紧凑的简报
和明确的假设。""",
    "research": f"""担任专业幻灯片团队的研究主管。
主题: {context['topic']}
受众: {context['audience']}
目的: {context['purpose']}
页数: {context['page_count']}

收集当前、有来源支持的事实、注意事项、示例和比较。按
幻灯片相关主题分组发现，并明确标记不确定的声明。""",
    "outline": f"""担任顶级PPT结构架构师。
主题: {context['topic']}
受众: {context['audience']}
目的: {context['purpose']}
页面要求: {context['page_count']}

使用金字塔原理：结论先行，父级要点总结子级要点，同级要点共享一个
逻辑类别，部分按清晰逻辑推进。使用研究上下文而非通用
填充内容。返回包含封面、目录、部分/页面和结束页的JSON大纲。""",
    "page-plan": f"""担任PPT规划总监。将 {context['topic']} 的研究大纲
转换为逐页规划草稿。为每张幻灯片提供幻灯片编号、信息、证据/内容
块、布局模式、视觉元素和设计风险。尚不生成最终样式。""",
    "svg": """担任信息架构师和SVG演示文稿设计师。将一张幻灯片计划转换为
可编辑的SVG页面。使用 viewBox="0 0 1280 720"。使用由内容层次结构驱动的卡片/网格布局。
卡片之间至少保持20px间距，保持文本在容器内，仅返回SVG代码。"""
}

if phase == "all":
    selected = packets
elif phase in packets:
    selected = {phase: packets[phase]}
else:
    print(f"Unsupported phase: {phase}", file=sys.stderr)
    sys.exit(2)

print(json.dumps({
    "status": "success",
    "skill": "expert-ppt-workflow",
    "phase": phase,
    "context": context,
    "prompts": selected,
}, ensure_ascii=False, indent=2))
PY
