---
categories:
- "技术志"
tags:
- "Security"
date: 2022-03-09
title: "秘钥凭证 （Proof Key）在OAuth 客户端 Code Exchange 阶段的应用"
url: "/2022/03/09/PKCE"
---

基于授权码（`Authorization code grant`）技术的 OAuth 2.0 客户端容易受到授权码被劫持（interception attack）的风险。本篇文章基于 [RFC7636](https://datatracker.ietf.org/doc/html/rfc7636) 主要介绍了OAuth 2.0 客户端在 `code exchange` （Authz code exchange access token）阶段如何使用秘钥凭证来减缓这种攻击。

<!--more-->

### 授权码拦截攻击

在 OAuth 2.0 协议 [RFC6749](https://datatracker.ietf.org/doc/html/rfc6749) 中，授权码是通过认证/授权服务器返回到重定向的 URI的，并且这个返回的路径是不受 TLS 保护的，这个重定向 URI 可以指向某个 URL 或者是客户端系统内的某个应用程序。

一旦攻击者获取到这个 `Authz code`， 就能够利用它去交换得到一个 `Access token`。有了这个 token，攻击者就能冒充合法的应用程序访问到服务器（`service provider`）中的资源了。

下图展示了攻击者如何进行授权码拦截的过程：

![pic](/pic/2022/2022-03-09-PKCE-1.png)

**第一步**：运行在终端设备上的本地应用（legitimate OAuth 2.0 App）通过操作系统或者浏览器发送 OAuth 2.0 的授权请求（`Authz request`），一般 `redirect URI` 都是自定义的。

**第二、三步**：授权请求经过操作系统或者浏览器发往了授权服务器（`Authz server`）, 然后授权服务器返回了授权码（`Authz code`）。因为 OAuth 要求使用 TLS 作为传输的协议，所以这些请求都是受 TLS 保护的，不会收到中间人攻击。

**第四步**：通过步骤一提供的 URI 重定向的方式将 `Authz code` 返回给了这个 `redirect URI` 指向的地址。除了合法的 App 之外，恶意程序（malicious App）也有可能将自己注册为自定义的 redirect URI ，这样恶意程序就有可能拿到这个 Authz code。

#### 授权码拦截的一些先决条件

1. Hack 需要将自己的恶意 App  安装到用户的终端设备， 还需要将自定义的 Redirect URI 注册到其他的 App， 也就是操作系统必须允许这种自定义的 URI scheme 能够跨 App 的注册。
2. Hack 需要能够拿到 OAuth 2.0 中的 `client_id` 和 `client_secret`。这里的 client_id 是基于设备的，也就是不同的设备类型（Mac/Windows/IOS/Android）使用不同的 client_id，client_secret。因为这种信息是在客户端保存的，这种在客户端保存的秘钥也不能被认为是绝对安全的。
3. Hack 能够监测到授权服务器的 response。

#### PKCE  （Proof Key for Code Exchange）流程

为了降低授权码被拦截的风险，这个协议引入了 `code verifier`（授权码验证器）的概念，它实际就是一个动态创建的、加密的随机秘钥。并且每个 `Authz request` 都会创建唯一的一个 code verifier, 并将其转换后的值 `code challenge` 发送到 `Authz server` 以获取 `Authz code`（见下图的步骤 A、B）。

然后，将这个获得的 Authz code 以及之前的 code verifier 一起发送到 Authz server，server 会将 code verifier 进行 `hash` 运算以及 `base64 URL` 编码，将得到的结果跟之前收到的 code challenge （之前 Authz request 携带过来的）进行比较。如果值相等则表示这个 Authz code 是有效的，会返回 access token，否则被认为是非法的，会返回无效授权的错误（见下图的步骤 C、D）。

PKCE 协议能够有效的降低授权码被劫持的风险，因为攻击者不知道这个一次性密钥，`Authz request` 和 `access token request` 都是通过 `TLS` 发送的并且无法被拦截。

![pic](/pic/2022/2022-03-09-PKCE-2.png)

### PKCE （Proof Key for Code Exchange）协议详解

* Client 创建一个 Code Verifier

Client 会为每个 Authz request 创建一个 `coder verifier`，它是由一串随机字符串组成的。这个 code verifier 应该有足够的高的熵（`entropy`）或者说足够高的随机性，这能够否防止 code verifier 被 hack 轻易的破解。

* Client 创建对应的 Code Challenge

Client 通过之前的 code verifier 创建对应的 `code challenge`, 创建规则如下：
~~~
[Plain]
code_challenge = code_verifier

[S256]
code_challenge = BASE64URL-ENCODE(SHA256(code_verifier))
~~~

如果 client 端能够支持 `S256`，就必须使用这种转换规则，并且这种规则在服务器端也是强制要求要能够支持的。而 client 端使用 `plain` 转换规则的前提是当且仅当 client 端由于某些技术原因不能支持 S256。

* Client 通过 Authz request 发送 Code Challenge 

Client 将 `code challenge` 作为 Authz request 的参数发送给 server。
~~~
[code_challenge]
必需填写项

[code_challenge_method]
可选项，默认是使用 plain，code verifier 转换的方法可以是 S256 或者 plain。
~~~
* Server 返回 Authz Code

当 server 在 Authz response 中返回 Authz code 的时候，server 必须要将 code_challenge 跟这个 Authz code 进行关联，以便在下一个 access token request 中能够验证 code verifier 的有效性。

* Client 发送 Authz Code 

Client 发送 Access token request 给 server,  除了 OAuth 2.0 需要的一些必要参数外，还需要额外的参数：`code_verifier`。

* Server 在返回 Access Token 之前验证 coder verifier

Server 会基于 code_verifier 做转换，然后将转换出的结果跟之前关联的 code_challenge 作比较。具体的转换规则依赖于 `code_challenge_method` 属性。
~~~
BASE64URL-ENCODE(SHA256(code_verifier)) == code_challenge
~~~
如果这个属性是 S256，code_verifier 需要做 SHA-256 的 hash, 然后是 base64url 的编码。如果这个属性是 plain，code_verifier 直接跟 code_challenge 比较。
~~~
code_verifier == code_challenge
~~~
如果比较的值相等，Authz server 会返回 Access token 给 client 端， 如果不相等，则返回一个 error message 表示这是一个无效的授权（ invalid grant）。

### 关于安全性的考虑

#### code_verifier 的熵

这个 PKCE 安全模型需要依赖于 code verifier 是否容易被 hack 学习或者猜到，坚持这一原则也是至关重要的。因此这个 code verifier 的创建必须是加密的并且具有足够高的随机性。

#### 防止窃听

客户端在尝试 `S256` 的规则后不得降级为 `plain` ，对于支持 PKCE 的服务器也必须要支持 S256，不支持 PKCE 的服务器将简单地忽略未知的 code_verifier 。 因此在出现 S256 时的错误只能表示 server 出现故障或者攻击者正在尝试降级攻击，而并不意味着 server 不支持 S256。

#### code_challenge 的 Salt

为了降低实现的复杂度，在产生 code challenge 过程中不需要使用 salting，因为 code verifier 已经包含了足够的随机性来避免被攻击。

### 参考阅读

[PKCE by OAuth Public Clients](https://datatracker.ietf.org/doc/html/rfc7636.html)