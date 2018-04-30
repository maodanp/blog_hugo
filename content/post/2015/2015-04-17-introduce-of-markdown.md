---
categories:
- "工具箱"
date: 2015-04-17
title: "Markdown简介"
url: "/2015/04/17/introduce-of-markdown"
---

这段时间才结束Markdown。
想想作为程序员，才接触Markdown，甚是晚哉。
学什么只要其实也没有早晚，只要用心，此理放之四海而皆准。
废话不多说，下面简单记录markdown。

<!--more-->

下面为markdown的官方文档说明：

>Markdown is intended to be as easy-to-read and easy-to-write as is feasible.

* Markdown内部支持HTML、自动转意特殊字符
* Markdown的语法相当简洁, 可以让作者专注于写作内容本身，而不是排版。
* 纯文档的，可以用任意文本编辑器打开

### Markdown语法
--------------
#### 标题
Markdown 支持两种分割的标题，[Setex](http://docutils.sourceforge.net/mirror/setext.html)和[Atx](http://www.aaronsw.com/2002/atx/)风格。
一般常用Atx风格, 用#表示1-6级标题。

#### 块引用
Markdown使用邮件风格的 > 作为块引用。

当然，块引用中可以包含其他的块。
#### 列表
列表分为有序列表、无序列表。

无序列表使用 *, + 和 - 作为列表生成器; 有序列表则使用数字标识。
![标题图片](http://7xt5nc.com1.z0.glb.clouddn.com/pic/2015/2015-04-17-introduce-of-markdown-list.png)

***注：标题、块引用都可以和前面的符号连着写，但列表符号就需要空行了***
#### 链接、图片
在 Markdown 中，插入链接不需要其他按钮，你只需要使用如下语法：
`显示文本(链接地址)`

插入图片的语法则是`![显示文本](链接地址)`。

***注：目前Markdown还不支持定义图片的宽高，如果需要，可以使用普通的 `<img>` 标签。***

### Markdown不同平台编辑

* Mac平台下推荐Mou
* windows平台推荐MarkdownPad
* Chorme提供Markdown-here插件(chrome插件下载都是需要科学上网的，大家都懂)

### 参考阅读

[献给写作者的 Markdown 新手指南](http://www.jianshu.com/p/q81RER)

[Markdown写作浅析](http://www.jianshu.com/p/PpDNMG)


