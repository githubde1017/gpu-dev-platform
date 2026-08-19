# 疑難排解：從零開始部署會遇到的問題

依照 `docs/00_wsl2_prerequisites.md` → `scripts/` 的執行順序，記錄每個階段第一次執行時最可能遇到的問題與排除方式。**建議照本文件「建議驗證順序」章節的順序執行，不要跳步驟**，才能在問題發生時快速定位是哪一層出錯。

---

## 階段一：WSL2安裝

### 問題1：BIOS虛擬化未開啟
**症狀**：`wsl --install`裝完，啟動distro時報錯（類似`WslRegisterDistribution failed with error 0x80370102`）。
**排除**：進BIOS/UEFI開啟「Intel Virtualization Technology」（VT-x）。

### 問題2：公司網域Group Policy封鎖虛擬化功能
**症狀**：一般使用者權限無法啟用Hyper-V/虛擬化平台功能。
**排除**：先確認公司IT是否有限制此政策，需IT協助放行。
**備註**：main-PC本身為獨立主機，非網域受管機器，不受此限制，此問題僅適用於網域受管的其他主機情境（例如未來若擴充到其他公司電腦）。

### 問題3：Windows版本過舊
**症狀**：`wsl --install`失敗或WSL2功能無法啟用。
**排除**：需Windows 10 2004+或Windows 11。跑`winver`確認版本，不足則先跑Windows Update，可能需重開機兩次以上。

---

## 階段二：NVIDIA驅動

### 問題4：不要在WSL2內裝Linux版NVIDIA驅動
**症狀**：在WSL2的Ubuntu裡`apt install nvidia-driver`會直接破壞GPU passthrough。
**排除**：**只在Windows端**裝一般Game Ready/Studio驅動（531版以上已內建WSL2 CUDA支援）。WSL2會自動透過`/usr/lib/wsl/lib`共用Windows端驅動，Ubuntu內完全不用裝驅動。

### 問題5：驅動版本過舊
RTX 5070是較新GPU，建議直接裝最新版驅動，避免WSL2 CUDA相容性問題。

---

## 階段三：Docker Desktop

### 問題6：WSL Integration忘記勾選
**症狀**：第一次`docker compose build`失敗，出現`docker: command not found`或`Cannot connect to the Docker daemon`。
**排除**：Docker Desktop → Settings → Resources → WSL Integration，確認`Ubuntu-22.04`已勾選啟用。

---

## 階段四：Port衝突（本專案特有）

### 問題7：Windows原生OpenSSH與WSL2的sshd搶Port 22
**症狀**：若先前裝過Windows原生OpenSSH Server（早期教學步驟），且WSL2設定了mirrored networking，兩邊會搶同一個Port 22，導致SSH連線行為不可預期。
**排除**：關閉Windows原生sshd服務：
```powershell
Get-Service sshd
Stop-Service sshd
Set-Service -Name sshd -StartupType Disabled
```
確認之後SSH連線走的是WSL2內的sshd。

---

## 階段五：Rootless Docker安裝

### 問題8：缺少uidmap / dbus-user-session依賴
**症狀**：`scripts/02_create_user.sh`執行到rootless安裝那步失敗，報錯要求`newuidmap`/`newgidmap`或dbus相關套件。
**排除**：跑腳本前先在主機（root權限）安裝：
```bash
sudo apt-get update && sudo apt-get install -y uidmap dbus-user-session
```

### 問題9：Rootless Docker的GPU支援需要額外設定
**症狀**：`docker-compose.yml`裡`deploy.resources.reservations.devices`寫法在rootless環境下不保證生效，容器內`nvidia-smi`看不到GPU。
**排除**：需要NVIDIA Container Toolkit產生CDI（Container Device Interface）規格：
```bash
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
```
且容器啟動可能需改用`--device nvidia.com/gpu=all`語法（rootless下`--gpus`旗標支援度不完整）。**建議先跑通`docker run --rm hello-world`確認rootless docker本身沒問題，再單獨測GPU passthrough，兩者分開驗證方便定位問題出在哪一層。**

---

## 建議驗證順序（強烈建議照此順序，不要跳步）

