---
categories:
- "技术志"
tags:
- machine learning
- 线性回归
- 正则化
date: 2017-05-20
title: "机器学习之线性回归"
mathjax: true
url: "/2017/05/20/linear-regression"
---

回归是监督学习中的一个重要问题，用于预测输入变量（自变量）和输出变量（因变量）之间的关系，回归模型正是表示从输入变量到输出变量之间映射的函数。

<!--more-->

## 线性回归

回归问题的学习等价于函数拟合：选择一条函数曲线使其很好地拟合已知数据且很好地预测未知数据。

回归问题分为**学习**和**预测**两个过程，学习系统基于训练数据构建一个模型，预测系统根据学习的模型确定对应的输出。

回归问题按照输入变量的个数分为**一元回归**和**多元回归**；按照输入变量和输出变量之间的类型，分为**线性回归**和**非线性回归**。

* 最大似然估计解释MLE（最小二乘法）

假设
$y^{(i)} = \theta^Tx^{(i)} + \epsilon^{(T)}$
其中误差$\epsilon^{(i)}(1 \le i \le m)$是独立同分布的，服从均值为0，方差为某定值$\theta^2$的**高斯分布**.

`$$
p(\epsilon^{(i)})=\frac{1}{\sqrt{2\pi}\sigma}exp(-\frac{(\epsilon^{(i)})^2}{2\sigma^2}) \\
p(y^{(i)}|x^{(i)};\theta)=\frac{1}{\sqrt{2\pi}\sigma}exp(-\frac{(y^{(i)}-\theta^Tx^{(i)})^2}{2\sigma^2}) \\
L(\theta) = \prod_{i=1}^m\frac{1}{\sqrt{2\pi}\sigma}exp(-\frac{(y^{(i)}-\theta^Tx^{(i)})^2}{2\sigma^2}) \\
$$`

`$$
\begin{align}  
lnL(\theta) 
&= log\prod_{i=1}^m\frac{1}{\sqrt{2\pi}\sigma}exp(-\frac{(y^{(i)}-\theta^Tx^{(i)})^2}{2\sigma^2}) \\
&=\sum_{i=1}^mlog\frac{1}{\sqrt{2\pi}\sigma}exp(-\frac{(y^{(i)}-\theta^Tx^{(i)})^2}{2\sigma^2}) \\
&=mln\frac{1}{\sqrt{2\pi}\sigma}-\sum_{i=1}^m\frac{(y^{(i)}-\theta^Tx^{(i)})^2}{2\sigma^2}
\end{align}  
$$`

则代价函数可以表示为:
`$$
J(\theta) = \frac{1}{2}\sum_{i=1}^m(h_\theta(x^{(i)})-y^{(i)})^2
$$`

* 目标函数求最小值—解析式求解

前面解析出目标函数为:
`$$
J(\theta) = \frac{1}{2}\sum_{i=1}^m(h_\theta(x^{(i)})-y^{(i)})^2=\frac{1}{2}(X\theta-y)^T(X\theta-y)
$$`
梯度:
`$$
\begin{align}
\nabla{J(\theta)} 
&= \nabla{[\frac{1}{2}(X\theta-y)^T(X\theta-y)]} \\
&=\nabla{[\frac{1}{2}(\theta^TX^T-y^T)(X\theta-y)]} \\
&= \nabla{\frac{1}{2}(\theta^TX^TX\theta - \theta^TX^Ty - y^TX\theta+y^Ty)} \\
&= \frac{1}{2}(2X^TX\theta - X^Ty - (y^TX)^T) = X^TX\theta-X^Ty
\end{align}
$$`

令偏导数为0, 得到参数的最优解:$\theta = (X^TX)^{-1}X^Ty$

若$X^TX$ **不可逆**或者防止**过拟合**，$\theta = (X^TX + \lambda{I})^{-1}X^Ty$

### 目标函数求最小值—梯度下降法

* 初始化$\theta$（随机初始化）

* 沿着负梯度方向迭代，更新后的$\theta$,使得$J(\theta)$更小, 其中，$\alpha$ 为学习率，步长.
  `$$
  \theta = \theta - \alpha \cdot \frac{\partial J(\theta)}{\partial \theta}
  $$`

