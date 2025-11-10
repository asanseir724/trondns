#!/bin/bash

set -e

# تابع برای بررسی وجود قفل dpkg
check_dpkg_lock() {
    # روش 1: استفاده از lsof (اگر موجود باشد)
    if command -v lsof >/dev/null 2>&1; then
        if sudo lsof /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
           sudo lsof /var/lib/dpkg/lock >/dev/null 2>&1 || \
           sudo lsof /var/cache/apt/archives/lock >/dev/null 2>&1; then
            return 0  # قفل وجود دارد
        fi
    # روش 2: استفاده از fuser (اگر lsof موجود نباشد)
    elif command -v fuser >/dev/null 2>&1; then
        if sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
           sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
           sudo fuser /var/cache/apt/archives/lock >/dev/null 2>&1; then
            return 0  # قفل وجود دارد
        fi
    # روش 3: بررسی وجود فایل قفل (کمتر دقیق)
    else
        if [ -f /var/lib/dpkg/lock-frontend ] || [ -f /var/lib/dpkg/lock ] || [ -f /var/cache/apt/archives/lock ]; then
            return 0  # احتمالاً قفل وجود دارد
        fi
    fi
    return 1  # قفل آزاد است
}

# تابع برای دریافت PID پروسه‌ای که قفل را نگه داشته
get_lock_pid() {
    if command -v lsof >/dev/null 2>&1; then
        sudo lsof -t /var/lib/dpkg/lock-frontend 2>/dev/null | head -1
    elif command -v fuser >/dev/null 2>&1; then
        sudo fuser /var/lib/dpkg/lock-frontend 2>/dev/null | awk '{print $1}' | head -1
    else
        ps aux | grep -E "unattended-upgr|apt|dpkg" | grep -v grep | awk '{print $2}' | head -1
    fi
}

# تابع برای انتظار برای آزاد شدن قفل dpkg
wait_for_dpkg_lock() {
    local timeout=${1:-300}  # پیش‌فرض 5 دقیقه
    local elapsed=0
    local check_interval=5
    
    echo "🔍 بررسی قفل dpkg..."
    
    while [ $elapsed -lt $timeout ]; do
        # بررسی وجود قفل
        if ! check_dpkg_lock; then
            echo "✅ قفل dpkg آزاد شد."
            return 0
        fi
        
        # نمایش پروسه‌ای که قفل را نگه داشته
        LOCK_PID=$(get_lock_pid)
        if [ ! -z "$LOCK_PID" ]; then
            LOCK_PROC=$(ps -p $LOCK_PID -o comm= 2>/dev/null || echo "unknown")
            echo "⏳ منتظر آزاد شدن قفل dpkg... (پروسه: $LOCK_PROC, PID: $LOCK_PID) - ${elapsed}s/${timeout}s"
        else
            echo "⏳ منتظر آزاد شدن قفل dpkg... - ${elapsed}s/${timeout}s"
        fi
        
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    echo "❌ خطا: قفل dpkg پس از $timeout ثانیه آزاد نشد."
    echo "💡 راه حل‌های پیشنهادی:"
    echo "   1. منتظر بمانید تا unattended-upgrades تمام شود:"
    echo "      sudo systemctl status unattended-upgrades"
    echo "   2. یا غیرفعال کنید (موقت):"
    echo "      sudo systemctl stop unattended-upgrades"
    echo "      sudo systemctl disable unattended-upgrades"
    echo "   3. یا دستی قفل را آزاد کنید (خطرناک - فقط در صورت اطمینان):"
    echo "      sudo killall unattended-upgr"
    echo "      sudo rm /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock"
    return 1
}

