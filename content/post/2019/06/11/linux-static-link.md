---
categories:
- "技术志"
tags:
- "linux"
date: 2019-06-11
title: "Linux的静态链接"
url: "/2019/06/11/linux-static-link"
---

本篇将详细讲述 Linux 中静态链接的过程，即链接器如何为目标文件分配在输出文件中的空间和地址，如何进行外部符号的解析与重定位。

<!--more-->

比如对于两个文件 `a.c` 与 `b.c` 形成的目标文件，我们可以通过如下命令形成可执行文件。
~~~
gcc -c a.c b.c
~~~

其中
~~~cpp
/*a.c*/
extern int shared;

int main()
{
    int a = 100;
    swap (&a, &shared);
    return 0;
}
~~~

~~~cpp
/*b.c*/
int shared = 1;

void swap(int *a, int *b)
{
    *a ^= *b ^= *a ^= *b;
}
~~~

其中模块 `b.c` 总共定义了两个全局符号，一个是变量"shared"，另一个是函数“swap”，并且在模块 `a.c` 里面引用了这两个全局符号。

我们知道可执行文件中的代码段和数据段都是通过输入的目标文件中合并而来的，那链接器如何将它们的各个段合并在输出文件中的呢？

现代链接器空间分配策略基本都采用两步链接（Two-pass Linking）的方法，即：

**第一步 空间与地址分配** 扫描所有的输入目标文件，获得各个段的长度、属性和位置，并且将输入目标文件中的符号表中所有的符号定义和符号引用收集起来，统一放到一个全局符号表。这一步中，链接器将能够获得所有输入目标文件的段长度，并且将它们合并，计算输出文件中各个段合并后的长度与位置，并建立映射关系。

**第二步 符号解析与重定位** 使用上面第一步中收集到的所有信息，读取输入文件中断的数据、重定位信息，并且进行符号解析与重定位、调整代码中的地址。

### 空间与地址分配

现代链接器一般将相同性质的段合并在一起，比如将所有输入文件的 `.text` 合并到输出文件的 `.text` 段，接着是 `.data` 段、`.bss` 段等等不同段进行合并。`.bss` 段在目标文件和可执行文件中并不占用文件的空间，但是它在装载时占用虚拟地址的地址空间。

![pic](/pic/2019/2019-06-11-linux-static-link-01.png)

我们使用 `ld` 命令将 a.o 和 b.o 链接起来：

~~~shell
$ld a.o b.o -e main -o ab
~~~

使用 objdump 来查看链接前后地址的分配情况：

~~~shell
$ objdump -h a.o

a.o:     file format elf32-i386

Sections:
Idx Name          Size      VMA       LMA       File off  Algn
  0 .text         0000002c  00000000  00000000  00000034  2**2
                  CONTENTS, ALLOC, LOAD, RELOC, READONLY, CODE
  1 .data         00000000  00000000  00000000  00000060  2**2
                  CONTENTS, ALLOC, LOAD, DATA
  2 .bss          00000000  00000000  00000000  00000060  2**2
                  ALLOC
...

$ objdump -h b.o 

b.o:     file format elf32-i386

Sections:
Idx Name          Size      VMA       LMA       File off  Algn
  0 .text         0000003a  00000000  00000000  00000034  2**2
                  CONTENTS, ALLOC, LOAD, READONLY, CODE
  1 .data         00000004  00000000  00000000  00000070  2**2
                  CONTENTS, ALLOC, LOAD, DATA
  2 .bss          00000000  00000000  00000000  00000074  2**2
                  ALLOC
...


$ objdump -h ab

ab:     file format elf32-i386

Sections:
Idx Name          Size      VMA       LMA       File off  Algn
  0 .text         00000066  08048094  08048094  00000094  2**2
                  CONTENTS, ALLOC, LOAD, READONLY, CODE
  1 .data         00000004  080490fc  080490fc  000000fc  2**2
                  CONTENTS, ALLOC, LOAD, DATA
...
~~~

其中 VMA 表示 Virtual Memory Address，即虚拟地址，LMA 表示 Load Memory Address，即加载地址。正常情况下两个值都是一样的。

