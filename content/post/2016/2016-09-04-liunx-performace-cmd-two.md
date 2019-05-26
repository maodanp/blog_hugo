---
categories:
- "工具箱"
tags:
- Linux
- 服务器性能
date: 2016-09-04
title: "Liunx性能检测常用命令(二)"
url: "/2016/09/04/linux-performace-cmd-two"
---

[前一篇](/2016/09/03/linux-performace-cmd-one)讲述了Linux分析常用的一些命令，本篇继续分析其他常用命令。
<!--more-->

### iostat
iostat主要用于监控系统设备的IO负载情况。 主要用法如下:

~~~
iostat -xz 1

Device:         rrqm/s   wrqm/s     r/s     w/s   rsec/s   wsec/s avgrq-sz avgqu-sz   await  svctm  %util
sda               0.00    51.00    0.00   22.00     0.00   648.00    29.45     0.00    0.05   0.05   0.10

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.88    0.00    0.38    0.04    0.00   98.70

Device:         rrqm/s   wrqm/s     r/s     w/s   rsec/s   wsec/s avgrq-sz avgqu-sz   await  svctm  %util
sda               0.00    20.00    0.00   16.00     0.00   288.00    18.00     0.01    0.75   0.06   0.10

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           3.69    0.00    0.88    0.00    0.00   95.43
~~~

其中，`-x`将用于显示和io相关的扩展数据; `-z`将取消显示在该间隔统计数据中无io活动的设备。

* `r/s, w/s, rkB/s, wkB/s` 分别表示每秒读写次数和每秒读写数据量（千字节）。读写量过大，可能会引起性能问题。
* `await` IO操作的平均等待时间，单位是毫秒。这是应用程序在和磁盘交互时，需要消耗的时间，包括IO等待和实际操作的耗时。如果这个数值过大，可能是硬件设备遇到了瓶颈或者出现故障。
* `avgqu-sz` 向设备发出的请求平均数量。如果这个数值大于1，可能是硬件设备已经饱和（部分前端硬件设备支持并行写入）。
* `%util` 设备利用率。这个数值表示设备的繁忙程度，经验值是如果超过60，可能会影响IO性能（可以参照IO操作平均等待时间）。如果到达100%，说明硬件设备已经饱和。

### free

~~~
free -m

              total       used       free      shared     buffers   cached
Mem:           1002        769        232        0           62       421
-/+ buffers/cache:         286        715
Swap: 1153 0 1153
~~~

第一部分Mem行。该行是针对OS而言的，它认为buffers/cached都是属于被使用,所以它认为free只有232M。存在如下关系：

~~~
total(1002M) = used(769M) + free(232M)
~~~
第二部分(-/+ buffers/cache)从应用程序的角度而言的，Mem行的buffers/cached 是等同可用的，因为buffer/cached是为了提高程序执行的性能，当程序使用内存时，buffer/cached会很快地被使用。

~~~
* (-buffers/cache) used内存数：286M (Mem行中的used – buffers – cached)
* (+buffers/cache) free内存数: 715M (Mem行中的free + buffers + cached)
~~~
**从应用的角度看，可用内存就是-/+ buffers/cache行的free**，如果可用内存非常少，系统可能会动用交换交换分区（如果配置了的话），这样会增加IO开销（可以在iostat命令中提现），降低系统性能。

### sar
#### 网络设备的吞吐率
`sar -n DEV 1` 可以用于查看各个网络设备的吞吐量，判断网络设备的饱和度。

~~~
sar -n DEV 1

11时58分49秒     IFACE   rxpck/s   txpck/s    rxkB/s    txkB/s   rxcmp/s   txcmp/s  rxmcst/s
11时58分50秒        lo    174.75    174.75     99.00     99.00      0.00      0.00      0.00
11时58分50秒       em1     27.27     19.19     13.53      3.12      0.00      0.00      1.01
11时58分50秒       em2      6.06      0.00      0.38      0.00      0.00      0.00      1.01
11时58分50秒       em3     98.99     94.95     37.58      7.10      0.00      0.00      0.00
11时58分50秒       em4      0.00      0.00      0.00      0.00      0.00      0.00      0.00
11时58分50秒   docker0      0.00      0.00      0.00      0.00      0.00      0.00      0.00
11时58分50秒    virbr0      0.00      0.00      0.00      0.00      0.00      0.00      0.00
11时58分50秒 virbr0-nic     0.00      0.00      0.00      0.00      0.00      0.00      0.00
~~~
其中，`rxkB/s`，`txkB/s`分别表示网卡的单位时间的进出口流量。在排查性能问题时，可以通过网络设备的吞吐量，判断网络设备是否已经饱和。

#### TCP连接状态
`sar -n TCP,ETCP 1`可以用于查看TCP连接状态。

~~~
sar -n TCP,ETCP 1

12时03分21秒  active/s passive/s    iseg/s    oseg/s
12时03分22秒     13.13     11.11    277.78    283.84
~~~
其中参数含义：

* active/s：每秒本地发起的TCP连接数，既通过connect调用创建的TCP连接
* passive/s：每秒远程发起的TCP连接数，即通过accept调用创建的TCP连接
* retrans/s：每秒TCP重传数量

TCP连接数可以用来判断性能问题是否由于建立了过多的连接，进一步可以判断是主动发起的连接，还是被动接受的连接。TCP重传可能是因为网络环境恶劣，或者服务器压力过大导致丢包。
### 参考阅读
[centos 下安装监控工具](http://www.tuicool.com/articles/mAFjaq)

[正确解读free -m](http://www.cnblogs.com/zhaoyl/p/4325811.html)

[linux sar 命令详解](http://www.chinaz.com/server/2013/0401/297942.shtml)