---
categories:
- "技术志"
tags:
- "C++"
date: 2020-05-31
title: "C++ 内存分配与 RAII"
url: "/2020/05/31/cpp_raii"
---

本篇主要描述 `C++` 的内存分配方式，以及 `RAII` 、智能指针。

<!--more-->

初入职场时，`C++` 是唯一的开发语言。干了两年多年，感觉互联网是风口，然后毫不犹豫的跳到了一家互联网创业公司，使用的编程语言是 `Go` + `Python` 。没干两年又重新跳回了传统 IT 企业，用 `C++` 重操旧业。既然是重操旧业，就得好好将手上的这把利器打磨打磨。

### 堆、栈

刚入职场那会，C++11 还没被广泛应用，记得当时分配/释放资源也是凭感觉：

* 对于简单 `POD` 类型（Plain Old Data）或者对象较小的类一般都是直接在栈上分配资源；

* 对于对象很大的或者在对象大小在编译器不能确定的，一般在堆上分配资源。

对于堆上分配内存，我们只需要正确使用 new 和 delete 即可。每个 new 出来的对象都应该用 delete 来释放。但是有时候就忘记 delete 或者由于中间代码抛出异常，导致最后 delete 得不到执行，所以也花费了很多时间去查内存泄漏。

比如如下代码，如果中间抛出异常，delete 就执行不到了。

~~~cpp
void foo()
{
  bar* ptr = new bar();
  …
  delete ptr;
}
~~~

栈上分配/释放内存就容易的多了，跟所在函数的生命周期绑在一起。当函数执行完成，这些内存也自然就释放掉了。对于含有构造和析构函数的非 POD 类型，栈上的内存分配也同样有效，编译器能自动调用析构函数，包括在函数执行发生异常的情况下（称之为栈展开 stack unwinding）。

下面展示了异常抛出时析构调用的情况：

~~~cpp

#include <stdio.h>

class Obj {
public:
  Obj() { puts("Obj()"); }
  ~Obj() { puts("~Obj()"); }
};

void foo(int n)
{
  Obj obj;
  if (n == 42)
    throw "life, the universe and everything";
}

int main()
{
  try {
    foo(41);
    foo(42);
  }
  catch (const char* s) {
    puts(s);
  }
}
~~~

执行结果：
~~~
Obj()
~Obj()
Obj()
~Obj()
life, the universe and everything
~~~

### RAII
这种资源管理的方式其实很早就在 Effective C++ 中读到过，但是直到现在的项目，才将 RAII 用到了极致，得益于这种资源管理模式，这几年也没怎么关注开发产品的内存泄漏问题。

RAII(resource acquisition is initialization) 是 C++ 特有的资源管理方式。
RAII 依托`栈`和`析构函数`，来对所有资源进行管理。对 RAII 的使用，使得 C++ 不需要类似于 Java 那样的垃圾收集方法，也能够有效的对内存进行管理。

RAII 的精髓就是两点：

* 获得资源后立即初始化对象。
* 运用析构函数确保资源被释放。一旦对象被销毁（ 离开作用域或者从队列中 remove ），其析构函数自然会被调用，于是资源被释放。

比如可以这样使用：
~~~cpp
std::mutex mtx;
void some_func()
{
  std::lock_guard<std::mutex> guard(mtx);
  // 做需要同步的工作
}
~~~

### 智能指针

#### 常见智能指针
智能指针即运用了 RAII 的资源管理方式，能够防止手动使用 new/delete 导致的内存泄漏问题。关于智能指针，常用的有 `shared_ptr` 和 `weak_ptr`。

* shared_ptr 允许多个该智能指针共享地拥有同一个对象，shared_ptr 实现上采用了引用计数，所以一旦一个 shared_ptr 指针放弃了 "所有权" （ reset 或离开作用域等等 ），其他的 shared_ptr 对该对象内存的引用不受影响。

* weak_ptr 可以指向 shared_ptr 指针指向的对象内存，却并不拥有该内存。而使用 weak_ptr 成员 lock, 则可返回其指向内存的一个 shared_ptr 对象，如果所在对象内存无效时，返回指针空值，weak_ptr 可以有效防止 shared_ptr 循环引用的问题。

#### shared_ptr的陷阱

1. 不要与裸指针混用

~~~cpp
int *ptr(new int(10));
shared_ptr<int> sp1(x);
shared_ptr<int> sp2(x);
~~~

虽然 sp1、sp2 都指向 ptr 所指的内存，但他们是独立的，并且裸指针本身也很危险，ptr 随时变成`空悬指针（ dangling pointer ）`，但是 sp1、sp2 都不知道。

2. 避免循环引用

~~~cpp
#include <iostream>
#include <memory>
using namespace std;

class AObj;
class BObj;

class AObj {
    public:
    std::shared_ptr<BObj> bPtr;
    ~AObj() { cout << "AObj is deleted!"<<endl; }
};

class BObj {
    public:
    std::shared_ptr<AObj> APtr;
    ~BObj() { cout << "BObj is deleted!" << endl; }
};

int main()
{
    auto ap = make_shared<AObj>();
    auto bp = make_shared<BObj>();
    ap->bPtr = bp;
    bp->APtr = ap;
}
~~~

智能指针最大的一个陷阱是循环引用，循环引用会导致内存泄漏。解决方法是用 weak_ptr 打破循环。

