# 客端（開發者筆電）VS Code 設置

## Step 1：產生SSH金鑰

```bash
ssh-keygen -t ed25519 -C "你的名字"
```
把`.pub`內容提供給主機管理者，用於`scripts/02_create_user.sh`。

## Step 2：安裝VS Code擴充功能

- **Remote - SSH**（連線到主機帳號）
- **Dev Containers**（連線後進入專屬容器）

## Step 3：設定SSH連線

`~/.ssh/config`（Windows是`C:\Users\你的名字\.ssh\config`）：
```text
Host DevHost-<你的帳號>
    HostName <主機區網IP>
    User <你的帳號>
    IdentityFile ~/.ssh/id_ed25519
    Port 22
```

## Step 4：連線並開啟專案

1. `F1` → `Remote-SSH: Connect to Host` → 選對應的Host
2. `File → Open Folder` → 選`~/projects/<專案名>`
3. `F1` → `Dev Containers: Reopen in Container`

## Step 5：驗證

容器內Terminal執行：
```bash
nvidia-smi
```
能看到GPU資訊即代表整條鏈路打通。
