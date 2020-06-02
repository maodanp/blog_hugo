---
categories:
- "技术志"
tags:
- "C++"
date: 2020-06-02
title: "C++ lambda 函数"
url: "/2020/06/02/cpp_lambda"
---
本篇主要描述 lambda 函数以及跟仿函数的关联，最后介绍 lambda 的使用陷阱。

<!--more-->

### lambda 介绍

lambda 表达式是 C++11 中引入的一项新技术，利用lambda表达式可以编写内嵌的匿名函数，用以替换独立函数或者函数对象，并且使代码更可读。lambda 函数的格式如下：

`[capture](parameters) mutable ->return—type {statement}`

* `[capture]` 捕捉列表。能够捕捉上下文中的变量以供lambda函数使用。捕获只能用于可见（在创建lambda的作用域可见）的非static局部变量（包含形参）
* `(parameters)` 参数列表。与普通函数的参数列表一致，若不需要参数传递，可以连同括号一起省略。
* `mutable` 修饰符。默认情况下lambda函数总是一个const函数，mutable可以取消其常量性。
* `->return-type` 返回类型。也可以省略该部分，让编译器对返回类型自动推导。
* `{statements}` 函数体，跟普通函数一样。除了可以使用的形参之外，还可以使用所有捕获的变量。

捕获列表由多个捕捉项组成，并且以逗号分隔。具体说来会有以下几种情况来捕获其所在作用域中的变量：

* `[]` 默认不捕获任何变量；
* `[=]` 默认以值捕获所有变量（ 包括 `this` ）；
* `[&]` 默认以引用捕获所有变量（ 包括 `this` ）；
* `[var]` 仅以值捕获 var，其它变量不捕获；
* `[&var]` 仅以引用捕获 var，其它变量不捕获；
* `[=, &var]` 默认以值捕获所有变量，但是 var 是例外，通过引用捕获；
* `[&, var]` 默认以引用捕获所有变量，但是 var 是例外，通过值捕获；
* `[this]` 通过值传递方式捕获当前的 this 指针。


### lambda 与 仿函数
在 C++11 之前，我们在使用 STL 算法时，通常会使用到函数对象或者仿函数（ functor ）。仿函数简单而言就是重新定义了成员函数 `operator()` 的一种自定义类型对象。

下面代码显示的例子分别使用了仿函数和 lambda 两种方式计算产品的价格。
~~~cpp
#include <iostream>
using namespace std;

class AirportPrice{
private:
 float _dutyFree;
public:
 AirportPrice(float rate): _dutyFree(rate){}
 float operator()(float price){
    return price*(1-_dutyFree/100);
 }
};

int main()
{
    float tax_rate = 5.5f;
    AirportPrice pricePurchased1(tax_rate);

    auto pricePurchased2 = [tax_rate](float price){return price*(1-tax_rate/100);};

    float resultFromFunc = pricePurchased1(3699);
    float resultFromLambda = pricePurchased2(3699);
    
    cout << resultFromFunc << " " << resultFromLambda << endl;
    
    return 0;
}
~~~
可以看出 lambda 和仿函数有着相同的内涵：`捕捉一些变量作为初始状态，并接受参数进行运算`。在 C++ 中，lambda 可以视为仿函数的一种 “语法糖”。

![pic](/pic/2020/2020-06-02-cpp_lambda.png)

但是 lambda 不是仿函数的完全替代者，由于 lambda 的捕捉列表的限制（仅仅能够捕捉到负作用域的非静态变量，而对于超出这个范围的变量是不能被捕捉的）。

比如下面的代码段:
~~~cpp
int d = 0;
int tryCapture() {
 auto lambda_test = [d](){};
~~~

在g++中上面代码段能够编译通过，但会给出警告：`warning: capture of variable ‘d’ with non-automatic storage duration `，但是仿函数则不会有这个限制。

总的来说，lambda 函数被设计的目的是就地书写、使用，是一种局部的封装与共享。而需要全局共享的代码逻辑，则需要用函数（无状态）或者仿函数（有状态）封装起来。

### 值捕获 V.S. 引用捕获
使用 lambad 函数时，捕捉列表不同会导致不同的结果。对于按值方式传递的捕获列表，其传递的值在 lambda 函数定义的时候就已经决定了；而按引用捕获列表变量，其传递的值则等 lambda 函数调用时决定。

> 注意最好不要使用 `[=]` 和 `[&]` 默认捕获所有变量。

对于默认引用捕获所有变量，有很大可能会出现 `悬挂引用（Dangling references）`，因为引用捕获不会延长引用的变量的生命周期：

~~~cpp
std::function<int(int)> add_x(int x)
{
    return [&](int a) { return x + a; };
}
~~~
因为参数 x 仅是一个临时变量，函数调用后就被销毁，但是返回的 lambda 表达式却引用了该变量，所以运行时会产生行为未定义的问题。

使用默认传值方式默认捕获了 this 指针，如果 lambda的执行是异步的，很可能等 lambda 真正执行，this 所指向的对象已经被析构了，也会存在同样的问题。

~~~cpp
using functionCallback = std::function<void(int)>;
class CSubObj(){
  public:
    CSubObj(){};
    asyncFunc(functionCallback callback){
        //异步操作
    }
};

class CObj{
  public: 
    CObj() {};
    void funcMethod1() {
    //Some operations
    };

    void FuncMethod2(int param) {
       _subObj->asyncFunc([=](param){
            funcMethod1();
       });
    };
    
  private:
    CSubObj _subObj;
};
~~~

如以上代码所示，假设函数 `CSubObj::asyncFunc(functionCallback callback)` 实现中存在异步操作，可能 `CObj::FuncMethod2(int param)` 中 lambda 执行时 `CObj` 对象已经被析构了。

这种问题的解决方案一般是在 lambda 实现的第一行就判断下是否 this 指针失效，如果失效了直接 return，代码段如下所示。
~~~cpp
#define RETURN_IF_DEAD(x) \
    auto sharedThis = x.lock();       \
    if (!sharedThis)                  \
        return;
     
class CObj :public std::enable_shared_from_this<CObj>{
  public: 
    CObj() {};
    void funcMethod1() {
    //Some operations
    };

    void FuncMethod2(int param) {
       _subObj->asyncFunc([weakThis = weak_from_this(), this](param){
            RETURN_IF_DEAD(weakThis);
            funcMethod1();
       });
    };
    
  private:
    CSubObj _subObj;
};
~~~