#!/bin/bash
#安装centos7.3+nginx脚本

chmod -R 777 /usr/local/src/nginx
#时间时区同步，修改主机名
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

ntpdate cn.pool.ntp.org
hwclock --systohc
echo "*/30 * * * * root ntpdate -s 3.cn.poop.ntp.org" >> /etc/crontab

sed -i 's|SELINUX=.*|SELINUX=disabled|' /etc/selinux/config
sed -i 's|SELINUXTYPE=.*|#SELINUXTYPE=targeted|' /etc/selinux/config
sed -i 's|SELINUX=.*|SELINUX=disabled|' /etc/sysconfig/selinux 
sed -i 's|SELINUXTYPE=.*|#SELINUXTYPE=targeted|' /etc/sysconfig/selinux 
setenforce 0 && systemctl stop firewalld && systemctl disable firewalld

rm -rf /var/run/yum.pid 
rm -rf /var/run/yum.pid

#安装依赖包 
rpm -q pcre pcre-devel zlib openssl openssl-devel gcc |grep 未安装|awk '{print $2}'|xargs yum install -y

#1:解压
cd /usr/local/src/nginx
mkdir -p /usr/local/nginx/
tar -zxvf nginx-1.12.0.tar.gz -C /usr/local/nginx

#2:创建nginx用户和组
useradd nginx -s /sbin/nologin

#3:configure配置安装
cd /usr/local/nginx/nginx-1.12.0
./configure --user=nginx  --group=nginx --prefix=/usr/local/nginx  
make && make install
chown -Rf nginx:nginx /usr/local/nginx/html
chmod -Rf 777 /usr/local/nginx/html

#4：验证nginx
/usr/local/nginx/sbin/nginx
/usr/local/nginx/sbin/nginx -V

#5：服务随机启动
cat > /lib/systemd/system/nginx.service <<EOF

[Unit] 
Description=nginx 
After=network.target 
 
[Service] 
Type=forking 
ExecStart=/usr/local/nginx/sbin/nginx 
ExecReload=/usr/local/nginx/sbin/nginx -s reload 
ExecStop=/usr/local/nginx/sbin/nginx -s quit
PrivateTmp=true 
 
[Install] 
WantedBy=multi-user.target 

EOF 

chmod +x /lib/systemd/system/nginx.service
systemctl enable nginx.service && systemctl start nginx.service　

#6:调优
sed -i '20c \    server_tokens  off;' /usr/local/nginx/conf/nginx.conf
/usr/local/nginx/sbin/nginx -t
/usr/local/nginx/sbin/nginx -s reload
rm -rf /usr/local/src/nginx
ps aux |grep nginx

# nginx(Tengine)使用——新模块添加使用
# 1.为nginx添加静态的模块,进入到nginx的源码包中，重新configure加入相应模块./configure --add-module=/path/to/module
# 例如，我下载的一个ngx_http_push模块放到了/usr/local/ngx_modules目录里，该模块的源码目录为ngx_http_push,那么configure指令为./configure --add-module=/usr/local/ngx_modules/ngx_http_push ; make && make install 

# 2.使用Tengine的dso_install(Tengine的新特性中的动态加载，在安装后的Tengine的sbin目录里，有nginx和dso_install两个指令.)，可以用./nginx -m 查看已经加载的相关模块，用./nginx -l查看相关模块列表，包含详细的配置指令。
# 用dso_install来安装模块要简单得多，直接执行./dso_install --add-module=/path/to/module即可，会把编译好的so文件直接复制到Tengine的modules目录里，然后在nginx.conf里面加入
# dso {
#   load ngx_http_push.so; 
# }
# 然后执行./nginx -s reload 重新加载一下配置文件就行。

        
# Nginx缓存配置及nginx ngx_cache_purge模块的使用
# 重新编译前最好把nginx备份一下，编译时要添加以前的（用/usr/local/nginx/sbin/nginx -V查看)模块
# 1、编译如下：
#  mkdir -pv /usr/local/nginx/module/ngx_cache_purge
#  tar -zxvf ngx_cache_purge-2.3.tar.gz -C /usr/local/nginx/module/ngx_cache_purge/
#  cd /usr/local/nginx/nginx-1.12.1/
#  ./configure --user=nginx --group=nginx --prefix=/usr/local/nginx --add-module=/usr/local/nginx/module/ngx_cache_purge/ngx_cache_purge-2.3/
#  make
#  make install
#  chown -Rf nginx:nginx /usr/local/nginx/module/
# 2、nginx配置如下：
# 创建缓存目录
# mkdir -pv /usr/local/nginx/cache
# 进入nginx安装的conf目录
# cd /usr/local/nginx/conf/

