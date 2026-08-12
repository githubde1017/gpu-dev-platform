#!/usr/bin/env bash
set -euo pipefail

# 校正對象：HE08-PC, RTX 5070 12GB VRAM
VRAM_TOTAL_MB=12000
WARN_THRESHOLD_PCT=75
CRIT_THRESHOLD_PCT=90

while true; do
    clear
    echo "=========================================="
    echo " 📊 HE08-PC 資源監控 (12GB VRAM預算) — Ctrl+C 退出"
    echo "=========================================="

    VRAM_USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
    VRAM_PCT=$(( VRAM_USED * 100 / VRAM_TOTAL_MB ))

    echo "--- 🖥️ GPU 使用率 ---"
    nvidia-smi --query-gpu=utilization.gpu,utilization.memory,memory.used,memory.total --format=csv

    if [ "$VRAM_PCT" -ge "$CRIT_THRESHOLD_PCT" ]; then
        echo -e "\n🔴 嚴重警告：VRAM佔用已達 ${VRAM_PCT}%！新增任務可能OOM失敗，請協調其他使用者釋放資源。"
    elif [ "$VRAM_PCT" -ge "$WARN_THRESHOLD_PCT" ]; then
        echo -e "\n🟡 警告：VRAM佔用已達 ${VRAM_PCT}%，建議暫緩啟動新的重GPU任務。"
    else
        echo -e "\n🟢 VRAM佔用 ${VRAM_PCT}%，資源充裕。"
    fi

    echo -e "\n--- ⚡ 顯存佔用程序清單 ---"
    nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv

    echo -e "\n--- ℹ️ 容器級別清單需個別使用者以自己身份查詢（Rootless架構已知限制）---"

    sleep 3
done
