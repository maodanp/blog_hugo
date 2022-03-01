---
categories:
- "技术志"
tags:
date: 2020-09-15
title: "SAML 标准协议解读"
url: "/2020/09/15/SAML"
---

SAML（`Security Assertion Makrup Language`）全称是`安全断言标记语言`，是一种基于 XML 格式的开放标准的协议，用于在不同的安全域之间进行身份认证。

<!--more-->
### SAML 简介

#### SAML 是什么

SAML 主要用于在不同的安全域（身份提供者 - `Identity Provider` 和 服务提供者 - `Service Provider`）之间进行身份认证（`Authentication`）和数据授权（`Authorization`）的一种协议，它可以用来传输安全的声明，比如：两台远程机器之间要通信，为了保证安全性可以采用加密的协议，也可以使用 SAML 来传输，两台机器可以不要求采用的是什么系统，只要能理解 SAML 规范即可。

SAML 全称中有两个关键词：安全、断言。就是说 SAML 是用安全的方式表达断言的一种语言。

* `断言`：就是做出判断的语言，SAML 结构中主要的内容就是为了证明登录的用户是谁（Authentication），拥有什么权限（Authorization）。
* `安全`：别人有可能假冒你提供的一个断言从而骗取 SP (Service Provider) 以便窃取资源，那 SP 为什么会信任你的断言呢？为了防止断言被人篡改，SAML 中加入了安全措施，通过给断言加上签名和加密，再结合数字证书系统就能够确保 SAML 不受攻击了。

#### SAML 优势

SAML 的一个非常重要的应用就是基于 Web 的单点登录（`SSO`）。使用 SAML 可以保证系统安全性，我们只需要向 Idp 提供用户名密码即可，而且通过基于 SAML 的SSO 技术，用户不需要记住多个系统的用户名和密码，只用一个就够了。



### SAML 工作流程

下图就是 SAML 的一种工作流程，图中共有三个角色：SP（服务提供者）、Idp（认证用户并生成断言）、Browser（client，就是用户）。

![pic](/pic/2020/2020-09-15-saml-1.png)

用户的用户名、密码信息都会存在 Idp 服务器中，它会认证你就是你，也会告诉你有哪些服务授权。而且 SP 和 Idp 是被各自域管理员设置为相互信任的，就是说双方都持有对方的公钥。当用户一开始访问 SP 提供的某个服务时，不带有任何认证信息，这个时候 SP 并不认识你，于是就会有下面的认证和授权步骤：

**步骤一**：你去访问 SP 的某个受保护资源，比如浏览器打开： 

~~~http
http://sp.company.com/myresource
~~~

**步骤二**：SP 并没有找到相应的有效安全上下文，没有认证信息，当然不能给你对应的页面资源。 它就会生成一个 SAMLRequest 的认证请求数据包，并将 Browser 重定向到 Idp：

~~~
302 Redirect
Location: https://idp.company.com/SAML2/SSO/Redirect?SAMLRequest=request&RelayState=token
~~~

其中这个 SAMLRequest 就是用 Base64 编码的 samlp:AuthnRequest。以下截取某网站的 SAMLRequest:

~~~html
<samlp:AuthnRequest  
    xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"
    ID="s2f6b9a86faddd8e7550f8871f3143f133708e16f8" 
    Version="2.0" IssueInstant="2022-02-27T14:10:48Z" 
    Destination="https://idp.company.com/idp/SSO.saml2" 
    ForceAuthn="false" IsPassive="false" 
    ProtocolBinding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" 
    AssertionConsumerServiceURL="https://sp.company.com/...">
    <saml:Issuer 
        xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion">https://sp.company.com/..
    </saml:Issuer>
    <samlp:NameIDPolicy  
        xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"  
        Format="urn:oasis:names:tc:SAML:2.0:nameid-format:transient" 
        SPNameQualifier="https://sp.company.com/1eb65fdf-9643-417f-9974-ad72cae0e10f" 
        AllowCreate="true">
    </samlp:NameIDPolicy>
    <samlp:Scoping xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol" ProxyCount="0">
    <samlp:IDPList  xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol">
    <samlp:IDPEntry xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol" ProviderID="idp.company.com">
    </samlp:IDPEntry>
    </samlp:IDPList>
    </samlp:Scoping>
</samlp:AuthnRequest>
~~~

**步骤三、四**：Idp 也需要认证你就是你， 于是返回给你一个认证的页面， 可能使用用户名密码认证，也可以使用其它的认证方式，idp保存有你的用户名和密码。

**步骤五**：Idp 在认证你之后，如果觉得你输入的用户名、密码都是合法的， 就为你生成一些断言， 证明你是谁，你有什么权限等等。 并用自己的私钥签名。 然后包装成一个 response 格式，放在 form 表单里返回给你（Browser）。XHTML form 表单如下：

~~~html
<form method="post" action="https://sp.flydean.com/SAML2/SSO/POST" ...>      
  <input type="hidden" name="SAMLResponse" value="<samlp:Response>..</samlp:Response>" />      
  <input type="hidden" name="RelayState" value="token" />       
  ...      
  <input type="submit" value="Submit" />  
