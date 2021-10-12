---
categories:
- "技术志"
tags:
- "C++"
date: 2020-06-20
title: "C++ 中 auto & decltype"
url: "/2020/06/20/cpp_auto_type"
---
C++11 的一个重要特性就是自动类型推导（auto type dedection)，通过引入 auto 和 decltype 关键字实现了类型推导，不仅能够方便的获取复杂类型，还能够简化书写，提高编码效率。

<!--more-->

### 自动类型推导

除了简化代码，自动类型推导还可以避免对类型的 “硬编码”，也就是能够自适应表达式的类型。比如下面的语句，如果把 map 改成 unordered_map，那么后面的代码不需要任何改动。

```cpp
std::map<int, std::string> m = {{1, 'a'}, {2, 'b'}};
auto iter = m.begin();
```

### 认识 auto 

auto 的 “自动推导” 能力只能用在 “初始化” 的场合。包括**赋值初始化** 或者**花括号初始化** （ Initializer list ），变量右边必须是一个表达式，如果纯是一个变量声明，则无法使用 auto 。

auto 的推导规则有些复杂，跟函数模板参数的自动推导有相似之处（ 具体函数模板参数自动推导规则可以参考《Effective Modern C++》条例1 ）。总结的规则大概两条：

1. 当声明为指针或者引用时，auto 的推导结果将保持初始化表达式的 cv 属性。

2. 当 auto 不声明为指针或者引用时，auto 的推导结果和初始化表达式会抛弃引用和 cv 限定符（ cv-qualifier，const 和volatile 限定符的统称 ）后的类型一致。

```cpp
int x = 0;
auto * a = &x; // auto 推导为 int
auto & c = x;  // auto 推导为 int

auto d = c;    // auto 推导为 int (表达式带有引用类型，auto 把引用类型抛弃，直接推导成原始类型 int)
const auto e = x; // auto 推导为 int
auto f = e; // auto 推导为 int  (表达式带有 const 类型，auto 把 const 类型抛弃，直接推导成原始类型 int)
```

auto 的最佳实践还用于 “range-based for”，不需要关心容器元素类型，迭代器返回值和首末位置，就能轻松完成遍历操作。为了保证效率，最好使用 “const auto&” 或 “auto&” 。

```cpp
vector <int> v = {1,2,3,4,5};
for(const auto& i : v)
{
  //...
}
```



### 认识 decltype

decltype 与 auto 关键字一样，用于进行编译时类型推导，不过它与 auto 还是有一些区别的。decltype 的类型推导并不是像 auto 一样是从变量声明的初始化表达式获得变量的类型，而是总是**以一个普通表达式作为参数**，返回该表达式的类型,而且 decltype 并不会对表达式进行求值。

* `decltype + 变量`：返回变量的类型（包括 const 和引用）。

```cpp
const int ci = 0, &cj = ci;
decltype(ci) x = 0; // x 类型是 const int
decltype(cj) x = 0; // x 类型是 const int&
```

* `decltype + 表达式`：返回表达式结果对应的类型。结果是左值的表达式得到类型的引用；结果是右值的表达式得到类型。

```cpp
int i = 42;
decltype(r + 0) b; // r + 0 返回右值，b 是一个 int 类型
decltype(*p) c = i; //c 是一个 int&


decltype ((i))var6 = i;           //int&  因为（i）是一个左值
decltype (true ? i : i) var7 = i; //int&  条件表达式返回左值。
decltype (++i) var8 = i;          //int&  ++i返回i的左值。
decltype(arr[5]) var9 = i;        //int&  []操作返回左值
decltype(*ptr)var10 = i;          //int&  *操作返回左值
decltype("hello")var11 = "hello"; //const char(&)[6]  字符串字面常量为左值，且为const左值。
```

* `decltype + 函数`：返回对应的函数类型，不会自动转换成相应的函数指针。

```cpp
void (*signal(int, void(* func)(int)))(int);
using sig_func_ptr_t = decltype(&signal);
```

* 与 using/typedef 结合使用，用于定义类型

```cpp
using size_t = decltype(sizeof(0));
using nullptr_t = decltype(nullptr);

vector<int >vec;
typedef decltype(vec.begin()) vectype;
for(vectype i = vec.begin(); i != vec.end(); i++)
{
   //...
}
```

* 泛型编程中结合 auto，用于追踪函数的返回值类型

```cpp
template <typename _Tx, typename _Ty>
auto multiply(_Tx x, _Ty y)->decltype(_Tx*_Ty)
{
    return x*y;
}
```