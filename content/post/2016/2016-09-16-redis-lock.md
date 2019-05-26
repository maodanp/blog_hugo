---
categories:
- "技术志"
date: 2016-09-16
title: "基于redis的分布式锁的实现方案"
url: "/2016/09/16/redis-lock"
---

在不同进程需要互斥的访问共享资源时，分布式锁是一种常用的技术手段。目前主要有几种解决方法，一种是借助于DB的事务来实现，另一种是借助于分布式键值存储系统(例如etcd, zookeeper等)实现。本篇主要介绍如何通过redis实现分布式锁。

<!--more-->

使用redis实现分布式锁也是常用的方案，因为本身redis在互联网产品应用中基本都会使用到，而且不用再依赖额外的etcd、zookeeper，另外相对于数据库事务实现的分布式锁，redis实现的性能相对来说会更高。

### 分布式锁的基本属性

* 互斥性：对于分布式锁来说，最基本的就是互斥性了，即不管在何时，只能有一个节点获得该锁
* 无死锁：拿到锁的节点挂掉了，没有释放锁，不会导致其它节点永远无法继续
* 高性能：分布式锁不能成为影响系统性能的瓶颈

### Redis单例实现分布式锁

我们可以通过单个Redis实例实现分布式锁机制，这也是后续Redis集群实现的基础。我们可以利用Redis的不同API实现锁，但大致思想都是类似的：

1. 获取当前时间，这里为更高的提供精度，可以设置为毫秒
2. 请求锁，实际就是向Redis中写入key(包括锁的**过期时间**)
3. 如果锁获取成功了，则返回成功
4. 如果锁获取失败了，则等待一定的时间(**重试时间**)，重新竞争锁资源
5. 如果超过一定的时间(**超时时间**) 还没有竞争到锁，则返回失败，后续是否继续获取锁由调用者决定。

上述步骤中引入这些时间是必要的，能够避免死锁问题。但是时间设定一般需要遵循以下的规则：

*`重试时间` < `过期时间` < `超时时间`*

#### SET实现方案

要获得锁，可以用下面这个命令： 

	SET key random_value NX PX 300

该命令的作用是在只有这个`key`不存在的时候才会设置这个`key`的值(`NX`选项的作用)，如果存在则不做任何动作直接返回；超时时间设为300毫秒(`PX`选项的作用).

这里`key`的值是`random_value`，这个值必须在所有获取锁请求的客户端里保持唯一。 基本上这个随机值就是用来保证能安全地释放锁，因为每个锁只能被获得锁的节点删除，如果被其他节点删除，而获得锁的节点任务还没完成，其他节点会再次获得该锁，这样就违背了锁的互斥性。

我们可以用下面的Lua脚本来实现锁的释放，保证获取锁与释放锁的节点是同一个。
~~~lua
if redis.call("get",KEYS[1]) == ARGV[1] then
        return redis.call("del",KEYS[1])
    else
        return 0
    end
~~~


`Lock()`方法的代码大致如下：
~~~go
func (r *RedisLock) Lock() (lock bool, err error) {
	until := time.Now().Add(r.TimeOut)
	for {
		// 大于超时时间，则返回超时
		if time.Now().Before(until) == false {
			return false, fmt.Errorf("timeout")
		}

		curTime := time.Now().UnixNano() / int64(time.Millisecond)
		conn := r.RedisPool.Get()
		// 过期时间
		reply, err := redis.String(conn.Do("SET", m.Name, curTime, "NX", "PX", int(r.Expiry/time.Millisecond)))
		conn.Close()
		if err != nil {
			goto LOCK_RETRY
		}
		if reply != "OK" {
			goto LOCK_RETRY
		}
		return true, nil
		
	LOCK_RETRY:
		//重试时间
		time.Sleep(r.Delay)
	}
	return
}
~~~

以上`Lock()`方法的实现还是相对简单的，其中`r.TimeOut`为该方法的超时时间，`r.Expiry`为该锁在Redis存储的过期时间，`r.Delay`为尝试获取锁的重试间隔。

#### LUA脚本实现方案

SET方案相当于将`SET`，`NX`，`PX`合成了一个步骤，并由Redis保证它们的原子性。当然，我们也可以采用`lua`脚本方式，保证三者的原子性。

~~~lua
var setScript = redis.NewScript(1, `
if redis.call("SET", KEYS[1], ARGV[1], "NX") == ARGV[1] then
	return redis.call("EXPIRE", KEYS[1], ARGV[2])
else
	return "ERR"
end`)
~~~

这样我们就可以使用如下代码代替上述的SET实现方案：
~~~go
reply, err := setScript.Do(conn, m.Name, curTime, int(r.Expiry/time.Millisecond))
~~~

#### SETNX+GET+GETSET 实现方案

