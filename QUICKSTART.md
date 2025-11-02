# 🚀 راهنمای سریع نصب TronDNS

## نصب یک خطی

```bash
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/trondns/main/install_byosh.sh | sudo bash
```

یا:

```bash
wget -qO- https://raw.githubusercontent.com/YOUR_USERNAME/trondns/main/install_byosh.sh | sudo bash
```

## مراحل بعد از نصب

1. IP عمومی سرور خود را یادداشت کنید
2. در تنظیمات DNS سیستم خود (کنسول بازی، کامپیوتر، موبایل):
   - DNS اول: IP سرور شما
   - DNS دوم: `8.8.8.8`

## تست نصب

```bash
# بررسی وضعیت کانتینر
sudo docker ps

# تست DNS
dig @YOUR_SERVER_IP google.com
```

## مشکل دارید؟

به بخش [عیب‌یابی](README.md#-عیب-یابی) در README.md مراجعه کنید.

