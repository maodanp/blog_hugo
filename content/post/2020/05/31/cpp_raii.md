---
categories:
- "技术志"
tags:
- "C++"
date: 2020-05-31
title: "C++ 智能指针"
url: "/2020/05/31/cpp_raii"

---

本篇主要描述C++的几种常用智能指针。

<!--more-->

初入职场时，`C++` 是唯一的开发语言。干了两年多年，感觉互联网是风口，然后毫不犹豫的跳到了一家互联网创业公司，使用的编程语言是 `Go` + `Python` 。没干两年又重新跳回了传统 IT 企业，用 C++ 重操旧业，发现项目中基本都用的 C++ 11 的特性。

### 堆、栈

刚入职场那会，C++11 还没被广泛应用，记得当时分配/释放资源也是凭感觉：对于简单 `POD` 类型（Plain Old Data）或者对象较小的类一般都是直接在栈上分配资源；对于对象很大的或者在对象大小在编译器不能确定的，一般在堆上分配资源。

对于堆上分配内存，需要正确使用 new 和 delete 即可。每个 new 出来的对象都应该用 delete 来释放。但是有时候就忘记 delete 或者由于中间代码抛出异常，导致最后 delete 得不到执行，所以也花费了很多时间去查内存泄漏。C++ 11 引入的只能指针就解决了手动申请、释放内存的问题。

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



### 智能指针

#### 什么是智能指针

所谓智能指针，当然相对裸指针而言的。指针是源自 C 语言的概念，本质上是一个内存地址索引，能够直接读写内存。因为它完全映射了计算机硬件，所以操作效率很高。当然，这也是引起无数 bug 的根源：访问无效数据、指针越界、内存分配后没有及时释放等等导致一系列严重的问题。

其实，C++ 也有类似 Java、Go 一样的垃圾回收机制，不过不是严格意义上的垃圾回收，而是广义上的垃圾回收，就是使用 **RAII（ Resource Acquisition is Initialization ）**。

RAII 是 C++ 特有的资源管理方式。RAII 依托于栈和构造/析构函数，通过代理模式，把裸指针包装起来，在构造函数里初始化，在析构函数里释放。这样当对象失效销毁时，C++ 就会自动调用析构函数，完成内存释放，资源回收等清理工作。

RAII 的精髓就是两点：

* 获得资源后立即初始化对象。
* 运用析构函数确保资源被释放。一旦对象被销毁（ 离开作用域或者从队列中 remove ），其析构函数自然会被调用，于是资源被释放。

智能指针完全实践了 RAII，包装了裸指针，而且因为重载了 * 和 -> 操作符，用起来和原始指针一模一样。



#### 常见智能指针

智能指针即运用了 RAII 的资源管理方式，能够防止手动使用 new/delete 导致的内存泄漏问题。关于智能指针，常用的有`unique_ptr` 、`shared_ptr` 和 `weak_ptr`。

* unique_ptr 是最简单、容易使用的一个智能指针，在声明的时候必须用模板参数指定类型，并且指针的所有权是唯一的，不允许共享的，任何时候只能有一个对象持有它。
* shared_ptr 允许多个智能指针共享地拥有同一个对象，shared_ptr 实现上采用了引用计数，所以一旦一个 shared_ptr 指针放弃了 "所有权" （ reset 或离开作用域等等 ），其他的 shared_ptr 对该对象内存的引用不受影响。
* weak_ptr 可以指向 shared_ptr 指针指向的对象内存，却并不拥有该内存。而使用 weak_ptr 成员 lock, 则可返回其指向内存的一个 shared_ptr 对象，如果所在对象内存无效时，返回指针空值，weak_ptr 可以有效防止 shared_ptr 循环引用的问题。

### 认识 unique_ptr

unique_ptr 在声明的时候必须用模板参数指定类型：

```cpp
unique_ptr<int> ptr1(new int(19)); 											// int 智能指针
assert(*ptr1 == 10);
assert(ptr1 != nullptr);

unique_ptr<std::string> ptr2(new string("hello world")); // string 智能指针
assert(*ptr2 == "hello world");
assert(ptr2->size() = 5);
```