1. 確認BIOS虛擬化已開啟 → `wsl --install` → 重開機
2. Windows端裝NVIDIA驅動（**不要**在WSL2裡裝）
3. 裝Docker Desktop，確認WSL Integration已勾選 → 用**rootful**模式測試GPU passthrough底層是否打通：
   ```powershell
   docker run --rm --gpus all nvidia/cuda:12.3.0-base-ubuntu22.04 nvidia-smi
   ```
4. 關閉Windows原生OpenSSH服務（問題7）
5. 完成`docs/00_wsl2_prerequisites.md`：`/etc/wsl.conf`啟用systemd → `wsl --shutdown` → 重進WSL2確認`systemctl status`正常
6. 補裝`uidmap`/`dbus-user-session`（問題8）
7. 跑`scripts/02_create_user.sh` → 先驗證**不含GPU**的rootless docker：`docker run --rm hello-world`
8. 補CDI設定（問題9）→ 才測試容器內GPU passthrough
9. 跑`scripts/01_enable_gpu_sharing.sh`、`scripts/03_monitor_gpu.sh`

**關鍵原則**：第3步先用rootful模式驗證GPU passthrough，之後如果rootless GPU測試（第8步）失敗，能確定問題出在「rootless GPU額外設定」而非「WSL2/驅動本身沒打通」，比較好定位問題根源。

---

## 階段六：長期維運（部署完成後仍需注意）

### 問題10：Docker Desktop商業授權門檻
**說明**：Docker Desktop對企業使用有免費門檻——員工數超過250人或年營收超過1000萬美元，需訂閱Docker Business才合規。
**排除**：部署前先確認公司規模是否落在需付費範圍，避免上線後才發現授權不合規，屬法務/採購問題而非技術問題。

### 問題11：主機睡眠會切斷所有連線
**症狀**：Windows閒置一段時間自動睡眠，所有開發者SSH連線與運行中容器全部中斷。
**排除**：設定 → 電源與電池 → 螢幕與睡眠 → 「電源連接時，裝置在閒置後進入睡眠」設為「永不」。

### 問題12：內網IP浮動導致客端連線失效
**症狀**：DHCP自動配發IP時，路由器重開機或租約到期可能改變main-PC的IP，所有開發者`~/.ssh/config`裡寫死的`HostName`失效。
**排除**：在路由器設定裡為main-PC的MAC位址做DHCP保留，或直接在Windows網卡設定靜態IP。

### 問題13：WSL2虛擬磁碟（.vhdx）只增不減
**症狀**：即使WSL2內刪除檔案，`ext4.vhdx`實體佔用空間不會自動釋放，長期使用後可能膨脹到數十GB。
**排除**：定期壓縮，建議每季執行一次：
```powershell
wsl --shutdown
diskpart
# select vdisk file="C:\Users\<帳號>\AppData\Local\Packages\...\ext4.vhdx"
# compact vdisk
```

### 問題14：Port分配無中央登記，多人容易撞號
**症狀**：`.env`裡的`HOST_PORT`目前靠開發者自行挑選，兩人選到同一port會導致服務啟動失敗，錯誤訊息不一定直觀。
**排除**：見 `docs/03_port_allocation.md`，新增專案前先登記查閱，避免衝突。

### 問題15：防毒軟體掃描WSL2/Docker檔案拖慢效能
**症狀**：即時掃描監控WSL2的`.vhdx`或Docker overlay檔案系統，造成I/O效能下降，容器build/啟動明顯變慢。
**排除**：在防毒軟體設定中，將WSL相關路徑（`%LOCALAPPDATA%\Packages\*wsl*`）與Docker Desktop資料目錄加入掃描排除清單。

---

## 客端Shell選擇（PowerShell / Bash 皆可）

客端要用PowerShell、Git Bash、Windows Terminal或macOS/Linux Terminal都不影響——SSH連線與VS Code Remote-SSH操作跟客端shell無關，差異僅在連線前那幾個本機指令（`ssh-keygen`、查看`.ssh/config`）的語法習慣。連上主機後，VS Code整合終端機接的是遠端主機/容器內的bash，不會有跨平台語法混淆的問題。

PowerShell客端需留意：
- `ssh`指令仰賴Windows內建OpenSSH Client是否已裝（見問題「客端SSH client狀態」，與shell種類無關，是系統層級功能）
- 若之後要寫PowerShell腳本輔助設定，受限帳戶可能受Execution Policy限制而跑不動`.ps1`，需調整原則或請MIS協助，但這不影響單純用`ssh`/VS Code連線本身
