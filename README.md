# gpu-dev-platform

main-PC（RTX 5070 12GB / 64GB RAM / Windows + WSL2）一機多人共用開發環境。

**架構**：VS Code Remote-SSH + Rootless Docker（每人獨立、無docker群組提權）+ WSL2 GPU passthrough

## 目錄結構

```
gpu-dev-platform/
├── README.md
├── .gitignore
├── docs/
│   ├── 00_wsl2_prerequisites.md      # 【必讀，第一步】WSL2啟用systemd等前提
│   ├── 01_client_setup.md            # 開發者筆電端VS Code設置
│   ├── 02_troubleshooting.md         # 【首次部署必讀】從零建置常見問題與排除，含長期維運注意事項
│   └── 03_port_allocation.md         # Port分配登記表，新增專案前先查閱
├── scripts/
│   ├── 01_enable_gpu_sharing.sh      # GPU共享機制（WSL2智能感知）
│   ├── 02_create_user.sh             # 開發者開戶（含Rootless Docker安裝）
│   └── 03_monitor_gpu.sh             # 資源監控（12GB VRAM告警閾值）
├── templates/
│   └── devcontainer-template/        # 開發者建立新專案時複製這份
│       ├── Dockerfile                # 非特權使用者(vscode)容器映像
│       ├── docker-compose.yml
│       ├── .devcontainer/devcontainer.json
│       └── .env.example
└── data/
    └── shared/
        ├── datasets/                 # 共用資料集（唯讀掛載給各容器）
        └── models/                   # 共用模型權重（唯讀掛載給各容器）
```

## 快速開始（管理者）

> ⚠️ 若main-PC尚未安裝WSL2，請先完整閱讀 `docs/02_troubleshooting.md`，照裡面「建議驗證順序」章節逐步執行，可預先避開首次部署最常見的9個坑（BIOS虛擬化、驅動裝錯位置、Port衝突、Rootless GPU設定等）。

1. 完成 `docs/00_wsl2_prerequisites.md` 全部步驟
2. Clone本repo到WSL2內部檔案系統（不要放`/mnt/c`）：
   ```bash
   git clone <repo-url> ~/gpu-dev-platform
   cd ~/gpu-dev-platform
   chmod +x scripts/*.sh
   ```
3. 啟用GPU共享：
   ```bash
   sudo ./scripts/01_enable_gpu_sharing.sh
   ```
4. 為每位開發者開戶（取得對方SSH公鑰後執行）：
   ```bash
   sudo ./scripts/02_create_user.sh alice "ssh-ed25519 AAAA...alice的公鑰"
   ```
5. 驗證該使用者rootless docker可用：
   ```bash
   sudo -u alice -i
   source ~/.bashrc
   docker run --rm hello-world
   ```
6. （選用）開一個Terminal常駐監控：
   ```bash
   sudo ./scripts/03_monitor_gpu.sh
   ```

## 快速開始（開發者）

參照 `docs/01_client_setup.md` 設定VS Code，SSH連上主機後：

```bash
mkdir -p ~/projects/<專案名>
cp -r ~/gpu-dev-platform/templates/devcontainer-template/* ~/projects/<專案名>/
cp -r ~/gpu-dev-platform/templates/devcontainer-template/.devcontainer ~/projects/<專案名>/
cd ~/projects/<專案名>
cp .env.example .env
# 編輯 .env：DEV_USER=你的帳號, COMPOSE_PROJECT_NAME=專案名, HOST_PORT=分配給你的port區段
```
VS Code開啟這個資料夾 → `F1` → `Dev Containers: Reopen in Container`。

## ⚠️ 12GB VRAM為共用硬限制

多人同時各自跑中大型本地模型會直接爆VRAM。啟動本地模型前請先跑`nvidia-smi`或看`03_monitor_gpu.sh`確認目前佔用，並在團隊頻道知會協調，避免衝突。詳細預算表另見團隊內部文件。

## Git協作規範

- `.env`、`secrets/`、`ssh-keys/*.pub`已在`.gitignore`排除，勿手動加回
- `templates/`裡的範本異動需通知全體開發者（影響大家新建專案的基礎映像）
- `scripts/`異動建議PR review後再合併，這些腳本涉及帳號與權限，改錯會影響所有人