# تابع برای اجرای دستورات apt با مدیریت قفل
run_apt_command() {
    local cmd="$1"
    local description="${2:-اجرای دستور apt}"
    
    echo "🔧 $description..."
    
    # انتظار برای آزاد شدن قفل
    if ! wait_for_dpkg_lock 300; then
        echo "⚠️  هشدار: نتوانست برای قفل dpkg منتظر بماند. تلاش برای ادامه..."
        # اگر کاربر می‌خواهد ادامه دهد، می‌تواند این خط را uncomment کند
        # return 1
    fi
    
    # اجرای دستور با retry
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if sudo $cmd; then
            return 0
        fi
        
        retry=$((retry + 1))
        if [ $retry -lt $max_retries ]; then
            echo "⚠️  خطا در اجرای دستور. تلاش مجدد ($retry/$max_retries)..."
            sleep 5
            wait_for_dpkg_lock 60  # انتظار کوتاه‌تر برای retry
        fi
    done
    
    echo "❌ خطا: نتوانست دستور را پس از $max_retries تلاش اجرا کند."
    return 1
}

echo "🚀 شروع نصب ByoSH از سورس ..."

# [1/10] به‌روزرسانی پکیج‌ها
echo "[1/10] به‌روزرسانی پکیج‌ها..."
run_apt_command "apt update -y" "به‌روزرسانی لیست پکیج‌ها"
run_apt_command "apt upgrade -y" "به‌روزرسانی پکیج‌ها"

# [2/10] نصب وابستگی‌ها
echo "[2/10] نصب وابستگی‌ها (Python3, pip, Docker, Git, Curl)..."
run_apt_command "apt install -y python3 python3-pip curl git docker.io" "نصب وابستگی‌ها"

# فعال‌سازی و شروع داکر
sudo systemctl enable docker
sudo systemctl start docker

# [3/10] دریافت سورس ByoSH
echo "[3/10] دریافت سورس ByoSH..."
if [ ! -d "byosh" ]; then
  git clone https://github.com/mosajjal/byosh || { echo "❌ خطا در clone کردن ByoSH"; exit 1; }
fi
cd byosh || { echo "❌ خطا: نتوانست به پوشه byosh برود"; exit 1; }

# [4/10] غیرفعال کردن systemd-resolved و سایر سرویس‌های DNS
echo "[4/10] غیرفعال کردن systemd-resolved و سایر سرویس‌های DNS برای آزاد کردن پورت 53..."
# غیرفعال کردن systemd-resolved
if systemctl is-active --quiet systemd-resolved; then
  sudo systemctl stop systemd-resolved
fi
if systemctl is-enabled --quiet systemd-resolved; then
  sudo systemctl disable systemd-resolved
fi

# غیرفعال کردن dnsmasq (اگر نصب شده باشد)
if command -v dnsmasq &> /dev/null || systemctl list-unit-files 2>/dev/null | grep -q dnsmasq.service; then
  echo "🔧 غیرفعال کردن dnsmasq..."
  sudo systemctl stop dnsmasq 2>/dev/null || true
  sudo systemctl disable dnsmasq 2>/dev/null || true
  # همچنین از mask استفاده می‌کنیم تا حتی در صورت enable شدن هم start نشود
  sudo systemctl mask dnsmasq 2>/dev/null || true
fi

# تنظیم resolv.conf
sudo rm -f /etc/resolv.conf
echo "127.0.0.1 $(hostname)" | sudo tee -a /etc/hosts
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# [5/10] اصلاح Dockerfile برای نصب dnslib
echo "[5/10] اصلاح Dockerfile..."
if [ ! -f "Dockerfile" ]; then
  echo "⚠️  هشدار: فایل Dockerfile پیدا نشد!"
else
  sed -i 's|pip3 install --no-cache-dir dnslib|pip3 install --no-cache-dir --break-system-packages dnslib|' Dockerfile || { echo "⚠️  خطا در اصلاح Dockerfile"; }
fi

