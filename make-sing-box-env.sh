#!/bin/bash
IFS_BAK=$IFS
IFS=$'\n'
set -e

echo "检查操作系统..."

if [[ "$(uname)" != "Darwin" ]]; then
  echo "本脚本仅支持 macOS。"
  exit 1
fi

echo "操作系统是 macOS"

# 检查 brew 是否已安装
if ! command -v brew >/dev/null 2>&1; then
  echo "未检测到 Homebrew，正在安装..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # 配置环境变量（适配 arm64）
  echo '正在设置环境变量...'
  arch_name="$(uname -m)"

  if [[ "$SHELL" == */zsh ]]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.bash_profile
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  echo "已安装 Homebrew"
fi

# 强制更新 Homebrew 本体和软件包信息
echo "正在更新 brew..."
brew update

# 安装 grep (GNU 版本)
echo "安装/升级 grep (GNU)..."
brew install grep || brew upgrade grep

# 安装 unar（解压 .rar/.zip）
echo "安装/升级 unar..."
brew install unar || brew upgrade unar

# 将 ggrep 设置为默认 grep（添加到 shell 配置）
if ! grep -q 'alias grep=' ~/.zshrc 2>/dev/null; then
  echo "alias grep='ggrep'" >> ~/.zshrc
  echo "添加 alias grep='ggrep' 到 ~/.zshrc"
fi

echo "所有工具安装完成，请重新打开终端或执行 'source ~/.zshrc'"

alias grep='ggrep'
command -v grep

USER_HOME="$HOME"
SING_BOX_DIR_PATH="${USER_HOME}/Desktop/sing-boxs"
if [[ ! -d ${SING_BOX_DIR_PATH} && ! -f ${SING_BOX_DIR_PATH} ]]; then
  SING_BOX_DIR=${SING_BOX_DIR_PATH}'/sing-box_config'
else
  SING_BOX_DIR_PATH=${SING_BOX_DIR_PATH}-$(uuidgen)
  SING_BOX_DIR=${SING_BOX_DIR_PATH}'/sing-box_config'
fi

# 订阅链接
echo "请输入你的订阅链接SUBS，不输入直接回车则使用默认但不保证节点有效:"
echo "默认 'https://panlongid.com/wp-content/uploads/nodelist/202508/20250901-base64-dmN9su.txt' "
read -r -s SUBS
SUBS=${SUBS:-'https://panlongid.com/wp-content/uploads/nodelist/202508/20250901-base64-dmN9su.txt'}
urlencode() {
  local LANG=C
  local length="${#1}"
  for (( i = 0; i < length; i++ )); do
    local c="${1:i:1}"
    case $c in
      [a-zA-Z0-9.~_-]) printf '%s' "$c" ;;
      *) printf '%%%02X' "'$c" ;;
    esac
  done
}
SUBS=$(urlencode ${SUBS})
# 规则策略模版
echo "请输入你的规则策略模版链接RULES，不输入直接回车则使用默认但不保证模版有效:"
echo "默认 'https://github.com/juewuy/ShellCrash/raw/master/rules/ShellClash_Full_Block.ini' "
read -r RULES
RULES=${RULES:-'https://github.com/juewuy/ShellCrash/raw/master/rules/ShellClash_Full_Block.ini'}
# 在线订阅转换API接口
echo "请输入你的在线订阅转换API链接SUBS_API，不输入直接回车则使用默认但不保证转换有效:"
echo "默认 'https://sub.d1.mk/sub' "
read -r SUBS_API
SUBS_API=${SUBS_API:-'https://sub.d1.mk/sub'}
SUB_URL=${SUBS_API}'?target=singbox&insert=true&new_name=true&scv=true&udp=true&exclude=&include=&url='${SUBS}'&config='${RULES}
SING_BOX_BIN_FILE_GZ="${SING_BOX_DIR_PATH}/sing-box-1.10.0-darwin-arm64.tar.gz"
SING_BOX_BIN_FILE="$(echo ${SING_BOX_BIN_FILE_GZ} | sed 's;.tar.gz;;g')"
SING_BOX_BIN_FILE_RENAME="${SING_BOX_DIR_PATH}/sing-box"
SING_BOX_PATH='/SagerNet/sing-box/releases/download/v1.10.0'
VERSION=$(basename $(echo ${SING_BOX_PATH} | sed 's;-;/;g') | tr 'A-Z' 'a-z' | sed 's;v;;g')
echo "https://github.com${SING_BOX_PATH}/sing-box-${VERSION}-darwin-arm64.tar.gz"
SING_BOX_BIN_FILE_URL="https://github.com${SING_BOX_PATH}/sing-box-${VERSION}-darwin-arm64.tar.gz"
UI_PATH=$(curl -SL --connect-timeout 30 -m 60 --speed-time 30 --speed-limit 1 --retry 2 -H "Connection: keep-alive" -k 'https://github.com/Zephyruso/zashboard/releases' | sed 's;";\n;g;s;tag;download;g' | grep '/download/' | head -n 1)
UI_URL="https://github.com${UI_PATH}/dist.zip"
UI_FILE=${SING_BOX_DIR}'/ui.zip'
GEOIP_URL='https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db'
GEOIP_FILE=${SING_BOX_DIR}'/geoip.db'
GEOSITE_URL='https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db'
GEOSITE_FILE=${SING_BOX_DIR}'/geosite.db'
TMP_FILE=${SING_BOX_DIR_PATH}'/temp_config.json'
OUT_FILE=${SING_BOX_DIR_PATH}'/out_config.json'
BASE_FILE=${SING_BOX_DIR_PATH}'/base_config.json'
SING_BOX_FILE=${SING_BOX_DIR_PATH}'/config.json'

