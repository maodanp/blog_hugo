---
categories:
- "技术志"
tags:
- network
date: 2015-05-13
title: "非阻塞connect"
url: "/2015/06/18/network_connect"
---

本文总结了关于非阻塞connect的处理细节，实现细节，作简要总结。
<!--more-->

### 非阻塞connect的用途
非阻塞的TCP套接字上调用connect时，connect将立即返回一个EINPROCESS错误，不过已经发起的TCP三路握手继续进行。接着用select检测这个连接或成功或失败的已建立条件。非阻塞connect有三个用途：

1. 我们可以把三路握手的时间叠加到其他处理上。完成一个connect要花费一个RTT时间，该时间波动范围很大，从几毫秒到几秒。这段时间内也许我们可以执行其他我们想要执行的工作。
2. 可以使用这个技术同时建立多个连接，这个用途已经随着web浏览器变得流行起来。
3. 由于我们用select等待连接的完成，因此可以给select设置一个时间限制，从而缩短connect的超时时间。

### 非阻塞connect的处理细节

1. 即使套接字是非阻塞的，如果连接服务器在同一台主机上，在调用connect时连接通常会立刻建立，我们必须处理这种情况。
2. 源自Berkeley的实现有两条与select和非阻塞I/O相关的规则: 当连接成功建立时，描述字变成可写; 当连接成功出错时，描述字变成即可读又可写

### 套接字可读/可写的条件
关于这里的套接字的可读可写，在《Unix网络编程（卷1）》第6章有这样的描述：

对于select返回套接字"准备好 可读/可写" 的明确条件：

1. 下列四个条件中任何一个满足时，套接字准备好读：

    a.  套接字缓冲区中的数据字节数大于等于套接字接收缓冲区中低潮限度的当前值。（我们可以用套接字选项SO_RCVLOWAT来设置此低潮限度， TCP/UDP默认值为1）。

    b.  连接的读这一半关闭（也就是说接收了FIN端的TCP连接），对这样的套接字的读操作将不阻塞且返回0（即为文件结束符）。

    c.   套接字是一个侦听套接字，且已经完成的连接数大于0。这样的监听套接字在accept上一般不会阻塞。

    d.  有一个套接字错误待处理。对这样的套接字的读操作将不会阻塞且返回一个错误值（-1）。errno设置成明确的错误条件。

 
2. 下列四个条件中任何一个满足时，套接字准备好写：

	a.  套接字发送缓冲区中的可用空间字节数大于等于套接字发送缓冲区低潮限度的当前值（ TCP/UDP默认值为2048）。

    b.  该连接的写半部关闭，对这样的套接字的写操作将产生SIGPIPE信号（参见上篇《服务器关闭与TCP异常》）。

    c.  使用非阻塞connect的套接字已经建立连接，或者connect已经以失败告终。

    d.  其上有一个套接字错误待处理。对这样的套接字的写操作将不阻塞并返回-1，同时把errno设置为确切的错误条件。

 注意：当某个套接字上发生错误时，它将由select标记为既可读又可写。

### 代码分析
以下为常用的非阻塞connect的实现模块（摘录自《Unix网络编程》 Unit16）
	
	int connect_nonb(int sockfd, const SA *saptr, socklen_t salen, int nsec) {
	　　int flags, n, error;
	　　socklen_t len;
	　　fd_set rset, wset;
	　　struct timeval tval;
	　　/* 获取当前socket的属性， 并设置 noblocking 属性 */
	　　flags = fcntl(sockfd, F_GETFL, 0);
	　　fcntl(sockfd, F_SETFL, flags | O_NOBLOCK);
	　　errno = 0;
	     /*=========================================
	      期望获得的错误(EINPROGRESS):
		       表示连接建立已经启动但尚未完成
	      其他错误则返回给本函数的调用者
	     =========================================*/
	　　if ( (n = connect(sockfd, saptr, salen)) < 0)
	　　if (errno != EINPROGRESS)  
	　　return (-1);

	　　/* 这里可以做任何其它的操作*/

	　　if (n == 0)
	　　goto done;       /* 服务器与客户端为同一个主机, 会返回 0*/
	　　FD_ZERO(&rset);
	　　FD_SET(sockfd, &rset);
	　　wset = rset; 	
			tval.tv_sec = nsec;
			tval.tv_usec = 0;
	     /*=========================================
	     如果nsec 为0，将使用缺省的超时时间，即其结构指针为 NULL
	     如果select的返回值为0，则表示超时:
			关闭套接字
			返回ETIMEOUT错误给调用者
	    =========================================*/
	　　if ((n = select(sockfd+1, &rset, &west, NULL,nsec ?tval:NULL)) == 0)
	    {
	　　	close(sockfd);
	　　	errno = ETIMEOUT;
	　　	return (-1);
	　  }
	    /*====================================================
	     检查描述符的可读、可写
	     需要getsockopt检查套接字上是否存在待处理错误，判断连接建立是否成功了:
			因为套接字上发生错误时，它将由select标记为既可读又可写
	     这里getsockopt存在移植性问题(以下代码兼容两种情况)：
			Berkeley实现, getsockopt返回0，error中返回待处理错误
			Solaris中getsockopt返回-1，error中返回待处理错误
	    ====================================================*/
	　　if(FD_ISSET(sockfd, &rset) || FD_ISSET(sockfd, &west))
			{

	　　	len = sizeof(error);
	　　	if (getsockopt(sockfd, SOL_SOCKET, SO_ERROR, &error, &len) < 0)
	　　	return (-1);
	　	}
	　　else err_quit(“select error: sockfd not set”);
	　　done:
	　　fcntl(sockfd, F_SETFL, flags);  /* 恢复socket 属性*/
	　　if (error)
	  {
	　　close(sockfd);
	　　errno = error;
	　　return (-1);
	　}
	　　Return (0);
	}



### 移植问题
首先，调用select之前，有可能连接已经建立并由来自对端的数据到达。该情况下，即使套接字上不发生错误，套接字也是既可读又可写，这和连接简历失败情况下套接字的读写条件一样。

除了getsockopt调用，还有其他方式可以判断连接建立是否成功么？UNIX网络编程提供的集中方案：

1. 调用getpeername代替 getsockopt。如果getpeername以ENOTCONN错误失败返回，那么连接建立已经失败，我们必须接着以SO_ERROR调用getsockopt取得套接字上待处理的错误；
2. 调用read,读取长度为0字节的数据.如果read调用失败,则表示连接建立失败,而且read返回的errno指明了连接失败的原因.如果连接建立成功,read应该返回0；
3. 再调用一次connect.它应该失败,如果错误errno是EISCONN,就表示套接口已经建立,而且第一次连接是成功的;否则,连接就是失败的。

### 参考文章
UNIX网络编程卷1： Unit16 非阻塞connect




