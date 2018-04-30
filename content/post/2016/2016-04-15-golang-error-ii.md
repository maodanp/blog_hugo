---
categories:
- "技术志"
tags:
- golang
date: 2016-04-15
title: "golang错误处理(二)"
url: "/2015/04/15/error-handling-in-go-part-ii"
---

该篇作为系列(二)，自然要更深入一层。本文翻译自[Error Handling In Go, Part II](https://www.goinggo.net/2014/11/error-handling-in-go-part-ii.html)，作者在该篇中将教我们怎么写自定义error接口，并且根据error如何识别具体的错误。

<!--more-->

### 简介

在第一部分中，我们学习了`error`接口，以及标准库如何通用`errors`包创建的`error`接口来提供支持的。 我们也学习了当错误发生时，我们如何识别是那种类型的错误。最后，我们看到在有些标准库中，如何对外提供`error`接口变量来帮助我们识别具体错误。

知道如何创建以及使用`error`类型在Go语言中常常会使我们感到迷惑。大多数情况下，通过`errors`包创建的`error`接口值已经足够了，然后有时候调用者需要额外的基于上下文的信息，以便能够基于详细的错误处理做处理。这就是本篇文章要讲的自定义错误类型。

在本篇文章我，我想将要学习如何自定义错误类型，以及给出两个标准库中的示例。其中每个示例都提供了关于如何实现自定义错误类型的非常有意思的实现方式。然后我们将会学习如何识别具体的错误接口值（值类型或者指针类型）。

### `net` 包
`net` 包中声明了一个自定义的错误类型—`OpError`. 在这个包的很多函数、方法中都将这个结构体的指针作为具体的类型（存储在返回的`error`接口值当中）：

**Listing 1.1**

	http://golang.org/src/pkg/net/dial.go

	01 func Listen(net, laddr string) (Listener, error) {
	02     la, err := resolveAddr("listen", net, laddr, noDeadline)
	03     if err != nil {
	04         return nil, &OpError{Op: "listen", Net: net, Addr: nil, Err: err}
	05     }
	06     var l Listener
	07     switch la := la.toAddr().(type) {
	08     case *TCPAddr:
	09         l, err = ListenTCP(net, la)
	10     case *UnixAddr:
	11         l, err = ListenUnix(net, la)
	12     default:
	13         return nil, &OpError{Op: "listen", Net: net, Addr: la, Err: &AddrError{Err: "unexpected address type", Addr: laddr}}
	14     }
	15     if err != nil {
	16         return nil, err // l is non-nil interface containing nil pointer
	17     }
	18     return l, nil
	19 }

Listing 1.1 展示了`net`包中的`Listen`函数的实现。我们看到在04和13行中，`OpError`结构体的指针被创建了，并且作为`error`接口值返回。因为`OpError`结构体指针实现了`error`接口，这个指针能够存储在`error`接口值中并且返回。而在09和11行，`ListenTCP`和`ListenUnix`函数也能返回`OpError`结构体指针, 只是它们已经被包含在了返回的`error`接口值中。

线面，让我来看下`OpError`结构的具体**声明**：

**Listing 1.2**

	http://golang.org/pkg/net/#OpError

	01 // OpError is the error type usually returned by functions in the net
	02 // package. It describes the operation, network type, and address of
	03 // an error.
	04 type OpError struct {
	05     // Op is the operation which caused the error, such as
	06     // "read" or "write".
	07     Op string
	08
	09     // Net is the network type on which this error occurred,
	10     // such as "tcp" or "udp6".
	11     Net string
	12
	13     // Addr is the network address on which this error occurred.
	14     Addr Addr
	15
	16     // Err is the error that occurred during the operation.
	17     Err error
	18 }

Listing 1.2中显示了`OpError`结构的定义。其中前三个字段（07、11、14行）提供了当执行网络操作时，错误发生的上下文信息。17行第四个字段声明为一个`error`接口类型，这个字段将包含具体当错误发生时的真实信息，这个具体类型的值多数情况下会是一个`errorString`类型的指针。

另外我们需要注意到：对于自定义的错误类型，Go语言中有一个约定俗成的规则，就是在自定义错误类型后面加`Error`后缀。基本上其他包中也是这么定义的。

下面，我们来看看`OpError`的具体**定义**：

**Listing 1.3**

	http://golang.org/src/pkg/net/net.go

	01 func (e *OpError) Error() string {
	02     if e == nil {
	03         return "<nil>"
	04     }
	05     s := e.Op
	06     if e.Net != "" {
	07         s += " " + e.Net
	08     }
	09     if e.Addr != nil {
	10         s += " " + e.Addr.String()
	11     }
	12     s += ": " + e.Err.Error()
	13     return s
	14 }

Listing 1.3中关于`error`接口的实现，我们能看到如何关联上下文与错误信息，从而产生基于上下的错误信息描述。这种包含上下文描述的错误能够帮助调用者关于如何处理错误提供更有价值性的参考。

### `json` 包

`json`包能够实现从编码后的JSON数据到原生的Go类型的转换，反之亦然。 所有可能返回的错误都是在包内部产生的。对于错误信息而言保留上下文信息显得至关重要，否则就不能对于发生的错误提供正确的信息。对于`json`包来说有包含多自定义的错误类型，而且这些类型都能够通过相同的函数或者方法返回。

下面，我们来看下其中的一个自定义错误类型：

**Listing 1.4**

	http://golang.org/src/pkg/encoding/json/decode.go

	01 // An UnmarshalTypeError describes a JSON value that was
	02 // not appropriate for a value of a specific Go type.
	03 type UnmarshalTypeError struct {
	04     Value string // description of JSON value
	05     Type reflect.Type // type of Go value it could not be assigned to
	06 }
	07
	08 func (e *UnmarshalTypeError) Error() string {
	09     return "json: cannot unmarshal " + e.Value + " into Go value of type " + e.Type.String()
	10 }

Listing 1.4 显示了`UnmarshalTypeError`类型的声明，以及对`error`接口的实现。这个结构通常对于那些JSON数据不能转换成原生的Go类型时发生的错误。这个结构包含两个字段，第一个(04行)包含了试图解码的值类型描述；第二个(05行)包含了试图转化成的Go类型的描述。08行是`error`接口的具体实现，它用于错误信息的上下文，并产生一个正确的错误信息。

在这个例子中，`UnmarshalTypeError`类型本身提供了错误的上下文信息。 当有关于解码类型的错误发生时，就会返回基于该结构指针的`error`接口值作为返回。

那么，当无效的参数传递到`unmarshal`函数呢，那返回的就不是`UnmarshalTypeError`类型指针了，而是`InvalidUnmarshalError`类型的指针：

**Listing 1.5**

	http://golang.org/src/pkg/encoding/json/decode.go

	01 // An InvalidUnmarshalError describes an invalid argument passed to Unmarshal.
	02 // (The argument to Unmarshal must be a non-nil pointer.)
	03 type InvalidUnmarshalError struct {
	04     Type reflect.Type
	05 }
	06
	07 func (e *InvalidUnmarshalError) Error() string {
	08     if e.Type == nil {
	09         return "json: Unmarshal(nil)"
	10     }
	11
	12     if e.Type.Kind() != reflect.Ptr {
	13         return "json: Unmarshal(non-pointer " + e.Type.String() + ")"
	14     }
	15     return "json: Unmarshal(nil " + e.Type.String() + ")"
	16 }

Listing 1.5展示了`InvalidUnmarshalError`结构的声明以及对`error`接口的实现。这里也同样在错误中提供了上下文信息描述。这种实现方式能够帮助产生错误信息，产生的错误信息能够有助于调用者根据错误处理做准确的判断。

### 具体类型的定义

在`json`的`Unmarshal`函数中，`error`接口值返回的类型指针可能是`UnmarshalTypeError`，或`InvalidUnmarshalError`或是`errorString`类型：

**Listing 1.6**
	
	http://golang.org/src/pkg/encoding/json/decode.go

	01 func Unmarshal(data []byte, v interface{}) error {
	02     // Check for well-formedness.
	03     // Avoids filling out half a data structure
	04     // before discovering a JSON syntax error.
	05     var d decodeState
	06     err := checkValid(data, &d.scan)
	07     if err != nil {
	08         return err
	09     }
	10
	11     d.init(data)
	12     return d.unmarshal(v)
	13 }
	14
	15 func (d *decodeState) unmarshal(v interface{}) (err error) {
	16     defer func() {
	17         if r := recover(); r != nil {
	18             if _, ok := r.(runtime.Error); ok {
	19                 panic®
	20             }
	21             err = r.(error)
	22         }
	23     }()
	24
	25     rv := reflect.ValueOf(v)
	26     if rv.Kind() != reflect.Ptr || rv.IsNil() {
	27         return &InvalidUnmarshalError{reflect.TypeOf(v)}
	28     }
	29
	30     d.scan.reset()
	31     // We decode rv not rv.Elem because the Unmarshaler interface
	32     // test must be applied at the top level of the value.
	33     d.value(rv)
	34     return d.savedError
	35 }

Listing 1.6，展示了作为`Unmarshal`函数调用返回的`error`接口值，存在的不同具体类型。 第27行，`unmarshal`方法返回了一个`InvalidUnmarshalError`类型的指针，第34行，返回了`decodeState`中的变量`savedError`，**这个值可以是很多不同的具体类型的指针**。

通过以上我们了解到了`json`包是自定义了`error`类型作为上下文的错误信息，那我们如何区分这些具体值得类型，使得调用者能够根据详细描述做判断？

下面给出一个示例，能够使得`Unmarshal`函数返回一个具体的`UnmarshalTypeError`类型的指针：

**Listing 1.7**

	http://play.golang.org/p/FVFo8mJLBV

	01 package main
	02
	03 import (
	04     "encoding/json"
	05     "fmt"
	06     "log"
	07 )
	08
	09 type user struct {
	10     Name int
	11 }
	12
	13 func main() {
	14     var u user
	15     err := json.Unmarshal([]byte({"name" : "bill"}), &u)
	16     if err != nil {
	17         log.Println(err)
	18         return
	19     }
	20
	21     fmt.Println("Name:", u.Name)
	22 }

	Output:
	2009/11/10 23:00:00 json: cannot unmarshal string into Go value of type int

Listing 1.7，展示了一个简单的代码，尝试将JSON格式数据转换成Go类型。在第15行，JSON数据包含一个名为`name`的字段，值为`bill`。 因为`user`类型中`Name`字段声明的是一个整型，`Unmarshal`函数返回了一个错误接口值，该值实际存储的是一个`UnmarshalTypeError`类型的具体指针。

现在我们可以做上面的代码做些改变，对于同样的`Unmarshal`调用返回的`error`接口，存储的是不一样的具体指针类型：

**Listing 1.8**

	http://play.golang.org/p/n8dQFeHYVp

	01 package main
	02
	03 import (
	04     "encoding/json"
	05     "fmt"
	06     "log"
	07 )
	08
	09 type user struct {
	10     Name int
	11 }
	12
	13 func main() {
	14     var u user
	15     err := json.Unmarshal([]byte({&quot;name&quot;:&quot;bill&quot;}), u)
	16     if err != nil {
	17         switch e := err.(type) {
	18         case *json.UnmarshalTypeError:
	19             log.Printf("UnmarshalTypeError: Value[%s] Type[%v]\n", e.Value, e.Type)
	20         case *json.InvalidUnmarshalError:
	21             log.Printf("InvalidUnmarshalError: Type[%v]\n", e.Type)
	22         default:
	23             log.Println(err)
	24         }
	25         return
	26     }
	27
	28     fmt.Println("Name:", u.Name)
	29 }

	Output:
	2009/11/10 23:00:00 json: Unmarshal(non-pointer main.user)
	2009/11/10 23:00:00 InvalidUnmarshalError: Type[main.user]	


Then we do something interesting on lines 17 through 24:

Listing 1.8，同样的代码我们做了小小的修改，在15行中我们传递了变量`u`的值，而不是它的地址。 这个改变导致了`Unmarshal`函数返回了一个错误接口值，它实际存储的是`InvalidUnmarshalError`这个具体的指针类型。

对于17-24行，我们进行了错误的处理：

**Listing 1.9**  

		17     switch e := err.(type) {
		18         case *json.UnmarshalTypeError:
		19             log.Printf("UnmarshalTypeError: Value[%s] Type[%v]\n", e.Value, e.Type)
		20         case *json.InvalidUnmarshalError:
		21             log.Printf("InvalidUnmarshalError: Type[%v]\n", e.Type)
		22         default:
		23             log.Println(err)
		24         }

在17行，我们加入了`switch`语句进行具体指针类型的识别（这个指针当然是存储在`error`接口值下的）。这里要注意如何在接口值转换中使用关键字类型的。我们也能够获取到具体类型的值,并且在每个`case`语句中使用它。

在18、20行的`case`语句中，进行了不同具体类型的检测，然后执行了关于错误处理的操作。在Go中是普遍采这种方式来识别具体类型的值或者指针。这些值或指针是存储在在`error`接口值当中的。

### 总结

我们所返回的函数或者方法中的`error`接口值，包含特定的运行上下文信息。它必须能够提供足够多的信息，以便调用者能够根据这些信息分辨。通常一个简单的错误消息就足够了，但是有时调用者需要知道更多信息。

我们能够看出，在`net`包中，一个自定义的`error`类型，声明中包含了原始`error`以及关联的上下文信息。而在`json`包中，我们看到自定义的错误类型提供了上下文信息以及关联状态。 在两者中，保持错误关联的上下文信息是一个必要的因素。

当传统的`error`接口值通过`errors`包创建, 并且提供了足够的信息，那么久使用它吧。这通常包含在标准库中，通常这些就已经足够了。如果你需要其他上下文信息以帮助调用者做具体决定，那么我们可以从标准库中找找线索，然后构建自定化`error`类型。





