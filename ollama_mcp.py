# -*- coding: utf-8 -*-
"""Ollama Smart Router v4 - auto-selects best model including Gemma4 26B/E4B split."""

import sys
import io
import json
import urllib.request
import re

sys.stdin  = io.TextIOWrapper(sys.stdin.buffer,  encoding="utf-8", errors="replace", newline="")
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace", newline="\n")

# -- Model registry --
MODELS = {
    "gemma":       {"primary": "gemma4:26b",                   "fallback": None},
    "qwen":        {"primary": "qwen2.5-coder:32b",            "fallback": None},
    "nemotron":    {"primary": "nemotron-3.5-lightning:latest", "fallback": None},
}

# -- Task type to model routing --
TASK_ROUTE = {
    "code":      "qwen",       # Qwen 2.5 Coder 32B
    "reasoning": "nemotron",   # Nemotron 3.5 Lightning
    "general":   "gemma",      # Gemma4 26B  - complex general tasks
    "quick":     "gemma",      # Gemma4 26B  - fast simple tasks (now unified)
}

# -- Keyword classifiers --
CODE_KEYWORDS = re.compile(
    r'\b(code|debug|refactor|function|class|def |import |script|api|sql|regex|'
    r'unit\s*test|syntax|compile|runtime|error|exception|bug|fix|implement|'
    r'endpoint|crud|query|index|sort|algorithm|variable|loop|array|dict|list|'
    r'string|integer|float|bool|return|async|await|promise|callback|'
    r'git|docker|pip|npm|yarn|cmake|makefile|autolisp|lisp|python|java|'
    r'typescript|javascript|csharp|c\+\+|rust|go|ruby|swift|kotlin|html|css)\b',
    re.IGNORECASE
)

REASONING_KEYWORDS = re.compile(
    r'\b(calculate|compute|prove|compare|analyze|evaluate|optimize|'
    r'mathematical|equation|formula|probability|statistics|'
    r'logic|reasoning|deduc|induc|trade.?off|pros?\s*(and|&)\s*cons?|'
    r'risk\s*analysis|decision|strategy|plan|benchmark|'
    r'geotechnical|bearing\s*capacity|settlement|soil|borehole|SPT|'
    r'structural|load|stress|strain|moment|shear|pile|foundation|'
    r'tinh\s*toan|phan\s*tich|so\s*sanh|suy\s*luan|chung\s*minh|'
    r'suc\s*chiu\s*tai|dia\s*chat|nen\s*mong|coc)\b',
    re.IGNORECASE
)

QUICK_SIGNALS = re.compile(
    r'\b(dich|translate|nghia\s*la|meaning|what\s*is|la\s*gi|'
    r'dinh\s*nghia|definition|hello|hi|xin\s*chao|cam\s*on|thanks)\b',
    re.IGNORECASE
)



def classify_prompt(prompt):
    """Classify prompt into task_type: code, reasoning, general, quick."""
    code_score = len(CODE_KEYWORDS.findall(prompt))
    reasoning_score = len(REASONING_KEYWORDS.findall(prompt))
    quick_score = len(QUICK_SIGNALS.findall(prompt))

    # Code blocks are strong signals
    if '```' in prompt or 'def ' in prompt or 'import ' in prompt:
        code_score += 5

    # Priority: code > reasoning > quick > general
    if code_score > reasoning_score and code_score > 0:
        return "code"
    if reasoning_score > 0:
        return "reasoning"
    if quick_score > 0:
        return "quick"
    return "general"


# -- Ollama helpers --
def get_available_models():
    try:
        req = urllib.request.Request("http://localhost:11434/api/tags")
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return [m.get("name") for m in data.get("models", [])]
    except Exception:
        return []


def resolve_model(model_key):
    cfg = MODELS.get(model_key)
    if cfg is None:
        return None, "No config for model key '%s'" % model_key

    available = get_available_models()
    selected = cfg["primary"]

    if selected not in available:
        fb = cfg.get("fallback")
        if fb and fb in available:
            selected = fb
        elif available:
            # Try prefix match
            prefix = model_key.split("_")[0]  # gemma_full -> gemma
            match = [m for m in available if m.startswith(prefix)]
            selected = match[0] if match else None
        else:
            return None, "Ollama not ready. Run: ollama pull %s" % cfg["primary"]

    if selected is None:
        return None, "Model '%s' not available. Run: ollama pull %s" % (model_key, cfg["primary"])
    return selected, None


