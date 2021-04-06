---
categories:
- "技术志"
tags:
- "c++"
date: 2020-07-11
title: "观察者模式中Subject在C++中的模板化"
url: "/2021/01/18/cpp_observer_subject"
---

本篇将介绍观察者模式中 Subject 类在 C++ 中的模板化的实现。

<!--more-->

### 观察者模式概要
以下是观察者模式的定义：

> 观察者模式定义了对象之间的一对多依赖关系，这样一来，当一个对象改变状态时，它的所有依赖者都会收到通知并自动更新。

一般情况下，被依赖的对象称为**被观察者**，依赖的对象被称为**观察者**。不过在实际项目中，这两种对象的称呼比较灵活，有各种不同的叫法，比如 `Subject-Observer`, `Publisher-Subscriber`, `Producer-Consumser`, `Dispatcher-Listener`。不管怎么称呼，只要应用场景符合上述定义，都可以看作观察者模式。

下面是观察者模式的类图：

![pic](/pic/2020/2020-07-11-cpp-observer-subject.png)

* `Subject`：抽象主题（抽象被观察者），抽象主题角色把所有观察者对象保存在一个集合里，每个主题都可以有任意数量的观察者，抽象主题提供一个或者多个接口，可以增加和删除观察者对象。
* `ConcreteSubject`：具体主题（具体被观察者），该角色将有关状态存入具体观察者对象，在具体主题的内部状态发生改变时，给所有注册过的观察者发送通知。
* `Observer`：抽象观察者，是观察者者的抽象类，它定义了一个或者多个更新接口，使得在得到主题更改通知时更新自己。
* `ConcreteObserver`：具体观察者，实现抽象观察者定义的更新接口，以便在得到主题更改通知时更新自身的状态。

### Subject类在C++中的模板化
对于观察者模式中 Subjet 的 C++ 实现，主要就是上面类图中三个方法的实现：

```cpp

class Subject{
  void addObserver(observer);
  void removeObserver(observer);
  void notify();
};
```

对于模板化的 Subject 类，以下几点需要考虑的：
1. 模板参数的设置，可以将 **Observer** 作为模板参数，这样对于 ConcreteSubject 来说只要继承这个 Subject，并且在必要时更新状态/发送主题
2. 设置 **ConcreteObserver** 对象的指针作为 addObserver/removeObserver的参数，作为观察者
3. 关于 notify 的实现，怎么让 ConcreteSubject 能够让 Subject 触发不同的事件（考虑到不同事件的参数不同）

关于第3点， 我们可以利用 C++11 的可变模板参数：
~~~cpp
template <typename event, typename... Args>
~~~
其中，**event** 是具体关注的事件，**Args** 是可变参数，对应 event 的可变参数。这样对于 ConcreteSubject 而言，notify 时只需要传入对应接口名称以及对应实参。

有了以上考虑，就可以写出一个简单的基于模板的Subject的类实现了
~~~cpp
template <typename ObserverT>
class Subject
{
public:
    using ObserverWeakPtr = std::weak_ptr<ObserverT>;
    using ObserverPtr = std::shared_ptr<ObserverT>;
    
    // 这里使用weak_ptr 存储，不至于影响Observer的生命周期
    using ObserverList = std::vector<ObserverWeakPtr>;
    
    virtual ~Subject() = default;
    void addObserver(ObserverPtr observer)
    {
        std::lock_guard<std::mutex> lock(mDataLock);
        if (std::find_if(mObservers.begin(), mObservers.end(), [observer](ObserverWeakPtr mWeakObserver) {
                if (auto mObserver = mWeakObserver.lock())
                {
                    return observer == mObserver;
                }
                return false;
            }) == mObservers.end())
        {
            mObservers.push_back(observer);
        }
    }
    
    void removeObserver(ObserverPtr observer)
    {
        std::lock_guard<std::mutex> lock(mDataLock);
        auto iter = std::find_if(mObservers.begin(), mObservers.end(), [observer](ObserverWeakPtr mWeakObserver) {
            if (auto mObserver = mWeakObserver.lock())
            {
                return observer == mObserver;
            }
            return false;
        });

        if (iter != mObservers.end())
        {
            mObservers.erase(iter);
        }
    }
    
 protected:
    ObserverList mObservers;
    std::mutex mDataLock;
    
    template <typename Func, typename... Args>
    void notify(Func func, Args&&... args)
    {
        for (auto observer : mObservers)
        {
            if (auto lockedObserver = observer.lock())
            {
                std::invoke(func, lockedObserver, std::forward<Args>(args)...);
            }
        }
    }
    
}
~~~

有了上面 Subject的模板类，其他几个类也就可以写了：
~~~cpp
// Observer 接口
class IObserver
{
public:
   virtual void update_event1(int parm) = 0;
   virtual void update_event2(int parm1, int parm2) = 0;
};

// ConcreteObserver： 继承 IObserver，并实现相关主题/事件的业务处理
class ConcreteObserver: public IObserver
{
public:
   ConcreteObserver(Subject subject){
      this.subject = subject;
      this.subject.addObserver(this);
   }
   
   void update_event1(int parm) override
   {
     // ...
   }
   void update_event2(int parm1, int parm2) override
   {
     //...
   }

   std::shared_ptr<Subject> mSubject;
};


// 继承 Subject，并且以 IObserver作为模板参数，只需要调用 notify 方法通知 Observers
class ConcreteSubject: public Subject<IObserver>
{
    void someMethodToFireEvent1()
    {
      // 业务逻辑
      Subject<IObserver>::notify(&IObserver::update_event1, param);
    }
    
    void someMethodToFireEvent2()
    {
      // 业务逻辑
      Subject<IObserver>::notify(&IObserver::update_event1, param1, param2);
    }
}
~~~


### 观察者模式优缺点
#### 优点
* 观察者模式可以实现表示层和数据逻辑层的分离，抽象了更新接口，使得可以有各种各样不同的表示层作为具体观察者角色
* 观察者模式在观察目标和观察者之间建立一个抽象的耦合
* 观察者模式支持广播通信

#### 缺点
* 在应用观察者模式时需要考虑一下开发效率和运行效率的问题，程序中包括一个被观察者、多个观察者，将所有的观察者都通知到会花费很多时间。如果考虑到性能问题，可以实现一个异步非阻塞的观察者模式，在每次fire subject的时候创建一个新的线程执行代码。

* 观察者模式没有相应的机制让观察者知道所观察的目标对象是怎么发生变化的，而仅仅只是知道观察目标发生了变化。