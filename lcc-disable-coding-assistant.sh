#!/bin/bash
# JupyterLab LCC: disable the Kiro / Jupyter AI / ACP coding-assistant chat panel
# and stop the .agent/.kiro/.claude skill+agent artifacts from being created.
#
# Mirrors the config the SMD image already applies to SHARED spaces (which are
# confirmed clean): a server-extension disable drop-in AND a frontend
# page_config disabledExtensions block, written to the system jupyter paths.
# Also removes the skill/agent dirs that start-jupyter-server syncs for private
# spaces. Debug lines are tagged [LCC-DISABLE-CA] so they are greppable in the
# Studio CloudWatch logs for the space.
set -eux

echo "[LCC-DISABLE-CA] start $(date -u +%FT%TZ) HOME=$HOME whoami=$(whoami)"

SERVER_CONF_DIR="/opt/conda/etc/jupyter/jupyter_server_config.d"
LAB_SETTINGS_DIR="/opt/conda/share/jupyter/lab/settings"

echo "[LCC-DISABLE-CA] writing server-extension disable drop-in to $SERVER_CONF_DIR"
sudo mkdir -p "$SERVER_CONF_DIR"
sudo tee "$SERVER_CONF_DIR/zzz_disable_coding_assistant.json" >/dev/null <<'JSON'
{
    "ServerApp": {
        "jpserver_extensions": {
            "jupyter_ai": false,
            "jupyter_ai_acp_client": false,
            "jupyter_ai_tools": false,
            "jupyter_ai_persona_manager": false,
            "jupyter_ai_router": false,
            "jupyter_ai_chat_commands": false,
            "jupyter_server_mcp": false,
            "jupyterlab_chat": false,
            "jupyterlab_commands_toolkit": false,
            "jupyter_live_content": false
        }
    }
}
JSON

echo "[LCC-DISABLE-CA] writing frontend disabledExtensions to $LAB_SETTINGS_DIR/page_config.json"
sudo mkdir -p "$LAB_SETTINGS_DIR"
sudo tee "$LAB_SETTINGS_DIR/page_config.json" >/dev/null <<'JSON'
{
    "disabledExtensions": {
        "jupyterlab-chat-extension": true,
        "@jupyter-ai/router": true,
        "@jupyter-ai/persona-manager": true,
        "@jupyter-ai/acp-client": true,
        "@jupyter-ai/chat-commands": true,
        "jupyterlab-commands-toolkit": true,
        "jupyterlab-ai-commands": true,
        "@jupyter-ai-contrib/live-content": true,
        "jupyterlab-diff": true,
        "jupyterlab-cell-input-footer-extension": true
    }
}
JSON

echo "[LCC-DISABLE-CA] removing skill/agent artifact dirs from \$HOME"
rm -rf "$HOME/.agent" "$HOME/.kiro" "$HOME/.claude" "$HOME/untitled.chat" || true

echo "[LCC-DISABLE-CA] server conf dir listing:"; ls -la "$SERVER_CONF_DIR" || true
echo "[LCC-DISABLE-CA] lab settings dir listing:"; ls -la "$LAB_SETTINGS_DIR" || true
echo "[LCC-DISABLE-CA] HOME dotdirs after cleanup:"; ls -la "$HOME" | grep -E '\.agent|\.kiro|\.claude|untitled' || echo "[LCC-DISABLE-CA] none present"
echo "[LCC-DISABLE-CA] done $(date -u +%FT%TZ)"
