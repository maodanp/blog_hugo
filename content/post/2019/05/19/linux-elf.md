---
categories:
- "技术志"
tags:
- "linux"
date: 2019-05-19
title: "目标文件的那些事"
url: "/2019/05/19/linux-elf"
---

本篇主要探讨目标文件（Linux中的ELF）的内部结构，并对神秘目标文件一探究竟。
<!--more-->

### ELF 文件结构概述

我们知道可执行文件的形成需要经过`预编译`、`编译`、`汇编`、`链接`，最终形成可执行文件。

目标文件即为编译后生成的文件，它从文件结构上而言跟最终可执行文件是类似的，可能有些符号或者地址还需要调整。

Linux中ELF（Executable linkable Format）文件包括以下4类：

|    ELF文件类型    | 说明 |
| ---------- | --- |
| 可重定位文件（Relocatable File） |  其中包含数据与代码段，被用来链接生成可执行文件，静态链接库也归为这一类 |
| 可执行文件（Executable File）       |  最终可执行程序 |
| 共享目标文件（Shared object File）       |  包含数据和代码 |
| 核心转储文件（Core dump File）      |  由于进程意外终止形成的文件，包括进程地址空间及终止时的一些其他信息 |

#### 解析目标文件
通过以下的一个实例来解析下目标文件中包括哪些内容。
~~~cpp
/*
 * example.c
 * gcc -c example.c
 */
int printf(const char* format, ...);

int global_int_var = 84; 
int global_unint_var;

void fun1(int i)
{
    printf("%d\n", i); 
}

int main(void)
{
    static int static_var = 85; 
    static int static_var2;

    int a = 1;
    int b;

    func1(static_var + static_var2 + a + b); 
}
~~~

`global_int_var`与`global_unint_var`分别表示已初始化和未被初始化的全局静态变量。
`static_var`与`static_var2`分别表示已初始化和未被初始化的局部静态变量。
`a`和`b`分别表示已初始化和未被初始化的局部变量。

我们可以观察上面几个变量在目标文件中是怎么存储的。通过`objdump -h example.o` 可以查看该ELF的结构和内容。
~~~
Sections:
Idx Name          Size      VMA       LMA       File off  Algn
  0 .text         0000004c  00000000  00000000  00000034  2**2
                  CONTENTS, ALLOC, LOAD, RELOC, READONLY, CODE
  1 .data         00000008  00000000  00000000  00000080  2**2
                  CONTENTS, ALLOC, LOAD, DATA
  2 .bss          00000004  00000000  00000000  00000088  2**2
                  ALLOC
  3 .rodata       00000004  00000000  00000000  00000088  2**0
                  CONTENTS, ALLOC, LOAD, READONLY, DATA
  4 .comment      0000002e  00000000  00000000  0000008c  2**0
                  CONTENTS, READONLY
  5 .note.GNU-stack 00000000  00000000  00000000  000000ba  2**0
                  CONTENTS, READONLY
~~~
我用了32位的系统测试，所以对于64位，ELF的段结构会有差异。对照段长度（Size）和偏移位置（File Offset）可以得出如下结构图：

![pic](/pic/2019/2019-05-19-elf-1.png)

#### 段结构

* **ELF头文件（ELF header）**

描述整个文件的属性，包括文件是否可执行，是静态链接还是动态链接，目标硬件、目标操作系统。从上图可以看出，头文件的大小是固定的，为0x34个字节，后面一小节会有专门介绍。

* **段表（Section Table）**

描述文件中各个段的一个数组。描述各段在文件中偏移量、读写权限及段属性。后面一小节再专门介绍。

* **代码段（.text）**

保存执行语句编译后生成的机器代码

* **数据段（.data）与只读数据段（.rodata）**

保存已经初始化的全局变量和局部静态变量。只读数据段则保存程序里的只读变量。

通过命令：`objdump -x -s -d exmpale.o`， 可以查看到数据段：
~~~
......
Contents of section .data:
 0000 54000000 55000000                    T...U...
Contents of section .rodata:
 0000 25640a00                             %d..
......
~~~

可以看到 `.data` 的前4个字节，从低到高分别为 0x54, 0x00, 0x00, 0x00，刚好是 `global_int_var` , 十进制 84。后面4个字节则刚好是 `static_var` 的值 85。

> 现代PC的CUP中都是Little-Endian。Little-endian 规定MSB在存储是放在高地址，传输时放在流的末尾；LSB存储时放在低地址，传输时放在流的开始。

`.rodata` 段则是一个常量字符串 `%d\n` 外加结束符。

* **.bss段**

保存未初始化的全局变量和局部静态变量。理论上应该存储 `global_uninit_var` 和 `static_var2` 的总大小8字节，但是这里确只有4个字节。

这里编译器将 `global_uninit_var` 看作了一个未定义的全局变量符号，等到最终链接成可执行文件时才会再在 `.bss` 段中分配空间。