一般初学智能指针有一个容易犯的错误是把它当普通对象来用，不初始化，而是声明后直接使用：

```cpp
unique_ptr<int> ptr3;  // 未初始化智能指针
*ptr3 = 42;            // 错误，操作了空指针
```

未初始化的 unique_ptr 表示空指针，这样就相当于操作了空指针，运行时就会产生致命的错误（core dump）。为了避免这种低级错误，你可以调用工厂函数 make_unique()，强制创建智能指针的时候必须初始化。同时还可以利用自动推导 auto :

```cpp
auto ptr4 = make_unique<int>(42);             		// 工厂函数创建智能指针
auto ptr5 = make_unique<string>("hello world");   // 工厂函数创建智能指针
```

unique_ptr 指针的所有权是唯一的，为了实现这个目的，unique_ptr 应用了 C++ 的转移语义，同时禁止了拷贝赋值，所以在向另一个 unique_ptr 赋值的时候，要特别留意，必须使用  **std::move()**  函数显示地声明所有权转移。

```cpp
auto ptr1 = make_unique<int>(42);
assert(ptr1 && *ptr1 == 142);

auto ptr2 = std::move(ptr1);         // 使用 move() 转移所有权
assert(!ptr1 && ptr2);               // ptr1 变成了空指针
```

赋值操作之后，指针的所有权就被转走了，原来的 unique_ptr 变成了空指针，新的 unique_ptr 接替了管理权，保证所有权的唯一性。

### 认识 shared_ptr 

shared_ptr 和 unique_ptr 差不多，也可以使用工厂函数来创建，也重载了 * 和 -> 操作符，用法几乎一样。但 shared_ptr 的所有权是可以被安全共享的，也就是说支持拷贝赋值，允许被多个对象同时持有。

```cpp
auto ptr1 = make_shared<int> (42);     // 共产书创建智能指针
assert(ptr1 && ptr1.unique())          // 此时智能指针有效且唯一
  
auto ptr2 = ptr1;											 // 直接拷贝赋值，不需要使用 move()
assert(ptr1 && ptr2)                   // 此时两个智能指针均有效
  
assert(ptr1 == ptr2)                   // shared_ptr 可以直接比较

// 两个智能指针均不唯一，且引用计数为2
assert(!ptr1.unique() && ptr1.use_count() == 2)
assert(!ptr2.unique() && ptr2.use_count() == 2) 
```

shared_ptr 内部使用了 “引用计数”，如果发生拷贝赋值，引用计数就会增加，而发生析构销毁的时候，引用计数就会减少，只有当引用计数减少到 0， 它才会真正调用 delete 释放内存。

#### shared_ptr 的注意事项

1. 不要与裸指针混用

~~~cpp
int *ptr(new int(10));
shared_ptr<int> ptr1(x);
shared_ptr<int> ptr2(x);
~~~

虽然 ptr1、ptr2 都指向 ptr 所指的内存，但他们是独立的，并且裸指针本身也很危险，ptr 随时变成`空悬指针（ dangling pointer ）`，但是 ptr1、ptr2 都不知道。

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

3. 析构操作尽量简单

因为我们把指针交给了 shared_ptr 去自动管理，所以在运行阶段，引用计数的变动非常复杂、很难知道它真正释放资源的时机，无法像 Java、Go 那样明确掌握的垃圾回收机制。

需要特别小心对象的析构函数，不要有非常复杂、严重的阻塞操作，一旦 shared_ptr 在某个不确定时间点析构释放资源，就会阻塞整个进程或者线程。

### 总结

1. 智能指针是代理模式的具体应用，它使用 RAII 技术代理了裸指针，能够自动释放内存，无效手动 delete。
2. unique_ptr 为独占式智能指针，它为裸指针添加了很多限制，使用更加安全；shared_ptr 为共享式智能指针，功能非常完善，用法几乎与原是指针一样。
3. 应当使用工厂函数 make_unique()、make_shared() 来参加智能指针，强制初始化，而且还能使用 auto 来简化声明。
4. 工程项目中尽量不要使用裸指针，new/delete 来操作内存，尽量使用智能指针。