#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
    echo "使用方式: sudo $0 <使用者名稱> \"<SSH_Pub_Key內容>\""
    exit 1
fi

USERNAME="$1"
SSH_PUB_KEY="$2"
USER_HOME="/home/${USERNAME}"

echo "=========================================="
echo " 🛡️ 建立開發者帳號: ${USERNAME}"
echo "=========================================="

# 1. 建立帳號（無docker群組，避免root等效提權）
if id "${USERNAME}" &>/dev/null; then
    echo "⚠️ 帳號已存在，跳過建立。"
else
    sudo adduser --disabled-password --gecos "" "${USERNAME}"
fi

# 2. 家目錄權限鎖定
sudo chown -R "${USERNAME}:${USERNAME}" "${USER_HOME}"
sudo chmod 700 "${USER_HOME}"

# 3. SSH金鑰配置
sudo -u "${USERNAME}" mkdir -p "${USER_HOME}/.ssh"
echo "${SSH_PUB_KEY}" | sudo -u "${USERNAME}" tee "${USER_HOME}/.ssh/authorized_keys" > /dev/null
sudo chmod 700 "${USER_HOME}/.ssh"
sudo chmod 600 "${USER_HOME}/.ssh/authorized_keys"
sudo chown -R "${USERNAME}:${USERNAME}" "${USER_HOME}/.ssh"

# 4. 啟用linger，讓rootless docker在沒有SSH session時也能持續運行
#    （需要WSL2先啟用systemd，見 docs/00_wsl2_prerequisites.md）
sudo loginctl enable-linger "${USERNAME}"

# 5. 實際安裝並啟動Rootless Docker
echo "🐳 安裝Rootless Docker..."
sudo -u "${USERNAME}" bash -c '
    curl -fsSL https://get.docker.com/rootless | sh
    mkdir -p ~/.config/systemd/user
'
USER_UID=$(id -u "${USERNAME}")

sudo -u "${USERNAME}" bash -c "cat >> ${USER_HOME}/.bashrc" <<EOF

# Rootless Docker 環境變數
export PATH=${USER_HOME}/bin:\$PATH
export DOCKER_HOST=unix:///run/user/${USER_UID}/docker.sock
EOF

sudo -u "${USERNAME}" env XDG_RUNTIME_DIR="/run/user/${USER_UID}" \
    systemctl --user enable docker
sudo -u "${USERNAME}" env XDG_RUNTIME_DIR="/run/user/${USER_UID}" \
    systemctl --user start docker

# 6. 建立預設專案資料夾
sudo -u "${USERNAME}" mkdir -p "${USER_HOME}/projects"

echo "✅ 帳號 ${USERNAME} 設定完成！"
echo "🔒 隔離層級：無docker群組提權 + 家目錄700 + Rootless Docker"
echo "💡 提醒${USERNAME}首次登入後執行: source ~/.bashrc"
echo "💡 驗證方式: sudo -u ${USERNAME} -i 後執行 docker run --rm hello-world"
