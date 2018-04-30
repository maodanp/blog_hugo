---
categories:
- "技术志"
tags:
- golang
date: 2016-04-12
title: "golang错误处理(一)"
url: "/2015/04/12/error-handling-in-go-part-i"
---

Golang中Error作为返回值是很常见的，几乎每个函数返回值都有error的interface。本文翻译自[Error Handling In Go, Part I](https://www.goinggo.net/2014/10/error-handling-in-go-part-i.html)，作者在该篇中对error接口的创建、使用等做了详细描述。

<!--more-->

### 简介
在Go语言中，使用error接口作为函数或者方法的返回值是一种很惯用的方法。这个接口同样在Go的标准库中也作为返回值。

例如，这是http包的Get方法声明：

**Listing 1.1**

	func (c *Client) Get(url string) (resp *Response, err error)

一般都会在函数、方法的返回中，判断error的值是否为`nil`:

**Listing 1.2**

	resp, err := c.Get("http://goinggo.net/feeds/posts/default")
	if err != nil {
	    log.Println(err)
	    return
	}

在 listing 1.2, 对`Get`方法的调用通过两个局部变量返回。 然后比较`err`变量是否等于`nil`。 如果不等，则表示有错误。

因为`error`是用于处理错误的接口，我们需要根据提供的接口实现具体的代码。标准库中`errorString`已经实现了该接口。

### Error接口与errString结构

`error`的接口声明如下：

**Listing 1.3**

	type error interface {
    Error() string
	}

在 listing 1.3中, 我们看到`err`接口的声明仅仅包括一个`Error`, 该方法返回`string`类型。因此，**任何类型只要实现了`Error`方法，也就实现了`err`接口**。 关于`Go`中的接口，可以参考[Methods, Interfaces and Embedded Types in Go](https://www.goinggo.net/2014/05/methods-interfaces-and-embedded-types.html)

标准库中也声明了`errorString`的结构，该结构在`errors`包中：

**Listing 1.4**

	http://golang.org/src/pkg/errors/errors.go
	type errorString struct {
     s string
	}

在 listing 1.4中, 我们看到`errorString`中只有一个类型为`string`的字段。我们能够看到结构以及内部的字段都是不能够被外部访问的，我们不能直接访问该结构或者它内部的变量，具体可以参考[Exported/Unexported Identifiers in Go](https://www.goinggo.net/2014/03/exportedunexported-identifiers-in-go.html)

**Listing 1.5**

	func (e *errorString) Error() string {
	    return e.s
	}

我们可以看到listing 1.5中，`error`接口通过指针类型的接受者`(*errorString)`实现了。`errorString`类型是标准库中最常用的类型，它能够作为`error`类型接口的返回值。

下面我们来学习标准库中如何通过`errorString`结构来创建`error`类型的接口。

### 创建Error值

标准库中，提供了两种方式来创建`errorString`类型的指针，以作为`error`类型的接口使用。当你定义的error是一个string类型，且不需要具体的格式化参数，那么可以通过`errors`包的`New`函数定义。

**Listing 1.6**

	var ErrInvalidParam = errors.New("mypackage: invalid parameter")

Listing 1.6中, 显示了`errors`包的`New`函数的调用。在这个示例中，我们声明了一个`error`类型的接口变量，然后通过调用`New`函数初始化该变量。下面为`New`的实现：

**Listing 1.7**

	// New returns an error that formats as the given text.
	func New(text string) error {
	    return &errorString{text}
	}

Listing 1.7中, 我们看到函数以`string`类型作为参数传入，返回了`error`类型的接口。在该函数的实现中，创建了一个`errorString`类型的指针。 在return语句中，编译器创建了`error`类型的接口，然后结合指针，作为返回。 `errorString`指针作为隐含的数据，当做`error`接口的值返回了。

那么问题来了，如果我们的错误消息需要格式化呢？ 不着急，下面的 `fmt`包中的`Errorf`函数能够做到。

**Listing 1.8**

	var ErrInvalidParam = fmt.Errorf("invalid parameter [%s]", param)

Listing 1.8中, 我们可以看到`Errorf`函数被调用了。如果你对`fmt`包中的其他函数熟悉，你就知道这个函数跟其他函数是类似的了。这里，通过调用`Errorf`函数， 我们再次创建并初始化了一个`error`类型的接口变量。

下面我们揭开`Errorf`函数的神秘面纱

**Listing 1.9**  

	http://golang.org/src/pkg/fmt/print.go

	// Errorf formats according to a format specifier and returns the string
	// as a value that satisfies error.
	func Errorf(format string, a …interface{}) error {
	    return errors.New(Sprintf(format, a…))
	}

Listing 1.9中, 我们看到依然是通过`error`接口作为返回值类型的。 在该函数的实现中，调用了`errors`包的`New`函数，其中参数为格式化好的字符串。所以不管你使用`errors`包或者`fmt`包来创建`error`类型的接口，***底层都是为`errorString`类型的指针***。

现在我们有两种不同的方式，都能通过`errorString`的指针实现`error`类型的接口。下面我们来学习在标准库中，如何在API调用中返回特有的`errors`信息。

### 比较Errors值

在`bufio`包中（标准库中其他包也是一样的），通过`errors`包中的`New`函数来创建不同error变量。

**Listing 1.10** 

	http://golang.org/src/pkg/bufio/bufio.go

	var (
	    ErrInvalidUnreadByte = errors.New("bufio: invalid use of UnreadByte")
	    ErrInvalidUnreadRune = errors.New("bufio: invalid use of UnreadRune")
	    ErrBufferFull        = errors.New("bufio: buffer full")
	    ErrNegativeCount     = errors.New("bufio: negative count")
	)

Listing 1.10 展示了四个不同的error变量，它们都在`bufio`包中声明、初始化。注意到这些变量都是通过`Err`作为前缀的，在Go中这是一种约定俗成的书写方式。因为这些变量都被声明为`error`类型接口，我们能够区分指定的错误，这些错误可以是由`bufio`包中不同的API返回的：

**Listing 1.11** 

	data, err := b.Peek(1)
	if err != nil {
	    switch err {
	    case bufio.ErrNegativeCount:
	        // Do something specific.
	        return
	    case bufio.ErrBufferFull:
	        // Do something specific.
	        return
	    default:
	        // Do something generic.
	        return
	    }
	}

在 listing 1.11 中，示例代码调用了`bufio.Reader`类型指针值的`Peek`方法。`Peek`方法返回的值可能是`ErrNegativeCount`或是 `ErrBufferFull`变量。 因为这些变量已经对外暴露了，所以我们能够利用这些变量来区分具体是哪个错误。区分这些变量也是标准库中错误处理的一部分。


设想如果我们没有声明这些`error`变量，那么我们不得不通过比较具体的错误信息来判断我们获得的是那些错误：

**Listing 1.12** 

	data, err := b.Peek(1)
	if err != nil {
	    switch err.Error() {
	    case "bufio: negative count":
	        // Do something specific.
	        return
	    case "bufio: buffer full":
	        // Do something specific.
	        return
	    default:
	        // Do something specific.
	        return
	    }
	}

在listing 1.12的例子中，有两个问题：首先，`Error()`函数的调用会产生一份错误消息的拷贝；其次，如果包的开发者改变了这些消息内容，那么这段代码就有问题了。

下面的`io`包是另外一个例子，声明了`error`类型的变量，并且都能够作为错误返回：

**Listing 1.13** 

	var ErrShortWrite    = errors.New("short write")
	var ErrShortBuffer   = errors.New("short buffer")
	var EOF              = errors.New("EOF")
	var ErrUnexpectedEOF = errors.New("unexpected EOF")
	var ErrNoProgress    = errors.New("multiple Read calls return no data or error")

Listing 1.13显示了在`io`包中的六个`error`变量。其中第三个变量是`EOF`错误变量的声明，表示没有多余的输入变量了。通常会在这个包中比较将函数返回的错误值与该值进行比较。

下面是`io`包中的`ReadAtLeast`函数的实现：

**Listing 1.14** 

	func ReadAtLeast(r Reader, buf []byte, min int) (n int, err error) {
	    if len(buf) < min {
	        return 0, ErrShortBuffer
	    }
	    for n < min && err == nil {
	        var nn int
	        nn, err = r.Read(buf[n:])
	        n += nn
	    }
	    if n >= min {
	        err = nil
	    } else if n > 0 && err == EOF {
	        err = ErrUnexpectedEOF 
	    }
	    return
	}

在listing 1.14中，`ReadAtLeast`函数显示了如何使用这些错误变量。这里要注意到 `ErrShortBuffer` 和 `ErrUnexpectedEOF`是如何作为返回值的。 同样需要注意到函数如何比较`err`变量与`EOF`变量的。

在你自己写的API中，创建错误类型变量，需要考虑是否有必要自己是实现，这也能使你提升错误处理的能力。

### 为何不是值类型

这里，也许会想到一个问题，为啥Go语言的设计者不直接设计一个`errString`的值类型，而是使用结构类型？

值类型可以定义为如下方式：

	type errorString string

结构类型定位为如下方式：

	type errorString struct {
     s string
	}

下面给出命名类型的具体实现例子：

**Listing 1.15** 

	01 package main
	02 
	03 import (
	04     "errors"
	05     "fmt"
	06 )
	07
	08 // Create a named type for our new error type.
	09 type errorString string
	10
	11 // Implement the error interface.
	12 func (e errorString) Error() string {
	13     return string(e)
	14 }
	15
	16 // New creates interface values of type error.
	17 func New(text string) error {
	18     return errorString(text)
	19 }
	20
	21 var ErrNamedType = New("EOF")
	22 var ErrStructType = errors.New("EOF")
	23
	24 func main() {
	25     if ErrNamedType == New("EOF") {
	26         fmt.Println("Named Type Error")
	27     }
	28
	29     if ErrStructType == errors.New("EOF") {
	30         fmt.Println("Struct Type Error")
	31     }
	32 } 

	Output:
	Named Type Error


Listing 1.15 提供了简单的示例，显示了`errorString`作为值类型的错误使用。在09行声明了一个`string`的值类型，在12行，`error`接口通过命名类型是吸纳。在17行实行了`New`函数定义。

在21和22行，定义、初始化了两种不同类型的变量。分别通过`New`函数和 `errors.New`函数进行初始化。最后，在`main()`函数中，与相同的方式创建的变量进行了比较。

当你运行这段代码时，得到了上述有趣的结果。25行`if`条件成立，而29行`if`条件不成立。通过使用命名类型，我们能够创建`error`类型值得接口，而且如果错误信息相同，那么就会匹配。这导致的问题其实和1.12l类似，因为我们能够创建自己的`error`值，并且使用它们。如果是通过值类型创建的`error`，那么包的作者改变错误消息的话，我们的代码判断就出问题了。


同样我们也能通过`errorString`的结构体类型复现上面的问题，只要接受者为值(T, 而不是 *T), 实现`error`接口如下：

**Listing 1.16** 

	01 package main
	02
	03 import (
	04    "fmt"
	05 )
	06
	07 type errorString struct {
	08    s string
	09 }
	10
	11 func (e errorString) Error() string {
	12    return e.s
	13 }
	14
	15 func NewError(text string) error {
	16    return errorString{text}
	17 }
	18
	19 var ErrType = NewError("EOF")
	20
	21 func main() {
	22    if ErrType == NewError("EOF") {
	23        fmt.Println("Error:", ErrType)
	24    }
	25 } 

	Output:
	Error: EOF

在listing 1.16中，我们实现了`errorString`的结构体类型，该类型对于`error`接口的实现用的接受者是 `errorString`, 而非`* errorString`. 这一次得到的结果正如 listing 1.15 一样，***他们真正比较的其实是具体类型中的值***。11-13行代码 可以与 listing 1.9 进行比较，值得回味哈。

在标准库中，** 使用`* errorString`作为`error`接口的实现的接受者 ** ，`errors.New`函数强制返回了指针值， 这个指针就是绑定接口的值，并且每次调用都是指向同一个对象。这种情况下比较的其实是指针的值，而不是真正的错误消息。

### 总结

该篇文章中，我们初步理解了`error`接口是什么，如何与`errorString`结构相结合的。 通过`errors.New`和`fmt.Errorf`函数来创建`error`类型的接口值，这种方式是非常普遍并且也是强烈推荐的。

我们也可以暴露（对外能否访问）我们定义的`error`类型的接口值（通常是标准库定义的），它能够通过API调用返回，帮助我们识别不同的错误信息。很多标准库的包中创建了这些对外可以访问的`error`变量，这些通常已经提供了足够的识粒度来区分不同的错误信息。

有时我们需要自己创建合理的`error`类， 这些将会在第二部分中讲述。现在，请使用标准库提供的支持来处理错误吧！