通过上面的地址分配结果可以知道，在链接前目标文件中的所有段的 VMA 都是 0 ， 因为虚拟地址空间还没有被分配，所以它们默认都是 0 。链接之后，可执行文件 ab 中，所有地址都已经是程序在进程中的虚拟地址空间，即我们关心上面各个段中的 VMA 和 Size，而忽略文件偏移（File  offset）。

![pic](/pic/2019/2019-06-11-linux-static-link-02.png)

上图中我们忽略了像 `.comments` 这样的段，只关心代码段和数据段。可以看到，a.o, b.o 代码段被先后叠加起来，合并成 ab 的一个 `.text` 段，加起来的长度为 `0x72`。 所以 ab 的代码段里是包含了 `main` 函数和 `swap` 函数的指令代码。

### 符号解析与重定位

在完成空间和地址的分配步骤之后，链接器就进入了**符号解析与重定位**的步骤。在分析符号解析和重定位之前，首先让我们看看 a.o 里面是怎么使用这两个外部符号的，也就是 a.c 使用的 `shared` 变量和 `swap` 函数。

使用 objdump 的 `-d` 参数可以看到 a.o 的代码段反汇编结果：

~~~shell
$ objdump -d a.o 

a.o:     file format elf32-i386

Disassembly of section .text:

00000000 <main>:
   0:	55                   	push   %ebp
   1:	89 e5                	mov    %esp,%ebp
   3:	83 e4 f0             	and    $0xfffffff0,%esp
   6:	83 ec 20             	sub    $0x20,%esp
   9:	c7 44 24 1c 64 00 00 	movl   $0x64,0x1c(%esp)
  10:	00 
  11:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
  18:	00 
  19:	8d 44 24 1c          	lea    0x1c(%esp),%eax
  1d:	89 04 24             	mov    %eax,(%esp)
  20:	e8 fc ff ff ff       	call   21 <main+0x21>
  25:	b8 00 00 00 00       	mov    $0x0,%eax
  2a:	c9                   	leave  
  2b:	c3                   	ret   
~~~

通过反汇编，我们可以清楚看到 a.o 共占用了 `0x2c` 个字节，与之前我们看到的 a.o 的 Size 相符合，共 17 条指令，其中最左边为每条指令的偏移量，中间则代表每一条指令。

其中偏移量为 `11` 的位置代表对于 `shared` 的引用是一条 `mov` 指令，这条指令总共 8 个字节，它的作用是将 `shared` 的地址赋值到 ESP 寄存器 +4 的偏移地址上去。 前面的 4 个字节是指令码， 后面的 4 个字节是 `shared` 的地址。

当源代码 a.c 在被编译成目标文件时，编译器并不是到 `shared` 和 `swap` 的地址，因为它们定义在其他目标文件中。所以编译器就暂时把地址 0  看作是 `shared` 的地址。

![pic](/pic/2019/2019-06-11-linux-static-link-03.png)

另一个是偏移为 `0x20` 的指令的一条调用指令，它其实是对 `swap` 函数的调用，如下图：

![pic](/pic/2019/2019-06-11-linux-static-link-04.png)

这条指令是一条**近址相对位移调用指令**，后面 4 个字节就是被调用函数的相对于调用指令的下一条指令的偏移量。在没有重定位之前，相对偏移被置为 `0xFFFFFFFC`（小端，为常量 -4 的补码）。紧跟在这条 call 指令后面的那条指令是 add 指令，add 指令的地址为 0x25，而相对于 add 指令偏移为 -4 的地址为 `0x25 - 4 = 0x21`，但是 `0x21` 存放的并不是 swap 函数的地址。跟前面 `shared` 一样， `0xFFFFFFFC` 只是一个临时的假地址，因为在编译的时候，编译器并不知道 `swap` 的真正地址。

通过前面的空间与地址分配可以得知，链接器在完成地址和空间分配之后就已经可以确定所有符号的虚拟地址了，那么链接器就可以根据符号的地址对每个须要重定位的指令进行地址修正。我们反汇编 ab 的代码段，可以看到 `main` 函数的两个重定位入口都已经被修正到了正确的位置：

