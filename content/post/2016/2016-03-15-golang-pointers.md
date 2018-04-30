---
categories:
- "技术志"
tags:
- golang
date: 2016-03-15
title: "golang参数传递"
url: "/2016/03/15/using-pointers-in-go"
---

以前在C/C++中，都知道传参时何时传值、指针、引用。那在Golang中的规则又是怎样的呢？对于参数传递是否有统一的规范呢？本文翻译自[Using Pointers In *Go](https://www.goinggo.net/2014/12/using-pointers-in-go.html)，作者总结出的方法一定让你受益匪浅。

<!--more-->

### 简介
在Go语言编程中，经常会遇到何时使用、何时不适用指针的问题。 绝大多数人都是基于他们的一个想法：权衡是否能够通过指针提高程序的性能。因此**大家都朝着性能方面去考虑代码中是否使用指针，并不是从代码的习惯用法、简洁性、可读性以及合理性去考虑的**。

我对于指针的使用原则，基于的是标准库中指针的使用。当然下面说的这些规则也有例外的情况，但是这篇文章需要展示的是普遍的规则。本文通过区分传递的值类型说起，这些类型包括Go内置类型，结构体以及引用类型。让我们开始逐个说明吧。

### 内置类型
Go的[内置类型](https://golang.org/ref/spec#Types)代表的是原生的数据，他们也是代码编写的基石。这些内置类型主要包括：布尔类型、数字类型以及字符串类型。当我们声明函数或者方法时，一般传递的是这些类型的值，标准库中很少通过指针传递它们。

让我们看下`env`包中的`isShellSpecialVar`函数：

**Listing 1**

	http://golang.org/src/os/env.go

	38 func isShellSpecialVar(c uint8) bool {
	39     switch c {
	40     case ‘*’, ‘#’, ‘$’, ‘@’, ‘!’, ‘?’, ‘0’, ‘1’, ‘2’, ‘3’, ‘4’, ‘5’, ‘6’, ‘7’, ‘8’, ‘9’:
	41         return true
	42     }
	43     return false
	44 }

Listing 1中，`isShellSpecialVar`函数接受一个`uint8`类型的值，返回一个`bool`类型的值。对于调用者而言，他们必须给这个函数传递一个`uint8`类型的值，同样返回的也是一个`bool`类型的值。

下面，我们看下`env`包中的`getShellName`函数：

**Listing 2**

	http://golang.org/src/os/env.go

	54 func getShellName(s string) (string, int) {
	55     switch {
	56     case s[0] == ‘{’:
	           …
	66         return "", 1 // Bad syntax; just eat the brace.
	67     case isShellSpecialVar(s[0]):
	68         return s[0:1], 1
	69     }
	       …
	74     return s[:i], i
	75 }

Listing 2中，`getShellName`函数接受一个`string`类型的值，同时返回了两个值：一个是`string`类型；另一个是`int`类型。`string`类型的值是一个内置的类型，它代表了一部分固定不变的字节数。因为这部分是不可增长的，值得容量与切片头([slice header](https://www.goinggo.net/2013/08/understanding-slices-in-go-programming.html))不存在关联。

当调用者调用`getShellName`函数时，需要传递一份`string`类型值的拷贝，然后函数会产生一份新的string值返回给调用者。所有的所要传递的输入输出的值都是需要进行拷贝的。

这种`string`类型值得拷贝在`strings`包中是很常见的：

**Listing 3**

	http://golang.org/src/strings/strings.go

	620 func Trim(s string, cutset string) string {
	621     if s == "" || cutset == "" {
	622         return s
	623     }
	624     return TrimFunc(s, makeCutsetFunc(cutset))
	625 }

`strings`包中很多函数，都会接受一份调用者的string值的拷贝，然后返回函数内部常见的string值得拷贝给调用者。Listing 3中展示了`Trim`函数的实现， 该函数接受了两个string值得拷贝，然后返回一个拷贝（这个拷贝可能是第一个形参，可能是截取后的新的string)。

如果你查看标准库中的代码，会发现这些内置类型的值很少会传指针，基本都是直接传递值得拷贝。如果一个函数或方法需要改变内置类型的值，那么改变后的新的值通常回座位返回值返回给调用者。

总之，不要通过指针来传递内置类的值。

### 结构体类型

结构体能够通过组合不同的类型，创建出复杂的数据类型。通过组合一系列的字段，每个字段都有一个名称和类型。当然，结构体也支持匿名组合方式，嵌入结构体类型。

结构体类型能够实现类似内置类型的功能。我们可以通过标准库的`time`包，看到结构体扮演的原生数据值（primitive data value）:

**Listing 4**

	http://golang.org/src/time/time.go

	39 type Time struct {
	40     // sec gives the number of seconds elapsed since
	41     // January 1, year 1 00:00:00 UTC.
	42     sec int64
	43
	44     // nsec specifies a non-negative nanosecond
	45     // offset within the second named by Seconds.
	46     // It must be in the range [0, 999999999].
	47     nsec int32
	48
	49     // loc specifies the Location that should be used to
	50     // determine the minute, hour, month, day, and year
	51     // that correspond to this Time.
	52     // Only the zero Time has a nil Location.
	53     // In that case it is interpreted to mean UTC.
	54     loc *Location
	55 }

Listing 4 shows the Time struct type. This type represents time and has been implemented to behave as a primitive data value. If you look at the factory function Now, you will see it returns a value of type Time, not a pointer:

Listing 4展示了`Time`结构类型。这个类型代表了时间，作为原生数据值实现的。下面的`Now`函数，返回了`Time`类型的值，而非指针：

**Listing 5**

	http://golang.org/src/time/time.go

	781 func Now() Time {
	782     sec, nsec := now()
	783     return Time{sec + unixToInternal, nsec, Local}
	784 }

Listing 5 shows how the Now function returns a value of type Time. This is an indication that values of type Time are safe to copy and is the preferred way to share them. Next, let’s look at a method that is used to change the value of a Time value:

Listing 5 展示了返回`Time`类型的`Now`函数。这个函数说明了`Time`类型的值返回时安全的，也是首选的方式。接下来，让我们看下我们如何通过`Time`的方法来改变内部值的：

**Listing 6**

	http://golang.org/src/time/time.go

	610 func (t Time) Add(d Duration) Time {
	611     t.sec += int64(d / 1e9)
	612     nsec := int32(t.nsec) + int32(d%1e9)
	613     if nsec >= 1e9 {
	614         t.sec++
	615         nsec -= 1e9
	616     } else if nsec < 0 {
	617         t.sec–
	618         nsec += 1e9
	619     }
	620     t.nsec = nsec
	621     return t
	622 }

正如我们知道的，内置类型是通过值传递并作为返回的。Listing 6展示了如何通过调用`Add`方法，来解决`Time`的值拷贝问题的。这个方法改变了接受者为值类型的局部变量，然后**返回给调用者这个改变后值的拷贝**。

**Listing 7** 

	http://golang.org/src/time/time.go

	1118 func div(t Time, d Duration) (qmod2 int, r Duration) {

	}

Listing 7声明了`div`函数，它接收`Time`和`Duration`类型的值。这里再次说明下，`Time`类型的值当做了原生数据类型，通过值来传递。

但是大部分时候，结构体类型就不能当做原生数据类型了，在这些情况下，通过传值得指针会是更佳的选择。让我们看下`os`包中的示例：

**Listing 8**

	http://golang.org/src/os/file.go

	238 func Open(name string) (file *File, err error) {
	239     return OpenFile(name, O_RDONLY, 0)
	240 }

Listing 8中，我们能够看到`os`包中的`Open`函数， 它打开了可读的文件，然后返回了`File`类型值的指针。下面，我们看看这个`File`结构在UNIX平台下的类型声明：

**Listing 9**

	http://golang.org/src/os/file_unix.go

	15 // File represents an open file descriptor.
	16 type File struct {
	17     *file
	18 }
	19
	20 // file is the real representation of *File.
	21 // The extra level of indirection ensures that no clients of os
	22 // can overwrite this data, which could cause the finalizer
	23 // to close the wrong file descriptor.
	24 type file struct {
	25     fd int
	26     name string
	27     dirinfo *dirInfo // nil unless directory being read
	28     nepipe int32 // number of consecutive EPIPE in Write
	29 }

上面关于`File`的注释很好的说明了一点。当你有个像`Open`那样的的工厂函数（factory function），它提供给你一个指针，它在提示你不能够创建这个返回值得拷贝。`Open`返回一个指针，因为如果将涉及的`File`值的拷贝返回，那将是不安全的。这个`File`值应该通过指针拷贝及使用。

Even if a function or method is not changing the state of a File struct type value, it still needs to be shared with a pointer. Let’s look at the epipecheck function from the os package for the UNIX platform:

即使有函数或方法没有改变`File`结构类型值，它仍然需要通过指针方式使用。下面我们看下`os`包，UNIX平台下的`epipecheck`函数的定义：

**Listing 10**

	http://golang.org/src/os/file_unix.go

	58 func epipecheck(file *File, e error) {
	59     if e == syscall.EPIPE {
	60         if atomic.AddInt32(&file.nepipe, 1) >= 10 {
	61             sigpipe()
	62         }
	63     } else {
	64         atomic.StoreInt32(&file.nepipe, 0)
	65     }
	66 }

在Listing 10中，`epipecheck`函数接受了一个`File`类型的指针。调用者因此能够通过指针共享`File`类型的值。注意到`epipecheck`函数并不能改变`File`值得状态，但是能够通过它执行操作。

这种应用方式在`File`类型的其他函数声明中也能够看到：

**Listing 11**

	http://golang.org/src/os/file.go

	224 func (f *File) Chdir() error {
	225     if f == nil {
	226         return ErrInvalid
	227     }
	228     if e := syscall.Fchdir(f.fd); e != nil {
	229         return &PathError{"chdir", f.name, e}
	230     }
	231     return nil
	232 }

Listing 11的`Chdir`方法中，通过接受者为指针来是实现了`Chdir`方法，但是并没有改变接受者值的状态。以上所有示例中，都是传递`File`类型的指针来实现共享的。一个`File`类型值并不是一个原生数据类型。

如果你阅读标准库中更多的代码，你将会看到如何传递结构类型的，可以像内置类型一样当原生类型使用，也可以通过指针实现共享。

**总之，对于结构类型值通过指针传递，除非结构类型的行为类似原生数据类型**

如果你还不确定，这里提供另一种思考方式。可以将每个结构看做一个自然。如果结构体本质上不能够改变，像时间、颜色或者坐标，那么就把结构体当做原生数据类型。如果结构体本质山是可以改变的东西，即使它在你的代码中从来没变化过，它就不能当做原生数据类型，而应该通过指针传递，我们不能够创建具有二义性的结构体。

### 引用类型

引用类型包括切片、映射、管道、接口以及函数等。这些值包含头节点，头节点会通过指针指向潜在的数据结构以及其他的元数据。我们很少传递引用类型的指针，因为这些头节点本来就是设计成允许拷贝的。我们来看下`net`包中的示例：

**Listing 12**

	http://golang.org/src/net/ip.go

	type IP []byte

Listing 12中，我们能够看到一个成为`IP`的命名类型，它实际的类型是一个字节类型的切片。当你需要声明一个内置内省或者引用类型，一般都使用它们的值传递。让我们看下`IP`命名类型下的`MarshalText`方法：

**Listing 13**

	http://golang.org/src/net/ip.go

	329 func (ip IP) MarshalText() ([]byte, error) {
	330     if len(ip) == 0 {
	331         return []byte(""), nil
	332     }
	333     if len(ip) != IPv4len && len(ip) != IPv6len {
	334         return nil, errors.New("invalid IP address")
	335     }
	336     return []byte(ip.String()), nil
	337 }

Listing 13中，我们能够看到`MarshalText`方法如何使用值类型的接受者的，这里并没有使用引用类型的指针作为接受者。我们能够给函数或方法传引用类型的值：

**Listing 14**  

	http://golang.org/src/net/ip.go

	318 // ipEmptyString is like ip.String except that it returns
	319 // an empty string when ip is unset.
	320 func ipEmptyString(ip IP) string {
	321     if len(ip) == 0 {
	322         return ""
	323     }
	324     return ip.String()
	325 }

Listing 14中，`ipEmptyString`函数接受了`IP`命名类型的值。因为`IP`的基本类型是字节数切片，是一个引用类型，因此我们不需要通过指针来共享。

但是对于**不要通过引用类型的指针来共享**这条规则，有个例外：

**Listing 15** 

	http://golang.org/src/net/ip.go

	341 func (ip *IP) UnmarshalText(text []byte) error {
	342     if len(text) == 0 {
	343         *ip = nil
	344         return nil
	345     }
	346     s := string(text)
	347     x := ParseIP(s)
	348     if x == nil {
	349         return &ParseError{"IP address", s}
	350     }
	351     *ip = x
	352     return nil
	353 }

任何时候，当你要将数据解码成引用类型时，你需要通过引用类型的**指针共享**，而不能通过**值共享**。Listing15显示了`UnmarshalText`方法的实现，它的接受者为指针类型，以实现解码操作。

当你阅读更多的标准库代码时，你将会看到引用类型的值在大多数情况下都是值共享的。因为引用类型包括头结点，能够共享头结点指向的数据结构。这个思想有点类似C/C++中指针的传递，我们在对指针指向对象初始化时，需要传递二级指针，其他情况下我们一般只要传递指针就行了。

总之，不要通过引用类型的指针来共享，除非你需要实现解码类型的功能。

### 值的切片

有一件事需要说明，当我(作者)在从数据库、网络或者文件中获取数据时，将这些数据存储在了切片中：

**Listing 16**

	10 func FindRegion(s *Service, region string) ([]BuoyStation, error) {
	11     var bs []BuoyStation
	12     f := func(c *mgo.Collection) error {
	13         queryMap := bson.M{"region": region}
	14         return c.Find(queryMap).All(&bs)
	15     }
	16
	17     if err := s.DBAction(cfg.Database, "buoy_stations", f); err != nil {
	18         return nil, err
	19     }
	20
	21     return bs, nil
	22 }

Listing 16中，通过`mgo`包去访问MongoDB数据库。在14行，传递给`All`方法的是`bs`切片的指针地址。`All`方法实际执行的是解码方法，来创建切片的值。当使用切片的值时，能够允许程序中的数据以连续的块存储在内存中。这意味着更多的核心数据能够被CPU缓存存储，能够在缓存中保存较长的时间。而如果创建的是群拍你的指针，却不能保证这些核心数据在内存中能够连续存储，而是指向这些数据的**指针**能够连续存储。

总之，当你编写自己的代码时，尽可能传递引用类型的值而非指针。

### 总结

基于值类型来共享/传递这种思想，在标准库中是相当一致的：

* 不要使用内置数据类型的指针除非你有其他需求
* 结构体具有二义性，如果结构体类型作为原生数据类型使用，就不需要使用指针；如果不是就使用指针
* 引用类型不应该通过指针传递，极少情况是需要用指针的（解码）

在结束本篇文章之前，再重申三点：

1. 在写代码时，要考虑习惯用法、简洁性、可读性以及合理性
2. 这无关乎对错，要多考虑代码背后的合理性
3. 将每种情况看做个例看待，并不只是一种解决方案

























