BASE_SING_BOX_CONFIG_FIXSCRIPT=$(cat <<'469138946ba5fa'
# 需要用 Python 或 JSON 专用工具转换
#command -v python
import json
import sys

def ensure_tls_insecure(node):
    """
    为支持 TLS 的 outbound 节点插入 tls.insecure = true
    """
    if not isinstance(node, dict):
        return node

    tls_supported = {"http", "vmess", "trojan", "hysteria", "vless", "shadowtls", "tuic", "hysteria2", "anytls", "reality"}

    if node.get("type") in tls_supported:
        tls = node.get("tls")
        if isinstance(tls, dict):
            if "insecure" not in tls:
                tls["insecure"] = True
        else:
            node["tls"] = {"enabled": True, "insecure": True}

    return node

input_path = sys.argv[1]
output_path = sys.argv[2]

with open(input_path, "r", encoding="utf-8") as f:
    data = json.load(f)

if isinstance(data, dict) and isinstance(data.get("outbounds"), list):
    data["outbounds"] = [ensure_tls_insecure(node) for node in data["outbounds"]]

with open(output_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(f"修复完成，所有 outbounds 节点已确保包含 tls.insecure: true → {output_path}")
469138946ba5fa
)
BASE_CONFIG_FIXSCRIPT_FILE=${SING_BOX_DIR_PATH}'/subs-fix.py'
SING_BOX_START=${SING_BOX_DIR_PATH}'/sing-box-start.sh'

mkdir -pv ${SING_BOX_DIR}

curl -L -C - --retry 3 --retry-delay 5 --progress-bar -o ${SING_BOX_BIN_FILE_GZ} ${SING_BOX_BIN_FILE_URL}
curl -L -C - --retry 3 --retry-delay 5 --progress-bar -o ${UI_FILE} ${UI_URL}
curl -L -C - --retry 3 --retry-delay 5 --progress-bar -o ${GEOIP_FILE} ${GEOIP_URL}
curl -L -C - --retry 3 --retry-delay 5 --progress-bar -o ${GEOSITE_FILE} ${GEOSITE_URL}

unar -f ${SING_BOX_BIN_FILE_GZ} -o ${SING_BOX_DIR_PATH}
mv -fv ${SING_BOX_BIN_FILE}/sing-box ${SING_BOX_BIN_FILE_RENAME}
rm -frv ${SING_BOX_BIN_FILE}
chmod -v a+x ${SING_BOX_BIN_FILE_RENAME}
if [[ -d ${SING_BOX_DIR}/ui ]]; then
  rm -frv ${SING_BOX_DIR}/ui
fi
unzip -o ${SING_BOX_DIR}'/ui.zip' -d ${SING_BOX_DIR}
mv -fv ${SING_BOX_DIR}/dist ${SING_BOX_DIR}/ui

# 合并自定义头部 + 提取部分
echo "${BASE_SING_BOX_CONFIG_FIXSCRIPT}" > "${BASE_CONFIG_FIXSCRIPT_FILE}"

chmod -Rv a+x ${SING_BOX_DIR_PATH}
chown -Rv $USER ${SING_BOX_DIR_PATH}

cat << 469138946ba5fa | tee ${SING_BOX_START}
#!/bin/bash
IFS_BAK=\$IFS
IFS=\$'\n'
set -e

echo "start sing-box..."
if [ -f '${TMP_FILE}' ]; then
  rm -fv '${TMP_FILE}'
fi

# -L --retry 3 --retry-delay 5 --progress-bar 
if curl -L --retry 3 --retry-delay 5 --progress-bar -o '${TMP_FILE}' '${SUB_URL}'; then
    # curl 成功，继续检查文件内容
    if [ ! -s '${TMP_FILE}' ]; then # -s 检查文件是否存在且大小不为0
        echo "Error: ${TMP_FILE} is empty or not created after curl. Exiting."
        exit 1
    fi
    echo "Temporary config downloaded to ${TMP_FILE}"
else
    # curl 失败
    echo "Error: curl download failed. Exiting."
    exit 2
fi

cp -fv '${TMP_FILE}' '${SING_BOX_FILE}'

# 修复 sing-box config.json 中自动选择策略的 url-test 设置
if [ -f '${SING_BOX_FILE}' ]; then
    echo "正在增强自动选择策略组配置..."

    # 替换测试 URL 为更稳定的 Cloudflare
    # 修复 sing-box config.json 中自动选择策略的 url-test 设置
    # 修复 sing-box config.json 中自动选择策略的 url-test 设置
    jq '
      (.. | objects | select(has("url")))
        |= (.url = "http://cp.cloudflare.com/generate_204")
      | (.. | objects | select(has("interval")))
        |= (.interval = "180s")
      | (.. | objects | select(has("tolerance")))
        |= (.tolerance = 300)
      | (.. | objects | select(has("listen_port")))
        |= (.listen_port = 7890)
      | (.. | objects | select(has("external_controller")))
        |= (.external_controller = ":9999")
      | (.. | objects | select(has("external_ui")))
        |= (.external_ui = "ui")
      # 插入 DNS inbound 到顶层 inbounds 数组
      #| .inbounds += [{
      #    "type": "dns",
      #    "tag": "dns-in",
      #    "listen": "0.0.0.0",
      #    "listen_port": 53,
      #    "detour": "dns_proxy"
      #  }]
    ' '${SING_BOX_FILE}' > '${SING_BOX_FILE}.tmp' && mv '${SING_BOX_FILE}.tmp' '${SING_BOX_FILE}'
else
  echo "Error: ${SING_BOX_FILE} is not exist. Exiting."
  exit 3
fi

cp -fv '${SING_BOX_FILE}' '${SING_BOX_FILE}.bak'

# 每个人的系统环境如此的不同
# 假如你原本就有python环境，而我如果写了一个脚本安装python环境，那一定会破坏你原本的python环境
# 所以python环境这块，你自己搭建好吗？
if python '/Users/af5ab649831964/Desktop/sing-boxs/subs-fix.py' '${SING_BOX_FILE}.bak' '${SING_BOX_FILE}'; then
  echo ok
else
  cp -fv '${SING_BOX_FILE}.bak' '${SING_BOX_FILE}'
fi

echo "配置已生成: ${SING_BOX_FILE}"

# 配置 NAT 转发并做好标记方便删除
pf_nat_udp_tcp() {
  # 获取默认网卡和网段
  # 获取默认网卡
  IFACE=\$(route get default | awk '/interface: / {print \$2}')
  # 获取 IP 地址
  IP=\$(ipconfig getifaddr "\$IFACE")
  # 获取十六进制子网掩码
  NETMASK_HEX=\$(ifconfig "\$IFACE" | awk '/netmask/ {print \$4}' | sed 's/^0x//')
  # 转换为十进制
  NETMASK_DEC=\$((16#\$NETMASK_HEX))
  # 计算 CIDR 位数
  CIDR_BITS=\$(echo "obase=2; \$NETMASK_DEC" | bc | grep -o "1" | wc -l | tr -d '[:space:]')
  # 构造 CIDR 网段
  IFS=. read -r o1 o2 o3 o4 <<< "\$IP"
  CIDR="\${o1}.\${o2}.\${o3}.0/\${CIDR_BITS}"
  echo "网卡: \$IFACE"
  echo "IP: \$IP"
  echo "子网掩码: \$NETMASK_HEX"
  echo "CIDR 位数: \$CIDR_BITS"
  echo "CIDR 网段: \$CIDR"
  MARKER="# inserted-by-nat-script"
  #NAT_RULE='nat on en0 from 192.168.255.0/24 to any -> (en0)'
  #NAT_RULE="nat on \$IFACE from \$CIDR to any -> (\$IFACE) \$MARKER"
  #NAT_RULE="nat on \$IFACE from any to any -> (\$IFACE) \$MARKER"
  NAT_RULE='nat-anchor "singbox/*" '\$MARKER
  #RDR_RULE='rdr pass on en0 proto udp from any to any -> 172.19.0.1'
  #RDR_RULE="rdr pass on \$IFACE proto udp from any to any -> 172.19.0.1 \$MARKER"
  RDR_RULE='rdr-anchor "singbox/*" '\$MARKER
  ANCHOR_FILE="/etc/pf.anchors/singbox"
  PF_CONF="/etc/pf.conf"

  # 删除旧规则（带标记的）
  sudo sed -i '' "/\$MARKER/d" "\$PF_CONF"
  sudo rm -fv \$ANCHOR_FILE

  # 插入 NAT 规则
  # 检查 /etc/pf.conf 是否存在 nat-anchor
  if grep -q "nat-anchor" "\$PF_CONF"; then
      # 找到 anchor，使用原有方式插入
      sudo sed -i '' "/nat-anchor/a\\\\
\$NAT_RULE
" "\$PF_CONF"
  else
      # 没找到 anchor，直接追加到文件末尾
      #echo "\$NAT_RULE" | sudo tee -a "\$PF_CONF"
      printf '%s\n' "\$NAT_RULE" | sudo tee -a "\$PF_CONF"

  fi

  # 插入 RDR 规则
  # 检查 /etc/pf.conf 是否存在 rdr-anchor
  if grep -q "rdr-anchor" "\$PF_CONF"; then
      # 找到 anchor，使用原有方式插入
      sudo sed -i '' "/rdr-anchor/a\\\\
\$RDR_RULE
" "\$PF_CONF"
  else
      # 没找到 anchor，直接追加到文件末尾
      #echo "\$RDR_RULE" | sudo tee -a "\$PF_CONF"
      printf '%s\n' "\$RDR_RULE" | sudo tee -a "\$PF_CONF"
  fi

  # 写入 anchor 规则
  cat <<469138946ba5fa_1 | sudo tee \$ANCHOR_FILE
# NAT 所有来自局域网的流量
nat on \$IFACE from any to any -> (\$IFACE)

# DNS 劫持：所有设备的 DNS 请求转发到 TUN 网卡
rdr pass on \$IFACE proto udp from any to any port 53 -> 172.19.0.1 port 53

# TCP/UDP 流量转发到 sing-box 7890
#rdr pass on \$IFACE proto {tcp udp} from any to any -> 172.19.0.1 port 7890
# TCP/UDP 流量转发到 sing-box TUN
rdr pass on \$IFACE proto {tcp udp} from any to any -> 172.19.0.1
469138946ba5fa_1

  # 重载 PF 加载并启用 PF
  sudo pfctl -d 2>/dev/null || true
  sudo pfctl -f "\$PF_CONF" || true
  sudo pfctl -e || true
  sudo pfctl -s nat
}

pf_nat_udp_tcp

# 开启 IP 转发避免反复写入
NAT_IP='net.inet.ip.forwarding=1'
SYS_CONF='/etc/sysctl.conf'
if ! grep -qF "\$NAT_IP" "\$SYS_CONF"; then
  echo "\$NAT_IP" | sudo tee -a "\$SYS_CONF"
fi

# 关闭则 sudo sysctl -w net.inet.ip.forwarding=0
sudo sysctl -w net.inet.ip.forwarding=1

# 刷新 DNS 缓存
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

sudo pkill -f 'sing-box -D' || true
sudo '${SING_BOX_BIN_FILE_RENAME}' -D '${SING_BOX_DIR}' -c '${SING_BOX_FILE}' run
IFS=\$IFS_BAK
469138946ba5fa

chmod -v a+x ${SING_BOX_START}
echo "已生成启动脚本: ${SING_BOX_START}"

echo "如果想要全局路由你需要配置路由器 DHCP 下发的 NetGateway 强制为本机 IP 同时将下发 DNS  为修改为任意真实 DNS（如 1.1.1.1, 8.8.8.8 或 223.5.5.5）或路由器 IP ，不要设置为 172.19.0.1 或 fake-ip 地址"
echo "如果想要旁路由，你需要为单个联网设备配置 NetGateway 强制为本机 IP 同时将下发 DNS  为修改为任意真实 DNS（如 1.1.1.1, 8.8.8.8 或 223.5.5.5）或路由器 IP ，不要设置为 172.19.0.1 或 fake-ip 地址"
echo "如果想要端口代理，你需要将联网代理设置为本机 IP:7890"
echo "如果想要本机，那就什么都没什么可说的了"
echo "执行脚本 ${SING_BOX_START} 启动测试看看吧"

IFS=$IFS_BAK
