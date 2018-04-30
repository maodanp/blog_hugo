---
categories:
- "技术志"
tags:
- golang
- 代理
date: 2016-09-11
title: "创建基于proxy的HTTP(s)连接"
url: "/2016/09/11/golang-https-proxy"
---

最近遇到了几次HTTP(s)如何通过代理访问内网的问题，本篇讲述基于proxy发送/接收HTTP(s)请求的客户端实现方法。

<!--more-->

开发者可能比较熟悉如何编写`http/https`的网络编程(包含客户端/服务端)。在`net/http`的标准库中也有相关很多示例。但是如何基于`proxy`创建HTTP(s)的连接，这个并不一定熟悉。

下面依次介绍两种方法，都能够实现HTTP(s)的代理转发:

* 第一种是直接通过对`http.Transport`的`proxy`字段设置代理，然后按照的客户端访问方式编写；
* 第二种是根据代理协议，与`proxy`先建立连接(传输层)，然后基于该连接再发送HTTP(s)数据(应用层)。

### `http.Client`创建代理连接

#### 基本方法

以下为客户端的常用方法：

~~~go
func (c *Client) Get(url string) (r *Response, err error)
func (c *Client) Post(url string, bodyType string, body io.Reader) (r *Response, err error)
func (c *Client) PostForm(url string, data url.Values) (r *Response, err error) func (c *Client) Head(url string) (r *Response, err error)
func (c *Client) Do(req *Request) (resp *Response, err error)
~~~

通常前三个基本能够满足条件，如果我们发起的HTTP请求需要更多的定制信息(增加HTTP头信息，传递Cookie等)，可以使用`Client.Do()`方法来实现：

