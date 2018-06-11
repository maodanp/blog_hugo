---
categories:
- "技术志"
tags:
- machine learning
date: 2017-04-10
title: "机器学习之概率论"
mathjax: true
url: "/2017/04/10/probability"
---

本篇介绍概率统计相关知识，后续机器学习中朴素贝叶斯算法用到了其中贝叶斯的原理，在文本处理方便也有着广泛的应用。
<!--more-->

## 概率论基础

### 概率与直观

给定某正整数N，从1到N的所有数所对应的阶乘中，首位数字出现1的概率？

* 本福特定律/第一数字定律

实际生活中得出的一组数据中，以1位首位数字出现的概率**约为总数的三成**。
~~~
--------------------
| 数字  | 出现概率  |
| ----  | ----- |
| 1     | 30.1% |
| 2     | 17.6% |
| 3     | 12.5% |
| 4     | 9.7%  |
| 5     | 7.9%  |
--------------------
~~~

包括：

* 阶乘/素数数列/斐波那契数列首位
* 住在地址号码
* 经济数据反欺诈
* 选举投票反欺诈

### 贝叶斯公式

`$$
P(A|B) = \frac{P(B|A)P(A)}{P(B)}
$$`

* $P(A)$: 没有数据支持下，A发生的概率；先验概率（在B事件发生之前，我们对A事件的一个判断）
* $P(A|B)$: 在数据B的支持下，A发生的概率；后验概率（在B事件发生之后，我们对A事件的一个评估）
* $P(B|A)/P(B)$: 调整因子，使得预估概率更接近真实概率；似然函数

`$$
后验概率 = 先验概率 \times 调整因子
$$`

**我们先预估一个"先验概率"，然后加入实验结果，看这个实验到底是增强还是削弱了"先验概率"，由此得到更接近事实的"后验概率"。**



### 常见概率分布

* 0-1分布/两点分布/伯努利分布(离散)

分布律：

| X    | 1    | 0    |
| ---- | ---- | ---- |
| p    | p    | 1-p  |

则期望、方差分别为:
`$$
E(X) = 1*p + 0*q = p \\\\\\
D(X) = E(X^2) - [E(X)]^2 = pq
$$`

* 二项分布

设随机变量X服从参数为$n, p$的二项分布。

设$X_i$为第$i$次试验中时间A发生的次数，$i = 1,2,..., n$,则
`$$
X = \sum_1^nX_i
$$`
显然，$x_i$相互独立均服从参数为$p$的0-1分布

`$$
E(X) = \sum_1^nE(X_i) = np \\\\\\
D(X) = \sum_1^nD(X_i) = np(1-p)
$$`

* 泊松分布

设$X \sim \pi(\lambda)$，且分布律为:
`$$
P\{X=k\} = \frac{\lambda^k}{k!}e^{-\lambda}, k = 0,1,\ldots, \lambda \gt 0 \\\\\\
E(X) = \lambda  \\\\\\
D(X) = \lambda
$$`
其中，$\lambda$ 是单位时间内随机事件的平均发生率。

* 均匀分布(连续的分布)

设$X \sim U(a, b)$，其概率密度为：
`$$
f(x) =
\begin{cases}  
\frac{1}{b-a}, \qquad a \lt x \lt b\\\\\\
3n+1, \qquad otherwise
\end{cases}
$$`
则有
`$$
E(X) = \int_{-\infty}^{\infty}xf(x)dx=\int_{a}^b\frac{1}{b-a}xdx = \frac{1}{2}(a+b) \\\\\\
D(X) = E(X^2) - [E(X)]^2 = \int_{a}^bx^2\frac{1}{b-a}dx - [\frac{a+b}{2}]^2 = \frac{(b-a)^2}{12}
$$`

* 指数分布

设随机变量X服从指数分布，其概率密度为：
`$$
f(x) =
\begin{cases}  
\lambda e^{-\lambda x} \quad x \gt 0\\\\\\
0, \qquad  x \le 0
\end{cases}
\lambda \gt 0
$$`
则有
`$$
E(X) = \theta \\\\\\
D(X) = \theta^2
$$`
**指数分布的无记忆性**, 如果一个随机变量呈指数分布, 当$s, t \ge 0$，则有:
`$$
P(x \gt s+t | x \gt s) = P(x \gt t)
$$`