`SET val NX PX expire`方式是**Redis2.6**之后的版本引入的。如果生产环境不支持该用法，或者没有意识到可以利用`LUA`脚本保证其原子性，那么是否还有其他的实现方式？

我们可以通过`SETNX`+`GET`+`GETSET`命令方式实现。主要步骤如下：

1. 调用`SETNX`命令，是否返回设置成功则表示获取了锁，未成功则进行后续操作
2. 调用`GET`命令，返回`valGet`. 将`当前时间`与`valGet`之差与`过期时间`比较，如果未达到过期时间，则sleep后重新尝试获取锁；如果大于过期时间了，则继续后续操作
3. 调用`GETSET`命令，设置新的当前时间，并且返回Redis中的值`valGetSet`。
4. 比较`valGet`与`valGetSet`，如果一致，则说明该节点获取了锁，如果不一致，则说明在该节点`GETSET`之前，已经被其他节点`GETSET`成功了(即表示其他节点获得了该锁)，则sleep后重新尝试获取锁

`Lock()`方法的代码大致如下：
~~~go
func (r *RedisLock) Lock() (lock bool, err error) {
	until := time.Now().Add(r.TimeOut)
	for {
		// timeOut
		if time.Now().Before(until) == false {
			return false, fmt.Errorf("timeout")
		}
		curTime := time.Now().UnixNano() / int64(time.Millisecond)
		succ, _ := r.cmdSetnx(r.Name, curTime)
		if succ {
			r.Value = curTime
			return true, nil
		}

		var valGet, valGetSet int64
		valGet, err = r.cmdGet(r.Name)
		// the lock is deleted when cmd GET returs err(nil returned)
		// so sleep and retry to run cmd SETNX
		// 锁已经被释放，则重新竞争
		if err != nil {
			goto LOCK_RETRY
		} else {
			// the lock is captured now
			// 锁还被占用着，如果锁未达到超时时间，则重新竞争
			if int64(r.Expiry/time.Millisecond) > curTime-valGet {
				goto LOCK_RETRY
			}
		}

		// the lock is timeout, so involve the race
		// 存储新的，返回旧的值
		valGetSet, err = r.cmdGetSet(r.Name, curTime)
		// the lock is deleted when cmd GETSET returs err(nil returned)
		// so sleep and retry to run cmd SETNX
		// 可能到这一步锁正好已经释放了，则重新竞争
		if err != nil {
			goto LOCK_RETRY
		}

		// haha, I get the lock!!
		// 如果GET的值与GETSET的值相等，则该协程获得了锁
		if valGet == valGetSet {
			r.Value = valGet
			return true, nil
		}

	LOCK_RETRY:
		time.Sleep(r.Delay)
	}
	return
}
~~~

以上为`SETNX`+`GET`+`GETSET`命令方式实现的`Lock()`方法，可以看到，相比于之前两种实现就稍微有些复杂了，需要考虑的地方较多。该方案的整体实现可以在我的[redislock](https://github.com/maodanp/redis-lock)中看到。

### Redis集群实现分布式锁

基于Redis单例的实现方式是一种理想的环境，对于一个非分布式的、单点的，保证永不宕机的环境而言，是没有任何问题的。但是在分布式环境中，如果假设有N个Redis master节点，又该如何实现分布式锁？

在Redis的官方文档中提供了官方的实现方案：[Redlock算法](https://github.com/antirez/redis-doc/blob/master/topics/distlock.md)。大体实现步骤如下：

1. 获取当前时间（单位是毫秒）
2. 轮流用相同的key和随机值在N个节点上请求锁，这一步相当于回归到了单节点获取锁的方式。如果一个master节点不可用了，我们应该尽快尝试下一个master节点。
3. 客户端计算第二步中获取锁所花的时间，只有当客户端在大多数master节点上成功获取了锁(N/2+1)，而且总共消耗的时间不超过锁释放时间，这个锁就认为是获取成功了
4. 如果锁获取成功了，那现在锁自动释放时间就是最初的锁释放时间减去之前获取锁所消耗的时间
5. 如果锁获取失败了，不管是因为获取成功的锁不超过一半(N/2+1)还是因为总消耗时间超过了锁释放时间，客户端都会到每个master节点上释放锁，即便是那些他认为没有获取成功的锁

关于Redis集群的实现方案可以参考Go语言[Redsync.go](https://github.com/hjr265/redsync.go)。官方文档也对安全性、可用性等做了论述，总体来说相对于DB的分布式锁实现应该还是具有很大的性能优势的，但是与etcd，zk的性能比较，这个还有待验证。

###  参考阅读

[dist-lock](https://github.com/antirez/redis-doc/blob/master/topics/distlock.md)

[dist-lock译文](http://ifeve.com/redis-lock/)

[基于Redis实现分布式锁](http://blog.csdn.net/ugg/article/details/41894947)