~~~go
req, err := http.NewRequest("GET", "http://example.com", nil) // ...
req.Header.Add("User-Agent", "Gobook Custom User-Agent")
// ...
client := &http.Client{ //... }
resp, err := client.Do(req)
// ...
~~~

#### 高级封装

Go暴露了比较底层的HTTP相关库，让开发者灵活定制和使用HTTP服务。

##### 自定义http.Transport

HTTP Client的Request结构主要操作是了HTTP Method, 目标URL，请求参数，请求内容等信息。而具体的HTTP的细节，都需要通过http.Transport去处理。比如：

* HTTP底层传输细节
* HTTP代理
* gzip压缩
* 连接池及管理
* 认证（SSL或其他认证方式）

http.Transport类型的具体结构如下：

~~~go
type Transport struct {
// Proxy指定用于针对特定请求返回代理的函数。
// 如果该函数返回一个非空的错误,请求将终止并返回该错误。
// 如果Proxy为空或者返回一个空的URL指针,将不使用代理
Proxy func(*Request) (*url.URL, error)
// Dial指定用于创建TCP连接的dail()函数。
// 如果Dial为空,将默认使用net.Dial()函数
Dial func(net, addr string) (c net.Conn, err error)
// TLSClientConfig指定用于tls.Client的TLS配置。
// 如果为空则使用默认配置
TLSClientConfig *tls.Config
DisableKeepAlives bool
DisableCompression bool
// 如果MaxIdleConnsPerHost为非零值,它用于控制每个host所需要
// 保持的最大空闲连接数。如果该值为空,则使用DefaultMaxIdleConnsPerHost 
MaxIdleConnsPerHost int
// ... 
}
~~~

其中`Proxy`指定了一个代理方法。如果 Proxy 未指定或者返回的 *URL 为零值,将不会有代理被启用；`TLSClientConfig`指定 tls.Client 所用的 TLS 配置信息,如果不指定, 也会使用默认的配置；`DisableKeepAlives`是否取消长连接,默认值为 false,即启用长连接；`DisableCompression`是否取消压缩(GZip),默认值为 false,即启用压缩。

#### 通过proxy创建client示例

下面为客户端的代码，其中我们对http.Transport指定了`Proxy`及`TLSClientConfig`, 相当于封装了具体的HTTP实现细节，最后通过`http.Client.Get`方法实现基于proxy的HTTP(s)代理。

~~~go
package main

import (
        "crypto/tls"
        "flag"
        "fmt"
        "net/http"
        "net/url"
        "time"
)

const timeout time.Duration = 10

func main() {
        // Parse cmdline arguments using flag package
        server := flag.String("server", "abhijeetr.com", "Server to ping")
        port := flag.Uint("port", 443, "Port that has TLS")
        proxy := flag.String("proxyURL", "", "Proxy to use for TLS connection")
        flag.Parse()

        // Prepare the client
        var client http.Client
        if *proxy != "" {
                proxyURL, err := url.Parse(*proxy)
                if err != nil {
                        panic("Error parsing proxy URL")
                }
                transport := http.Transport{
                        Proxy:           http.ProxyURL(proxyURL),
                        TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
                }
                client = http.Client{
                        Transport: &transport,
                        Timeout:   time.Duration(time.Millisecond * timeout),
                }

        } else {
                client = http.Client{}
        }
        // Now we've proper client, with or without proxy

        resp, err := client.Get(fmt.Sprintf("https://%v:%v", *server, *port))
        if err != nil {
                panic("failed to connect: " + err.Error())
        }

        fmt.Printf("Time to expiry for the certificate: %v\n", resp.TLS.PeerCertificates[0].NotAfter.Sub(time.Now()))
}
~~~

### `tls.Client`创建代理连接

上述http.Client能够实现代理连接的创建，但是如果我们需要通过代理传输原始数据，即TCP层的数据传输，而不是应用层的HTTP数据传输，那么我们可以直接与`proxy`先建立连接，然后基于该连接再发送HTTP(s)数据。

分两个步骤完成：
1. 与`proxy`建立连接，发送`CONNECT`方法的HTTP请求
2. 复用步骤1中的connection，发送原始数据(HTTP/HTTPS需要通过接口写入该connection)

下面分别通过描述

#### 建立连接

如下代码段所示，首先与`proxy`建立connecton, 发送`CONNECT`方法的HTTP请求。 如果`proxy`返回了200，则后面就能够复用该连接了，否则与`proxy`的连接就失败了。

~~~go
if conn, err = net.Dial("tcp", proxyURL.Host); err != nil {
                panic("Error net.Dial")
                return
        }

// send an HTTP proxy CONNECT message
req, err := http.NewRequest("CONNECT", "https://"+server, nil)
if err != nil {
        panic("Error http.NewRequest")
        return
}
//组织http协议，写入该connection
req.Write(conn)

// 读取proxy的返回
resp, err := http.ReadResponse(bufio.NewReader(conn), req)
if err != nil {
        panic("Error http.ReadResponse")
        return
}
resp.Body.Close()

if resp.StatusCode != 200 {
        err = fmt.Errorf("Non-200 response from proxy server: %s", resp.Status)
        return
}
~~~

#### 发送数据

有了该连接后，对于HTTP的请求就好办了，按照发送CONNECT方法的HTTP请求一样，我们可以通过`NewRequest`创建`GET`/`POST`方法，然后写入`connection`, 处理回应消息。完成整个请求流程。

但是对于HTTPS的请求, 因为需要TLS协议的加密，所以不能简单的传递明文，需要传递加密后的数据，这个过程在Go的`crypto/tls`包中已经实现了。我们需要对之前的connection再次封装一层，得到新的基于TLS协议的connection。

代码段如下：

~~~go
// 创建request结构
req, err = http.NewRequest("GET", "https://"+server, nil)
if err != nil {
        panic("Error http.NewRequest")
        return
}

//这里基于原先的conn创建了一个TLS的newConn
newConn := tls.Client(conn, proxyTlsConfig)

// 将request的相关信息写入到newConn中
// 后续将基于该newConn进行数据的读写操作
err = req.Write(newConn)
if err != nil {
        panic("Error req.Write")
        return
}
resp, err = http.ReadResponse(bufio.NewReader(newConn), req)
if err != nil {
        panic("Error http.ReadResponse")
        return
}
if respBody, err := ioutil.ReadAll(resp.Body); err != nil {
        panic("Error http.ReadResponse")
        return
} else {
        fmt.Printf("resp: %s", string(respBody))

}
resp.Body.Close()
~~~

通过以上方式，我们也能够传递其他原始数据，经过代理，并且经过加密传输。那基于该传输层的数据传输，对应的server端如何接收呢？

我们可以创建密钥，证书。然后通过`tls.Listen`方法监听指定端口。大致代码如下：

~~~go
func main() {
    cer, err := tls.LoadX509KeyPair("../cert_server/server.crt", "../cert_server/server.key")
    if err != nil {
        fmt.Println(err.Error())
    }
    config := &tls.Config{Certificates: []tls.Certificate{cer}}
    listener, erl := tls.Listen("tcp", ":8888", config)
    if erl != nil {
        fmt.Println(erl.Error())
        return
    }
    for {
        conn, err := listener.Accept()
        checkErr(err)
        go Handle(conn)
    }
}
~~~


### 总结

以上两种方式都能够实现通过proxy发送/接收HTTP(s)的请求。第一种方式相对来说简单，直接通过`http.Transport`的`proxy`字段设置就能通过代理发送请求，而第二种方式相对较为复杂，但是方法二更加的灵活，通过代理我们不仅能够收发HTTP(s)信息，同样也能对我们的原始数据进行加密传输。

### 参考阅读

[Golang: Creating HTTPS connection via proxy](http://www.tuicool.com/articles/uIbUnmE)

[https://golang.org/pkg/crypto/tls/](https://golang.org/pkg/crypto/tls/)

Go语言编程 Ch5 网络编程



