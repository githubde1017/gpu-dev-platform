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