* 正态分布

设 $X \sim N(\mu, \theta^2)$, 其概率密度为:
`$$
f(x) = \frac{1}{\sqrt{2\pi}\sigma}e^{-\frac{(x-u)^2}{2\sigma^2}}, \sigma \gt 0, -\infty \lt x \lt +\infty
$$`
则有:
`$$
E(X) = \mu \\\\\\\
D(X) = \sigma^2
$$`

### Sigmoid/Logistic函数的引入

伯努利分布也属于指数族。
`$$
p(y;\phi) = \phi^y(1-\phi)^{1-y} \\\\\\
=exp(ylog\phi + (1-y)log(1-\phi)) \\\\\\
= exp((log(\frac{\phi}{1-\phi}))y+log(1-\phi))
$$`
The natural parameter is given by $\eta = log(\phi/(1-\phi))$, we obtain $\phi = 1/(1+e^{-\eta})$.

Sigmoid 函数$f(x) = \frac{1}{1+e^{-x}}$导数:
`$$
f'(x) = (\frac{1}{1+e^{-x}})'\\\\\\
=\frac{e^{-x}}{(1+e^{-x})^2} \\\\\\
=\frac{1}{1+e^{-x}}\frac{e^{-x}}{1+e^{-x}}\\\\\\
=\frac{1}{1+e^{-x}}[1 - \frac{1}{1+e^{-x}}]\\\\\\
=f(x) \times (1-f(x))
$$`

### 期望/方差/协方差/相关系数

* 事件的独立性

给定A和B两个时间，若有$P(AB) = P(A)P(B)$，则称事件A和B相互独立。

思考: 试给出A,B相互包含的信息量的定义$I(AB)$，要求:如果A,B独立，则$I(AB)=0$

* 期望

`$$
离散 \qquad E(X) = \sum_ix_ip_i \\\\\\
连续 \qquad E(X) = \int_{-\infty}^{\infty}xf(x)dx
$$`

无条件成立:
`$$
E(kX) = kE(X)\\\\\\
E(X+Y) = E(X) + E(Y)
$$`
若X,Y相互独立:
`$$
E(XY) = E(X)E(Y)
$$`
反之不一定成立。事实上，上式只能说明XY不相关。

* 方差

`$$
Var(X) = E{[X-E(X)] ^2} = E(X^2) - E^2(X)
$$`

无条件成立:
`$$
Var(c) = 0\\\\\\
Var(X+c) = Var(X)\\\\\\
Var(kX)=k^2Var(X)
$$`
若X,Y相互独立:
`$$
Var(X+Y) = Var(X) + Var(Y)
$$`
反之不一定成立。另外， 方差的平方根为标准差。

* 协方差

`$$
Cov(X, Y) = E\{[X-E(X)][Y-E(Y)]\}
$$`

性质:
`$$
Cov(X,  Y) = Cov(Y, X)\\\\\\
Cov(aX+b, cY+d) = acCov(X, Y)\\\\\\
Cov(X_1+X_2, Y) = Cov(X_1, Y)+Cov(X_2, Y)\\\\\\
Cov(X, Y) = E(XY) - E(X)E(Y)
$$`
如果X和Y独立时，$Cov(X, Y) = 0$; 但是如果$Cov(X, Y) = 0$, 我们称X和Y不相关。

意义: 协方差是两个随机变量具有相同方向变化趋势的变量的度量;

若$Cov(X, Y) \gt 0$, 它们的变化趋势相同;

若$Cov(X, Y) \lt 0$, 它们的变化趋势相反;

若$Cov(X, Y) = 0$, 它们不相关。

若X与Y不相关，说明X和Y之间没有线性关系(但是不能存在其他函数关系)，不能保证X和Y相互独立。

但是对于二位正太随机变量，X和Y不相关等价于X和Y相互独立。

* Pearson 相关系数