* 梯度方向为:
  `$$
  \begin{align}
  \frac{\partial J(\theta)}{\partial \theta_j} 
  &= \frac{\partial}{\partial \theta_j} \frac{1}{2}(h_\theta(x) - y)^2 \\
  &=2 \cdot \frac{1}{2}(h_\theta(x) - y) \cdot \frac{\partial}{\partial \theta_j}(h_{\theta}(x)-y) \\
  &=(h_{\theta}(x)-y) \cdot \frac{\partial}{\partial \theta_j}(\sum_{i=0}^n\theta_ix_i-y)\\
  &=(h_{\theta}(x)-y)x_j
  \end{align}
  $$`

### 正则化方法

线性回归的目标函数为:
`$$
J(\theta) = \frac{1}{2}\sum_{i=1}^m(h_\theta(x^{(i)})-y^{(i)})^2
$$`
正则化项(regularizer)或罚项(penalty term)一般是模型复杂度的单调递增函数，模型越复杂，则正则化值就越大。正则化项可以是模型参数向量的范数，一般形式:
`$$
min \frac{1}{N}\sum_{i=1}^NL(y_i, f(x_i)) + \lambda{J(f)}
$$`
其中第1项是**经验风险**，第2项是**正则化项**。$\lambda$为调整两者之间关系的系数。第1项的经验风险较小的模型可能较为复杂(有多个非零参数，或者参数较大)，这时第2项的模型复杂度会较大。

> 正则化的作用是选择经验风险与模型复杂度同时较小的模型

Lasso将目标函数加入平方和损失（L1正则化）:
`$$
J(\theta) = \frac{1}{2}\sum_{i=1}^m(h_\theta(x^{(i)})-y^{(i)})^2 + \lambda \sum_{j=1}^n\theta_j^2
$$`
Ridge将目标函数加入平方和损失（L2正则化）:
`$$
J(\theta) = \frac{1}{2}\sum_{i=1}^m(h_\theta(x^{(i)})-y^{(i)})^2 + \lambda \sum_{j=1}^n|\theta_j|
$$`
Elastic Net:
`$$
J(\theta) = \frac{1}{2}\sum_{i=1}^m(h_\theta(x^{(i)})-y^{(i)})^2 + \lambda_1  \sum_{j=1}^n|\theta_j| +\lambda_2 \sum_{j=1}^n\theta_j^2
$$`
回归正则化方法在高纬和数据集变量之间多重共线性情况下运行良好。

* L1与L2正则区别

L1与L2的区别在于，L1正则是拉普拉斯先验，而L2正则则是高斯先验。它们都是服从均值为0，协方差为$\frac{1}{\lambda}$。当$\lambda=0$时，即没有先验，没有正则项，则相当于先验分布具有无穷大的协方差，那么这个先验约束则会非常弱，模型为了拟合所有的训练集数据， 参数$w$可以变得任意大从而使得模型不稳定，即方差大而偏差小。$\lambda$越大，表明先验分布协方差越小，偏差越大，模型越稳定。即，加入正则项是在**偏差bias**与**方差variance**之间做平衡tradeoff。

L1会趋向于产生少量的特征，而其他的特征都是0，而L2会选择更多的特征，这些特征都会接近于0。Lasso在特征选择时候非常有用，而Ridge就只是一种规则化而已。

* 奥卡姆剃刀原理

正则化符合奥卡姆剃刀原理：在所有可能选择的模型中，能够很好的解释一种数据并且十分简单才是最好的模型，也就是应该选择的模型；从贝叶斯角度看，正则化项对应于模型的先验概率，可以假设负责的模型有较大的先验概率，简单的模型有较小的先验概率。

* 总结

正则项是为降低模型的复杂度，从而避免模型过分拟合x训练数据，包括噪声与异常点。

另一角度上讲，正则化即是假设模型参数服从先验概率，即为模型参数添加先验，只是不同的正则化方式的先验分布是不一样的，这样就规定了参数的分布，使得模型的复杂度降低。还有个解释便是，从贝叶斯学派来看：加了先验，在数据少的时候，先验知识可以防止过拟合；从频率学派来看：正则项限定了参数的取值，从而提高了模型的稳定性，而稳定性强的模型不会过拟合，即控制模型空间。 

另外一个解释，规则化项的引入，在训练（最小化cost function）的过程中，当某一维的特征所对应的权重过大时，而此时模型的预测和真实数据之间距离很小，通过规则化项就可以使整体的cost function取较大的值，从而，在训练的过程中避免了去选择那些某一维（或几维）特征的权重过大的情况，即过分依赖某一维（或几维）的特征（引用知乎）。 


