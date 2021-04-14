---
categories:
- "技术志"
tags:
- "c++"
- "STL"
date: 2020-01-10
title: "STL容器的区间成员函数"
url: "/2020/01/10/stl-range-methods"
---

STL 中容器的插入、删除、赋值都有相应的区间成员函数，相比于单元素的成员函数而言，使用区间成员函数使得代码更加清晰，更加高效。

<!--more-->

### 区间函数示例

示例1：给定 v1 和 v2 两个向量，使得 v1 的内容和 v2 的后半部分相同。

方法一，使用单元素成员函数，依次将 v2 的元素 push back 到 v1 中
```cpp
v1.clear();
for(auto iter = v2.begin()+v2.size()/2; iter != v2.end(); iter ++)
{
  v1.push_back(*iter);
}
```

方法二，使用区间成员函数 assign
```cpp
v1.assign(v2.begin() + v2.size()/2, v2.end())
```

示例2：如何将一个 int 数组拷贝到一个 vector 的前端

方法一，通过循环依次将数组中的元素 insert 到 vector
```cpp
int data[numValues];
vector<int> v;
//...
auto insertLoc = v.begin();
for(int i = 0; i < numValues; i++)
{
  insertLoc = v.insert(insertLoc, data[i]);
  insertLoc++;
}
```

方法二，使用 vector 的区间 insert 函数
```cpp 
int data[numValues];
vector<int> v;
v.insert(v1.begin(), data, data+numValues);
```

通过以上两个示例，明显可以感觉到使用区间函数是非常的方便，而且意图清晰，代码更加的直接。而且使用区间函数往往比与之对应的单元素成员函数更加高效。

### 区间删除 erase 结合 remove 算法
如何删除 vector 容器中指定值的元素? 第一个想到的是 vector 提供的 erase 方法，但是该方法只能删除特定位置或者某个区间的元素值，那怎么删除指定值得元素呢，这里就要结合算法 remove 去实现了。

先看下 remove 声明如下，remove 需要一对迭代器来指定所要进行操作的元素区间：
```cpp
template<class ForwardIterator, class T>
ForwardIterator remove(ForwardIterator first, ForwardIterator last, const T& value);
```
因为从容器中删除元素的唯一方法就是调用该容器的成员函数，而 remove 并不知道它操作的元素所在的容器，所以 remove 不可能从容器中删除元素。remove 不是真正意义上的删除元素，只是返回一个指向新的区间结尾的迭代器。

在内部，remove 遍历整个区间，用需要保留的元素的值覆盖掉要被删除的元素的值。为了删除这些元素，需要调用区间形式的 erase 方法从新的逻辑结尾一直到原区间的结尾都删除。

```cpp
vector<int> v;
v.erase(remove(v.begin(), v.end(), 99), v.end);
```

但是有一个例外，就是 list 的 remove 成员函数，这是 STL 中唯一一个名为 remove 并且确实删除了容器中元素的函数：
```cpp 
list<int> lst;
//...

lst.remove(99); //删除所有值为99的元素，并且list的大小也会改变
```

### 区间函数分类

#### 区间创建
```cpp
container::container(InputIterator begin, InputIterator end);
```

#### 区间插入

所有标准序列容器（vector, string, deque, list）都提供了如下形式的 insert:
```cpp
void container::insert(iterator position,  // 在何处插入区间
                     InputIterator begin, 
                     InputIterator end);
```
关联容器（set, multiset, map, multimap）利用比较函数来决定元素该插入何处，它们提供了一个省去position参数的函数原型：
```cpp
void container::insert(InputIterator begin, InputIterator end);
```
对于标准序列容器，当看到使用 push_front 或者 push_back 循环调用时，或者 front_inserter 或者 back_inserter 被当做参数传递给 copy 函数时，你会发现在这里区间形式的 insert 可能是更好的选择。

#### 区间删除

所有的标准序列容器都提供了区间形式的删除操作，但对于序列和关联容器，其返回值有所不同。序列容器提供了这样的形式：
```cpp
iterator container::erase(iterator begin, iterator end);
```
而关联容器则提供了如下形式：
```cpp
void container::erase(iterator begin, iterator end);
```
对于 vector 和 string 来说，内存会反复分配（对 erase，会是反复的释放），但是当元素数目减少时却不会自动减少，这个时候就需要使用 swap 来去除多余容量了。比如：
```cpp
class CTest
vector<CTest> cTestVec;
vector<CTest>(cTestVec).swap(cTestVec);
```
这里表达式 vector<CTest>(cTestVec) 创建一个临时的向量, 它是cTestVec的拷贝，然而 vector 的拷贝构造函数置为所拷贝的元素分配所需的内存，所以这个临时向量没有多余的容量。然后将临时向量中的数据和 cTestVec 中的数据做swap 。

#### 区间赋值
```cpp
void container::assign(iterator begin, iterator end);
```
所有容器也都提供了区间形式的 assign 。


### 参考阅读
《Effective STL》 - 第5条，32条