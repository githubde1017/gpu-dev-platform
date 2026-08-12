# 前置作業：WSL2 啟用 systemd

Rootless Docker需要`systemctl --user`管理服務，`loginctl enable-linger`也需要systemd支援。WSL2預設**沒有**啟用systemd，這是整套rootless方案能否運作的關鍵前提，必須在跑`scripts/02_create_user.sh`之前完成。

## 步驟

1. 進入WSL2：
```bash
wsl
```

2. 編輯設定檔：
```bash
sudo nano /etc/wsl.conf
```

3. 加入：
```ini
[boot]
systemd=true
```

4. 存檔後回到Windows PowerShell重啟WSL2：
```powershell
wsl --shutdown
```

5. 重新開啟WSL2，確認systemd已啟用：
```bash
systemctl status
```
應看到systemd正常運作（不是「System has not been booted with systemd」的錯誤）。

## 其他前提確認

- WSL2版本已裝，Docker Desktop已裝且勾選"Use WSL 2 instead of Hyper-V"
- GPU passthrough已驗證：`docker run --rm --gpus all nvidia/cuda:12.3.0-base-ubuntu22.04 nvidia-smi`能正常輸出GPU資訊
- `%USERPROFILE%\.wslconfig`已設定mirrored networking：
```ini
[wsl2]
networkingMode=mirrored
```
- 專案資料夾放在WSL2內部檔案系統（如`~/gpu-dev-platform`），不放`/mnt/c`底下
- Windows「使用中自動重新啟動裝置」已關閉（設定 → Windows Update → 進階選項）
