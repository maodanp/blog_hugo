---
categories:
- "技术志"
tags:
- "linux"
date: 2019-05-26
title: "Linux的系统调用"
url: "/2019/05/26/linux-syscall"
---

系统调用是应用程序与操作系统内核之间的接口。本篇主要剖析 Linux 中系统调用的原理，详述系统调用从用户态到内核态的流程。
<!--more-->

### 系统调用介绍

系统调用是操作系统为应用程序提供的一套接口，不仅包含应用程序运行所必需的支持，例如创建/退出进程，进程内存管理，也有对系统资源的访问，如文件、网络、进程通信、硬件设备访问等。

系统调用作为接口，首先必需要有明确的定义，这样应用程序才能正确使用它，其次是需要保持向后兼容，以保证系统升级后原来的应用程序也能够正常的使用。

#### 系统调用与运行库

由于系统调用是各个操作系统提供的，所以会导致不同的操作系统的系统调用不能兼容，而且系统调用的接口相对比较原始，没有经过很好的封装。

运行库就是为了实现不同系统的兼容性，在系统调用与程序之间做了一层抽象层。作为语言级别的抽象库一般都封装的比较好，并且对于标准库，能够实现不同操作系统之间的兼容。

例如 Linux 下的 `read/write` 系统调用在 C 语言中是 `fread/fwrite` 标准库, 在 C++ 中是`iofstream` 标准库。但是运行库为了各个操作系统之间的兼容性，只能取各平台的交集，但是一些系统独有的系统调用就不同通过标准库调用了。

![pic](/pic/2019/2019-05-26-linux-syscall-01.png)

*系统调用与内核架构图*

#### 中断
操作系统一般是通过中断来完成从用户态切换到内核态的。即通过硬件或者软件向操作系统发送一个请求，要求 CPU 暂停当前的工作转而去处理更加重要的事。

中断一般具有两个属性，**中断号**以及**中断处理程序(Interrupt Service Routine, ISR)**。在内核中，有一个数组称为**中断向量表(Interrupt Vector Table)**，能够通过中断号找到对应的中断处理程序，并且中断处理程序执行完成之后，CPU 会返回继续执行用户态代码。

![pic](/pic/2019/2019-05-26-linux-syscall-02.png)
*内核中断处理*

Linux 使用 `int 0x80` 来触发所有的系统调用，并且系统调用号用 `eax` 存储，这样中断服务程序就可以从 `eax` 里取得系统调用号，进而调用对应的函数。

### 系统调用的实现原理

用户程序调用所有的系统调用的流程都是类似的，包含三部分:

* 用户程序需要设置系统调用的参数，传递给内核态。这里不同架构，以及不同系统的参数是不同的；
* 对于 x86，系统调用最终会调用 `glibc` 的 `DO_CALL`，这也就是程序将工作交给内核的切入点；
* 陷入内核态处理，并最终返回用户态，返回值也是内核完成对应任务后返回的值。如果内核执行该系统调用遇到错误，也会通过一个全局的错误号来存储错误信息。

#### 系统调用参数传递

在 i386 系统中，系统调用由 `int 0x80` 中断完成，各个通用寄存器用于传递参数，`eax` 寄存器用于系统调用的接口号。


|    arch    | arg1 |arg2 |arg3 |arg4 |arg5 |arg6 |
| ---------- | --- | --- |--- |--- |--- |--- |
|i386|ebx|ecx|edx|esi|edi|ebp|
|x86_64|rdi|rsi|rdx|r10|r8|r9|

*x86 架构通用寄存器参数对照表*

* 参数都是通过寄存器传递的，并且如上图所示，32 位和 64 位的寄存器也不一样。
* 系统调用的参数限制在 6 个

#### 系统调用在 glibc 中的实现

这里以常见的系统调用 open 为例，分析系统调用怎么实现的。glibc 的 open 函数定义如下：

~~~cpp
int open(const char *pathname, int flags, mode_t mode);
~~~

在 glibc 的源码中，有个文件 `syscalls.list`, 里面罗列了所有 glibc 的函数对应的系统调用，如下：

~~~
# File name	Caller	Syscall name	Args	Strong name	Weak names

accept		-	accept		Ci:iBN	__libc_accept	accept
access		-	access		i:si	__access	access
...
open		-	open		Ci:siv	__libc_open __open open
...
~~~

我们来看 glibc 中的文件 `open.c` 的实现函数 `__libc_open` :

~~~cpp
int
__libc_open (const char *file, int oflag, ...)
{
  int mode = 0;

  if (__OPEN_NEEDS_MODE (oflag))
    {
      va_list arg;
      va_start (arg, oflag);
      mode = va_arg (arg, int);
      va_end (arg);
    }

  return SYSCALL_CANCEL (openat, AT_FDCWD, file, oflag, mode);
}
~~~