`$$
\rho_{xy} = \frac{Cov(X, Y)}{\sqrt{Var(X)Var(Y)}} \qquad |\rho| \le 1
$$`

当且仅当X与Y有线性关系时，等号成立。

* 协方差矩阵

对于n个随机向量$(X_1, X_2, \ldots, X_n)$, 任意两个元素$X_i,X_j$都可以得到一个协方差，从而形成$n\times n$的矩阵，协方差矩阵是对称阵。
`$$
Cov(X_i, X_j) =
\begin{pmatrix}
c_{11} & c_{12} & \cdots & c_{1n} \\\\\\
 c_{21} & c_{22} & \cdots & c_{2n} \\\\\\
\vdots & \vdots& \vdots & \ddots \\\\\\
 c_{n1} & c_{n2} & \cdots & c_{nn}
\end{pmatrix}
$$`

### 大数定律

* 切比雪夫不等式

设随机变量X的期望为$\mu$, 方差为$\sigma^2$，对于任意正数$\epsilon$，有:
`$$
P\{|X-\mu|\ge \epsilon\} \le \frac{\sigma^2}{\epsilon^2}
$$`

切比雪夫不等式说明，X的方差越小，事件$\{|X-\mu|\ge \epsilon\}$发生的概率就越大。即X取的值基本集中在期望附近。


* 大数定律

设随机变量$X_1, X_2,\ldots, X_n,\ldots$相互独立，并且具有相同的期望$\mu$和方差$\sigma^2$。取前n个随机变量的平均`$Y_n=\frac{1}{n}\sum_{i=1}^nX_i$`，则对于任意正数$\epsilon$,有:
`$$
lim_{n\to\infty}P\{|Y_n-u| \lt \epsilon\} = 1
$$`
当n很大时，随机变量$X_1, X_2,\ldots, X_n$的平均值$Y_n$在概率原因下无线接近期望$\mu$. 当n无限大时，出现偏离的可能性为0。

### 中心极限定理

设随机变量$X_1, X_2,\ldots, X_n,\ldots$互相独立，服从同一分布，并且具有相同的期望$\mu$和方差$\sigma^2$，则随机变量`$Y_n=\frac{1}{n}\sum_{i=1}^nX_i$`:
`$$
Y_n = \frac{\sum_{i=1}^nX_i-n\mu}{\sqrt{n}\sigma}
$$`
的分布收敛到**标准正态分布**。

且$\sum_{i=1}^nX_i$收敛到正态分布$N(n\mu, n\sigma^2)$。

### 最大似然估计

就是利用已知的样本结果信息，反推最具有可能（最大概率）导致这些样本结果出现的模型参数值！

**换句话说，极大似然估计提供了一种给定观察数据来评估模型参数的方法，即：“模型已定，参数未知”。**

设总体分布为$f(x,θ)$，且$X_1, X_2, \ldots, X_n$为该总体采样得到的样本。因为$X_1,X_2, \ldots, X_n$独立同分布，于是，它们的联合密度函数为:
`$$
L(x_1, x_2, \ldots, x_n; \theta_1, \theta_2, \ldots, \theta_k) =\prod_{i=1}^nf(x_i;  \theta_1, \theta_2, \ldots, \theta_k)
$$`
这里的$\theta$被看作模型固定但未知的参数。求参数$\theta$的值，使得似然函数取最大值，这种方法就只最大似然估计。

正态分布的最大似然估计：

过给定一组样本$X_1, X_2, \ldots, X_n$，已知他们来自于高斯分布$N(\mu, \sigma^2)$, 试估计参数$\mu, \sigma$.
`$$
\mu=\frac{1}{n}\sum_{i}x_i\\\\\\
\sigma^2 = \frac{1}{n}\sum_{i}(x_i-\mu)^2			
$$`

### 参考阅读

[贝叶斯推断及其互联网应用（一）：定理简介](http://www.ruanyifeng.com/blog/2011/08/bayesian_inference_part_one.html)

[一文搞懂极大似然估计](https://zhuanlan.zhihu.com/p/26614750)