#打开nginx.conf文件添加以下内容：
#proxy_temp_path /usr/local/nginx/cache/proxy_temp_path;
#proxy_cache_path /usr/local/nginx/cache/proxy_cache_path levels=1:2 keys_zone=cache_one:6072m inactive=7d max_size=30g;
#proxy_ignore_headers X-Accel-Expires Expires Cache-Control Set-Cookie;

#proxy_cache cache_one;
#proxy_cache_valid 200 304 302 5d;
#proxy_cache_valid any 7d;
#proxy_cache_key $host$uri$is_args$args;
#add_header X-Cache '$upstream_cache_status from $host';

# 工作进程个数：多开几个可以减少io带来的影响，
# 根据 lscpu查出来的cpus设置（一般为当前机器核心数的1-2倍，最大不超过8）,
# worker_processes 2; 
# worker_cpu_affinity需要结合worker_processes使用，一个worker_processes绑定一个CPU，
# 比如两核是01，四核是0001，下面是8核绑定8个worker_processes的示例
# worker_cpu_affinity 01 10;
# error_log logs/error.log info;
# events {
    #使用epoll模型提高性能
#    use epoll;
    #单个进程连接数（最大连接数=连接数*进程数）
#    worker_connections 65535;
# }
# http {
    #文件扩展名与文件类型映射表 
#    include mime.types;
    #默认文件类型 
#    default_type application/octet-stream;
    #开启高效文件传输模式，sendfile指令指定nginx是否调用sendfile函数来输出文件，对于普通应用设为 on，
    #如果用来进行下载等应用磁盘IO重负载应用，可设置为off，以平衡磁盘与网络I/O处理速度，降低系统的负载。
    #注意：如果图片显示不正常把这个改成off
#    sendfile on;
    #长连接超时时间，单位是秒 
