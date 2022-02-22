---
categories:
- "技术志"
tags:
date: 2022-02-22
title: "基于云服务的 KMS 架构解读"
url: "/2022/02/22/key_management_service"
---

本文主要介绍 Cisco System 使用的一种秘钥管理服务（Key Management Service）架构，该架构旨在标准化KMS 的服务协议，促进完善 KMS 服务提供商的生态系统， 目前该[架构](https://datatracker.ietf.org/doc/html/draft-abiggs-saag-key-management-service-02)还在草案阶段，未纳入 RFC 标准。

<!--more-->

保护用户的隐私数据对于每个产品来说都是必须要考虑的一个问题，对于走国际化的 APP 来说尤其如此。 最近 Zoom 爆料出了很多隐私和安全漏洞，使得各界对于 Zoom 抱有不信任的态度，股价也随之暴跌。 目前端到端加密（E2E Encryption）也是各大公司主流的加密方式，该加密方式需要基于秘钥管理服务（KMS），这个在整个加密流程中是非常关键的一环，很多公司都有自己的一套规范，比如 [Google Cloud Platform KMS](https://cloud.google.com/docs/security/key-management-deep-dive) 、[AWS KMS](https://www.encryptionconsulting.com/aws-kms-vs-azure-key-vault-vs-gcp-kms/) 等等。



之前在项目开发过程中涉及过 `E2E Encryption` 技术，使用的技术跟本篇介绍的规范虽然有些差异，但大体结构是类似的。



### KMS 简介

目前基于云的`服务提供商`（Cloud Service Provider）通常都会使用一些安全协议（例如 TLS 或 IPSec）在传输级别保护用户数据。这些协议虽然可以有效地保护用户数据在传输过程中免受第三方软件的篡改和窃听；但是，因为用户数据是保存在 Cloud Server 端的，所以这些传输级别的协议本身并不能保护用户数据免受云提供商的监听、滥用，也就是说 Service Provider 也是不受信任的。

E2E Encryption 就是用来确保第三方/云服务商永远不会拥有未加密的用户数据，或者永远不能够得到解密后用户数据。该篇文章主要介绍了一种用于建立、管理和安全分发加密密钥的开放架构，用于在线通信和共享内容的端到端加密。



### 架构总览

该模型的核心是通信资源服务器（`Communications Resource Server`），它被假定为由云服务提供商操作，以提供某种形式的通信服务。使用通信资源服务器的服务是通信资源客户端（`Communications Resource Client`），可以由云提供商提供或由第三方开发。

从下图的整体架构可以看出，用户的客户端必须是受信任的一方，否则用户也不会使用该 APP 登录自己的账号，或者基于该 APP 分享资源；KMS Server 也必须是受信任的一方，E2E Encryption 中秘钥的生成，管理都需要依赖于该 Server。但是第三方的云服务提供商以及 KMS 的传输过程我们假定都不是受信任的，都有可能被第三方篡改和窃听。


![pic](/pic/2022/2022-02-22-kms-1.png)

### KMS 使用示例

下面的示例图描述了基于 KMS 架构的 E2E Encryption 的基本流程。

![pic](/pic/2022/2022-02-22-kms-2.png)

1. Client A 向 KMS Server 请求一个未绑定的加密所需的秘钥（`Unbound Key`）。
2. Client A 通过第一步的 Unbound Key 去加密通信资源（`Communications Resource`）。
3. Client A 向 KMS Server 请求创建一个新的 KMS 资源对象（`KMS Resource Object`，简称 `KRO`），并且将第二步中的 Unbound Key 绑定到这个新的 KRO 上，这个时候这个 `Unbound Key` 就变成了 `Bound Key` 了。同时也授权 Client B 去获取这个 Bound Key 了。
4. Client B 向 KMS Server 请求这个 KMS Key，KMS Server 识别到 Client B 已经被授权，就会返回这个 KMS Key。
5. Client B 通过这个 KMS Key 就能够对 Resource Server 中加密的 `Communications Resource` 进行解密，这样就能达到了端到端加密的效果，只有 Client A 和 Client B 能够解开相应的加密的资源。

### KMS 协议

#### 用户身份识别

KMS Server 之所以称得上密钥存储的核心，是因为它能够将存储密钥信息的访问权限仅限于授权用户，这就需要有非常强壮的用户身份验证机制以及对每个用户进行明确和唯一标识的方法。

符合 KMS 架构的部署必然需要依赖于身份提供商（ `Identity Provider`，简称 `IDP`），IDP 是用来创建和管理个人或组织的用户身份和相关的身份属性的一种服务，目前大多数 IDP 都能够支持 [OAuth 2.0](https://datatracker.ietf.org/doc/pdf/rfc6749) 的身份验证及授权， KMS Server 必须依赖相同的 IDP 来验证从客户端接收到的访问令牌（Access token）。

客户端用来证明访问 KMS 资源的身份和授权的 Access token 不得用于任何其他服务，任何将 KMS 使用的 Access token 暴露给第三方（例如其他服务的提供商）都会危及所有 KMS 密钥的安全。此外，Access token 必须作为 KMS API 中 payload 的一部分传送给 KMS Server，这样 KMS Server 能够验证客户端是否已被授权，是否能够访问 KMS Server。

#### 对象类型

KMS 协议定义了三种对象类型：资源（Resources）、密钥（Keys）和授权（Authorizations）。 客户端与 KMS Server 就是通过创建和操作这些对象类型的实例进行交互的。

* 资源

资源是在 KMS 对象模型中标识的通信资源的对象。 密钥和用户授权与资源对象相关联（绑定）。

* 秘钥

密钥是一个对象，表示由 KMS 生成并提供给授权客户端的对称密钥。密钥可能存在于以下两种状态之一：“绑定” 和“未绑定”。 未绑定键不与任何资源相关联，而绑定键仅与一个资源相关联。

* 授权

授权是用户与特定资源的关联。 当用户和资源之间存在这种关联时，这意味着用户有权获取绑定到该资源的任何密钥，并有权为同一资源上的其他用户添加或删除授权。

#### 消息结构

* KMS 秘钥对象

KMS 秘钥对象的定义如下所示，使用了 Json 格式：

~~~
kmsUri (
  "uri" : uri relative
)
keyRep {
  kmsUri,
  "jwk" : jwk,
  "userId" : string,
  "clientId" : string,
  "createDate" : date-time,
  "expirationDate" : date-time,
  ?"resourceUri" : kmsUri,
  ?"bindDate" : date-time
}
key (
  "key" : keyRep
)
keys (
  "keys" : [ *keyRep ]
)
keyUris (
  "keyUris" : [ *kmsUri ]
)
~~~

**uri**: KMS 对象标识符的标准定义。

**userId**: 经过身份验证的用户的唯一标识符。

**clientId**: 创建秘钥的客户端提供的不透明的唯一标识符。

**bindData**: 标识秘钥被绑定的时间点。

* KMS 资源对象

KMS 资源对象的定义如下所示，使用了 Json 格式：

~~~
resourceRep {
  kmsUri,
  keys / keyUris,
  authorizations / authorizationUris
}
resource (
  "resource" : resourceRep
)
resources (
  "resources" : [ *resourceRep ]
)
resourceUris (
  "resourceUris" : [ *kmsUri ]
)
~~~

**keys**: 表示一组秘钥对象，每个秘钥都可以对应到一个绑定的资源。

**keyUris**: 一组秘钥对象标识符，这个对于授权用户而言，可以通过keyUri 找到对应的 key，也就是说 key 和 keyUri 是一一对应的，它们跟每个资源对象也是一一对应的。

**authorizations**: 一组授权对象的表示，每一个授权对象应用于一个资源的授权

#### KMS API 概述

##### 创建 KMS 资源

当 Client 打算开始通信资源的 E2E 加密时，它首先请求创建 KMS 资源对象。 这个 KMS Resource 在逻辑上表示 KMS 数据模型中的通信资源。Request 消息示例如下：

~~~
JWE(K_ephemeral, {
  "client": {
    "clientId": "android_a6aa012a-0795-4fb4-bddb-f04abda9e34f",
    "credential": {
      "bearer": "ZWU5NGE2YWYtMGE2NC0..."
    }
  }
  "method": "create",
  "uri": "/resources",
  "requestId": "10992782-e096-4fd3-9458-24dca7a92fa5",
  "authIds": [
    "b46e8124-b6e8-47e0-af0d-e7f1a2072dac",
    "39d56a84-c6f9-459e-9fd1-40ab4ad3e89a"
  ],
  "keyUris": [
    "/keys/b4cba4da-a984-4af2-b54f-3ca04acfe461",
    "/keys/2671413c-ab80-4f19-a0a4-ae07e1a94e90"
] })

~~~

创建KMS 资源对象的 Response 示例如下：

~~~
JWE(K_ephemeral, {
  "status": 201,
  "requestId": "10992782-e096-4fd3-9458-24dca7a92fa5",
  "resource": {
      "uri": "/resources/7f35c3eb-95d6-4558-a7fc-1942e5f03094",
      "authorizationUris": [
        "/authorizations/50e9056d-0700-4919-b55f-84cd78a2a65e",
        "/authorizations/db4c95ab-3fbf-42a8-989f-f53c1f13cc9a"
      ],
      "keyUris": [
        "/keys/b4cba4da-a984-4af2-b54f-3ca04acfe461",
        "/keys/2671413c-ab80-4f19-a0a4-ae07e1a94e90"
] }
})
~~~

##### 创建未绑定的秘钥

当 Client 需要对称密钥用于通信资源的 E2E 加密时，它首先会请求从 KMS 创建一个或多个密钥。 新创建的密钥的初始状态是 “未绑定”，因为它还不属于特定资源。 客户端可在通信资源存在之前随时提交此请求。Request 消息示例如下：

~~~
JWE(K_ephemeral, {
  "client": {
    "clientId": "android_a6aa012a-0795-4fb4-bddb-f04abda9e34f",
    "credential": {
      "bearer": "ZWU5NGE2YWYtMGE2NC0..."
    }
  }
  "method": "create",
  "uri": "/keys",
  "requestId": "10992782-e096-4fd3-9458-24dca7a92fa5",
  "count": 2
})
~~~

Response 示例如下：

~~~
JWE(K_ephemeral, {
  "status": 201,
  "requestId": "10992782-e096-4fd3-9458-24dca7a92fa5",
  "keys": [
    {
      "uri": "/keys/52100fa4-c222-46d0-994d-1ca885e4a3a2",
      "jwk": {
        "kid": "52100fa4-c222-46d0-994d-1ca885e4a3a2",
        "kty": "oct",
        "k": "ZMpktzGq1g6_r4fKVdnx9OaYr4HjxPjIs7l7SwAsgsg"
      }
      "userId": "842e2d82-7e71-4040-8eb9-d977fe888807",
      "clientId": "android_a6aa012a-0795-4fb4-bddb-f04abda9e34f",
      "createDate": "2014-10-09T15:54:48Z",
      "expirationDate": "2014-10-09T16:04:48Z"
}, {
      "uri": "/keys/fed33890-f9fa-43ad-a9f8-ab55a983a543",
      "jwk": {
        "kid": "fed33890-f9fa-43ad-a9f8-ab55a983a543",
        "kty": "oct",
        "k": "q2znCXQpbBPSZBUddZvchRSH5pSSKPEHlgb3CSGIdpL"
      }
      "userId": "842e2d82-7e71-4040-8eb9-d977fe888807",
      "clientId": "android_a6aa012a-0795-4fb4-bddb-f04abda9e34f",
      "createDate": "2014-10-09T15:54:48Z",
      "expirationDate": "2014-10-09T16:04:48Z"
} ]
})
~~~

对于这些未绑定的秘钥，每个秘钥的 resourceUri 属性都是未定义或者空的。

##### 更新秘钥（绑定状态）

为了开始使用未绑定的 KMS 密钥来保护通信资源，客户端将创建相应的 KMS 资源对象，然后将未绑定的密钥绑定到该资源。这里的 request 中引入了 resourceUri 属性表示秘钥要绑定到哪个KMS资源对象上。

~~~
JWE(K_ephemeral, {
     "client": {
       "clientId": "android_a6aa012a-0795-4fb4-bddb-f04abda9e34f",
       "credential": {
         "bearer": "ZWU5NGE2YWYtMGE2NC0..."
       }
     }
     "method": "update",
     "uri": "/keys/52100fa4-c222-46d0-994d-1ca885e4a3a2",
     "requestId": "10992782-e096-4fd3-9458-24dca7a92fa5",
     "resourceUri": "/resources/7f35c3eb-95d6-4558-a7fc-1942e5f03094"
})
~~~

Response 示例如下：

~~~
JWE(K_ephemeral, {
{
  "status": 200,
  "requestId": "10992782-e096-4fd3-9458-24dca7a92fa5",
  "key": {
    "uri": "/keys/52100fa4-c222-46d0-994d-1ca885e4a3a2",
    "clientId": "android_a6aa012a-0795-4fb4-bddb-f04abda9e34f",
    "jwk": {
      "kid": "52100fa4-c222-46d0-994d-1ca885e4a3a2",
      "kty": "oct",
      "k": "ZMpktzGq1g6_r4fKVdnx9OaYr4HjxPjIs7l7SwAsgsg"
    }
    "userId": "842e2d82-7e71-4040-8eb9-d977fe888807",
    "clientId": "android_a6aa012a-0795-4fb4-bddb-f04abda9e34f",
    "createDate": "2014-10-09T15:54:48Z",
    "bindDate": "2014-10-09T15:55:34Z",
    "expirationDate": "2014-10-10T15:55:34Z",
    "resourceUri": "/resources/7f35c3eb-95d6-4558-a7fc-1942e5f03094"
} })
~~~

在成功将以前未绑定的 KMS 密钥绑定到资源对象时，必须将 bindDate 反映为当前时间。 随后，KMS 必须将密钥视为绑定到由 resourceUri 标识的 KMS 资源对象，并且必须拒绝后续将相同密钥绑定到任何其他资源对象的请求。



### 参考阅读

[draft-abiggs-saag-key-management-service-02](https://datatracker.ietf.org/doc/html/draft-abiggs-saag-key-management-service-02)