def query_ollama(prompt, model_key):
    selected, err = resolve_model(model_key)
    if err:
        return err, None

    payload = json.dumps({
        "model": selected,
        "prompt": prompt,
        "stream": False,
        "keep_alive": "60m",
    }).encode("utf-8")

    req = urllib.request.Request(
        "http://localhost:11434/api/generate",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data.get("response", ""), selected
    except Exception as e:
        return "Ollama API error: %s" % str(e), selected


def query_with_crosscheck(prompt, primary_model_key):
    """Executes a 2-stage cross-check process. 
    1. Generates draft with primary model. 
    2. Reviews with Gemma4 26B."""
    draft_ans, primary_model = query_ollama(prompt, primary_model_key)
    if draft_ans.startswith("Ollama API error") or primary_model is None:
        return draft_ans, primary_model, None

    # If the primary model is already gemma, we skip cross-check to save time and redundancy
    if primary_model_key in ["general", "quick", "gemma", "gemma_full"]:
        return draft_ans, primary_model, None

    reviewer_model_key = "gemma"
    review_prompt = (
        "USER_REQUEST:\n" + prompt + "\n\n"
        "DRAFT_ANSWER:\n" + draft_ans + "\n\n"
        "INSTRUCTION:\n"
        "Please review the DRAFT_ANSWER for the USER_REQUEST. "
        "Fix any factual, logical, or formatting errors. "
        "Output ONLY the final, polished response. Do not include introductory phrases like 'Here is the revised version'."
    )
    final_ans, reviewer_model = query_ollama(review_prompt, reviewer_model_key)
    if final_ans.startswith("Ollama API error") or reviewer_model is None:
        # Fallback to draft if reviewer fails
        return draft_ans, primary_model, None

    return final_ans, primary_model, reviewer_model


# -- MCP JSON-RPC --
TOOL_DEFINITIONS = [
    {
        "name": "ask_auto",
        "description": "Smart Router: auto-selects best local model. Qwen Coder for code, Nemotron for reasoning/math, Gemma4-26B for complex general tasks, Gemma4-E4B for quick/simple tasks. Provide task_type to override.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "prompt": {"type": "string", "description": "The prompt to send"},
                "task_type": {
                    "type": "string",
                    "enum": ["code", "reasoning", "general", "quick"],
                    "description": "code=programming, reasoning=math/logic, general=complex text (26B), quick=simple/short tasks (26B). Auto-detected if omitted."
                }
            },
            "required": ["prompt"],
        },
    },
    {
        "name": "ask_gemma",
        "description": "Gemma4 26B - complex general reasoning, long analysis, document review (17GB, 262K context)",
        "inputSchema": {
            "type": "object",
            "properties": {"prompt": {"type": "string", "description": "The prompt to send"}},
            "required": ["prompt"],
        },
    },

    {
        "name": "ask_qwen",
        "description": "Qwen 2.5 Coder 32B - code generation, debugging, refactoring, code review",
        "inputSchema": {
            "type": "object",
            "properties": {"prompt": {"type": "string", "description": "The prompt to send"}},
            "required": ["prompt"],
        },
    },
    {
        "name": "ask_nemotron",
        "description": "Nemotron 3.5 Lightning - complex reasoning, math, geotechnical analysis, structural calc",
        "inputSchema": {
            "type": "object",
            "properties": {"prompt": {"type": "string", "description": "The prompt to send"}},
            "required": ["prompt"],
        },
    },
]

TOOL_TO_MODEL = {
    "ask_gemma":      "gemma",
    "ask_qwen":       "qwen",
    "ask_nemotron":   "nemotron",
}


def send_response(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def main():
    while True:
        line = sys.stdin.readline()
        if not line:
            break

        line = line.lstrip("\ufeff").strip()
        if not line:
            continue

        try:
            req = json.loads(line)
        except json.JSONDecodeError:
            continue

        req_id = req.get("id")
        method = req.get("method")

        if method == "initialize":
            send_response({
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {"tools": {}},
                    "serverInfo": {"name": "ollama-smart-router", "version": "4.0.0"},
                },
            })
            continue

        if method == "notifications/initialized":
            continue

        if method == "tools/list":
            send_response({
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {"tools": TOOL_DEFINITIONS},
            })
            continue

        if method == "tools/call":
            params = req.get("params", {})
            name = params.get("name", "")
            args = params.get("arguments", {})
            prompt = args.get("prompt", "")

            if name == "ask_auto":
                task_type = args.get("task_type", "")
                if not task_type:
                    task_type = classify_prompt(prompt)
                model_key = TASK_ROUTE.get(task_type, "gemma")
                ans, p_model, r_model = query_with_crosscheck(prompt, model_key)
                
                if r_model:
                    header = f"[Router: task={task_type} | Generated by {p_model} | Reviewed by {r_model}]\n\n"
                else:
                    header = f"[Router: task={task_type} | Generated by {p_model}]\n\n"
                ans = header + ans
            else:
                model_key = TOOL_TO_MODEL.get(name)
                if model_key:
                    ans, _ = query_ollama(prompt, model_key)
                else:
                    ans = "Invalid tool: %s" % name

            send_response({
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {"content": [{"type": "text", "text": ans}]},
            })
            continue

        if req_id is not None:
            send_response({
                "jsonrpc": "2.0",
                "id": req_id,
                "error": {"code": -32601, "message": "Method not found: %s" % method},
            })


if __name__ == "__main__":
    main()
