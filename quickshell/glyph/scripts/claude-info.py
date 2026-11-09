#!/usr/bin/env python3
"""Print Claude Code account, model and usage-limit info as JSON for the Quickshell bar.

Usage limits come from the same endpoint Claude Code's /usage uses (unofficial; may change).
The OAuth token is only sent to api.anthropic.com and is never printed.
"""

import glob
import json
import os
import socket
import subprocess
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

HOME = os.path.expanduser("~")

# urllib tries addresses one at a time and IPv6 stalls here, so try IPv4 first
_getaddrinfo = socket.getaddrinfo
socket.getaddrinfo = lambda *a, **k: sorted(_getaddrinfo(*a, **k), key=lambda r: r[0] != socket.AF_INET)
LIMIT_LABELS = {
    "session": "Current session",
    "weekly_all": "Weekly · all models",
    "weekly_opus": "Weekly · Opus",
    "weekly_sonnet": "Weekly · Sonnet",
}


def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def version():
    try:
        out = subprocess.run(["claude", "--version"], capture_output=True, text=True, timeout=5).stdout
        return out.split()[0] if out else ""
    except (OSError, subprocess.SubprocessError):
        return ""


def transcripts_since(ts):
    files = glob.glob(f"{HOME}/.claude/projects/*/*.jsonl")
    return sorted((f for f in files if os.path.getmtime(f) >= ts), key=os.path.getmtime, reverse=True)


def activity():
    """Last model used, plus today's sessions / messages / tokens from local transcripts."""
    midnight = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    last_model, sessions, messages, tokens_in, tokens_out = "", 0, 0, 0, 0
    for path in transcripts_since(midnight.timestamp()):
        counted = False
        try:
            with open(path) as f:
                for line in f:
                    if '"assistant"' not in line:
                        continue
                    try:
                        e = json.loads(line)
                    except ValueError:
                        continue
                    msg = e.get("message") or {}
                    if e.get("type") != "assistant" or not msg.get("model"):
                        continue
                    stamp = e.get("timestamp", "")
                    try:
                        when = datetime.fromisoformat(stamp.replace("Z", "+00:00")).astimezone()
                    except ValueError:
                        continue
                    if when.timestamp() < midnight.timestamp():
                        continue
                    if not last_model:
                        last_model = msg["model"]
                    counted = True
                    messages += 1
                    u = msg.get("usage") or {}
                    tokens_in += (u.get("input_tokens") or 0) + (u.get("cache_creation_input_tokens") or 0) \
                        + (u.get("cache_read_input_tokens") or 0)
                    tokens_out += u.get("output_tokens") or 0
        except OSError:
            continue
        sessions += counted

    # Nothing today: fall back to the most recent transcript for the model
    if not last_model:
        for path in transcripts_since(0)[:3]:
            try:
                with open(path) as f:
                    for line in f:
                        if '"model"' in line and '"assistant"' in line:
                            m = (json.loads(line).get("message") or {}).get("model")
                            last_model = m or last_model
            except (OSError, ValueError):
                continue
            if last_model:
                break

    return last_model, {"sessions": sessions, "messages": messages, "tokensIn": tokens_in, "tokensOut": tokens_out}


def usage(cred):
    if not cred.get("accessToken"):
        return None, "Not logged in to Claude Code"
    if cred.get("expiresAt", 0) / 1000 < time.time():
        return None, "Login expired — open Claude Code to refresh it"
    req = urllib.request.Request("https://api.anthropic.com/api/oauth/usage", headers={
        "Authorization": "Bearer " + cred["accessToken"],
        "anthropic-beta": "oauth-2025-04-20",
        "User-Agent": "claude-code/" + (version() or "2"),
    })
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.load(r), ""
    except urllib.error.HTTPError as e:
        return None, f"Usage request failed ({e.code})"
    except (urllib.error.URLError, OSError, ValueError):
        return None, "Couldn't reach Anthropic"


def main():
    state = load(f"{HOME}/.claude.json")
    settings = load(f"{HOME}/.claude/settings.json")
    cred = load(f"{HOME}/.claude/.credentials.json").get("claudeAiOauth", {})
    acct = state.get("oauthAccount") or {}

    last_model, today = activity()
    data, error = usage(cred)

    limits = []
    extra = None
    if data:
        for lim in data.get("limits") or []:
            limits.append({
                "label": LIMIT_LABELS.get(lim.get("kind"), (lim.get("kind") or "").replace("_", " ").capitalize()),
                "percent": lim.get("percent") or 0,
                "severity": lim.get("severity") or "normal",
                "resetsAt": lim.get("resets_at") or "",
                "active": bool(lim.get("is_active")),
            })
        ex = data.get("extra_usage") or {}
        if ex.get("is_enabled"):
            scale = 10 ** (ex.get("decimal_places") or 0)
            extra = {
                "used": (ex.get("used_credits") or 0) / scale,
                "limit": (ex.get("monthly_limit") or 0) / scale,
                "currency": ex.get("currency") or "",
            }

    print(json.dumps({
        "version": version(),
        "account": {
            "name": acct.get("displayName") or acct.get("fullName") or "",
            "email": acct.get("emailAddress") or "",
            "org": acct.get("organizationName") or "",
            "plan": cred.get("subscriptionType") or acct.get("billingType") or "",
        },
        "model": {"configured": settings.get("model") or "", "lastUsed": last_model},
        "limits": limits,
        "extra": extra,
        "today": today,
        "error": error,
        "fetchedAt": int(time.time()),
    }))


if __name__ == "__main__":
    main()