#    keepalive_timeout 65;
    #Nginx的gzip模块是内置的，在http中添加如下配置：
    # gzip on;
    # gzip_static on；              nginx对于静态文件的处理模块
    # gzip_min_length 1k;           建议设置成大于1k的字节数，小于1k可能会越压越大。
    # gzip_buffers 16 64K;          按照原始数据大小以64k为单位的16倍申请内存。
    # gzip_http_version 1.1;        nginx和后端的upstream server之间是用HTTP/1.0协议通信的
    # gzip_comp_level 6;            gzip压缩比/压缩级别，压缩级别1-9，级别越高压缩率越大，当然压缩时间也就越长（传输快但比较消耗cpu）。
    # gzip_types text/plain application/x-javascript text/css application/xml text/javascript application/x-httpd-php image/jpeg image/gif image/png;
    # gzip_vary on;                 和http头有关系，加个vary头，给代理服务器用的，有的浏览器支持压缩，有的不支持，所以避免浪费不支持的也压缩，所以根据客户端的HTTP头来判断，是否需要压缩
    # header设置：用户真实的ip地址转发给后端服务器
    # proxy_set_header Host $host;
    # proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    # proxy_set_header X-Real-IP $remote_addr;
    #缓冲
    # client_body_buffer_size 512k;
    # proxy_connect_timeout 5;
    # proxy_read_timeout 60;
    # proxy_send_timeout 5;
    # proxy_buffer_size 16k;
    # proxy_buffers 4 64k;
    # proxy_busy_buffers_size 128k;
    # proxy_temp_file_write_size 128k;       
    ##########################缓存#####################
    #设置缓存临时目录，要配合linux的内存目录/dev/shm使用的话，必须给赋予目录权限，因为默认root权限
    # proxy_temp_path /usr/local/nginx/cache/proxy_temp_path;
    #设置缓存目录，并设置Web缓存区名称为cache_one，内存缓存空间大小为128m，7天没有被访问的内容自动清除，硬盘缓存空间大小为5GB。
    # proxy_cache_path /usr/local/nginx/cache/proxy_cache_path levels=1:2 keys_zone=cache_one:128m inactive=7d max_size=5g;
    #启用html、jsp...<meta>标签不缓存的设置
    # proxy_ignore_headers X-Accel-Expires Expires Cache-Control Set-Cookie;  
    ################################################集群 ###################################################    
    #动态资源集群
    #upstream dynamic_server { 

        #服务器配置 weight是权重的意思，权重越大，分配的概率越大。 
        #server 192.168.1.111:8080 weight=1 max_fails=2 fail_timeout=30s;
        #server 192.168.1.111:8081 weight=1 max_fails=2 fail_timeout=30s; 
    #} 
    #静态资源集群（一般由nginx管理，因为nginx处理静态资源性能好，如果服
    #务器有限，也可以部署在代理服务器本地）
    #upstream static_server { 
        #server 192.168.1.111:808 weight=1;
    #}
    ################################################Nginx代理###################################################    
    #server {
        #监听80端口，可以改成其他端口 
        #listen 80;
        #nginx服务的域名，通过域名就可以访问应用
        #server_name localhost;
        ##静态资源存放在nginx服务器的地址
        #root /opt/static/demo;
        #用于清除缓存的url设置
        #假设一个URL为cache/test.gif,那么就可以通过访问cache/purge/test.gif清除该URL的缓存。
        #location ~ /purge(/.*) {
            #设置只允许指定的IP或IP段才可以清除URL缓存
            #allow 127.0.0.1;
            #allow 10.74.147.91;
            #deny all;
            #proxy_cache_purge cache_one $host$1$is_args$args;
        #}
        #反向代理：网页、视频、图片文件从nginx服务器读取
        #location ~ .*\.(js|css|htm|html|gif|jpg|jpeg|png|bmp|swf|ioc|rar|zip|txt|flv|mid|doc|ppt|pdf|xls|mp3|wma)$
        # { 
            ##########################缓存#####################
            #使用web缓存区cache_one
            #proxy_cache cache_one;
            #对200 304 302状态码设置缓存时间5天，其他的7天
            #proxy_cache_valid 200 304 302 5d;
            #proxy_cache_valid any 7d;
            #以域名、URI、参数组合成Web缓存的Key值，Nginx根据Key值哈希，存储缓存内容到二级缓存目录内
            #proxy_cache_key $host$uri$is_args$args;
            #如果后端的服务器返回502、504、执行超时等错误，自动将请求转发到upstream负载均衡池中的另一台服务器，实现故障转移
            #proxy_next_upstream http_502 http_504 error timeout invalid_header;
            #增加一个header字段方便在浏览器查看是否击中缓存（生产中可注释）
            #add_header X-Cache '$upstream_cache_status from $host';
            #反向代理，静态的由nginx来处理（不配置默认nginx的html目录，静态资源的目录结构必须和tomcat的web工程一致）
            #proxy_pass http://static_server; 
            #浏览器中缓存30天
            #expires 30d;
        #} 
        #反向代理： 其他动态文件转发到后端的tomcat集群
        #location ~ .*$ {
            #proxy_pass http://dynamic_server; 
        #}
        #错误提示页面
        #error_page 500 502 503 504 /50x.html;
        #location = /50x.html {
            #root html;
        #}
    #}
    #静态资源服务器，这里监听本地808端口，因为静态资源服务器和代理服务器是同一台机器，所以有如下配置
    #如果是独立的服务器，直接在集群upstram配置即可。
    #server{
        #listen 808;
        #server_name static;
        #反向代理：网页、视频、图片文件从nginx服务器读取
        #location /
        # { 
            #浏览器中缓存30天
            #expires 30d;
        # } 
    #}
#}

# /usr/local/nginx/sbin/nginx -s reload
