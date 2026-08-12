#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo " 🚀 正在配置 GPU 算力共享機制 "
echo "=========================================="

if grep -qi "microsoft" /proc/version; then
    echo "ℹ️ 檢測到 Windows WSL2 環境。"
    echo "⚠️ WSL2 目前無官方 NVIDIA MPS 支援，退回預設 GPU context switching（排隊式）機制，"
    echo "   非平行處理，多人重任務同時執行會互相排隊等待，建議人為錯開使用時段。"
    echo "✅ GPU 直通已就緒（依賴 Docker Desktop 的 WSL2 GPU passthrough）。"
else
    echo "ℹ️ 檢測到原生 Linux 環境，啟動 NVIDIA MPS..."
    export CUDA_VISIBLE_DEVICES=0
    sudo nvidia-smi -i 0 -c EXCLUSIVE_PROCESS || true
    sudo mkdir -p /tmp/nvidia-mps /tmp/nvidia-log
    sudo chmod 777 /tmp/nvidia-mps /tmp/nvidia-log
    sudo nvidia-cuda-mps-control -d
    echo "✅ NVIDIA MPS 已啟動。"
fi
