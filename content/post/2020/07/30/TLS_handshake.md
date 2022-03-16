---
categories:
- "技术志"
tags:
- "Security"
date: 2020-07-30
title: "TLS 握手协议解析"
url: "/2020/07/30/TLS_handshake"
---

TLS 是一种密码学的协议，用来保证两个实体之间的会话安全，TLS 是一种位于应用层和传输层之间的协议。本文将会详细描述 TLS 中的握手协议的流程。

<!--more-->

TLS 包括四个核心的子协议：握手协议（`handshake protocol`）、秘钥规格变更协议（`change cipher spec protocol`）、应用数据协议（`application data protocol`）、警报协议（`alert protocol`）。握手协议是 TLS 协议中最精密也是最复杂的部分。在这个过程中，通信双方协商连接参数，并且完成身份验证。

### 完整的握手过程

下图展示的是 Server 和 Client 之间一次完整的 session 握手流程：

![pic](/pic/2020/2020-07-30-tls-handshake-1.png)

1. **ClientHello**: Client 开始新的握手，并将自身支持的功能提交给 Server
2. **ServerHello**:  Server 选择连接参数
3. **Certificate**:  Server 发送其证书链（仅当需要 Server 身份验证，非必须）
4. **ServerKeyExchange**: 根据选择的秘钥交换方式，Server 发送生成主秘钥（`Master Secret`）的额外信息（非必须）
5. ~~**CertificateRequest**: 如果需要 Client 身份验证时，需要发送该请求（非必须）~~
6. **ServerHelloDone**: Server 通知 Client 自己完成了协商过程
7. **Certificate**：Client 发送其证书链（仅当需要 Client 身份验证，非必须）
8. **ClientKeyExchange**: Client 生成主秘钥的额外信息，并通知 Server
9. ~~**CertificateVerify**: Client 通知 Server 自己的公私钥验证结果（仅当需要客户端身份验证，非必须）~~
10. **ChanageCipherSpec**:  Client 切换加密方式并通知 Server
11. **Finished**: 加密握手消息 （`Encrypted Handshake Message`） 结束，Client 将之前所有发送的数据做个摘要，再⽤主密钥加密⼀下，让 Server 做个验证
12. **ChanageCipherSpec**:  Server 切换加密方式并通知 Client
13. **Finished**: 加密握手消息结束，Server 将之前所有发送的数据做个摘要，再⽤主密钥加密⼀下，让 Client 做个验证

假设没有出现错误，到这一步，连接就建立起来了，可以开始发送应用数据。现在我们来了解一下这些握手消息的更多细节。

### TLS 第一次握手 - ClientHello

在每一次新的握手流程中，ClientHello 消息总是第一条消息。Client 会在新建连接之后，希望重新协商或者响应服务器发起的重新协商请求时，发送这条消息。包含的关键元素如下：

~~~
Version: TLS 1.2
Random: b76fjdiaei04q9jfea0fjdioaidofja.....
Cipher Suites
		Cipher Suites: TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
		Cipher Suites: TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA384
		Cipher Suites: TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA256
		Cipher Suites: TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384		
~~~

我们可以看到消息中主要包含有 Client 使用的 TLS 版本号、支持的密码套件列表、以及生成的随机数（`Client Random`）。在握手时，Client 和 Server 都会提供随机数，它们也是生成对称秘钥的必备条件。

### TLS 第二次握手- ServerHello、Certificate

#### ServerHello

ServerHello 消息的意义是将 Server 选择的连接参数传送给 Client。包括确认 TLS 版本号是否支持，从密码套件列表中选择一个密码套件，以及生成随机数（`Server Random`）。

~~~
Version: TLS 1.2
Random: 9f0ae9qe9rer9q0etub61t4y.....
Cipher Suite: TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
~~~

密码套件有固定的的格式和规范。基本形式是 「`秘钥交换算法` + `签名算法` + `对称加密算法` + `摘要算法`」。比如 TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 的密码套件表示的含义如下：

* 秘钥交换算法（属于 `handshake` 部分），基于非对称秘钥用于交换对称秘钥，这里使用了 ECDHE，其他常用的还有 DHE
* 签名算法（属于 `Authentication` 部分），这里使用了 RSA 验证证书签名，其他常见的还有 ECDSA
* 对称加密算法（属于 `Encryption` 部分），使用对称秘钥加密数据，这里的 AES_128_GCM 分别表示算法、强度和分组模式
* 摘要算法（属于 `Hashing` 部分），用于计算消息的散列值，防止消息中途被篡改，这里使用了 SHA256。常见的有 SHA384，SHA512

