#!/bin/bash

# بررسی نصب بودن cron
if ! dpkg -l | grep -q cron; then
    echo "Cron نصب نیست. در حال نصب cron ..."
    sudo apt update
    sudo apt install cron -y
    sudo systemctl enable cron
    sudo systemctl start cron
    echo "Cron با موفقیت نصب شد."
else
    echo "Cron از قبل نصب شده است."
fi

# دریافت مسیر اسکریپت از کاربر (اگر خالی باشد، نادیده گرفته می‌شود)
read -p "لطفاً مسیر کامل اسکریپت خود را وارد کنید (یا اینتر بزنید تا خالی بماند): " SCRIPT_PATH

# اگر کاربر مسیر را وارد کند، بررسی می‌کنیم که فایل وجود دارد یا خیر
if [ ! -z "$SCRIPT_PATH" ]; then
    if [ ! -f "$SCRIPT_PATH" ]; then
        echo "خطا: فایل اسکریپت در مسیر مشخص شده وجود ندارد."
        exit 1
    fi
fi

# دریافت نام سرویس‌هایی که باید ریستارت شوند از کاربر (می‌تواند خالی باشد)
read -p "آیا می‌خواهید سرویس خاصی ری‌استارت شود؟ (نام سرویس را وارد کنید یا خالی بگذارید): " SERVICES

# چک کردن وجود سرویس
if [ ! -z "$SERVICES" ]; then
    for service in $SERVICES; do
        if ! systemctl list-units --type=service --state=running | grep -q "$service.service"; then
            echo "خطا: سرویس '$service' وجود ندارد یا در حال حاضر در حال اجرا نیست."
            exit 1
        fi
    done
fi

# توضیح زمان‌بندی کرون جاب به صورت جزئی
echo ""
echo "فرمت زمان‌بندی کرون شامل 5 بخش است: دقیقه، ساعت، روز ماه، ماه، روز هفته."
echo "در هر بخش می‌توانید از * (ستاره) استفاده کنید:"
echo "  - ستاره (*) به معنی هر مقدار ممکن است. مثلاً در بخش ساعت * به معنی هر ساعتی است."
echo ""

# دریافت زمان‌بندی از کاربر به‌صورت جداگانه
read -p "دقیقه (0-59 یا * برای هر دقیقه): " MINUTE
read -p "ساعت (0-23 یا * برای هر ساعت): " HOUR
read -p "روز ماه (1-31 یا * برای هر روز): " DAY_OF_MONTH
read -p "ماه (1-12 یا * برای هر ماه): " MONTH
read -p "روز هفته (0-7، 0 و 7 هر دو یکشنبه هستند، یا * برای هر روز هفته): " DAY_OF_WEEK

# ترکیب کردن زمان‌بندی وارد شده توسط کاربر
CRON_SCHEDULE="$MINUTE $HOUR $DAY_OF_MONTH $MONTH $DAY_OF_WEEK"

# نمایش فرمت نهایی به کاربر
echo "زمان‌بندی شما: $CRON_SCHEDULE"

# توضیح فارسی زمان‌بندی وارد شده
echo "توضیح زمان‌بندی به صورت فارسی:"

# تعیین زمان اجرا بر اساس مقادیر وارد شده
[ "$MINUTE" == "*" ] && MINUTE="هر دقیقه" || MINUTE="دقیقه $MINUTE"
[ "$HOUR" == "*" ] && HOUR="هر ساعت" || HOUR="ساعت $HOUR"
[ "$DAY_OF_MONTH" == "*" ] && DAY_OF_MONTH="هر روز" || DAY_OF_MONTH="روز $DAY_OF_MONTH"
[ "$MONTH" == "*" ] && MONTH="هر ماه" || MONTH="ماه $MONTH"
[ "$DAY_OF_WEEK" == "*" ] && DAY_OF_WEEK="هر روز هفته" || case $DAY_OF_WEEK in
    0|7) DAY_OF_WEEK="یکشنبه" ;;
    1) DAY_OF_WEEK="دوشنبه" ;;
    2) DAY_OF_WEEK="سه‌شنبه" ;;
    3) DAY_OF_WEEK="چهارشنبه" ;;
    4) DAY_OF_WEEK="پنج‌شنبه" ;;
    5) DAY_OF_WEEK="جمعه" ;;
    6) DAY_OF_WEEK="شنبه" ;;
esac

# نمایش زمان‌بندی به فارسی
echo "اسکریپت یا سرویس شما در $MINUTE از $HOUR، در $DAY_OF_MONTH از $MONTH و $DAY_OF_WEEK اجرا خواهد شد."

# ساختن یک اسکریپت موقت برای کرون جاب
TEMP_SCRIPT="/tmp/temp_cron_script.sh"
echo "#!/bin/bash" > $TEMP_SCRIPT

# اگر کاربر مسیر اسکریپت وارد کرده باشد، آن را به اسکریپت اضافه می‌کنیم
if [ ! -z "$SCRIPT_PATH" ]; then
    echo "bash $SCRIPT_PATH" >> $TEMP_SCRIPT
fi

# اگر سرویسی برای ری‌استارت مشخص شده باشد، آن را به اسکریپت اضافه می‌کنیم
if [ ! -z "$SERVICES" ]; then
    for service in $SERVICES; do
        echo "sudo systemctl restart $service" >> $TEMP_SCRIPT
    done
fi

# اسکریپت موقت را قابل اجرا می‌کنیم
chmod +x $TEMP_SCRIPT

# اضافه کردن کرون جاب به crontab که اسکریپت موقت را اجرا می‌کند
(crontab -l 2>/dev/null; echo "$CRON_SCHEDULE bash $TEMP_SCRIPT") | crontab -

echo "کرون جاب با موفقیت اضافه شد."
