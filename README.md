# PAM
1. Запретить всем пользователям, кроме группы admin логин в выходные (суббота и воскресенье), без учета праздников

# Подготовка стенда к работе
На стендовой виртуальной машине создадим 3х пользователей:
```
sudo useradd day && \
sudo useradd night && \
sudo useradd friday
```
Назначим им пароли:
```
echo "Otus2019"|sudo passwd --stdin day &&\
echo "Otus2019" | sudo passwd --stdin night &&\
echo "Otus2019" | sudo passwd --stdin friday
```
Чтобы быть уверенными, что на стенде разрешен вход через ssh по паролю выполним:
```
sudo bash -c "sed -i 's/^PasswordAuthentication.*$/PasswordAuthentication yes/' /etc/ssh/sshd_config && systemctl restart sshd.service"
```
# Модуль pam_time

Модуль pam_time позволяет достаточно гибко настроить доступ пользователя с учетом времени. Настройки данного модуля хранятся в файле /etc/security/time.conf.
```
cd /etc/security/
sudo vi time.conf
```
Добавим в конец файла строки
```
*;*;day;Al0800-2000
*;*;night;!Al0800-2000
*;*;friday;Fr
```
Теперь настроим PAM, так как по-умолчанию данный модуль не подключен.
Для этого приведем файл ```/etc/pam.d/sshd``` к виду:
```
...
account required pam_nologin.so
account required pam_time.so
...
```

После чего в отдельном терминале можно проверить доступ к серверу по ssh для созданных пользователей.


# Модуль pam_exec

*Предварительную подготовку стенда также выполняем, если переходим на другую машину*

Еще один способ реализовать задачу - выполнить при подключении пользователя скрипт, в котором необходимая информация обработается самостоятельно.
Удалим из /etc/pam.d/sshd изменения из предыдущего этапа и приведем его к следующему виду:
```
...
account required pam_nologin.so
account required pam_exec.so /usr/local/bin/test_login.sh
...
```


Добавлен модуль ```pam_exec``` и, в качестве параметра, указан скрипт, который осуществит необходимые проверки. взят готовый.
При запуске данного скрипта PAM-модулем будет передана переменная окружения PAM_USER, содержащая имя пользователя.

После всех действий проверки не работали и пускало всё равно всех пользователей, поэтому скрипту я изменил права на выполнение

```
chmod 777 test_login.sh 
```
После этого проверки на вход начали выполняться корректно.



# Модуль pam_script

Согласно методичке - не заработало. day, night, friday выполняют вход без ограничений.

Разобрано в рамках выполнения домашней работы. В методичке для модуля *account* было указано, в результате поднялось в модулем *auth*.

# Модуль pam_cap

Для демонстрации работы модуля установим дополнительный пакет nmap-ncat(CentOS)

```sudo yum install nmap-ncat -y```

Пользователь *day* остался из предыдущего примера.

Войдем на стендовую машину под пользователем *day* и попробуем выполнить команду ```ncat -l -p 80``` и получим сообщение об ошибке. Это связано с тем, что непривелигерованный пользователь day, от имени которого выполняется команда, не может открыть для прослушивания 80й порт.

Предоставим пользователю права (возможности), чтобы он смог открыть порт. Способ более гибкий, потому что можно
указать что именно, кому и при помощи какой программы разрешаем. Для этого воспользумся pam-модулем ```pam_cap```. Поскольку это демо-стенд, то SELinux можно выключить, выполнив
```
sudo setenforce 0
```

Приведем файл /etc/pam.d/sshd к виду (если стенд голый - то добавляется только строка ```auth required pam_cap.so```:

```
...
auth include postlogin
auth required pam_cap.so
...
```

Таким образом, мы включили обработку capabilities при подключении по ssh. Пропишем необходимые права пользователю day. Для этого создадим файл ```/etc/security/capability.conf```, содержащий одну строку:

```
cap_net_bind_service day
```

Теперь необходимо программе (```/usr/bin/ncat```), при помощи которой будет открываться порт, так же выдать разрешение на данное действие:
```
sudo setcap cap_net_bind_service=ei /usr/bin/ncat
```
Мы сопоставили права, выданные пользователю с правами выданными на программу. Снова зайдем на стенд под пользователем
day и проверим, что мы получили необходимые права:

```
capsh --print
```

Теперь попробуем выполнить команду:
```
ncat -l -p 80
```
Теперь ошибки не возникло. Теперь можно открыть еще одну ssh-консоль также от пользователя *day* и там выполнить:

```
echo "Make Linux great again" > /dev/tcp/127.0.0.7/80
```

Сообщение ```Make Linux great again``` отобразится в первой консоли



# ДЗ


Описание работы.

Запретить всем пользователям, кроме группы admin логин в выходные (суббота и воскресенье), без учета праздников

Реализовано через ```pam_script```.

Установлены epel-release + pam_script
```
yum install epel-release -y
yum install pam_script -y
```
Добавляем в ```/etc/pam.d/sshd``` соответствующую запись ```auth  required  pam_script.so```.
Сам скрипт скопировали из текущей директории на vm и выдали права на выполнение
```
chmod 777 /vagrant/pam_script
cp /vagrant/pam_script /etc/
```
Создаём группу admin, создаём user1 и сразу добавляем его в админы при создании, задаём пароль.
```
groupadd admin
useradd -G admin user1
echo "bun:Otus2022" | chpasswd
```
Создаём user2, задаём пароль.
```
useradd user2
echo "cookie:Otus2022" | chpasswd
```
Чтобы быть уверенными, что на стенде разрешен вход через ssh по паролю выполним:
```
bash -c "sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config"
```
Перезапускаем сервис ```systemctl restart sshd``` - можно проверять


