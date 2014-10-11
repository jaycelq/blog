---
layout: post
title: "用Gitweb git-http-backend Apache搭建GIT HTTP服务器"
date: 2014-10-11 16:53:47 +0800
comments: true
sharing: false
categories: Apache Git Git-http-backend 
---

买来之后，就想在上面搭点东西，现在OCTOPRESS和ShadowSocks已经弄好了，就想能不能在上面架一个Git的服务器，可以通过HTTP/S push pull，并且可以有一个web前端可以看，想起了很早之前看到的git-http-backend 和 Gitweb。  
<center>{% img fancybox /images/2014-10-11/gitweb.png 500 %}</center>
<!-- more -->
### GitWeb配置 
GitWeb是Git自带的CGI脚本，可以用来显示简单的Web界面，运行效果有点像[http://git.kernel.org](http://git.kernel.org)。   
1. 安装GitWeb  
`apt-get install git-web`  
2. 在www目录下创建软链接（我用的是LAMPP所以目录在htdocs下）  
`ln -s /usr/share/gitweb /opt/lampp/htdocs`  
3. 在Apache配置目录下创建`<VirtualHost>`项  
`<VirtualHost>`配置可以参考上一篇文章[Apache配置](http://blog.liqiang.me/blog/2014/10/11/apache-virutal-host-pei-zhi/)。
```
<VirtualHost *:80>
    DocumentRoot /opt/lampp/htdocs/gitweb
    ServerName git.test.com
    <Directory /opt/lampp/htdocs/gitweb>
        Options ExecCGI +FollowSymLinks +SymLinksIfOwnerMatch
        AllowOverride All
        order allow,deny
        Allow from all
        AddHandler cgi-script cgi
        SetEnv GITWEB_CONFIG /etc/gitweb.conf
        DirectoryIndex gitweb.cgi
    </Directory>
</VirtualHost>
```
`<Directory>`和`</Directory>`用于封装一组指令，使之仅对某个目录及其子目录生效。任何可以在"directory"作用域中使用的指令都可以使用。`<Directory>`的参数<i>Directory-path</i>可以是一个目录的完整路径，或是包含了Unix shell匹配语法的通配符字符串。  
Options指令控制了在特定目录中将使用哪些服务器特性。  
* `ExecCGI`    允许使用mod_cgi执行CGI脚本。  
* `FollowSymLinks`  服务器允许在此目录中使用符号连接。  
* `SymLinksIfOwnerMatch` 服务器仅在符号连接与其目的目录或文件的拥有者具有相同的uid时才使用它。   

AllowOverride 当服务器发现一个.htaccess文件(由AccessFileName指定)时，它需要知道在这个文件中声明的哪些指令能覆盖在此之前指定的配置指令。  
Order 控制默认的访问状态与Allow和Deny指令生效的顺序。  
* `Allow,Deny` Allow指令在Deny指令之前被评估。默认拒绝所有访问。任何不匹配Allow指令或者匹配Deny指令的客户都将被禁止访问。  

剩下的配置选项基本上可以按照字面理解。  
4. GitWeb配置文件  
`$projectroot = "/opt/lampp/htdocs/repo"`  
指定仓库路径。

### git-http-backend配置
git-http-backend也是一个CGI脚本，它能够让客户端通过HTTP/S协议访问代码仓库。  
git-http-backend会确认仓库中含有git-deamon-export-ok文件才会响应对于该仓库的HTTP请求，除非GIT_HTTP_EXPORT_ALL环境变量被设置。  
Apache中的配置如下：  
```
    SetEnv GIT_PROJECT_ROOT /opt/lampp/htdocs/repos/
    SetEnv GIT_HTTP_EXPORT_ALL
    ScriptAliasMatch \
        "(?x)^/(.*/(HEAD | \
                info/refs | \
                objects/(info/[^/]+ | \
                    [0-9a-f]{2}/[0-9a-f]{38} | \
                    pack/pack-[0-9a-f]{40}\.(pack|idx)) | \
                git-(upload|receive)-pack))$" \
        /usr/lib/git-core/git-http-backend/$1
```  
设置git仓库路径，设置GIT_HTTP_EXPORT_ALL环境变量  
`ScriptAliasMatch` 使用正则表达式映射一个URL到文件系统并视之为CGI脚本，上述配置的含义为所有对仓库中代码的请求都通过git-http-backend完成。

### 权限认证
```
    <Location />
        AuthType Digest
        AuthName "Shared Git Repo"
        AuthUserFile /var/git/.htpasswd
        Require valid-user
    </Location>
```  

1. `<Location>指令` 将封装的指令作用于匹配的URL,上述指令将用于匹配根目录下所有的文件，web访问 push和pull都需要密码。   
2. 创建用户名和密码  
`htdigest -c /var/git/.htpasswd "Shared Git Repo" user`  
用自己的用户名替换user

### 创建代码仓库
```
    cd /opt/lampp/htdocs/repo && git init --bare --shared myproj.git 
    chown -R www-data.www-data /opt/lampp/htdocs/repo
```
创建一个所谓的裸仓库，之所以叫裸仓库是因为这个仓库只保存git历史提交的版本信息，而不允许用户在上面进行各种git操作。  

### 通过git clone  
`git clone http://git.test.com/myproj.git`

### 通过浏览器访问

登陆界面  
<center>{% img fancybox /images/2014-10-11/auth.png %}</center>
显示界面
<center>{% img fancybox /images/2014-10-11/login.png %}</center>

### 通过git push
一般来说，push是不会出现问题的，如果出现以下错误  
```
error: unpack failed: unpack-objects abnormal exit   
To http://git.example.com/proj.git  
! [remote rejected] master -> master (n/a (unpacker error))  
error: failed to push some refs to 'http://git.example.com/proj2.git'  
```
原因一般是运行apache进程的用户和用户组与repo目录的用户用户组不一致造成的，可以通过修改httpd.conf中的User和Group字段改正。

参考资料：[Setup Git, Gitweb with git-http-backend / smart http on ubuntu 12.04](http://www.tikalk.com/alm/setup-git-gitweb-git-http-backend-smart-http-ubuntu-1204)



