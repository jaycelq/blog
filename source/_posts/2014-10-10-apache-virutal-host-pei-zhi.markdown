---
layout: post
title: "Apache 配置"
date: 2014-10-10 22:30:33 -0700
comments: true
sharing: false
categories: Apache 
---

用过Apache的人基本上都动过Apache的配置文件，以前改Apache的时候总是从网上搜一下是怎么改的，然后照着改一下，经常出错，因此决定将Apache的常用设定整理一下，方便以后查阅和使用。

## Apache VirtualHost 设置
VirtulHost的配置是为了在同一台服务器上可以使用多个web站点（比如test1.example.com, test2.example.com）。VirtualHost可以上基于IP的，也就是说每个站点对应一个IP，也可以是基于主机名的，即同一个IP上运行了多个web站点。
<!-- more -->
### 前置条件NameVirtualHost
NameVirtualHost可以指定来自哪些IP的请求会使用Name-based VirtualHost。一般情况下，这个IP地址是域名解析对应的IP地址。如果有多个地址对应多个主机名，重复这个指令。

下面的代码表示所有通过111.22.33.44的80端口进入的请求都会使用VirutalHost的设定。  
` NameVirtualHost 111.22.33.44:80 `

如果任何(星号)通过 80 port 进入的连接，都使用用VirtualHost设定。  
`NameVirtualHost *:80`

### `<VirtualHost>`块
对于每一个你想要服务的web站点，都需要创建一个`<VirtualHost>`块。`<VirtualHost >`的参数必须符合NameVirtualHost的参数，并且每个`<VirtualHost>`块内部都要包含一个ServerName和一个DocumentRoot。  
>首选host失效  
>如果你在当前的web服务器中加入了VirtualHost，那么你一定要创建一个`<VritualHost>`块，并且制定其中的ServerName和DocumentRoot与全局的ServerName和DocumentRoot一致，放在第一个作为默认的VirtualHost。

```
NameVirtualHost *:80

<VirtualHost *:80>
ServerName www.domain.tld
ServerAlias domain.tld *.domain.tld
DocumentRoot /www/domain
</VirtualHost>

<VirtualHost *:80>
ServerName www.otherdomain.tld
DocumentRoot /www/otherdomain
</VirtualHost>
```
NameVirualHost和`<VitualHost>`中的星号可以替换成一个确定的IP地址。 
 
很多服务器希望不止通过一个域名访问，通过ServerAlias可以设置。将ServerAlias放在`<VirtualHost>`内部。比如以下设置所有到domain.ltd和*.domain.ltd的请求都会通过www.domain.ltd完成。  
`ServerAlias domain.tld *.domain.tld`  

更多关于VirtualHost的配置可以参考Apache关于VirtualHost的[官方配置文档](http://httpd.apache.org/docs/2.2/vhosts/)。