### 交叉验证

———————————————————————————————————

|———训练数据->$\theta$———|———验证数据->$\lambda$———|———测试数据———|

———————————————————————————————————

训练数据集: 用该集合中的数据计算参数$\theta$；

验证数据集：$\lambda$ 无法通过计算获得，为了计算 $\theta$所引入的新的参数(超参数)；通过计算出的一组$\theta$，通过比较cost function, 找到一个最优的$\theta$，比较同一model不同参数的**优劣**；

测试数据集: 用于比较model的优劣，比如线性回归model1, 决策树model2, **比较不同model的优劣**。

CV—>$\lambda$—>$\theta$—>$\hat y$

如果给定样本数据充足，进行选择的一种简单方法是随机将数据集切分成三部分，在学习到的不同复杂度的参数对应模型中，选择对验证集有最小预测误差的模型，由于验证集有足够多的数据，用它对模型进行选择也是可以的。

但是实际应用中数据是不充足的，为了选择好的模型可以采用交叉验证的方法。交叉验证的基本思想是重复的使用数据；把给定的数据进行切分，将切分的数据集组合为训练集与测试集，在此基础上反复进行训练、测试以及模型选择。该过程也是为了选择出泛化能力强的模型。

* 简单交叉验证
* S折交叉验证

首先随机将数据切分成S个互不相交的大小相同的子集；然后利用S-1个子集数据训练模型，利用余下的自己测试模型；将这一过程对可能的S中选择重复进行；最后选出S次评测中平均测试误差最小的模型。

* 留一交叉验证

S折交叉验证的特殊形式S=N。

### 梯度下降算法

* 批量梯度下降算法（batch gradient descent）

`$$
\begin{align}
Repeat \quad until\quad  convergence \{ \\
& \theta_j := \theta_j + \alpha\sum_{i=1}^m(y^{(i)}-h_\theta(x^{(i)}))x_j^{(i)}\\
&\}
\end{align}
$$`

我们每一轮的参数迭代更新都用到了所有的训练数据，如果训练数据非常多的话，是**非常耗时的**。

* 随机梯度下降算法（stochastic gradient descent）

`$$
\begin{align}
Repeat\{ \\
 &for \quad i=1 \quad to \quad m, \{ \\
&   \theta_j := \theta_j + \alpha (y^{(i)}-h_\theta(x^{(i)}))x_j^{(i)} \\
&\} \\
\}
\end{align}
$$`

随机梯度下降是通过每个样本迭代更新一次，对比上面的BGD，迭代一次需要用到所有训练样本。SGD伴随的一个问题是噪音较BGD要多，使得SGD并不是每次迭代都向着整体最优化方向。 但大体上是往最优值方向移动的。

* 折中梯度下降算法（min-batch gradient descent）

如果不是每拿到一个样本即更改梯度，而是若干个样本的平均梯度作为更新方向，则是mini-batch梯度下降算法。


### 统计意义下的参数

*  Model v.s. Parameter

ML/DL 实际可以分为两个问题: What and How.

1) **What**: 根据数据(Data)选择模型(Model), 选择模型是**重点**

2) **How**: 如何选择模型(Model)的参数($\theta$). SGD/BGD/牛顿法

* 统计意义下的参数

对于m个样本$(x_1, y_1), (x_2, y_2),\cdots,(x_m, y_m)$，某模型的估计值为$(x_1, \hat y_1), (x_2,\hat  y_2),\cdots,(x_m, \hat y_m)$。

1) 样本总平方和TSS (Total Sum of Squares): $TSS = \sum_{i=1}^m(y_i - \overline y)$

2) 残差平方和RSS (Residual Sum of Squares): $RSS = \sum_{i=1}^m(\hat y_i - y_i)$

3) 定义$R^2 = 1-RSS/TSS$, $R^2$越大，拟合效果越好。

### 参考阅读

[Gradient Descent](http://freemind.pluskid.org/machine-learning/gradient-descent-wolfe-s-condition-and-logistic-regression/)

[防止过拟合的处理方法](http://blog.csdn.net/heyongluoyao8/article/details/49429629)

[机器学习中正则化项L1和L2的直观理解](https://blog.csdn.net/jinping_shi/article/details/52433975)



