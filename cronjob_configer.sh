#!/bin/bash

# بررسی نصب بودن cron و نصب آن در صورت عدم وجود
if ! dpkg -l | grep -q cron; then
    echo "Cron نصب نشده است. نصب Cron..."
    sudo apt update
    sudo apt install -y cron
    sudo systemctl enable cron
    sudo systemctl start cron
    echo "Cron نصب و فعال شد."
else
    echo "Cron از قبل نصب است."
fi

# درخواست زمان‌بندی کرون جاب
echo "لطفاً زمان‌بندی کرون جاب را وارد کنید:"
echo "توجه: اگر بخواهید از علامت * استفاده کنید، به معنی «هر مقدار» است."
echo "برای مثال، * در بخش دقیقه یعنی «هر دقیقه»، یا * در بخش ساعت یعنی «هر ساعت»."

read -p "دقیقه (0-59، * برای هر دقیقه): " minute
read -p "ساعت (0-23، * برای هر ساعت): " hour
read -p "روز ماه (1-31، * برای هر روز): " day
read -p "ماه (1-12، * برای هر ماه): " month
read -p "روز هفته (0-7، 0=یکشنبه، * برای هر روز هفته): " weekday

# درخواست مسیر فایل اجرایی
read -p "مسیر فایل اجرایی را وارد کنید (به طور کامل): " filepath

# ساخت کرون جاب
cronjob="$minute $hour $day $month $weekday $filepath"

# افزودن کرون جاب به crontab
(crontab -l ; echo "$cronjob") | crontab -

echo "کرون جاب با موفقیت اضافه شد:"
echo "$cronjob"