</form>
~~~
SAML Response 的语句大致如下
~~~html
<samlp:Response
    xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"
    xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
    ID="identifier_2"
    InResponseTo="identifier_1"
    Version="2.0"
    IssueInstant="2020-09-05T09:22:05Z"
    Destination="https://sp.company.com/SAML2/SSO/POST">
    <saml:Issuer>https://idp.company.com/SAML2</saml:Issuer>
    <samlp:Status>
      <samlp:StatusCode
        Value="urn:oasis:names:tc:SAML:2.0:status:Success"/>
    </samlp:Status>
  
    <saml:Assertion
      xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
      ID="identifier_3"
      Version="2.0"
      IssueInstant="2020-09-05T09:22:05Z">
      <saml:Issuer>https://idp.company.com/SAML2</saml:Issuer>
      <!-- a POSTed assertion MUST be signed -->
      <ds:Signature
        xmlns:ds="http://www.w3.org/2000/09/xmldsig#">...</ds:Signature>
      
      <saml:Subject>
        <saml:NameID
          Format="urn:oasis:names:tc:SAML:2.0:nameid-format:transient">
          3f7b3dcf-1674-4ecd-92c8-1544f346baf8
        </saml:NameID>
        <saml:SubjectConfirmation
          Method="urn:oasis:names:tc:SAML:2.0:cm:bearer">
          <saml:SubjectConfirmationData
            InResponseTo="identifier_1"
            Recipient="https://sp.company.com/SAML2/SSO/POST"
            NotOnOrAfter="2020-09-05T09:27:05Z"/>
        </saml:SubjectConfirmation>
      </saml:Subject>
      
      <saml:Conditions
        NotBefore="2020-09-05T09:17:05Z"
        NotOnOrAfter="2020-09-05T09:27:05Z">
        <saml:AudienceRestriction>
          <saml:Audience>https://sp.company.com/SAML2</saml:Audience>
        </saml:AudienceRestriction>
      </saml:Conditions>
      
     <saml:AuthnStatement
        AuthnInstant="2020-09-05T09:22:00Z"
        SessionIndex="identifier_3">
        <saml:AuthnContext>
          <saml:AuthnContextClassRef>
            urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport
         </saml:AuthnContextClassRef>
        </saml:AuthnContext>
     </saml:AuthnStatement>
      
     <saml:AttributeStatement>
      <saml:Attribute
       xmlns:x500="urn:oasis:names:tc:SAML:2.0:profiles:attribute:X500"
       x500:Encoding="LDAP"
       NameFormat="urn:oasis:names:tc:SAML:2.0:attrname-format:uri"
       Name="urn:oid:1.3.6.1.4.1.5923.1.1.1.1"
       FriendlyName="eduPersonAffiliation">
       <saml:AttributeValue
         xsi:type="xs:string">member</saml:AttributeValue>
       <saml:AttributeValue
         xsi:type="xs:string">staff</saml:AttributeValue>
      </saml:Attribute>
     </saml:AttributeStatement>
      
    </saml:Assertion>
  </samlp:Response>
~~~

其中 Authnstatement 认证语句表示你认证成功了。subject 表示你是谁。而Attributestatement 表示你有哪些属性。 还有一个授权语句上面例子中没有。

**步骤六**：这个 form 被 JavaScript 自动提交给 SP。

**步骤七**：SP 读到 form 提交上来的断言（Assertion）。 并通过 idp 的公钥验证了 Assertion 的签名。 于是信任了这个 Assertion， 知道你是idp的合法用户了。 所以就最终给你返回了你最初请求的页面了。 


如果在**步骤一**中，Browser 带有认证信息，比如对于 OAuth2.0 而言，带有 self-contained Access token，SP 收到这个请求之后会就不需要问 Idp 这个人是谁，是否有访问该资源的权限。而是只要通过解密 Access token 中的签名 Hash 信息，就能通过认证与授权，将 Resource 直接返回给用户。当然，这个 Access token 是有时效性的，通常是几个小时，通常情况下 Client 会在 Access token 快过期的时候，提前通过 Refresh token 去交换一个新的 Access Token, 这样新的 Access token 有会有几小时的有效期，而 Refresh token 本身的有效期通常达到几十天。



### SAML 标准结构

![pic](/pic/2020/2020-09-15-saml-2.png)


SAML 标准从内到外，可以分为上图的 4 个层次：

#### Assertions

 断言。 规定了断言的xml结构，它规定了这个 assertion 节点该怎么写，也就是这个节点的 scheme。它里面由一个或者多个语句组成：

~~~html
   <saml:Assertion
      <saml:Subject> ... </saml:Subject>
      <saml:Conditions>...</saml:Conditions>
      <saml:AuthnStatement>...</saml:AuthnStatement>
      <saml:AttributeStatement>...</saml:AttributeStatement>
      ...
    </saml:Assertion>
~~~

#### Protocols

协议。定义了如何请求和回复 SAML 消息。它规定了怎么发送，回复消息的格式，这样不同域的服务器才能通信。

#### Bindings

绑定。规定了怎么样传输 SAML 的协议，这里规定了如何在 http 上或者 SOAP 上传输 SAML 的协议数据包。只要 SAML 消息本身是完整的可靠的，用什么协议传输不重要。SAML 标准规定的绑定只是一种标准实现，SAML 消息可以绑定到任何协议上，只要 SP 和 Idp 协商好就行了。 

#### Profiles

配置或者称之为解决方案。它规定了某些场景下一整套 SAML 认证的细节和步骤。比如，它规定了比较著名的SSO方案。就是如何用 SAML 实现 SSO 的一整套配置和详细步骤。规定了 ECP（Enhanced Client and Proxy）Profile 等等。


### 参考阅读

[SAML2.0 初探](https://www.cnblogs.com/flydean/p/14129755.html)

[我眼中的SAML](https://www.cnblogs.com/flydean/p/14129755.html)

[SAML tech overview](https://www.oasis-open.org/committees/download.php/11511/sstc-saml-tech-overview-2.0-draft-03.pdf)

[RFC755-SAML for OAuth 2.0 Client Authentication and Authorization Grants](https://datatracker.ietf.org/doc/html/rfc7522)