# [5.5/10] بررسی و اصلاح پوشه domain برای حذف دامنه‌های EA/FIFA
echo "[5.5/10] بررسی و اصلاح پوشه domain..."
if [ -d "domain" ] || [ -d "domine" ]; then
  DOMAIN_DIR=""
  if [ -d "domain" ]; then
    DOMAIN_DIR="domain"
  elif [ -d "domine" ]; then
    DOMAIN_DIR="domine"
  fi
  
  if [ ! -z "$DOMAIN_DIR" ]; then
    echo "🔍 بررسی فایل‌های دامنه در پوشه $DOMAIN_DIR..."
    # بکاپ از فایل‌های domain
    sudo cp -r "$DOMAIN_DIR" "${DOMAIN_DIR}.backup" 2>/dev/null || true
    
    # لیست دامنه‌های EA/FIFA که باید حذف شوند
    EA_DOMAINS=(
      "ea.com"
      "fifa.com"
      "easports.com"
      "origin.com"
      "eagames.com"
      "fut.ea.com"
      "accounts.ea.com"
      "api.ea.com"
      "*.ea.com"
      "*.fifa.com"
    )
    
    # جستجو و حذف دامنه‌های EA/FIFA از تمام فایل‌ها
    while IFS= read -r file; do
      [ -z "$file" ] && continue
      FILE_MODIFIED=false
      for domain in "${EA_DOMAINS[@]}"; do
        # escape کردن دامنه برای استفاده در regex
        if [[ "$domain" == *"*"* ]]; then
          # برای wildcard domains
          ESCAPED_DOMAIN=$(echo "$domain" | sed 's/\./\\./g' | sed 's/\*/.*/g')
        else
          # برای دامنه‌های عادی
          ESCAPED_DOMAIN=$(echo "$domain" | sed 's/\./\\./g')
        fi
        
        # بررسی و حذف خطوط شامل دامنه
        if grep -q "$ESCAPED_DOMAIN\|$domain" "$file" 2>/dev/null; then
          if [ "$FILE_MODIFIED" = false ]; then
            echo "🗑️  حذف دامنه‌های EA/FIFA از $file..."
            FILE_MODIFIED=true
          fi
          # حذف خطوطی که شامل دامنه هستند
          sed -i "/$ESCAPED_DOMAIN/d" "$file" 2>/dev/null || true
          sed -i "/$domain/d" "$file" 2>/dev/null || true
        fi
      done
    done < <(find "$DOMAIN_DIR" -type f 2>/dev/null)
    
    echo "✅ دامنه‌های EA/FIFA از پوشه $DOMAIN_DIR حذف شدند."
    echo "💡 این کار باعث می‌شود که برای این دامنه‌ها به DNS عمومی fallback شود."
  fi
fi

# [5.6/10] اضافه کردن fallback DNS به کد ByoSH (اگر فایل Python وجود دارد)
echo "[5.6/10] بررسی کد ByoSH برای اضافه کردن fallback..."
# پیدا کردن فایل‌های Python اصلی
PYTHON_FILES=$(find . -name "*.py" -type f 2>/dev/null | head -5)
if [ ! -z "$PYTHON_FILES" ]; then
  echo "📝 فایل‌های Python پیدا شد. برای fallback کامل، ممکن است نیاز به بررسی دستی باشد."
fi

# [6/10] ساخت ایمیج
echo "[6/10] ساخت ایمیج سفارشی ByoSH ..."
sudo docker build . -t byosh:myown

# [7/10] دریافت IP و تنظیم iptables
echo "[7/10] دریافت IP و تنظیم iptables..."
echo "لطفاً IP عمومی سرور را وارد کنید:"
read PUBIP

echo "🔧 حذف قوانین مسدودکننده iptables برای پورت‌های مورد نیاز..."
sudo iptables -D INPUT -p udp --dport 53 -j DROP 2>/dev/null || true
sudo iptables -D INPUT -p tcp --dport 53 -j DROP 2>/dev/null || true
sudo iptables -D INPUT -p tcp --dport 80 -j DROP 2>/dev/null || true
sudo iptables -D INPUT -p tcp --dport 443 -j DROP 2>/dev/null || true

# [8/10] بررسی پورت 53 و اجرای کانتینر
echo "[8/10] بررسی پورت 53 و اجرای کانتینر ByoSH ..."