~~~shell
$ objdump -d ab 

ab:     file format elf32-i386

Disassembly of section .text:

08048094 <main>:
 8048094:	55                   	push   %ebp
 8048095:	89 e5                	mov    %esp,%ebp
 8048097:	83 e4 f0             	and    $0xfffffff0,%esp
 804809a:	83 ec 20             	sub    $0x20,%esp
 804809d:	c7 44 24 1c 64 00 00 	movl   $0x64,0x1c(%esp)
 80480a4:	00 
 80480a5:	c7 44 24 04 fc 90 04 	movl   $0x80490fc,0x4(%esp)
 80480ac:	08 
 80480ad:	8d 44 24 1c          	lea    0x1c(%esp),%eax
 80480b1:	89 04 24             	mov    %eax,(%esp)
 80480b4:	e8 07 00 00 00       	call   80480c0 <swap>
 80480b9:	b8 00 00 00 00       	mov    $0x0,%eax
 80480be:	c9                   	leave  
 80480bf:	c3                   	ret    

080480c0 <swap>:
 80480c0:	55                   	push   %ebp
 80480c1:	89 e5                	mov    %esp,%ebp
 80480c3:	53                   	push   %ebx

~~~

经过修正后，`shared` 和 `swap` 的地址分别为 `0x080490fc` 和 `0x00000007`。关于 `shared` 很好理解，之前分析过，该变量的地址就是 `0x080490fc`；对于 `swap` 来说，这个 `call` 指令是一条**近址相对位移调用指令**，它后面的指令是 `add` 指令，地址为 `0x80480b9`, 所以 “相对于 add 指令偏移量为 0x00000007” 的地址为 `0x80480b9 + 7 = 0x80480c0`，即刚好是 `swap` 函数的地址 （可以通过 `main` 函数地址 `0x08048094` + 长度 `0x2c` 获得）。

#### 重定位表
链接器是怎么知道哪些指令需要被调整，怎么调整的？在ELF文件中，有一个叫重定位表（Relocation Table）的结构专门用来保存这些与重定位相关的信息。

比如代码段 `.text` 如有要被重定位的地方，则有一个相对应的 `.rel.text` 的段保存代码段的重定位表；如果数据段 `.data` 有要被重定位的地方，就会有一个相对应的 `.rel.data` 的段保存数据段的重定位表。可以通过 objdump 来查看目标文件的重定位表：

~~~shell
$ objdump -r a.o

a.o:     file format elf32-i386

RELOCATION RECORDS FOR [.text]:
OFFSET   TYPE              VALUE 
00000015 R_386_32          shared
00000021 R_386_PC32        swap
~~~

我们可以看到 a.o 里面有两个重定位的入口。第一列表示重定位入口的偏移（Offset） 表示该入口在要被重定位的断中的位置，对照前面反汇编结果可知，`0x15` 和 `0x21` 分别对应代码中的 `mov` 指令和 `call` 指令的地址部分。

第二列表示重定位入口的类型，其中 `R_386_32` 表示 32 位的绝对寻址修正，`R_386_PC32` 表示 32 位的相对寻址修正。


#### 符号解析

我们平时在编写程序时常遇到的问题之一是在链接时符号未定义。前面已经介绍了重定位的过程，重定位过程也伴随着符号的解析过程，每个目标文件都可能定义一些符号，也可能引用到定义在其他目标文件的符号。

> 重定位的过程中，每个重定位的入口都是对一个符号的引用，那么当链接器需要对某个符号的引用进行重定位时，它就要确定这个符号的目标地址，这时候链接器就回去查找由所有输入目标文件的符号表组成的全局符号表，找到相应的符号后进行重定位。

比如我们查看 a.o 的符号表：

~~~shell
$ readelf -s a.o 

