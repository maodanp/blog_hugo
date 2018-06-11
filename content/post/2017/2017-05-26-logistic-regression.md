---
categories:
- "技术志"
tags:
- machine learning
- Logistic回归
date: 2017-05-26
title: "机器学习之Logistic回归"
mathjax: true
url: "/2017/05/26/logistic-regression"
---

分类是监督学习中的一个重要问题，当输出变量Y取有限个离散值时，预测问题便成为分类问题。此时的X可以是离散的或者连续的。

<!--more-->

## Logistic回归

### 背景与定义

分类问题包括学习和分类两个过程。在学习过程中，根据已知的训练数据集利用有效的学习方法学习一个分类器；在分类过程中，利用学习的分类器对新的输入实例进行分类。

评价分类器性能的指标一般是分类准确率,即对于给定的测试数据集，分类器正确分类的样本数与总样本数之比。

~~~
-------------------------------------------------------
|                   | Actual class 1 | Actual class 0 |
| ----------------- | -------------- | -------------- |
| Predicted class 1 |        TP      |       FP       |
| Predicted class 0 |        FN      |       TN       |
-------------------------------------------------------
~~~

精确率定义为：
`$$
P = \frac{TP}{TP+FP}
$$`
召回率定义为：
`$$
R = \frac{TP}{TP+FN}
$$`
此外还有$F_1$值，是精确率与召回率的调和均值。
`$$
\frac{2}{F_1} = \frac{1}{P}+\frac{1}{R} \\
F_1 = \frac{2TP}{2TP+FP+FN}
$$`

在Logistic regression二分类问题中，我们可以使用sigmoid函数将输入$Wx+b$映射到$(0,1)$区间中，从而得到属于某个类别的概率。将这个问题进行泛化，推广到多分类问题中，可以使用**softmax**函数，对输出的值归一化为概率值。

#### 交叉熵

说交叉熵之前先介绍相对熵，相对熵又称为KL散度（Kullback-Leibler Divergence），用来衡量两个分布之间的距离，记为$D_{KL}(p||q)$
`$$
\begin{align}
D_{KL}(p||q)=
\sum_{x\in X}p(x)log\frac{p(x)}{q(x)} \\ 
=\sum_{x\in X}p(x)logp(x)-\sum_{x\in X}p(x)logq(x) \\ 
=-H(p) - \sum_{x\in X}p(x)logq(x)
\end{align}
$$`
其中$H(p)$是$p$的熵。

假设有两个$p$和$q$，它们在给定样本集上的交叉熵定义为：
`$$
CE(p,q)=-\sum_{x\in X}p(x)log q(x) = H(p) +D_{KL}(p||q)
$$`
从这里可以看出，交叉熵和相对熵相差了$H(p)$，而当$p$已知的时候，$H(p)$是个常数，所以交叉熵和相对熵在这里是等价的，反映了分布$p$和$q$之间的相似程度

对于一个样本来说，真是类标签分布与模型预测的类标签分布可以用交叉熵来表示：
`$$
l_{CE}=-\sum_{i=1}^Ct_ilog(y_i)
$$`
该等式与对数似然函数形式一样.

最终，对于所有的样本，有以下损失函数：
`$$
L = -\sum_{k=1}^n\sum_{i=1}^Ct_{ki}log(y_{ki})
$$`
其中，`$t_{ki}$`是样本$k$属于类别$i$的概率, $y_{ki}$是模型对样本$k$预测为属于类别$i$的概率。


### Logistic回归

* Logistic/sigmoid 函数

`$$
h_{\theta}(x) = g(\theta^Tx) = \frac{1}{1+e^{-\theta^Tx}} \\
g'(x) = (\frac{1}{1+e^{-x}})'=\cdots=g(x)\cdot(1-g(x))
$$`

* Logistic回归参数估计

假定:
`$$
P(y=1|x;\theta) = h_{\theta}(x) \\
P(y=0|x;\theta) = 1- h_{\theta}(x) \\
P(y|x;\theta) = (h_{\theta}(x))^y (1-h_{\theta}(x))^{1-y}
$$`
对数似然函数:
`$$
\begin{align}
L(\theta) 
&= \prod_{i=1}^mp(y^{(i)}|x^{(i)};\theta) \\
&= \prod_{i=1}^m(h_\theta(x^{(i)}))^{y^{(i)}}(1-h_\theta(x^{(i)}))^{1-y^{(i)}} 
\end{align}
$$`

`$$
l(\theta) = lnL(\theta) = \sum_{i=1}^my^{(i)}logh(x^{(i)})+(1-y^{(i)})log(1-h(x^{(i)}))
$$`

