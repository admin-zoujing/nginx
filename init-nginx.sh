#!/bin/bash
#安装centos7.4+nginx-1.12.2脚本
#nginx下载模块https://www.nginx.com/resources/wiki/modules/index.html
chmod -R 777 /usr/local/src/nginx
#时间时区同步，修改主机名
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

ntpdate ntp1.aliyun.com
hwclock -w
echo "*/30 * * * * root ntpdate -s ntp1.aliyun.com" >> /etc/crontab
crontab /etc/crontab

#sed -i 's|SELINUX=.*|SELINUX=disabled|' /etc/selinux/config
#sed -i 's|SELINUXTYPE=.*|#SELINUXTYPE=targeted|' /etc/selinux/config
#sed -i 's|SELINUX=.*|SELINUX=disabled|' /etc/sysconfig/selinux 
#sed -i 's|SELINUXTYPE=.*|#SELINUXTYPE=targeted|' /etc/sysconfig/selinux 
#setenforce 0 && systemctl stop firewalld && systemctl disable firewalld

rm -rf /var/run/yum.pid 
rm -rf /var/run/yum.pid

#安装依赖包 
yum -y install pcre pcre-devel zlib openssl openssl-devel gcc make
#rpm -ivh /usr/local/src/nginx/rpm/*.rpm --force --nodeps

#1:解压
cd /usr/local/src/nginx
mkdir -p /usr/local/nginx/
tar -zxvf nginx-1.12.2.tar.gz -C /usr/local/nginx

#2:创建nginx用户和组
groupadd nginx
useradd -g nginx -s /sbin/nologin nginx

#3:configure配置安装
cd /usr/local/nginx/nginx-1.12.2
mkdir -pv /usr/local/nginx/{logs,cache}
./configure --prefix=/usr/local/nginx --sbin-path=/usr/local/nginx/sbin/nginx --conf-path=/usr/local/nginx/conf/nginx.conf --error-log-path=/usr/local/nginx/logs/error.log --http-log-path=/usr/local/nginx/logs/access.log --pid-path=/usr/local/nginx/logs/nginx.pid --lock-path=/usr/local/nginx/logs/nginx.lock --http-client-body-temp-path=/usr/local/nginx/cache/client_temp --http-proxy-temp-path=/usr/local/nginx/cache/proxy_temp --http-fastcgi-temp-path=/usr/local/nginx/cache/fastcgi_temp --http-uwsgi-temp-path=/usr/local/nginx/cache/uwsgi_temp --http-scgi-temp-path=/usr/local/nginx/cache/scgi_temp --user=nginx --group=nginx --with-http_ssl_module --with-http_realip_module --with-http_addition_module --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_random_index_module --with-http_secure_link_module --with-http_stub_status_module --with-http_auth_request_module --with-mail --with-mail_ssl_module --with-file-aio --with-cc-opt='-O2 -g -pipe -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector --param=ssp-buffer-size=4 -m64 -mtune=generic' --with-pcre --with-http_v2_module --with-http_gzip_static_module 
#nginx1.8.0编译时参数   --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --user=nginx --group=nginx --with-http_ssl_module --with-http_realip_module --with-http_addition_module --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_random_index_module --with-http_secure_link_module --with-http_stub_status_module --with-http_auth_request_module --with-mail --with-mail_ssl_module --with-file-aio --with-ipv6 --with-http_spdy_module --with-cc-opt='-O2 -g -pipe -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector --param=ssp-buffer-size=4 -m64 -mtune=generic'
make 
make install

#4：验证nginx
#二进制程序：
echo 'export PATH=/usr/local/nginx/sbin:$PATH' > /etc/profile.d/nginx.sh 
source /etc/profile.d/nginx.sh
#头文件输出给系统：
#ln -sv /usr/local/nginx/include /usr/include/nginx
#库文件输出
#echo '/usr/local/nginx/lib' > /etc/ld.so.conf.d/nginx.conf
#让系统重新生成库文件路径缓存
ldconfig
#导出man文件：
cp -r /usr/local/nginx/nginx-1.12.2/man/ /usr/local/nginx/
echo 'MANDATORY_MANPATH                       /usr/local/nginx/man' >> /etc/man_db.conf
source /etc/profile.d/nginx.sh 
/usr/local/nginx/sbin/nginx -V

#5：服务随机启动
cat > /usr/lib/systemd/system/nginx.service <<EOF
[Unit]
Description=The nginx HTTP and reverse proxy server
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/usr/local/nginx/logs/nginx.pid
ExecStartPre=/usr/bin/rm -f /usr/local/nginx/logs/nginx.pid
ExecStartPre=/usr/local/nginx/sbin/nginx -t
ExecStart=/usr/local/nginx/sbin/nginx
ExecReload=/bin/kill -s HUP \$MAINPID
KillSignal=SIGQUIT
TimeoutStopSec=5
KillMode=process
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
sed -i 's|#user  nobody;|user  nginx;|' /usr/local/nginx/conf/nginx.conf
sed -i 's|#error_log  logs/error.log;|error_log  logs/error.log;|' /usr/local/nginx/conf/nginx.conf

systemctl daemon-reload 
systemctl enable nginx.service 
chown -R nginx:nginx /usr/local/nginx
systemctl start nginx

#6:调优
sed -i '/sendfile        on;/a\    server_tokens  off;' /usr/local/nginx/conf/nginx.conf
/usr/local/nginx/sbin/nginx -t
/usr/local/nginx/sbin/nginx -s reload
rm -rf /usr/local/src/nginx
ps aux |grep nginx
firewall-cmd --permanent --zone=public --add-port=80/tcp --permanent
firewall-cmd --permanent --query-port=80/tcp
firewall-cmd --reload

#nginx添加第三方模块，以及启用nginx本身支持的模块（nginx不支持动态安装、加载模块的）
#一定要注意：首先查看你已经安装的nginx模块！然后安装新东西的时候要把已安装的再次配置。
#查看nginx现有的配置：
#/usr/local/nginx/sbin/nginx -V

#./configure后面一定还要带上--add-module=/home/softback/echo-nginx-module-0.60,否则会被覆盖的。
#1、在未安装nginx的情况下安装nginx第三方模块(需要make install)
# cd /usr/local/nginx/nginx-1.12.2/
# ./configure --prefix=/usr/local/nginx \
# --with-http_stub_status_module \
# --with-http_ssl_module --with-http_realip_module \
# --with-http_image_filter_module \
# --add-module=../ngx_pagespeed-master --add-module=/第三方模块目录
# make
# make isntall
# /usr/local/nginx/sbin/nginx

# 2、在已安装nginx情况下安装nginx模块(不需要make install，只需要make)
# cd /usr/local/nginx/nginx-1.12.2/
# ./configure --prefix=/usr/local/nginx \
# --with-http_stub_status_module \
# --with-http_ssl_module --with-http_realip_module \
# --with-http_image_filter_module \
# --add-module=../ngx_pagespeed-master
# make
# /usr/local/nginx/sbin/nginx -s stop
# cp objs/nginx /usr/local/nginx/sbin/nginx
# /usr/local/nginx/sbin/nginx 