# بررسی و متوقف کردن هر سرویسی که روی پورت 53 در حال اجراست
if sudo netstat -tuln 2>/dev/null | grep -q ":53 " || sudo ss -tuln 2>/dev/null | grep -q ":53 "; then
  echo "⚠️  پورت 53 در حال استفاده است. متوقف کردن سرویس‌های DNS..."
  
  # متوقف کردن تمام سرویس‌های DNS ممکن
  sudo systemctl stop dnsmasq 2>/dev/null || true
  sudo systemctl stop systemd-resolved 2>/dev/null || true
  sudo systemctl stop bind9 2>/dev/null || true
  sudo systemctl stop named 2>/dev/null || true
  
  # اگر کانتینر قبلی وجود دارد، آن را متوقف می‌کنیم
  sudo docker stop test-dns 2>/dev/null || true
  sleep 2
fi

sudo docker rm -f test-dns || true
sudo docker run -d --name test-dns --restart=always \
  -p 53:53/udp \
  -p 443:443 \
  -p 80:80 \
  --net=host \
  -e PUB_IP=$PUBIP \
  byosh:myown

# توضیح درباره fallback
echo ""
echo "📌 نکته مهم درباره fallback DNS:"
echo "   با حذف دامنه‌های EA/FIFA از لیست domain، این دامنه‌ها"
echo "   باید از طریق DNS عمومی (8.8.8.8) resolve شوند."
echo "   اگر ByoSH fallback داخلی نداشته باشد، ممکن است نیاز باشد"
echo "   تنظیمات DNS در سیستم عامل به صورت ترکیبی استفاده شود:"
echo "   DNS اول: $PUBIP (ByoSH)"
echo "   DNS دوم: 8.8.8.8 (Google DNS برای fallback)"

echo "✅ نصب و اجرای ByoSH کامل شد."
echo "📌 DNS Server روی پورت 53 اجرا شده است."
echo "📌 آدرس سرور: $PUBIP"

# [9/10] ایجاد پوشه py-api و کپی main.py
echo "[9/10] ایجاد پوشه py-api و کپی main.py..."
cd ~ || cd /root || cd "$HOME"
if [ ! -d "py-api" ]; then
  mkdir -p py-api
fi

# دانلود main.py از گیت‌هاب (از پوشه py-api در ریپازیتوری)
echo "📥 دانلود main.py از گیت‌هاب..."
cd py-api || { echo "❌ خطا: نتوانست به پوشه py-api برود"; exit 1; }

# استفاده از همان ریپازیتوری که اسکریپت از آن اجرا می‌شود
# اگر GITHUB_USER و GITHUB_REPO تعریف شده باشند، استفاده می‌کنیم
GITHUB_USER="${GITHUB_USER:-asanseir724}"
GITHUB_REPO="${GITHUB_REPO:-trondns}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"

# تلاش برای دانلود از گیت‌هاب
wget -q "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH/py-api/main.py" -O main.py 2>/dev/null || \
curl -sL "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH/py-api/main.py" -o main.py 2>/dev/null || {
  echo "⚠️  خطا در دانلود از گیت‌هاب. تلاش با لینک اصلی..."
  wget -q https://mjsd.ir/main.py -O main.py || { 
    echo "❌ خطا: نتوانست main.py را دانلود کند"
    echo "💡 لطفاً دستی دانلود کنید:"
    echo "   cd ~/py-api"
    echo "   wget https://mjsd.ir/main.py -O main.py"
    exit 1
  }
}

if [ -f main.py ]; then
  echo "✅ فایل main.py در پوشه ~/py-api دانلود شد."
else
  echo "❌ خطا: فایل main.py پیدا نشد!"
  exit 1
fi

# [10/10] نصب Flask و اجرای main.py
echo "[10/10] نصب Flask و راه‌اندازی API..."
pip3 install flask --break-system-packages 2>/dev/null || pip3 install flask || { echo "⚠️  خطا در نصب Flask - لطفاً دستی نصب کنید: pip3 install flask"; }

echo ""
echo "🚀 راه‌اندازی API Server..."

