---
categories:
- "技术志"
tags:
- "C++"
date: 2020-06-11
title: "C++ 右值引用和移动语义"
url: "/2020/06/11/cpp_move"
---
C++11 引入的右值引用和移动语义，可以避免无谓的复制，提高了程序性能。

<!--more-->

### 关于拷贝构造

拷贝构造是 C++ 的一种特殊的构造函数，它在创建对象时，是使用同一类中之前创建的对象来初始化新创建的对象，通常在如下场景中被调用：

* 通过使用另一个同类型的对象来初始化新创建的对象;
* 复制对象把它作为参数传递给函数;
* 复制对象，并从函数返回这个对象。

一般格式定义如下：

~~~cpp
class obj{
  //.....
  obj(const obj &) {};
};
~~~

如果在类中没有定义拷贝构造函数，编译器会自行定义一个。如果类带有指针变量，并有动态内存分配，则用户必须自定义拷贝构造函数来实现 ” 深拷贝（deep copy）”，否则通过 C++ 生成的 “ 浅拷贝（shollow copy）” 会导致内存泄漏的情况。

还有要注意的是对于临时类对象作为函数返回值，会产生很多的无谓复制，并且这些临时变量的产生和销毁以及拷贝的发生对程序员来说是不可见的。比如下面的代码：

~~~cpp

#include <iostream>
using namespace std;

int g_constructCnt = 0;
int g_copyConstructCnt = 0;
int g_destructCnt = 0;
struct A{
A():m_ptr(new int(0)){
    cout << "Construct: " << ++g_constructCnt << endl;
}
A(const A&a):m_ptr(new int(*a.m_ptr)){
    cout << "Copy Construct: " << ++g_copyConstructCnt << endl;
}
~A(){
    cout << "destruct: " << ++g_destructCnt << endl;
    delete m_ptr;
}

private:
    int* m_ptr;
};

A GetA()
{
    return A();
}

int main()
{
  A a = GetA();
  return 0;
}
~~~

在 GCC 下编译时设置编译选项 `-fno-elide-constructors` 来关闭返回值优化效果，输出结果：
~~~
Construct: 1
Copy Construct: 1
destruct: 1
Copy Construct: 2
destruct: 2
destruct: 3
~~~

从上面的例子中可以看出，在没有返回值优化的情况下，拷贝构造函数调用了两次，一个是 `GetA()` 函数内部创建的对象返回后构造的一个临时对象产生的，另一个是在 `main()` 函数中构造 `a` 对象产生的。

如果示例中堆内存很大，那么拷贝构造的代价就会很大，也势必带来了额外的性能损耗。有没有什么办法避免临时对象的深拷贝呢？可以通过右值引用或者移动拷贝构造方式减少对象的深拷贝。

### 右值引用
在介绍右值引用之前先了解什么是左值和右值。

左值是指表达式结束后依然存在的持久对象，所有的具名变量或对象都是左值。
右值是指表达式结束时就不再存在的临时对象，右值是不具名的。

在 C++11 中，右值是由两个概念构成，一个是`将亡值（xvalue, eXpiring Value）`，另一个则是`纯右值（prvalue, Pure Rvalue）`。

其中纯右值就是 C++98 标准中右值的概念，比如非引用返回的临时变量、运算表达式产生的临时变量、原始字面量和 lambda 表达式。将亡值则是 C++11 新增的跟右值引用相关的表达式，比如，将要被移动的对象、T&& 函数返回值、std::move 返回值和转换为 T&& 的类型的转换函数的返回值。

#### 右值引用特性
右值引用就是对一个右值进行引用的类型。通过右值引用的声明，改右值又 “重获新生”，其生命周期与右值引用类型变量的生命周期一样。

如果在上面的代码中通过右值引用来绑定函数返回值，结果如何？

~~~cpp
int main() {
    A&& a = GetA();
    return 0;
}
~~~

结果如下：
~~~
Construct: 1
Copy construct: 1
destruct: 1
destruct: 2
~~~

通过右值引用，比之前少了一次拷贝构造和析构，原因在于右值引用绑定了右值，让临时右值的生命周期延长了。


实际上，在 C++98 中，通过常量左值引用也经常用来做性能优化，将上面代码改成：
~~~cpp
const A& a = GetA();
~~~
输出的结果和右值引用一样，因为常量左值引用是一个 “万能” 的引用类型，可以接受左值、右值、常量左值和常量右值。但是普通的左值引用不能接受右值，比如下面的写法编译器会报错：
~~~cpp
A& a = GetA();
~~~

实际上， `T&&` 并不一定表示右值，它绑定的类型是未定的，极可能是左值也可能是右值。
~~~cpp
template<typename T>
void f(T&& param)

f(10);  // 10 是右值

int x = 10;
f(x);   // x 是左值
~~~

从上例中可以看出，param 有时是左值，有时是右值，上例中 T&& param，其中 param 是一个未定义的引用类型（universal references）。它是左值还是右值引用取决于它的初始化，如果 && 被一个左值初始化，它就是一个左值；如果它被一个右值初始化，他就是一个右值。

Universal reference 仅仅在 T&& 下发生，任何一点附加条件都会使之失效，而变成一个普通的右值引用。

#### 移动拷贝构造

这里可以给出关于如何避免临时对象的深拷贝的答案了，只需要在上述代码中加上移动构造即可，这样能够避免对临时对象的深拷贝。
~~~cpp
    A(A&& a): m_ptr(a.m_ptr)
    {
        a.m_ptr = nullptr;
        cout << "Move construct: " << ++g_moveConstructCnt << endl;
    }
~~~

结果如下：
~~~
Construct: 1
Move construct: 1
destruct: 1
Move construct: 2
destruct: 2
destruct: 3
~~~

从移动构造函数的（Move Construct）实现中可以看出，它的参数是一个右值引用了型的参数 `A&&` ，没有深拷贝，只有浅拷贝，这样就避免了对临时对象的深拷贝，这也就是所谓的移动语义（move 语义）。

### Move 语义

移动语义是通过右值引用来匹配临时值，对于普通左值，可以用 move 方法来将左值转换为右值，从而方便应用移动语义。move 是将对象的状态或者所有权从一个对象转移到另一个对象。

假设对于下面的例子，tokens 容器很大，赋值给另一个容器：
~~~cpp
std::list<std::string> tokens;
//tokens 赋值操作
//......

std::list<std::string> t = std::move(tokens);
~~~
如果不使用 std::move , 拷贝的代价很大，性能较低。使用 move 几乎没有任何代价，只是转换了资源的所有权。

当一个对象内部有较大的堆内存或者动态数组时，很有必要写 move 语义的拷贝构造函数和复制函数，避免无谓的深拷贝，以提高性能。