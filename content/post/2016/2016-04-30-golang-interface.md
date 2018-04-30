---
categories:
- "技术志"
tags:
- golang
date: 2016-04-30
title: "Golang — 面向对象语言(方法、接口、匿名组合)"
url: "/2016/04/30/golang-interface"
---

初学Golang时，一直困惑其中的`struct类型`是否等同于面向对象中的object, `interface`是否等同于多态。下面来好好扒一扒Golang与面向对象的关系。

<!--more-->

### Go中的对象
在面向对象的编程中，封装、继承、多态是主要的三大要素，表示对象本身的状态、行为；不同对象之间的相互关系等。Steve Francia对面向对象做了一个标准的定义：

> 面向对象系统将数据和代码通过“对象”集成到一起，而不是将程序看成由分离的数据和代码组成。对象是数据类型的抽象，它有状态（数据）和行为（代码）

那在Go语言中，并不像C++/Java那样通过class定义类对象及其方法，Go中实际并没有对象，但是Go中的结构体类型/struct有着跟object相同的特性。

> struct是一种包含了命名字段和方法的类型

Go语言有意得被设计为没有继承语法。但这并不意味go中的对象（struct value)之间没有关系，只不过go的作者选择了另外一种机制来暗含这种特性。Go语言严格遵循着 [组合优于继承的原则](https://en.wikipedia.org/wiki/Composition_over_inheritance)

**go通过在struct和interface上使用组合和多态来实现继承关系， 通过struct实现 has-a 关系； 通过interface实现 is-a 关系。**

### 方法
Go 语言中同时有函数和方法。一个方法就是一个包含了**接受者(类型对象)**的函数，接受者可以是命名类型或者结构体类型的一个值或者是一个指针。也就是说我们可以给任意类型(包括内置类型，但不包括指针类型)添加相应的方法。

下面简单给出示例说明：

	import ”fmt“
	type User struct {
	    Name  string
	    Email string
	    age   int
	}

	//User(值) 的Notify()方法
	func (u User) Notify() error {
	    u.age += 1
	    return nil
	}

	//User(指针) 的NotifyPtr()方法
	func (u *User) NotifyPtr() error {
	    u.age += 1
	    return nil
	}

	func main() {

	    // User 类型的值可以调用接受者是值的方法
	    damon := User{"AriesDevil", "ariesdevil@xxoo.com", 20}
	    damon.Notify()
	    fmt.Printf("client.do info:%v\n", damon)
	    // User 类型的值可以调用接受者是指针的方法
	    damon.NotifyPtr()
	    fmt.Printf("client.do info:%v\n", damon)

	    // User 类型的指针同样可以调用接受者是值的方法
	    alimon := &User{"A-limon", "alimon@ooxx.com", 20}
	    alimon.Notify()
	    fmt.Printf("client.do info:%v\n", alimon)
	    //User 类型的指针同样可以调用接受者是指针的方法
	    alimon.NotifyPtr()
	    fmt.Printf("client.do info:%v\n", alimon)
	}


* 当接受者命名为一个值时，原来的对象的成员都没有变（age=20）
* 当接受者命名为一个指针时，原来的对象成员发生了变化（age=21）

*当接受者不是一个`指针`而是`值`时，该方法操作对应接受者的值的副本（即使使用了指针调用函数，但是函数的接受者是值类型，所以函数内部操作还是对副本的操作）。*

### 接口
Go语言中的接口很特别，而且提供了难以置信的一系列灵活性和抽象性。接口(interface)是一组抽象方法的集合，如果实现了interface中的所有方法，即该对象就实现了该接口。在Go语言中，只要两个接口有相同的方法列表，那么就可以互相赋值，而不需要知道继承于哪里。

当一个接口只包含一个方法时，按照Go语言的约定命名该接口时添加 -er 后缀。这个约定很有用，特别是接口和方法具有相同名字和意义的时候(在 Go 语言标准库中，一个接口基本包含一种方法)。

下面简单给出示例说明：

	package main
	import "fmt"
	type User struct {
	    Name  string
	    Email string
	    age   int
	}

	//定义了一个 Notifier 接口并包含一个 Notify 方法
	type Notifier interface {
	    Notify() error
	}

	//定义函数接受任意一个实现了接口 Notifier 的类型的值或者指针
	func SendNotification(notify Notifier) error {
	    return notify.Notify()
	}

	func (u *User) Notify() error {
	    log.Printf("User: Sending User Email To %s<%s>\n",
	        u.Name,
	        u.Email)
	    return nil
	}

	func main() {
	    user := User{
	        Name:  "AriesDevil",
	        Email: "ariesdevil@xxoo.com",
	    }

	    SendNotification(user)
	}

运行结果如下：

**`cannot use user (type User) as type Notifier in argument to SendNotification:`
	`User does not implement Notifier (Notify method has pointer receiver)`**

上面运行说：User类型没有实现Notifier接口，但是User指针类型接受者实现了Notifier接口。 如果将上述的接受者改为值类型，就正常运行了：

	func (u User) Notify() error {
	    log.Printf("User: Sending User Email To %s<%s>\n",
	        u.Name,
	        u.Email)
	    return nil
	}
或者只需要传入 User 值的地址到 SendNotification 函数：

    user := &User{
	        Name:  "AriesDevil",
	        Email: "ariesdevil@xxoo.com",
	    }

**接口的调用规则不同于方法的调用， 接口的调用规则需要建立在这些方法的接受者和接口如何被调用的基础上。** 下面是Go语言规范中定义的规则：

1. 类型 T 的可调用方法集不包含接受者为 \*T 的方法

	即我们传入 SendNotification 函数的接口变量一个值类型的话，那 Notify() 方法的接受者必须是值类型的。

2. 类型 \*T 的可调用方法集包含接受者为 \*T 或 T 的所有方法集

	即我们传入 SendNotification 函数的接口变量一个指针类型的话，那 Notify() 方法的接受者可以是值类型也可以是指针类型。


### 匿名域/匿名组合
结构体类型可以包含匿名或者嵌入字段(嵌入类型的名字充当了匿名组合的字段名)。

	type Admin struct {
	  User
	  Level  string
	}

Effective Go中有关于嵌入类型的规则描述： 

> 当我们嵌入一个类型，这个类型的方法就变成了外部类型的方法；但是当它被调用时，方法的接受者是内部类型(嵌入类型)，而非外部类型。

下面的例子中，Admin和匿名组合User同时实现了Notifier接口，那么编译器该确定使用哪个接口？如下[完整代码](https://play.golang.org/p/8V4yo97AxN)

	
	func main() {
		
		a := &Admin{
			User: User{
				Name:  "admin",
				Email: "ariesdevil@xxoo.com",
			},
			Level: "master",
		}

		//Sending User Email To AriesDevil<ariesdevil@xxoo.com>
		a.User.Notify()

		//Sending Admin Email To AriesDevil<ariesdevil@xxoo.com>
		a.Notify()
	}

从上述代码中可以看出，如果Admin类型的接口实现的输出，User 类型的接口实现不被提升到外部类型了。

对于Go语言中外部类型方法集提升的规则：

1. 如果 S 包含一个匿名字段 T，S 和 *S 的方法集都包含接受者为 T 的方法提升

2. 对于 *S 类型的方法集包含接受者为 *T 

	当外部类型使用指针调用内部类型的方法时，只有接受者为指针类型的内部类型方法集将被提升

3. 如果S包含一个匿名字段 *T，S 和 *S 的方法集都包含接受者为 T 或者 *T 的方法提升


4. 如果 S 包含一个匿名字段 T，S 的方法集不包含接受者为 *T 的方法提升


### Go中的多态实现
真正意义上，如果匿名域能实现多态，则外层独享应该等同于嵌入的对象，而实际上并非如此，他们仍然是不同的存在：

	package main

	type A struct{
	}

	type B struct {
	    A  //B is-a A
	}

	func save(A) {
	    //do something
	}

	func main() {
	    b := B
	    save(&b);  //OOOPS! b IS NOT A
	}

多态是一种is-a的关系。在go语言中，每种类型(type)都是不同的，一种类型不能完全等同于另外一种类型，但它们可以绑定到同一个接口（interface）上。接口能用于函数（方法）的输入输出中，因而可以在类型之间建立起is-a的关系。 [完整代码](https://play.golang.org/p/Iw0g_OO0nj)

	func SendNotification(notify Notifier) error {
		return notify.Notify()
	}

	func main() {
		u := &User{
				Name:  "user",
				Email: "user@xxoo.com",
			}
			
		a := &Admin{
			User: User{
				Name:  "admin",
				Email: "admin@xxoo.com",
			},
			Level: "master",
		}

		//Sending User Email To AriesDevil<ariesdevil@xxoo.com>
		SendNotification(u)

		//Sending Admin Email To AriesDevil<ariesdevil@xxoo.com>
		SendNotification(a)
	}

### 参考阅读
[Go是面向对象语言吗？](http://studygolang.com/articles/4390)

[Methods, Interfaces and Embedded Types in Go](https://www.goinggo.net/2014/05/methods-interfaces-and-embedded-types.html)

[Go语言中的方法、接口和嵌入类型详解](http://www.jb51.net/article/56812.htm)
