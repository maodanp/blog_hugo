---
categories:
- "技术志"
tags:
- "c++"
- "STL"
date: 2019-07-05
title: "C++ 中基于谓词的 std::sort 介绍"
url: "/2019/07/05/std-sort-cpp"
---

数据结构于算法中有很多种不同的排序算法，在 C++ 语言中，常见的排序排序算法是 `std::sort`, 本篇主要介绍基于谓词的 `std::sort` 以及常见使用场景。

<!--more-->

### C++ 中的排序方法概述
C++ 中 `std::sort` 是一个标准的排序算法， 它的语法声明如下：
```cpp
template <class RandomAccessIterator>
void sort ( RandomAccessIterator first,RandomAccessIterator last );

template <class RandomAccessIterator,class Compare>
void sort ( RandomAccessIterator first,RandomAccessIterator last, StrictWeakOrdering comp );
```
参数中通过 `first`、 `last` 作为需要排序的区间，一般比较多的使用场景是针对 `std::vector` 或者数组进行排序 (其他 STL 例如 `std::map`, `std::set` 本身存储的是已经排好序的)。当然，从声明中我们可以看到迭代器类型是随机访问的，也就是可以对支持随机访问迭代器的容器（`Container`）进行排序。

`std::list` 则不能通过 `std::sort` 方法排序, 因为它的迭代器不是随机访问迭代器。如果你想要对 `std::list` 进行排序，你需要使用 `std::list::sort` 成员方法进行排序。

`std::sort`所使用的排序算法取决于不同的编译器，但是时间复杂度一般不会超过 `O(N log N)`，其中 `N` 为元素个数。通常 `std::sort` 的实现会基于不同排序算法的优缺点组合实现。其中一个算法是 `IntroSort`。
`IntroSort` 是一种混合的排序算法，其目标就是提供一种排序算法，它具有快速的平均时间复杂度和最优的最差时间复杂度。它结合了快速排序和堆排序，结合了两者的有点。 其平均和最差时间复杂度都是 `O(N log N)`。

理论上，对数字进行排序和对任何数据进行排序是没有任何区别的。它们使用相同的算法，唯一的差别是不同的数据类型使用了不同的比较方法。

#### String 类型排序
任何带有 `RandomIterator` 的容器都可以使用 `std::sort` 进行排序，`std::string` 也实现了随机访问迭代器，下面的示例展示了对 `Hello World` 字符串的排序：
```cpp
#include <algorithm>
#include <string>
#include <iostream>

std::string hello{ "Hello World!" };
std::sort(hello.begin(), hello.end());
std::cout << hello << "\n";
```

输出结果为 ` !HWdellloor`, 可以看到输出结果是严格按照字母递增排序的。

### 对结构或者类的排序
如果某个数据可以通过小于操作符 `<` 进行比较，那么当该数据位于支持随机访问的容器中时， 就可以对其进行排序。
考虑到下面是的示例：
```cpp
struct some_data
{
    some_data() = default;
    some_data(int val) : a(val) {}
    int a;
};

std::vector<some_data> elements = { 0,9,2,7,3,5,7,3 };
std::sort(elements.begin(), elements.end());
```

当运行这断代码时，你将会得到下面的编译错误，编译器没有找到合适的 `operator <` 比较操作去比较两个 `some_data` 实例。
```
 error: no match for ‘operator<’ (operand types are ‘some_data’ and ‘some_data’)
```

通常有三种方式解决这问题：
* 在类的内部，实现 `operator<` 成员函数的重载
* 在类的外部，实现 `operator<` 非成员函数的重载
* 通过谓词（`predicate`）来实现

#### 成员函数 operator < 的重载
如果这种比较函数仅仅针对这个类/结构体本身使用，成员函数 `operator < ` 的重载是最简单和简洁的一种方式。
还是使用上面的 `some_data` 作为例子，在结构体中使用下面声明的方法 (`rhs` 表示 `right hand side`)：
```cpp
bool operator < (const some_data& rhs) const
```

结构体定义如下：
```cpp
struct some_data
{
    some_data() = default;
    some_data(int val) : a(val) {}

    int a;

    bool operator<(const some_data & rhs) const
    {
        return a < rhs.a;
    }
};
```

再次使用 `std::sort` 将会调用到自定义的重载的小于操作符。