到这里为止，Client 和 Server 都产生了随机数，并且都传给了对方，这两个随机数也是后续作为生成 「主秘钥」或者说「会话秘钥」的条件。这里的主秘钥就是数据传输时所使用的对称加密秘钥。

#### Certificate

Server 发送 Certificate 消息，Server 端必须保证它发送的证书与所选择的密码套件是一致的。Certificate 的作用就是用来认证公钥持有者的身份，证明 Server 的合法性，以防止第三方进行冒充。那证书包含了哪些内容？Client 又是怎么认证证书的呢？

1. 数字证书和 CA 机构

Certificate 主要包含了 **Server 的公钥**、**持有者信息**、**证书认证机构**（CA）的信息、CA 对这份文件的**数字签名**及使用的**算法**、**证书有效期**以及其他额外信息。CA 是网络世界里的公证中心，具有极高的可信度，由它签发的 Certificate 必然也是被信任的。之所以要签名，是因为签名的作用可以避免中间人在获取 Certificate 时对其内容作篡改。

2. 数字证书签发和验证

下图为数字证书的签名过程以及客户端的验证过程（下图取自 《图解网络》）。

![pic](/pic/2020/2020-07-30-tls-handshake-2.png)

CA 签发证书的过程，如上图左边部分：

* CA 将持有者的公钥、用户、颁发者、有效期等信息进行打包，然后进行 Hash 计算
* CA 使用自己的私钥将该 Hash 值加密，生成数字签名（`Certificate Signature`），也就是 CA 对证书做了签名
* 最后将数字签名添加到证书文件中，形成数字证书（`Digital Certificate`）

Client 端校验服务器的数字证书的过程，如上图右边部分：

* Client 端使用同样的 Hash 算法获取该证书的 Hash 值 **H1**
* 通常浏览器和操作系统中集成了 CA 的公钥信息，浏览器收到蒸熟后可以用 CA 的公钥解密数字签名的内容，得到一个 Hash 值 **H2**
* 最后比较 H1 和 H2，如果值相同，则为可信赖的证书，否则认为证书不可信

3. 证书的吊销

当出现私钥泄露或者不再需要使用时，我们就需要吊销证书。目前有两种证书吊销的标准：

* 证书吊销列表（certificate revocation list，`CRL`）是一组被吊销的证书序列号列表（但是证书没有过期），CA 维护了一个或者多个这样的列表。CRL 最大的问题在于它越来越大，实时查询起来会非常慢
* 在线证书状态协议（online certificate status protocol，`OCSP`）允许新来访获得一张证书的吊销信息。OCSP 支持实时查询并且解决了 CRL 的最大缺点，但是并没有解决所有的吊销问题：OCSP 的使用也会带来性能、隐私方面的问题和新的漏洞。

### TLS 第三次握手- ClientKeyExchange、ChangeCipherSpec、Finished

#### ClientKeyExchange

Client 在验证完证书后，认为数字证书是可信的，接着 Client 端会生成一个新的随机数（`pre-master`），然后用 Sever 的公钥加密算法加密该随机数，然后通过 「`Client Key Exchange`」 消息传给 Server 端。Server 在收到这个 pre-master 之后，用私钥解密，得到了 Client 发来的这个随机数。

#### ChangeCipherSpec

双方根据已经得到的三个随机数，生成主秘钥，生成完主秘钥之后，Client 会发送一个「`Change Cipher Spec`」，表示已经生成主秘钥，并且将模式切换到加密模式，告诉 Server 开始使用加密方式发送消息。ChangeCipherSpec 之前传输的 TLS 握手数据都是明文的，之后都是对称秘钥加密的秘文。

#### Finished

Client 再发一个 「`Encrypted Handshake Message (Finished)`」消息，将之前所有发送的数据做个摘要，再用主秘钥加密一下，让 Server 来验证加密通信是否可用，验证之前的握手信息是否被中途篡改过。

### TLS 第四次握手 - ChangeCipherSpec、Finished

Server 也同样会发送 「`Change Cipher Spec`」和 「`Encrypted Handshake Message (Finished)`」消息，如果双方都验证加密和解密没问题，那么握手正式完成。后续就能够基于「会话秘钥」加解密 HTTP 的请求和响应了。



### 参考阅读

[The Transport Layer Security (TLS) Protocol](https://www.rfc-editor.org/rfc/pdfrfc/rfc5246.txt.pdf)