最终，`SYSCALL_CANCEL` 在 `sysdep.h` 中的展开为：

~~~cpp
#define __INLINE_SYSCALL3(name, a1, a2, a3) \
INLINE_SYSCALL (name, 3, a1, a2, a3)
  
#ifndef INLINE_SYSCALL
#define INLINE_SYSCALL(name, nr, args...) __syscall_##name (args)
#endif
~~~

`__syscall_##name` 在代码中完全找不到, 应该是 makefile 中有调用 `make-syscalls.sh` 来生成嵌套代码, 其使用模板是 `syscall-template.S`。

在 `syscall-template.S` 中，定义了这个系统调用的调用方式：

~~~cpp
T_PSEUDO (SYSCALL_SYMBOL, SYSCALL_NAME, SYSCALL_NARGS)
    ret
T_PSEUDO_END (SYSCALL_SYMBOL)

#define T_PSEUDO(SYMBOL, NAME, N)		PSEUDO (SYMBOL, NAME, N)


#define PSEUDO(name, syscall_name, args)           \
  .text;                                        \
  ENTRY (name)                                    \
    DO_CALL (syscall_name, args);                  \
    cmpl $-4095, %eax;                               \
    jae SYSCALL_ERROR_LABEL
~~~

对于任何一个系统调用，会调用 `DO_CALL`。对于 **32 位系统**而言，该实现（`i386/sysdep.h`）如下：

~~~cpp
#define DO_CALL(syscall_name, args)			          \
    PUSHARGS_##args							  \
    DOARGS_##args							  \
    movl $SYS_ify (syscall_name), %eax;	      \
    ENTER_KERNEL							  \
    POPARGS_##args
~~~

其中 `movl $SYS_ify (syscall_name), %eax;` 表示将前面所讲的系统调用的调用号 `__NR_open` 赋给 `eax`。`ENTER_KERNEL` 宏展开就是 `int $0x80` 中断。

其中，`__NR_open` 是一个宏，表示 open 系统调用的调用号。32 位系统，该宏的定义可以在 Linux 系统中 `/usr/include/asm/unistd_32.h` 中找到，64 位系统可以在 `/usr/include/asm/unistd_64.h` 中找到。以下是 32 位系统的调用号的宏定义：
~~~
#define __NR_restart_syscall      0
#define __NR_exit         1
#define __NR_fork         2
#define __NR_read         3
#define __NR_write        4
#define __NR_open         5
#define __NR_close        6
......
~~~

对于 64 位系统而言，`DO_CALL`实现（`x86_64/sysdep.h`）的定义如下：
~~~cpp
#define DO_CALL(syscall_name, args)					      \
  lea SYS_ify (syscall_name), %rax;					      \
  syscall
~~~

这里 64 位系统还是将系统调用名称转换为系统调用号，放在寄存器 `rax` 中。但是不是通过中断，而是通过 `syscall` 指令进行真正的内核调用。`syscall` 指令使用了一种特殊的寄存器，**特殊模块寄存器（Model Specific Registers, MSR）**。


#### 内核对调用函数的处理

(以下内核代码都是基于 `4.10.1` 版本)


##### 触发中断与堆栈切换

在内核启动时调用 `start_kernel` 作为内核启动的函数入口， 其中有一个函数 `trap_init` 用于初始化中断的，里面有一句对于 `int $0x80` 的中断入口:

~~~cpp
set_system_intr_gate(IA32_SYSCALL_VECTOR, entry_INT80_32);
~~~

以下是 `entry_INT80_32` 的实现：

~~~
ENTRY(entry_INT80_32)
        ASM_CLAC
        pushl   %eax                    /* pt_regs->orig_ax */
        SAVE_ALL pt_regs_ax=$-ENOSYS    /* save rest */
        movl    %esp, %eax
        call    do_syscall_32_irqs_on
.Lsyscall_32_done:
......
.Lirq_return:
	INTERRUPT_RETURN
~~~

通过 `push` 和 `SAVE_ALL` 将当前用户态的寄存器，保存在 `pt_regs` 结构里，然后调用`do_syscall_32_irqs_on`。

~~~cpp
static __always_inline void do_syscall_32_irqs_on(struct pt_regs *regs)
{
	struct thread_info *ti = current_thread_info();
	unsigned int nr = (unsigned int)regs->orig_ax;
......
	if (likely(nr < IA32_NR_syscalls)) {
		regs->ax = ia32_sys_call_table[nr](
			(unsigned int)regs->bx, (unsigned int)regs->cx,
			(unsigned int)regs->dx, (unsigned int)regs->si,
			(unsigned int)regs->di, (unsigned int)regs->bp);
	}
	syscall_return_slowpath(regs);
}
~~~