`$$
\begin{align}
\frac{\partial l(\theta)}{\partial \theta_j} 
&= \sum_{i=1}^m[\frac{y^{(i)}}{h(x^{(i)})} - \frac{1-y^{(i)}}{1-h(x^{(i)})}]\cdot\frac{\partial h(x^{(i)})}{\partial \theta_j} \\
&= \sum_{i=1}^m[\frac{y^{(i)}}{h(x^{(i)})} - \frac{1-y^{(i)}}{1-h(x^{(i)})}]\cdot\frac{\partial g(\theta^Tx^{(i)})}{\partial \theta_j} \\
&= \sum_{i=1}^m[\frac{y^{(i)}}{h(x^{(i)})} - \frac{1-y^{(i)}}{1-h(x^{(i)})}]\cdot h(x^{(i)}) \cdot (1-h(x^{(i)}))\frac{\partial \theta^Tx^{(i)}}{\partial \theta_j} \\
&=\sum_{i=1}^m(y^{(i)}(1-g(\theta^Tx^{(i)}))-(1-y^{(i)})g(\theta^Tx^{(i)}))\cdot x_j^{(i)} \\
&=\sum_{i=1}^m(y^{(i)} - g(\theta^Tx^{(i)}))\cdot x_j^{(i)}
\end{align}
$$`

* Logistic交叉熵损失函数

交叉熵损失函数公式：
`$$
J(\theta)=-\frac{1}{m}\sum_{i=1}^{m}y^{(i)}\log(h_\theta(x^{(i)}))+(1-y^{(i)})\log(1-h_\theta(x^{(i)})),
$$`
以及$J(\theta)$的参数$\theta$的偏导数（用于诸如梯度下降法等优化算法的参数更新），如下：
`$$
\frac{\partial}{\partial\theta_{j}}J(\theta) =\frac{1}{m}\sum_{i=1}^{m}(h_\theta(x^{(i)})-y^{(i)})x_j^{(i)}
$$`

- **logistic回归（是非问题）**中，$y^{(i)}$取0或者1；
- **softmax回归（多分类问题）**中，$y^{(i)}$取1,2…k中的一个表示分类标号的一个数。

### Softmax回归

* softmax函数定义

一直模型输出有$C$个值，其中$C$是要预测的类别数，模型可以是全连接网络的输出$a$, 即输出为$a_1, a_2,…,a_C$。对于每个样本，它属于类别$i$的概率为：
`$$
y_i = \frac{e^{a_i}}{\sum_{i=1}^Ce^{a_k}} \quad \forall i \in 1...C
$$`
上式中$\sum_{i=1}^Cy_i=1$ 保证了属于各个类别的概率和为1

* softmax函数求导

对softmax函数进行求导，即求$\frac{\partial y_i}{\partial a_j}$

$e^{a_i}$分两对$a_j$求导分情况讨论：

1. 如果$i=j$，则求导结果为$e^{a_i}$
2. 如果$i \ne j$，则求导结果为0

当$i=j$时：
`$$
\frac{\partial y_i}{\partial a_j}=\frac{e^{a_i}\sum - e^{a_i}e^{a_j}}{\sum^2}=\frac{e^{a_i}}{\sum}\frac{\sum-e^{a_j}}{\sum}=y_i(1-y_j)
$$`
当$i \ne j$时：
`$$
\frac{\partial y_i}{\partial a_j}=\frac{0-e^{a_i}e^{a_j}}{\sum^2}=-\frac{e^{a_i}}{\sum}\frac{e^{a_j}}{\sum}=-y_iy_j
$$`


* 交叉熵损失函数求导

对单个样本来说，loss function对输入$a_j$的导数为：
`$$
\frac{\partial l_{CE}}{\partial a_j}= -\sum_{i=1}^C\frac{\partial t_ilog(y_i)}{\partial a_j} =  -\sum_{i=1}^Ct_i\frac{1}{y_i}\frac{\partial y_i}{\partial a_j}
$$`
将求导结果带入：
`$$
-\sum_{i=1}^Ct_i\frac{1}{y_i}\frac{\partial y_i}{\partial a_j}=-\frac{t_i}{y_i}\frac{\partial y_i}{\partial a_i}-\sum{}_{i \ne j}^C\frac{t_i}{y_i}\frac{\partial y_i}{\partial a_j} \\ 
=-t_j+t_jy_j+\sum_{i \ne j}^Ct_iy_j = -t_j + \sum_{i =1}^Ct_iy_j \\
=-t_j + y_i\sum_{i=1}^Ct_i = y_j - t_j
$$`

* 梯度下降法表示

与线性回归的参数估计一样，可以将批量梯度下降法表示如下：
`$$
\begin{align}
Repeat \quad until\quad  convergence \{ \\
& \theta_j := \theta_j + \alpha\sum_{i=1}^m(y^{(i)}-h_\theta(x^{(i)}))x_j^{(i)}\\
&\}
\end{align}
$$`
随机梯度下降法表示如下：
`$$
\begin{align}
Repeat\{ \\
 &for \quad i=1 \quad to \quad m, \{ \\
&   \theta_j := \theta_j + \alpha (y^{(i)}-h_\theta(x^{(i)}))x_j^{(i)} \\
&\} \\
\}
\end{align}
$$`
其中:
`$$
h_\theta(x)=
\begin{cases}
\theta^Tx, &\text{linear regression} \\[2ex]
\frac{1}{1+e^{-\theta^Tx}}, &\text{logistic regression}
\end{cases}
$$`

## 参考阅读

[交叉熵代价函数及其推导](http://blog.csdn.net/jasonzzj/article/details/52017438)

[Softmax函数与交叉熵](https://zhuanlan.zhihu.com/p/27223959)



