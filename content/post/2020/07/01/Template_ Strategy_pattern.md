---
categories:
- "技术志"
tags:
- "c++"
- "design pattern"
date: 2020-07-01
title: "Template 与 Strategy 模式比较"
url: "/2020/07/01/template_strategy"
---

本篇将分别介绍 Template 与 Strategy 模式。

<!--more-->

### Template 模式

Template 模式通常应用于一种场景：对于某一个业务逻辑的算法实现在不同的对象中有不同的实现，但是逻辑（算法）框架是相同的，Template 模式采用继承的方式实现了这一点：将逻辑（算法）框架放在抽象基类中，并定义好细节的接口，子类中实现细节。

Template 模式在 GoF 的《设计模式》中定义如下：

> Define the skeleton of an algorithm in an operation, deferring some steps to subclasses. Template Method lets subclasses redefine certain steps of an algorithm without changing the algorithm’s structure.

翻译成中文就是：Template 模式就是在一个方法中定义一个算法骨架，并将某些步骤推迟到子类中实现。Teamplate 模式可以让子类在不改变算法整体结构的情况下，重新定义算法中的某些步骤。

#### Template 模式实现

![pic](/pic/2020/2020-07-01-dp-template.png)

代码实现比较简单，如下所以，其中，algorithmInterface1() 和 algorithmInterface2() 定义为纯虚函数，是为了强迫子类去实现（这个也不是必须的，这两个函数也可以在子类中实现，提供通用的算法）。

~~~cpp
class AbstractClass {
  public:
  void doActionForTemplateMethod() {
    //....
    algorithmInterface1();
    
    //...
    algorithmInterface2();
  }
  
  virtual void algorithmInterface1() = 0;
  virtual void algorithmInterface2() = 0;
};

class ConcreteClass1: public AbstractClass {
  public:
  	void algorithmInterface1() override {
        //....
		}
  
    void algorithmInterface2() override {
        //....
		}
};

class ConcreteClass2: public AbstractClass {
  public:
  	void algorithmInterface1() override {
        //....
		}
  
    void algorithmInterface2() override {
        //....
		}
};
~~~

#### Template 模式的作用

**复用**：Template 模式把一个算法中不变的流程抽象到父类的模板方法 doActionForTemplateMethod() 中，将可变的部分 algorithmInterface1()、algorithmInterface2() 留给子类 ConcreteClass1、ConcreteClass2 来实现，所有的子类都可以复用父类中模板方法定义的流程代码。

**扩展**：框架通过 Template 模式提供功能扩展点，让框架用户可以在不修改框架源码的情况下，基于扩展点定制化框架功能。

Template 模式实际上就是利用面向对象中多态的概念实现算法实现细节和高层接口的松耦合。但是由于继承是一种强约束行的条件，这也给 Template 模式带来了许多不方便的地方。



### Strategy 模式

Strategy 模式和 Template 模式要解决的问题是相同的，都是为了给业务逻辑（算法）具体实现和抽象接口之间解耦。Strategy 模式将逻辑（算法）封装在一个类（Context）里面，通过组合的方式将具体算法的实现在组合对象中实现，再通过委托的方式将抽象接口的实现委托给组合对象实现。

Strategy 模式在 GoF 的《设计模式》中定义如下：

> Define a family of algorithms, encapsulate each one, and make them interchangeable. Strategy lets the algorithm vary independently from clients that use it.

翻译成中文就是：定义一族算法类，将每个算法分别封装起来，让他们可以相互替换。Strategy 模式可以使得算法的变化独立于使用它们的客户端（使用算法的代码）。

#### Strategy 模式实现

![pic](/pic/2020/2020-07-01-dp-strategy.png)

基于上面的 Strategy 模式类图，我们可以从定义、创建、使用这三个方面描述 Strategy 模式。

**Strategy 类的定义**

所有的 Strategy 类都实现相同的接口，客户端代码基于接口而非实现编程，可以灵活地替换不同的策略。

~~~cpp
class Strategy{
  virtual void algorithmInterface() = 0;
}

public ConcreteStrategyA {
  void algorithmInterface() override {
    // 具体算法....
  }
}

public ConcreteStrategyB {
  void algorithmInterface() override {
    // 具体算法....
  }
};
~~~



**Strategy 类的创建**

Strategy 模式包含一组策略，在使用它们的时候，一般会通过类型来判断创建哪个策略来使用。为了封装创建逻辑，我们需要对客户端代码屏蔽创建细节。我们可以根据 type 创建策略的逻辑剥离出来，放在工厂类中：

~~~cpp
class Strategy;

class StrategyFactory {
 public:
  static shared_ptr<Strategy> getStrategy(std::string type) {
    if (type == null || type.isEmpty()) {
		  	return null;
    }

    if (type.equals("A")) {
      return std::make_shared<ConcreteStrategyA>();
    } else if (type.equals("B")) {
      return std::make_shared<ConcreteStrategyB>();
    }

    return null;
  }
};
~~~



**Strategy 类的使用**

一般客户端代码是在运行时动态确定使用哪种策略，这里的运行时动态是指，我们事先不知道使用哪种策略，而是在程序运行期间，根据程序运行结果来动态确定使用哪种策略。

~~~cpp
public Context {
  public:
  	Context(Strategy strategy) 
    : mStrategyPtr()
    {
    }
  
    void doAction(){
      // ...
      mStrategyPtr->algorithmInterface();
      // ...
    }
    
  private:
    std::shared_prt<Strategy> mStrategyPtr;
};

int main()
{
  std::string type;
  // type 值根据用户输入、配置、计算结果动态设定
  
  auto strtegyObject = StrategyFactory::getStrategy(type);
  Context context(strtegyObject);
  context->doAction();
}
~~~

* Strategy 类的定义比较简单，包含一个 Strategy 接口和一族实现这个接口的 Strategy 类
* Strategy 的创建由工厂类来完成，封装了策略的创建细节
* Strategy 模式包含一组策略，客户端代码如何选择使用哪个策略，有两种确定方法：编译时静态确定和运行时动态确定。其中，“运行时动态确定” 才是策略模式的最典型的应用场景。



### Template V.S. Strategy

Template 和 Strategy 模式实际上是实现了一个抽象接口的两种方式：`继承`和`组合`。继承是一种实现抽象接口的方式：我们将抽象节课声明在基类中，将具体的实现放在具体子类中；组合（委托）是另一种方式：我们将接口的实现放在被组合对象中，将具体的算法实现放在组合类中。两种方式各有优缺点：

**继承**

*[优点]*

1. 易于修改和扩展那些被复用的实现

*[缺点]*

1. 破坏了封装性，继承中父类的实现细节暴露给子类了
2. 当父类的实现更改时，其所有子类将不得不随之改变
3. 从父类继承而来的实现在运行期间不能改变（编译期间就已经确定了）

**组合**

*[优点]*

1. 被包含对象的内部细节对外是不可见的，封装性好
2. 实现和抽象（组合对象和被组合对象）之间的依赖性很小
3. 可以在运行期间动态定义实现（通过抽象基类的指针）

*[缺点]*

1. 系统中对象过多。在面向对象的设计中，组合相比继承可以取得更好的效果，因此优先使用组合而非继承。

实际上，继承是一种限制性很强的抽象接口的方式，因此也是的基类和具体子类之间的耦合性很强。而组合的方式则有很小的耦合性，实现和接口之间的依赖性很小。例如 ConcerteStrategyA 的具体实现操作很容易被别的类复用，例如我们要建另一个 Context 类 AnotherContext, 只要组合一个指向 Strategy 的指针就可以很容易的复用 ConcerteStrategyA 的实现了。

