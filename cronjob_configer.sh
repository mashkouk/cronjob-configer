#!/bin/bash

# -------------------------------------------
# بررسی نصب بودن cron
# -------------------------------------------
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

# -------------------------------------------
# دریافت مسیر اسکریپت از کاربر
# -------------------------------------------
while true; do
    echo ""
    echo "-------------------------------------------"
    read -p "لطفاً مسیر کامل اسکریپت خود را وارد کنید (یا اینتر بزنید تا خالی بماند): " SCRIPT_PATH

    # اگر کاربر مسیر را وارد کند، بررسی می‌کنیم که فایل وجود دارد یا خیر
    if [ ! -z "$SCRIPT_PATH" ]; then
        if [ -f "$SCRIPT_PATH" ]; then
            break  # اگر فایل وجود داشت، حلقه را متوقف می‌کنیم
        else
            echo "خطا: فایل اسکریپت در مسیر مشخص شده وجود ندارد. لطفاً دوباره وارد کنید."
        fi
    else
        break  # اگر کاربر چیزی وارد نکرد، از حلقه خارج می‌شویم
    fi
done

# -------------------------------------------
# دریافت نام سرویس‌هایی که باید ریستارت شوند
# -------------------------------------------
while true; do
    echo ""
    echo "-------------------------------------------"
    read -p "آیا می‌خواهید سرویس خاصی ری‌استارت شود؟ (نام سرویس را وارد کنید یا خالی بگذارید): " SERVICES

    if [ ! -z "$SERVICES" ]; then
        for service in $SERVICES; do
            if systemctl list-units --type=service --state=running | grep -q "$service.service"; then
                break  # اگر سرویس وجود داشت، از حلقه خارج می‌شویم
            else
                echo "خطا: سرویس '$service' وجود ندارد یا در حال حاضر در حال اجرا نیست. لطفاً دوباره وارد کنید."
            fi
        done
    else
        break  # اگر کاربر چیزی وارد نکرد، از حلقه خارج می‌شویم
    fi
done

# -------------------------------------------
# دریافت تنظیمات زمان‌بندی از کاربر
# -------------------------------------------
while true; do
    echo ""
    echo "-------------------------------------------"
    echo "لطفاً یکی از گزینه‌های زیر را انتخاب کنید:"
    echo "1) اسکریپت هر چند ساعت یک بار اجرا شود"
    echo "2) اسکریپت در یک ساعت مشخص از روز اجرا شود"

    read -p "انتخاب شما (1 یا 2): " OPTION

    if [ "$OPTION" == "1" ]; then
        # پرسیدن اینکه هر چند ساعت اجرا شود
        while true; do
            read -p "لطفاً فاصله زمانی اجرای اسکریپت را (به ساعت) وارد کنید (مثال: هر 3 ساعت): " INTERVAL_HOURS
            if [[ "$INTERVAL_HOURS" =~ ^[0-9]+$ ]]; then
                CRON_SCHEDULE="0 */$INTERVAL_HOURS * * *"
                echo "اسکریپت هر $INTERVAL_HOURS ساعت یک بار اجرا خواهد شد."
                break  # مقدار صحیح وارد شده، از حلقه خارج می‌شویم
            else
                echo "خطا: لطفاً یک عدد صحیح وارد کنید."
            fi
        done
        break
    elif [ "$OPTION" == "2" ]; then
        # پرسیدن ساعت اجرای اسکریپت
        while true; do
            read -p "لطفاً ساعت اجرای اسکریپت را وارد کنید (0-23 برای ساعت): " HOUR
            if [[ "$HOUR" =~ ^[0-9]+$ ]] && [ "$HOUR" -ge 0 ] && [ "$HOUR" -le 23 ]; then
                break
            else
                echo "خطا: لطفاً یک ساعت معتبر وارد کنید (0-23)."
            fi
        done

        while true; do
            read -p "دقیقه اجرای اسکریپت را وارد کنید (0-59 برای دقیقه): " MINUTE
            if [[ "$MINUTE" =~ ^[0-9]+$ ]] && [ "$MINUTE" -ge 0 ] && [ "$MINUTE" -le 59 ]; then
                CRON_SCHEDULE="$MINUTE $HOUR * * *"
                echo "اسکریپت هر روز در ساعت $HOUR:$MINUTE اجرا خواهد شد."
                break
            else
                echo "خطا: لطفاً یک دقیقه معتبر وارد کنید (0-59)."
            fi
        done
        break
    else
        echo "خطای ورودی: گزینه نامعتبر است. لطفاً یکی از گزینه‌های 1 یا 2 را انتخاب کنید."
    fi
done

# نمایش فرمت نهایی به کاربر
echo ""
echo "-------------------------------------------"
echo "زمان‌بندی شما: $CRON_SCHEDULE"

if [ "$OPTION" == "1" ]; then
    echo "توضیح: اسکریپت شما هر $INTERVAL_HOURS ساعت یک بار در دقیقه 0 اجرا خواهد شد."
elif [ "$OPTION" == "2" ]; then
    echo "توضیح: اسکریپت شما هر روز در ساعت $HOUR و دقیقه $MINUTE اجرا خواهد شد."
fi

# -------------------------------------------
# ساختن یک اسکریپت موقت برای کرون جاب
# -------------------------------------------
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

# -------------------------------------------
# اضافه کردن کرون جاب به crontab
# -------------------------------------------
(crontab -l 2>/dev/null; echo "$CRON_SCHEDULE bash $TEMP_SCRIPT") | crontab -

# نمایش پیام موفقیت و مسیر فایل کرون‌جاب
echo "کرون جاب با موفقیت اضافه شد."
echo "فایل کرون‌جاب شما در مسیر زیر ایجاد شده است:"
echo "$TEMP_SCRIPT"
