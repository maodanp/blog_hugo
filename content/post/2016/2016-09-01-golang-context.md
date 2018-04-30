---
categories:
- "技术志"
tags:
- golang
- 代理
date: 2016-09-04
title: "golang中context包"
url: "/2016/09/04/go"
---

在阅读一些标准库(net、net/http、os/exec)时，经常会遇到context包，大致知道是当做关闭事件触发用的。阅读完GoTeam的文章[Go Concurrency Patterns: Context](https://blog.golang.org/context)，才更深刻的了解了其设计意图。

<!--more-->

一般我们会通过`select + channel`的方式去终止一个协程，这也是最简单的情况。我们可以考虑些稍微复杂的情形，比如在写Go的Server服务，context包能够使得传递某些信息给相关的处理协程变得很简单，这些传递信息包括：**请求域的值(request-scoped values)**、**中断信号(cancelation signals)**、**过期时间**等。或者想中止某个goroutine创建的goroutines，使用context也很方便。

目前Go1.7将原来的`golang.org/x/net/context`包挪入了标准库中，放在`$GOROOT/src/context`，可见context模式用途广泛。
### Context接口

**context**包的核心是一个**Context**类型：

~~~go
// Context包 携带信息包括过期时间、中止信号，参数值等
// context 包里的方法是线程安全的，可以被多个 goroutine 使用
type Context interface {

    // 当Context被canceled或times out的时候，Done返回一个被close的channel 
    Done() <-chan struct{}

    // 在Done的channel被closed后， Err代表被关闭的原因   
    Err() error

    // 如果存在，Deadline返回Context将要关闭的时间 
    Deadline() (deadline time.Time, ok bool)

    // 如果存在，Value返回与key相关了的值，不存在返回nil  
    Value(key interface{}) interface{}
}
~~~

其中的Done方法返回了一个通道，代表了Context的一个中止信号：当这个通道关闭，函数将中止并且立即返回。Err方法也将返回为何被终止的错误。

Done方法返回的通道是只读的，所以Context并没有提供Cancel方法来关闭通道。这个也比较好理解，比如当一个协程创建了很多的子协程，这些子协程不能够中止父协程的。而父协程则可以通过WithCancel函数(后面描述)提供的一种方式来中止子协程。


### 派生的结构

context包为我们提供了两个Context包的实现，Background()与TODO()。只是返回的这两个实例都是空 Context。它们没有过期时间，没有任何值，一般在`main`,`init`,`tests`等函数中，当做对上层的Context使用，其他Context往往派生于它们(一般嵌入到其他Context中)。

#### cancelCtx

cancelCtx结构体继承了Context ，实现了canceler方法：

~~~go
//*cancelCtx 和 *timerCtx 都实现了canceler接口，实现该接口的类型都可以被直接canceled
type canceler interface {
    cancel(removeFromParent bool, err error)
    Done() <-chan struct{}
}        

type cancelCtx struct {
    Context
    done chan struct{} // closed by the first cancel call.
    mu       sync.Mutex
    children map[canceler]bool // set to nil by the first cancel call
    err      error             
}

~~~

其中，核心方法是`cancel`。该方法会依次遍历c.children，每个child分别cancel；如果设置了removeFromParent，则将c从其parent的children中删除

~~~go
func (c *cancelCtx) cancel(removeFromParent bool, err error) {
      //...
}
~~~

我们可以通过WithCancel函数来创建一个cancelCtx。返回一个 cancelCtx的结构，同时也会返回一个CancelFunc自定义函数，调用该函数，将会关闭对应的c.done，也就是让他的后代goroutine退出。

~~~go
func WithCancel(parent Context) (ctx Context, cancel CancelFunc) {
    //...
}
~~~

#### timerCtx 

timerCtx 结构继承 cancelCtx。

~~~go
type timerCtx struct {
    cancelCtx //此处的封装为了继承来自于cancelCtx的方法，cancelCtx.Context才是父亲节点的指针
    timer *time.Timer // 计时器
    deadline time.Time
}
~~~

我们可以通过下面两个函数来创建timerCtx：

~~~go
func WithDeadline(parent Context, deadline time.Time) (Context, CancelFunc)
func WithTimeout(parent Context, timeout time.Duration) (Context, CancelFunc)
~~~

WithDeadline 和 WithTimeout 是相似的，WithDeadline 是设置具体的deadline时间，到达deadline的时候，派生goroutine退出；WithTimeout设置的是时间间隔。


#### valueCtx 

valueCtx 结构实现了Cancel接口。该结构多了一对key,val的值。其派生goroutine通过Context以及key都能得到响应的val。

~~~go
type valueCtx struct {
    Context
    key, val interface{}
}
~~~

### 示例

下面模拟了一个累加器，通过context传递累加的上限。

~~~go
package main

import (
        "context"   //go1.7以上版本直接使用标准库中的context
        "fmt"
        "time"
)

// 模拟累加器
func accumulator(ctx context.Context) (res int) {
        loop, ok := ctx.Value(userKey).(int)
        if !ok {
                return 0
        }

        // 直到累加结束或者收到closed channel
        for i := 0; i < loop; i++ {
                res += i
                select {
                case <-ctx.Done():
                        fmt.Println("need to done")
                        return res
                default:
                }
        }
        fmt.Println("finish calculate")
        return res
}

type key int

const userKey key = 0

func main() {
        // cancelCtx
        ctx, cancel := context.WithCancel(context.Background())
        // valueCtx
        newCtx := context.WithValue(ctx, userKey, 10000000)

        go func() {
                time.Sleep(1 * time.Millisecond)
                cancel() // 在调用处主动取消
        }()
        res := accumulator(newCtx)
        fmt.Printf("accumulato result: %d\n", res)
}
~~~

### 总结

在请求的输入输出函数中，一般讲context作为首个参数传递。它能够非常简便的控制超时、中止等操作，并且也能够确保信息在goroutine中的安全传输。

### 参考阅读

[Go Concurrency Patterns: Context](https://blog.golang.org/context)









