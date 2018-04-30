---
categories:
- "技术志"
tags:
- machine learning
date: 2017-04-03
title: "机器学习之数学分析"
mathjax: true
url: "/2017/04/03/math-analysis"
---

本篇为机器学习中涉及的数学分析的概念，也是机器学习的基础。

<!--more-->
### 导数

#### 导数概念

* 简单而言，导数就是曲线的斜率，是曲线变化快慢的反应
* 二阶导数是斜率变化快慢的反应，表征曲线凸凹性

#### 常用函数的导数
`$$
(sinx)'=cosx \qquad (cosx)'=-sinx \\\\\\
(a^x)'=a^xlna \qquad (e^x)=e^x \\\\\\
(log_ax)'=\frac{1}{x}log_ae \qquad (lnx)'=\frac{1}{x} \\\\\\
(u+v)'=u'+v' \qquad (uv)'=u'v+uv'
$$`
#### 具体应用

* 已知函数$f(x)=x^x, x \gt 0$, 求$f(x)$的最小值
`$$
t=x^x \\\\\\
\to lnt=xlnx \\\\\\
 \stackrel {两边对x求导} \to \frac{1}{t}t'=lnx+1 \\\\\\
 \stackrel {t'=0} \to lnx+1=0 \\\\\\
 \to x=e^{-1}\\\\\\
 \to t=e^{-\frac{1}{e}}
$$`


* 当$N \to \infty$, $lnN!$ 值？
`$$
lnN!=\sum_{i=1}^Nlni \approx \int_{1}^Nlnxdx \\\\\\
=xlnx|_1^N-\int_{1}^Nxdlnx \\\\\\
=NlnN-\int_{1}^Nx \cdot \frac{1}{x}dx \\\\\\
=NlnN - N + 1 \to NlnN - N
$$`
### Taylor 公式-Maclaurin公式
`
$$
f(a+x) = f(a)+f'(a)x+o(x)
$$
`
其中，$o(h)$是比$h$高阶的无穷小。

Taylor公式可以把一个可导的函数拆成若干个多项式之和，当n越大，若干个多项式之和逼近于原函数的值
`$$
f(x)=f(x_0)+f'(x-x_0)+\frac{f''(x_0)}{2!}(x-x_0)^2+\ldots+\frac{f^{(n)}(x_0)}{n!}(x-x_0)^n+R_n(x) \\\\\\
f(x)=f(x_0)+f'(0)x+\frac{f''(x_)}{2!}(x)^2+\ldots+\frac{f^{(n)}(0)}{n!}(x)^n+o(x^n)
$$`

#### 具体应用

数值计算: 初等函数值的计算（在原点展开）
`$$
sin(x)=x-\frac{x^3}{3!}+\frac{x^5}{5!}-\frac{x^7}{7!}+\ldots+(-1)^{m-1}\cdot\frac{x^{2m-1}}{(2m-1)!}+R_{2m}\\\\\\
e^x=1+x+\frac{x^2}{2!}+\frac{x^3}{3!}+\ldots+\frac{x^n}{n!}+R_n
$$`


* 计算$e^x$

求整数k和小数r，使得 $x=k \cdot ln2 + r, |r|\lt0.5 \cdot ln2$
`$$
e^x=e^{k\cdot ln2+r} \\\\\\
=e^{k\cdot ln2}e^{r} \\\\\\
=2^k\cdot e^r
$$`

* Gini系数

考察Gini系数的图像、熵、分类误差率三者之间的关系。将$f(x)=-lnx$在$x=1$处一阶展开，忽略高阶无穷小，得到$f(x) \approx 1-x$.
`$$
H(x)=-\sum_{k=1}^Kp_klnp_k  \\\\\\ 
\approx \sum_{k=1}^Kp_k(1-p_k)
$$`

### 方向导数与梯度

#### 方向导数

如果函数$z=f(x,y)$在点$P(x,y)$是可微分的，那么函数在该点沿任一方向L的方向导数都存在，且有：
`$$
\frac{\partial f}{\partial l} = \frac{\partial f}{\partial x}cos \varphi + \frac{\partial f}{\partial y}sin \varphi
$$`
其中，$\varphi$ 为$x$轴到方向$L$的转角。

#### 梯度

设函数$z=f(x,y)$在平面区域D内具有一阶连续偏导数，则对于每一个点$P(x,y)\in D$,向量
`$$
(\frac{\partial f}{\partial x}, \frac{\partial f}{\partial y})
$$`
为函数$z=f(x,y)$在点P的梯度，记做$gradf(x,y)$。

* 梯度的方向是函数在改点变化最快的方向
* 梯度下降法

### 组合数与信息熵关系

#### 组合数

* 把$n$个物品分成$k$组，使得每组物品的个数分别为$n_1, n_2,\ldots,n_k$,$(n=n_1+n_2+\ldots+n_k)$,则不同的分组方法有$\frac{n!}{n_1! \cdot n_2! \cdot n_3! \ldots n_k!}$种。


* 上述的简化版本，即n个物品分成2组，第一组m个，第二组$n-m$个，则分组方法有: $\frac{n!}{n! \cdot (n-m)!}$，即 ${n \choose m}$。

#### 组合数背后的秘密

`$$
\begin{align}
H
&=\frac{1}{N}ln\frac{N!}{\prod_{i=1}^kn_i!}\\
&=\frac{1}{N}ln(N!)-\frac{1}{N}\sum_{i=1}^kln(n_i!) \\
&\to (lnN-1)-\frac{1}{N}\sum_{i=1}^kn_i(lnn_i-1) =lnN-\frac{1}{N}\sum_{i=1}^kn_ilnn_i\\
&=-\frac{1}{N}((\sum_{i=1}^kn_ilnn_i)-NlnN) =-\frac{1}{N}\sum_{i=1}^k(n_ilnn_i-n_ilnN)\\
&=-\frac{1}{N}\sum_{i=1}^k(n_iln\frac{n_i}{N})=-\sum_{i=1}^k(\frac{n_i}{N}ln\frac{n_i}{N}) \\
&\to -\sum_{i=1}^k(p_ilnp_i)
\end{align}
$$`



### 参考阅读

[如何直观形象的理解方向导数与梯度](https://www.zhihu.com/question/36301367)

[多元函数微分学](https://wenku.baidu.com/view/5dfb0b5a16fc700aba68fc1f.html)

[梯度下降小结](https://www.cnblogs.com/pinard/p/5970503.html)

