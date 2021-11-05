---
categories:
- "技术志"
tags:
- "c++"
- "design pattern"
date: 2020-01-23
title: "C++ 关于单例模式的几种实现"
url: "/2020/01/23/singleton_pattern"
---

本篇将介绍关于单例模式的几种实现，并分析该模式存在的一些问题。

<!--more-->

### 单例模式简介

单例模式 (Singleton Pattern，也称为单件模式)，是使用最广泛的设计模式之一。其意图是保证一个类仅有一个实例，并提供一个访问它的全局访问点，该实例被所有程序模块共享。

定义一个单例类通常需要考虑以下几点的条件：

1.   考虑私有化它的构造函数，以防止外界创建单例类对象
2.   考虑对象创建时的线程安全问题
3.   考虑是否支持延迟加载
4.   考虑获取该实例的公有静态方法 `getInstance()` 的性能是否高（是否加锁）

### 单例模式几种实现

#### 饿汉模式

下面给出饿汉式的实现方式，在类加载的时候，`mInstance` 静态实例就已经创建并初始化好了，所以 `mInstance` 的创建过程是线程安全的，不过这样的实现不支持延迟加载。

~~~c++
class singleton
{
  public:
      static singleton* getInstance()
      {
        return mInstance;
      }

    private:
      singleton (singleton const&);
      void operator=(singleton const&);

      static singleton* mInstance {new instance()};
}
~~~

这种实现方法的优势是能够将耗时的初始化操作提前到程序启动的时候去完成，能避免在程序运行的时候再去初始化而导致的性能问题。

#### 懒汉模式

懒汉式延迟了类对象的初始化，这样不调用 `getInstance()` 就不会创建对象。

~~~c++
static singleton* getInstance()
{
  if(mInstance == nullptr){
     mInstance = new singleton();
   }
 }
~~~

然而在多线程情况下，这种实现方式是不安全的。假设线程 **A** 执行 `mInstance = new singleton()` 还没有完成，这个时候 `mInstance` 仍然为 `nullptr`, 线程 **B** 也执行 `mInstance = new singleton()` 操作，就会产生两个对象，这样有可能发生内存泄漏。

#### 线程安全实现版本

下面为线程安全的版本实现，即在 `getInstance()` 的实现中开始的时候就加一把锁。

~~~c++
static singleton* getInstance()
{
    std::lock_guard<std::mutex> lock(mMutex);
    if(mInstance == nullptr){
       mInstance = new singleton();
     }
 }
~~~

这种写法性能不高，因为每次访问都需要加锁、释放锁，即使这个 `mInstance` 在第一次已经被创建了，后面的线程如果同时访问的话都会被阻塞住。

#### 双重检测

下面是针对线程安全版本做了优化，上面的实现不管三七二十一上来就上锁，这会导致不必要的锁的消耗，这里的双重检测的实现会先判断 `mInstance` 是否为空，如果不为空，说明对象已经创建了，就不需要锁，直接返回即可。

~~~c++
static singleton* getInstance()
{
    if(mInstance == nullptr)
    {
      std::lock_guard<std::mutex> lock(mMutex);
      if(mInstance == nullptr){
         mInstance = new singleton();
       }  
    }
    return mInstance;
 }
~~~

这种实现看起来非常的完美，只有在第一次必要的时候才会使用锁。在相当长的时间内这种实现也是迷惑了很多人，最终在 2000 年才被人发现漏洞，原因是内存读写的乱序执行：

这里 `mInstance = new singleton();` 分为三个步骤来执行：

1.   分配一个 `singleton` 类对象所需的内存
2.   在分配的内存处调用构造函数，构造 `singleton` 类型的对象
3.   把分配的内存地址赋给指针 `mInstance`

编译器有可能不是严格按照 `1，2，3` 的执行步骤，有可能是 `1，3，2` 的顺序，如果线程 **A** 按照这种顺序，执行完步骤 `2 `，这个时候就切换到了线程 **B**，由于 `mInstance` 不为空了，所有线程 **B** 会直接 `return mInstance` 得到一个对象，而这个对象并没有真正的被析构，从而产生严重的 bug 。

#### 局部静态变量实现最简洁的实现

在 C++ memory model 中对 static local variable 有这种描述：

>   The initialization of such a variable is defined to occur the first time control passes through its declaration; for multiple threads calling the function, this means there’s the potential for a race condition to define first.

在一个线程开始 Local static 对象的初始化后到完成初始化之前，其他线程执行到这个 Local static 对象的初始化语句就会等待，直到该 Local static 对象初始化完成。这个是针对 C++11 以上版本才适用的。

在 C++11 之前，在多线程环境下 Local static 对象的初始化并不是线程安全的。具体表现就是：如果一个线程正在执行 Local static 对象的初始化语句但还没有完成初始化，此时若其它线程也执行到该语句，那么这个线程会认为自己是第一次执行该语句并进入该 Local static 对象的构造函数中。这会造成这个 Local static 对象的重复构造，进而产生 **内存泄露** 问题。

~~~c++
static singleton& getInstance()
{
    static singleton mInstance; // 局部静态变量
    return mInstance;
 }
~~~

通过局部静态变量实现创建的类对象，其创建过程中的线程安全性是由 C++11 保证的，而且非常的简洁，不需要加锁，由于是在栈上申请的空间，也不需要像指针那样判断是否为空。

### 单例存在的问题

1.   单例会隐藏类之间的依赖关系

代码的可读性非常重要，在阅读代码的时候，我们希望一眼能看出类与类之间的依赖关系，但是，单例类不需要显示创建、不需要依赖参数传递，在函数中直接调用就可以了。如果代码比较复杂，这种调用关系就会非常隐蔽。在阅读代码的时候，我们就需要仔细查看每个函数的代码实现，才能知道这个类到底依赖了哪些单例类。

2.   对代码的扩展性不友好

单例类只能有一个对象实例。如果未来某一天，我们需要在代码中创建两个实例或多个实例，那就要对代码有比较大的改动。也就是说，单例类在某些情况下会影响代码的扩展性、灵活性。

3.   单例对代码的可测试性不友好

单例模式的使用会影响到代码的可测试性。如果单例类依赖比较重的外部资源，比如 DB，我们在写单元测试的时候，希望能通过 mock 的方式将它替换掉。而单例类这种硬编码式的使用方式，导致无法实现 mock 替换。



### 参考阅读

[C++ and the Perils of Double-Checked Locking](https://www.aristeia.com/Papers/DDJ_Jul_Aug_2004_revised.pdf)

[设计模式之单例模式(c++版)](https://segmentfault.com/a/1190000015950693)

《设计模式之美》- geekbang.org