#### 非成员函数 operator< 的重载
如果你不能改变类或者结构体的话，可以使用非成员函数 `operator <` 的重载，在类的外部定义下面的方法：
```cpp
bool operator<(const some_data & lhs, const some_data & rhs)
{
    return lhs.a < rhs.a;
}
```

#### 基于谓词（predict）的排序
对于排序，一个谓词表示对象 `A` 是否在对象 `B` 之前，因此一个搜索谓词必须有两个相同类型的参数。
假设下面的一个汽车的结构，每辆汽车都有特定的属性，如制造商、型号、年份和价格。
```cpp
struct car
{
    std::string make;
    std::string model;
    int year;
    double price;
};
```
我们可以基于汽车的某个属性进行排序。

* Lambda 作为排序谓词

使用 `lambda` 表达式作为谓词也许是最简单和高效的一种实现方式。`lambda` 是一种匿名方法，编译器能够更加容易对其进行内联和优化，同样它相比普通函数而言也更加容易阅读。
我们可以定义下面基于 `lambda` 的谓词对制造商、型号进行排序。
```cpp
auto sortByMakeAndModel = 
    [](const car & a, const car & b) -> bool
{
    if (a.make < b.make) return true;
    if (a.make > b.make) return false;
    if (a.model < b.model) return true;
    if (a.model > b.model) return false;

    return false;
};

std::sort(first, last, sortByMakeAndModel);
```
或者下面的表达式：
```cpp
auto sortByMakeAndModel = 
    [](const car & a, const car & b) -> bool
{
    return 
        (
            (a.make < b.make) ||
            (a.make == b.make && a.model < b.model)
        );
};

std::sort(first, last, sortByMakeAndModel);
```
这两种表达式都是等价的。

* 非成员函数作为谓词

非成员函数是没有定义在类或者结构体中的方法，它的行为像 `lambda`，但是可以出现在多个编译模块。出于性能原因，使用非成员方法可以声明为 `inline`。我们可以给编译器一个提示，使用 `inline` 来内联该方法。
```cpp
inline bool sortYear(const car & a, const car & b)
{
    return a.year < b.year;
}

std::sort(first, last, &sortYear);
```

* 成员函数作为谓词

使用成员方法需要基于类或结构的实例。`c++11` 引入了 `std::bind`。它简化了绑定到类中的方法，但是在构造 `std::bind` 对象时必须小心。
```cpp
struct car_sort
{
    bool sortYear(const car & a, const car & b) const
    {
        return a.year < b.year;
    }
};
```
这里必须要声明一个类的可用的实例，`car_sort sortInstance`,  `sortYear` 这个方法也必须要声明为 public 。
```cpp
std::sort(                 // (1) Call to std::sort
  first,                   // (2) First iterator
  last,                    // (3) End iterator
  std::bind(               // (4) Predicate, which is std::bind
    &car_sort::sortYear,   // (5) Pointer to member method
    sort_instance,         // (6) Instance of struct
    std::placeholders::_1, // (7) Placeholder for argument 1
    std::placeholders::_2  // (8) Placeholder for argument 2
  )
);
```

使用 `std::bind` 有可能导致运行时的开销，因为通过这种方式调用的谓词本质上是一个函数指针，与任何指针一样它可能在运行时被更改。编译器可能会优化哪些在运行时不会被更改的指针，这也是动态绑定的一个例子。
使用 `lambda` 表达式，可以获得静态绑定的指针，也就是 `lambda` 可以在编译时就被解析。

### std::list 排序
对 `std::list` 进行排序与对 `std::vector` 或者 `std::string` 的排序几乎类似的，除了 `std::list` 的排序方法是一个成员函数。 除了这个区别，`list::sort· 方法不接受范围，它有两个重载类型，一个是没有谓词，一个是有谓词。
对于没有谓词的排序，默认是小于操作符 `operator <` 。
```cpp
std::list<int> numbers = { 0,9,1,2,8,4,6 };
numbers.sort();
```
对于包含谓词的 `std::list::sort`, 我们可以基于 `lambda` 表达式去实现：
```cpp
auto sortYearPredicate = [](const car & a, const car & b) -> bool
{
    return a.year < b.year; 
};
cars.sort(sortYearPredicate);
```


### 参考阅读
[std::sort - cppreference.com](https://en.cppreference.com/w/cpp/algorithm/sort)

[std::sort排序算法](https://blog.csdn.net/xijiacun/article/details/72902680)

[C++ std::sort predicate with templates](https://studiofreya.com/cpp/cpp-std-sort-predicate-with-templates/)