Symbol table '.symtab' contains 10 entries:
   Num:    Value  Size Type    Bind   Vis      Ndx Name
     0: 00000000     0 NOTYPE  LOCAL  DEFAULT  UND 
     1: 00000000     0 FILE    LOCAL  DEFAULT  ABS a.c
     2: 00000000     0 SECTION LOCAL  DEFAULT    1 
     3: 00000000     0 SECTION LOCAL  DEFAULT    3 
     4: 00000000     0 SECTION LOCAL  DEFAULT    4 
     5: 00000000     0 SECTION LOCAL  DEFAULT    6 
     6: 00000000     0 SECTION LOCAL  DEFAULT    5 
     7: 00000000    44 FUNC    GLOBAL DEFAULT    1 main
     8: 00000000     0 NOTYPE  GLOBAL DEFAULT  UND shared
     9: 00000000     0 NOTYPE  GLOBAL DEFAULT  UND swap
~~~

其中有两项 `shared` 和 `swap` 都是 `UND`, 即 `undefined` 未定义类型，这种未定义的符号都是因为该目标文件中有关于它们的重定位项。所以在链接器扫描完所有的输入目标文件之后，所有这些未定义的符号都应该能够在全局符号表中找到，否则链接器就会报符号未定义错误。

我们也可以看下链接之后可执行文件中是否还有未定义的符号类型：

~~~shell
 $ readelf -s ab 

Symbol table '.symtab' contains 12 entries:
   Num:    Value  Size Type    Bind   Vis      Ndx Name
     0: 00000000     0 NOTYPE  LOCAL  DEFAULT  UND 
     1: 08048094     0 SECTION LOCAL  DEFAULT    1 
     2: 080490fc     0 SECTION LOCAL  DEFAULT    2 
     3: 00000000     0 SECTION LOCAL  DEFAULT    3 
     4: 00000000     0 FILE    LOCAL  DEFAULT  ABS a.c
     5: 00000000     0 FILE    LOCAL  DEFAULT  ABS b.c
     6: 080480c0    58 FUNC    GLOBAL DEFAULT    1 swap
     7: 080490fc     4 OBJECT  GLOBAL DEFAULT    2 shared
     8: 08049100     0 NOTYPE  GLOBAL DEFAULT  ABS __bss_start
     9: 08048094    44 FUNC    GLOBAL DEFAULT    1 main
    10: 08049100     0 NOTYPE  GLOBAL DEFAULT  ABS _edata
    11: 08049100     0 NOTYPE  GLOBAL DEFAULT  ABS _end
~~~

我们看到 `shared` 和 `swap` 的 `Ndx` 分别为 2、1。表示符号所在的段索引分别为2、1, 那段索引怎么看呢？如果你还记得之前的一篇[目标文件的那些事](https://maodanp.github.io/2019/05/19/linux-elf/)，你应该就能联想到了这里代表的含义，可以通过 `readelf -a` 命令查看：

~~~shell
$ readelf -a ab
ELF Header:
 ...

Section Headers:
  [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al
  [ 0]                   NULL            00000000 000000 000000 00      0   0  0
  [ 1] .text             PROGBITS        08048094 000094 000066 00  AX  0   0  4
  [ 2] .data             PROGBITS        080490fc 0000fc 000004 00  WA  0   0  4
  [ 3] .comment          PROGBITS        00000000 000100 00002d 01  MS  0   0  1
  [ 4] .shstrtab         STRTAB          00000000 00012d 000030 00      0   0  1
  [ 5] .symtab           SYMTAB          00000000 000278 0000c0 10      6   6  4
  [ 6] .strtab           STRTAB          00000000 000338 000032 00      0   0  1
   ...
~~~

从上图可知，`shared` 和 `swap` 表示这些符号分别位于**数据段**和**代码段**。

### 总结

本篇详述了静态链接的两个步骤，即目标文件在被链接成最终可执行文件时，输入目标文件中的各个段是如何被合并到输出文件中的。一旦输入端的最终地址被确认，接下来链接器会对各个输入目标文件中外部符号的引用进行解析，对每个段中须要重定位的指令和数据进行“修补”，使它们都指向正确的位置。

### 参考阅读

《程序员的自我修养-链接、装载与库》- 第 4 章 静态链接