# بررسی و متوقف کردن API Server قبلی (اگر در حال اجرا باشد)
if pgrep -f "python3.*main.py" > /dev/null; then
  OLD_PID=$(pgrep -f "python3.*main.py")
  echo "⚠️  API Server قبلی با PID $OLD_PID پیدا شد. متوقف کردن..."
  kill $OLD_PID 2>/dev/null || sudo kill $OLD_PID 2>/dev/null || true
  sleep 2
fi

# بررسی پورت 5000
if sudo netstat -tuln 2>/dev/null | grep -q ":5000 " || sudo ss -tuln 2>/dev/null | grep -q ":5000 "; then
  PORT_PID=$(sudo lsof -ti:5000 2>/dev/null | head -1 || sudo fuser 5000/tcp 2>/dev/null | awk '{print $2}')
  if [ ! -z "$PORT_PID" ]; then
    echo "⚠️  پورت 5000 توسط پروسه $PORT_PID اشغال است. متوقف کردن..."
    sudo kill $PORT_PID 2>/dev/null || true
    sleep 2
  fi
fi

echo "⚠️  توجه: این دستور در background اجرا خواهد شد."
echo ""

# اجرای main.py در background
cd ~/py-api || cd /root/py-api || cd "$HOME/py-api"
sudo nohup python3 main.py > /tmp/py-api.log 2>&1 &
API_PID=$!
sleep 3

# بررسی اینکه آیا پروسه در حال اجراست
if ps -p $API_PID > /dev/null 2>&1; then
  echo "✅ API Server با PID $API_PID در حال اجرا است."
  echo "📝 لاگ‌ها در /tmp/py-api.log ذخیره می‌شوند."
  echo "💡 برای مشاهده لاگ: tail -f /tmp/py-api.log"
  echo "💡 برای متوقف کردن: kill $API_PID"
else
  # بررسی لاگ برای خطا
  if grep -q "Address already in use\|Port.*is in use" /tmp/py-api.log 2>/dev/null; then
    echo "❌ خطا: پورت 5000 هنوز در حال استفاده است."
    echo "💡 لطفاً دستی بررسی کنید:"
    echo "   sudo lsof -i:5000"
    echo "   یا"
    echo "   sudo netstat -tulpn | grep 5000"
    echo "   سپس پروسه را متوقف کنید و دوباره تلاش کنید."
  else
    echo "⚠️  هشدار: ممکن است API Server شروع نشده باشد."
    echo "💡 برای مشاهده خطاها: cat /tmp/py-api.log"
    echo "💡 برای اجرای دستی: cd ~/py-api && sudo python3 main.py"
  fi
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ نصب و راه‌اندازی کامل شد!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "🌐 DNS Server:"
echo "   IP: $PUBIP"
echo "   پورت: 53 (UDP)"
echo ""
echo "🔗 API Server:"
echo "   URL: http://$PUBIP:5000"
echo "   لاگ: /tmp/py-api.log"
echo ""
echo "📋 راه حل مشکل بازی آنلاین فیفا:"
echo "   دامنه‌های EA/FIFA از لیست domain حذف شدند."
echo "   برای اتصال آنلاین در فیفا، باید از DNS ترکیبی استفاده کنید:"
echo ""
echo "   🔧 در تنظیمات DNS سیستم خود (کنسول/کامپیوتر):"
echo "      DNS اول: $PUBIP"
echo "      DNS دوم: 8.8.8.8 (یا 1.1.1.1)"
echo ""
echo "   این باعث می‌شود که:"
echo "   - دامنه‌های در لیست ByoSH → از ByoSH resolve شوند"
echo "   - دامنه‌های EA/FIFA → از Google DNS resolve شوند"
echo ""
echo "💡 دستورات مفید:"
echo "   # تست DNS:"
echo "   dig @$PUBIP google.com"
echo "   dig @8.8.8.8 accounts.ea.com"
echo ""
echo "   # مشاهده وضعیت:"
echo "   sudo docker ps"
echo "   ps aux | grep main.py"
echo ""
echo "   # مشاهده لاگ API:"
echo "   tail -f /tmp/py-api.log"
echo ""
echo "═══════════════════════════════════════════════════════════"

sudo docker ps
