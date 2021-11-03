---
categories:
- "技术志"
tags:
- "c++"
- "design pattern"
date: 2020-01-18
title: "Factory 工厂模式"
url: "/2020/01/18/factory_pattern"
---

本篇将介绍设计模式中的工厂模式，主要讲解简单工厂，工厂方法这两种设计模式。

<!--more-->

我们经常会抽象出一些类的公共接口已形成抽象基类或者接口，这样我们可以通过声明一个指向基类的指针来指向实现的子类实现，已达到多态的目的。这很容易出现的问题是一个问题 n 多个子类继承自抽象基类，我们不得不在每次都要用到子类的地方编写诸如 `new XXX` 的代码，这样带来的问题是:
1. 程序员必须知道实际子类的名称，以及子类的不同实现功能
2. 程序的扩展性和维护也变的越来越困难。

我们通常使用工厂模式来解决上述的问题。我们通常会**声明一个创建对象的接口，并封装对象的创建过程**。工厂模式分为三种细分的类型：`简单工厂`、`工厂方法`和`抽象工厂`，抽象工厂的原理稍微复杂，在实际项目中相对也不常用，本文也就不作介绍。

### 简单工厂模式

下面的展示了简单工厂的设计类图， 我们根据不同的配置文件的后缀（`json`、`xml`、`yaml`） 选择出不同的解析器（`jsonConfigParser`、`yamlConfigParser`、`xmlConfigParser`）进行解析，并将配置文件的信息解析成内存对象 `ruleConfig`。

![pic](/pic/2020/2020-01-18-factory-easy.png)

这里的 `ConfigParserFactory` 类就是一个工厂类，这个类只负责对象的创建。其中 `CreateParser()`方法就是根据不同的后缀产生不同的解析器对象。具体代码如下：

~~~cpp
struct ruleConfig{
   // 配置信息  
};

class configManager{
  public:
  	ruleConfig load(fullPath)
    {
      	string fileExtension = getFileExtension(fullPath);
        auto parser = ConfigParserFactory::createParser(fileExtension);
      	if(parser)
        {
          		// 读取配置文件到 configText 中
          		string configText = fileUtils::read(fullPath);
          		ruleConfig result = parser->parse(configText);
          		return result;
        }
		}
};

class ConfigParserFactory {
public:
  static IConfigParser createParser(string fileExtension)
  {
      IConfigParser parser = nullptr;
      if(fileExtension == "json")
      {
          parser = new jsonConfigParser();
      }
      else if(fileExtension == "xml")
      {
          parser = new xmlConfigParser();            
      }
      else if(fileExtension == "yaml")
      {
          parser = new yamlConfigParser();            
      }

      return parser;
   }
};
~~~

上述代码中，每次调用 `ConfigParserFactory` 的 `createParser()` 方法的时候都会创建一个新的 `parser` 对象。实际上，如果 `parser` 可以复用，为了节省内存和对象创建的时间，我们可以事先建立好，当调用 `createParser()` 的时候，我们可以从内存中取出直接使用。代码如下：

~~~cpp
class ConfigParserFactory {
public:
  static unordered_map<string, IconfigParser> mParsers {
      {"json", new jsonConfigParser()};
      {"xml", new xmlConfigParser()};
      {"yaml", new yamlConfigParser()};
  };
  
  static IConfigParser createParser(string fileExtension)
  {
    IConfigParser parser = nullptr;
    if(mParsers.find(fileExtension) != mParsers.end())
    {
        parser = mParsers[fileExtension];
    }
    return parser;
    }
};
~~~

这种先创建 parser 对象，再获取的方式有点类似`单例模式`和`简单工厂模式`的结合。


### 工厂方法模式

工厂方法模式就是将对象的创建也放到了子类中实现，`IConfigParserFactory` 只提供了对象创建的接口，实现放到了其子类 `jsonConfigParserFactory`、`jsonConfigParserFactory`、`jsonConfigParserFactory` 中去实现。

![pic](/pic/2020/2020-01-18-factory-method.png)

具体代码如下：

~~~cpp
class IConfigParserFactory{
  	virtual IConfigParser CreateParser(string fileExtension) = 0;
}

class jsonConfigParserFactory: class IConfigParserFactory{
  		IConfigParser CreateParser(string fileExtension) override {
          return new jsonConfigParser();
      }
}

class xmlConfigParserFactory: class IConfigParserFactory{
  		IConfigParser CreateParser(string fileExtension) override {
          return new xmlConfigParser();
      }
}

class yamlConfigParserFactory: class IConfigParserFactory{
  		IConfigParser CreateParser(string fileExtension) override {
          return new yamlConfigParser();
      }
}

// 创建工厂类对象的工厂
class ConfigParserFactory {
  public:
  static unordered_map<string, IconfigParser> mParsersFactoryMap {
      {"json", new jsonConfigParserFactory()};
      {"xml", new xmlConfigParserFactory()};
      {"yaml", new yamlConfigParserFactory()};
  };
  
  static IConfigParser getParserFactory(string fileExtension)
  {
      IConfigParser parser = nullptr;
      if(mParsersFactoryMap.find(fileExtension) != mParsersFactoryMap.end())
      {
          parser = mParsersFactoryMap[fileExtension];
      }
      return parser;
   }
}

class configManager{
public:
  	ruleConfig load(fullPath)
    {
      	string fileExtension = getFileExtension(fullPath);
        auto parser = ConfigParserFactory::getParserFactory(fileExtension);
      	if(parser)
        {
          		// 读取配置文件到 configText 中
          		string configText = fileUtils::read(fullPath);
          		ruleConfig result = parser->parse(configText);
          		return result;
        }
		}
};
~~~

其中，`ConfigParserFactory` 是创建工厂类对象的工厂，`getParserFactory()` 返回的是缓存好的单例工厂对象。

### 简单工厂 V.S. 工厂方法

一般情况下，如果代码块的逻辑过于复杂，可以剥离出来独立成函数或者类，剥离之后能让代码更加清晰、可读、可维护。所以当对象的创建逻辑比较复杂，不只是简单的 `new` 一下就可以，而是要组合其他类对象做各种初始化工作的时候，我们推荐使用工厂方法模式，将所有的创建逻辑都放到工厂类中。

如果只是简单的 `new` 操作就能创建对象，功能单薄，那就没有必要设计成独立的类，所以在这个应用场景下，简单工厂模式简单好用，比工厂方法更加合适。