> 编译器默认的函数和初始化了的全局变量作为强符号，未初始化的全局变量作为弱符号。

~~~
Idx Name          Size      VMA       LMA       File off  Algn
......
  2 .bss          00000004  00000000  00000000  00000088  2**2
......
~~~

### ELF 文件结构详述

这里我先将这个ELF的文件中所有的段位置、长度都画出来，中间的 `Section Table` 以及 `.real.text` 都由于对齐原因与前面的段之间分别有一个字节的间隔。

![pic](/pic/2019/2019-05-19-elf-2.png)

最后 `.real.text` 结束后长度为 0x450, 恰好是 `example.o` 的文件大小。下面分别描述这些不同的段结构信息。

#### ELF头文件 （ELF Header）
通过 `readelf -h example.o` 命令可以查看ELF头文件的具体信息。

~~~
ELF Header:
  Magic:   7f 45 4c 46 01 01 01 00 00 00 00 00 00 00 00 00
  Class:                             ELF32
  Data:                              2's complement, little endian
  Version:                           1 (current)
  OS/ABI:                            UNIX - System V
  ABI Version:                       0
  Type:                              REL (Relocatable file)
  Machine:                           Intel 80386
  Version:                           0x1
  Entry point address:               0x0
  Start of program headers:          0 (bytes into file)
  Start of section headers:          268 (bytes into file)
  Flags:                             0x0
  Size of this header:               52 (bytes)
  Size of program headers:           0 (bytes)
  Number of program headers:         0
  Size of section headers:           40 (bytes)
  Number of section headers:         11
  Section header string table index: 8
~~~

分别对应了 `/usr/include/elf.h` 中的头文件结构。分别定义了**ELF魔数**、**文件机器字节长度**、**数据存储方式**、**版本**、**运行平台**、**ABI版本**、**ELF重定位类型**、**硬件平台**、**硬件平台版本**、**入口地址**、**程序头入口和长度**、**段表的位置和长度**及**段数量**等 。
~~~cpp
typedef struct
{
  unsigned char e_ident[EI_NIDENT]; /* Magic number and other info */
  Elf32_Half    e_type;         /* Object file type */
  Elf32_Half    e_machine;      /* Architecture */
  Elf32_Word    e_version;      /* Object file version */
  Elf32_Addr    e_entry;        /* Entry point virtual address */
  Elf32_Off e_phoff;        /* Program header table file offset */
  Elf32_Off e_shoff;        /* Section header table file offset */
  Elf32_Word    e_flags;        /* Processor-specific flags */
  Elf32_Half    e_ehsize;       /* ELF header size in bytes */
  Elf32_Half    e_phentsize;        /* Program header table entry size */
  Elf32_Half    e_phnum;        /* Program header table entry count */
  Elf32_Half    e_shentsize;        /* Section header table entry size */
  Elf32_Half    e_shnum;        /* Section header table entry count */
  Elf32_Half    e_shstrndx;     /* Section header string table index */
} Elf32_Ehdr;
~~~

其中，`e_ident[EI_NIDENT]` 即为ELF的魔数。各个字节含义见下表：

|    字节    | 说明 |
| ---------- | --- |
| 7f |  ASCII中DEL控制字符 |
| 45 4c 46       |  对应ELF三个字符的ASCII |
| 01       |  32位系统， 02则表示64位 |
| 01      |  字节序 |
| 01      |  ELF主版本号 |


#### 段表（Section Header Table）

前面介绍过 `.text`, `.data` 等基本的段，这个段表就是用来保存这些段的基本属性。如每个段的段名、段长度、在文件中的偏移、读写权限以及段的其他属性。

通过 `readelf -S example.o`可以看到所有的段表结构：

~~~
There are 11 section headers, starting at offset 0x10c:

Section Headers:
  [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al
  [ 0]                   NULL            00000000 000000 000000 00      0   0  0
  [ 1] .text             PROGBITS        00000000 000034 00004c 00  AX  0   0  4
  [ 2] .rel.text         REL             00000000 000428 000028 08      9   1  4
  [ 3] .data             PROGBITS        00000000 000080 000008 00  WA  0   0  4
  [ 4] .bss              NOBITS          00000000 000088 000004 00  WA  0   0  4
  [ 5] .rodata           PROGBITS        00000000 000088 000004 00   A  0   0  1
  [ 6] .comment          PROGBITS        00000000 00008c 00002e 01  MS  0   0  1
  [ 7] .note.GNU-stack   PROGBITS        00000000 0000ba 000000 00      0   0  1
  [ 8] .shstrtab         STRTAB          00000000 0000ba 000051 00      0   0  1
  [ 9] .symtab           SYMTAB          00000000 0002c4 000100 10     10  10  4
  [10] .strtab           STRTAB          00000000 0003c4 000063 00      0   0  1
Key to Flags:
  W (write), A (alloc), X (execute), M (merge), S (strings)
  I (info), L (link order), G (group), x (unknown)
  O (extra OS processing required) o (OS specific), p (processor specific)
~~~

以上输出分别对应了 `/usr/include/elf.h` 中的段表文件结构。

~~~cpp
typedef struct
{
  Elf32_Word    sh_name;        /* Section name (string tbl index) */
  Elf32_Word    sh_type;        /* Section type */
  Elf32_Word    sh_flags;       /* Section flags */
  Elf32_Addr    sh_addr;        /* Section virtual addr at execution */
  Elf32_Off sh_offset;      /* Section file offset */
  Elf32_Word    sh_size;        /* Section size in bytes */
  Elf32_Word    sh_link;        /* Link to another section */
  Elf32_Word    sh_info;        /* Additional section information */
  Elf32_Word    sh_addralign;       /* Section alignment */
  Elf32_Word    sh_entsize;     /* Entry size if section holds table */
} Elf32_Shdr;
~~~

#### 重定位表（Relocatable Table）

`.rel.text` 为重定位表，即表示代码段中与一个需要重定位的代码段。`.rel.text` 就是对 `.text` 的重定位表，因为 `.text` 中有对 `printf` 外部函数的调用，需要在链接阶段重定位其实际函数地址。


#### 字符串表（String Table）
常见有 `.strtab` 和 `.shstrtab` 两种字符串表，分别表示为字符串表（string table）和段表字符串表（section header string table）。

字符串表存放普通字符串的，段表字符串表则是用来保存段表中用到的字符串名的。

#### 符号表（Symbol Table）

整个链接过程正是基于符号才能正确完成，每一个目标文件都会有一个相应的符号表，这个表里记录了目标文件中所用到的所有符号。
每个定义的符号有一个对应的值，对于函数和变量来说，这个符号值就是它们的地址。 `.symtab` 中进行存储。

通过 `readelf -s example.o` 命令可以查看ELF头文件的具体信息。

~~~
Symbol table '.symtab' contains 16 entries:
   Num:    Value  Size Type    Bind   Vis      Ndx Name
     0: 00000000     0 NOTYPE  LOCAL  DEFAULT  UND
     1: 00000000     0 FILE    LOCAL  DEFAULT  ABS exmpale.c
     2: 00000000     0 SECTION LOCAL  DEFAULT    1
     3: 00000000     0 SECTION LOCAL  DEFAULT    3
     4: 00000000     0 SECTION LOCAL  DEFAULT    4
     5: 00000000     0 SECTION LOCAL  DEFAULT    5
     6: 00000004     4 OBJECT  LOCAL  DEFAULT    3 static_var.1243
     7: 00000000     4 OBJECT  LOCAL  DEFAULT    4 static_var2.1244
     8: 00000000     0 SECTION LOCAL  DEFAULT    7
     9: 00000000     0 SECTION LOCAL  DEFAULT    6
    10: 00000000     4 OBJECT  GLOBAL DEFAULT    3 global_int_var
    11: 00000004     4 OBJECT  GLOBAL DEFAULT  COM global_unint_var
    12: 00000000    27 FUNC    GLOBAL DEFAULT    1 fun1
    13: 00000000     0 NOTYPE  GLOBAL DEFAULT  UND printf
    14: 0000001b    49 FUNC    GLOBAL DEFAULT    1 main
    15: 00000000     0 NOTYPE  GLOBAL DEFAULT  UND func1
~~~

以上输出分别对应了 `/usr/include/elf.h` 中的符号表文件结构。

~~~cpp
typedef struct
{
  Elf32_Word    sh_name;        /* Section name (string tbl index) */
  Elf32_Word    sh_type;        /* Section type */
  Elf32_Word    sh_flags;       /* Section flags */
  Elf32_Addr    sh_addr;        /* Section virtual addr at execution */
  Elf32_Off sh_offset;      /* Section file offset */
  Elf32_Word    sh_size;        /* Section size in bytes */
  Elf32_Word    sh_link;        /* Link to another section */
  Elf32_Word    sh_info;        /* Additional section information */
  Elf32_Word    sh_addralign;       /* Section alignment */
  Elf32_Word    sh_entsize;     /* Entry size if section holds table */
} Elf32_Shdr;
~~~

其中 `sh_info` 为符号类型和绑定信息。其中低4位为符号类型，高4位位符号绑定信息。对应输出中的 `Type` 与 `Bind` 两项。

|    Type 类型    | 说明 |
| ---------- | --- |
| NOTYPE |  未知类型符号 |
| OBJECT       |  数据对象，如变量、数组 |
| FUNC       |  函数或其他可执行代码 |
| SECTION      |  表示一个段 |
| FILE      |  表示文件名 |

|    Bind 类型    | 说明 |
| ---------- | --- |
| LOCAL |  局部符号，目标文件外部不可见 |
| GLOBAL       |  全局符号，外部课件 |



