# 📦 راهنمای انتشار پروژه در گیت‌هاب

## مراحل انتشار

### 1. ساخت ریپازیتوری جدید در گیت‌هاب

1. به [GitHub](https://github.com) بروید
2. روی **New repository** کلیک کنید
3. نام ریپازیتوری را **trondns** قرار دهید
4. توضیحات را پر کنید (اختیاری)
5. **Public** یا **Private** را انتخاب کنید
6. **Initialize with README** را تیک نزنید (چون ما از قبل README داریم)
7. روی **Create repository** کلیک کنید

### 2. آماده‌سازی پروژه محلی

```bash
# در دایرکتوری پروژه
git init
git add .
git commit -m "Initial commit: TronDNS - Auto installer for ByoSH DNS Server"
```

### 3. اتصال به گیت‌هاب

```bash
# اضافه کردن remote (YOUR_USERNAME را با نام کاربری خود جایگزین کنید)
git remote add origin https://github.com/YOUR_USERNAME/trondns.git

# تغییر نام شاخه اصلی به main
git branch -M main

# ارسال به گیت‌هاب
git push -u origin main
```

### 4. به‌روزرسانی README.md

قبل از push، در فایل `README.md` و `QUICKSTART.md` تمام موارد `YOUR_USERNAME` را با نام کاربری گیت‌هاب خود جایگزین کنید:

```bash
# جایگزینی خودکار
sed -i 's/YOUR_USERNAME/your_actual_username/g' README.md
sed -i 's/YOUR_USERNAME/your_actual_username/g' QUICKSTART.md
```

یا به صورت دستی در ویرایشگر متن تغییر دهید.

### 5. اضافه کردن توضیحات ریپازیتوری

در صفحه ریپازیتوری گیت‌هاب:
- به **Settings** → **General** بروید
- در بخش **Repository details** توضیحات را اضافه کنید:
  ```
  🚀 Auto installer for ByoSH DNS Server with FIFA online gaming support
  ```

### 6. اضافه کردن Topics/Tags

در صفحه اصلی ریپازیتوری:
- روی **⚙️** کنار **About** کلیک کنید
- Topics را اضافه کنید:
  - `dns`
  - `byosh`
  - `fifa`
  - `gaming`
  - `bash-script`
  - `docker`
  - `ubuntu`
  - `debian`

### 7. ایجاد Release (اختیاری)

برای ایجاد نسخه اول:

```bash
git tag -a v1.0.0 -m "Initial release"
git push origin v1.0.0
```

سپس در گیت‌هاب به **Releases** → **Draft a new release** بروید و نسخه را منتشر کنید.

## 📝 دستورات Git کامل

```bash
# اگر قبلاً git init نکرده‌اید
git init

# اضافه کردن تمام فایل‌ها
git add .

# کامیت اولیه
git commit -m "Initial commit: TronDNS installer"

# اضافه کردن remote (یادتان باشد YOUR_USERNAME را تغییر دهید)
git remote add origin https://github.com/YOUR_USERNAME/trondns.git

# تغییر نام شاخه
git branch -M main

# ارسال به گیت‌هاب
git push -u origin main
```

## 🔄 به‌روزرسانی پروژه در آینده

```bash
git add .
git commit -m "توضیحات تغییرات"
git push
```

## ✅ چک‌لیست قبل از انتشار

- [ ] تمام فایل‌ها commit شده‌اند
- [ ] `YOUR_USERNAME` در README.md و QUICKSTART.md جایگزین شده
- [ ] .gitignore صحیح است
- [ ] README.md کامل و واضح است
- [ ] اسکریپت `install_byosh.sh` تست شده
- [ ] مجوز (LICENSE) اضافه شده

---

**موفق باشید! 🎉**