这里将系统调用号从 eax 中取出，然后根据系统调用号，在系统调用表里找到对应函数进行带哦用，并将寄存器中保存的参数取出来作为函数参数传递。

最终 `INTERRUPT_RETURN` 宏展开后为 `iret`，将原来用户态保存的线程恢复回来。包含代码段、指令指针寄存器等。


##### 内核对系统函数的处理

内核中会维护一个系统调用号与对应函数的系统调用表。这里以 32 位的系统调用表（`arch/x86/entry/syscalls/syscall_32.tbl`）为例：
~~~
# <number> <abi> <name> <entry point> <compat entry point>
5	i386	open			sys_open  compat_sys_open
~~~

其中第一列数字就是系统调用号，第四列是系统调用在内核的实现函数，都是以 `sys_` 开头。

系统调用在内核中的实现函数声明一般在 `include/linux/syscalls.h` 文件中, 可以看到 `sys_open` 的声明：
~~~cpp
asmlinkage long sys_open(const char __user *filename,
				int flags, umode_t mode);
~~~

真正实现一般在对应的 `.c` 文件中，例如 `sys_ope`n 的实现在 `fs/open.c` 文件中。

~~~cpp
SYSCALL_DEFINE3(open, const char __user *, filename, int, flags, umode_t, mode)
{
        if (force_o_largefile())
                flags |= O_LARGEFILE;
        return do_sys_open(AT_FDCWD, filename, flags, mode);
}
~~~

其中 `SYSCALL_DEFINE3` 是一个表示带有三个参数的宏，将其展开后，实现如下：

~~~cpp
asmlinkage long sys_open(const char __user * filename, int flags, int mode)
{
 long ret;


 if (force_o_largefile())
  flags |= O_LARGEFILE;


 ret = do_sys_open(AT_FDCWD, filename, flags, mode);
 asmlinkage_protect(3, ret, filename, flags, mode);
 return ret;
 }
~~~

结合以上分析，这里总结下 32 位的系统调用从用户态到内核态是如何执行的。

![pic](/pic/2019/2019-05-26-linux-syscall-03.png)
*32 位的系统调用 图片来源：趣谈Linux操作系统*

### 系统调用实例

通过以上的分析，相信大家已经了解了系统调用的整个流程。下面通过三种不同的方式，实现对终端的输出。

* 通过 `write()` 系统调用实现
* 通过 `syscall()` 系统调用实现
* 通过汇编，调用 `syscall` 指令

#### write() 系统调用
这里我们没有使用 `printf` 这个标准库，而是使用 Linux 的系统调用 `write` 。参数 `1` 表示标准输出文件描述符。

~~~cpp
#include <fcntl.h>
#include <unistd.h>
int main () 
{
    write (1, "Hello World", 11);
return 0; 
}
~~~

#### syscall() 系统调用

现在，我们使用 glibc 提供的 `syscall` 接口，实现同样的逻辑。
~~~cpp
#include <unistd.h>
#include <sys/syscall.h>
int main () 
{
    syscall (1, 1, "Hello World", 11);
return 0; 
}
~~~

这里第一个参数表示系统调用的调用号，我是在 64 位系统上运行的，所以 `write` 对应的调用号为 `1` ，如果是 32 位系统，则调用号为 `4`。

也就是说 `syscall` 也是一个系统调用，而且接口更加原始，其他的系统调用都可以看作是通过 `syscall` 实现的一种封装。

#### syscall 指令

下面是通过汇编代码，实现同样的逻辑。这里的方法是将值放到对应的寄存器中，然后调用 `syscall` 指令。
~~~s
section .text global _start
_start: ; ELF entry point ; 1 is the number for syscall write ().
mov rax, 1
; 1 is the STDOUT file descriptor.
mov rdi, 1
    ; buffer to be printed.
    mov rsi, message
    ; length of buffer
    mov rdx, [messageLen]
    ; call the syscall instruction
syscall
; sys_exit
mov rax, 60
; return value is 0
mov rdi, 0
; call the assembly instruction
syscall
section .data
messageLen: dq message.end-message message: db 'Hello World', 10
.end:
~~~

对应汇编代码的 makefile 如下：

~~~
all:
    nasm -felf64 write.asm
    ld write.o -o elf.write
clean:
    rm -rf *.o
~~~

可以看到，这里将系统调用号 `1` 放入了 `eax`，后面的几个参数分别放入了寄存器 `rdi`, `rsi`, `rdx`, 顺序是与之前的 64 位系统通用寄存器传递参数的顺序是一致的。

