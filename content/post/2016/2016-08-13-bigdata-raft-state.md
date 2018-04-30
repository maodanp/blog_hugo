---
categories:
- "技术志"
tags:
- 分布式存储
date: 2016-08-13
title: "分布式存储之Raft协议应用详解"
url: "/2016/08/13/bigdata-raft-state"
---


最近研究Raft协议，也阅读了[go-raft](https://github.com/goraft/raft)的实现代码，虽然已经不维护了，但**etcd**, **InfluxDB**等项目前期都是使用的该库，还是很有工程上的参考价值。本篇针对[论文](http://files.catwell.info/misc/mirror/raft/raft.pdf)与实现过程作简要的分析, 并分析了Raft的容错处理。

<!--more-->

### Raft节点状态数据

下图为每个Raft节点保存的一些状态信息：

![](http://7xt5nc.com1.z0.glb.clouddn.com/pic/2016/2016-08-13-bigdata-raft-state-1.png)

大致解释为：

| 状态 | **所有节点**保存的持久化数据 |
| ------------ | ------------- | 
| **currentTerm** |  最新任期数，第一次启动时为0，单调递增的 |  
| **voteFor** |  当前任期内，本节点投票目标节点 |
|  **log[]** |  日志项：每一项包含状态机命令，以及从**Leader**接收到的该日志项的任期 |  

| 状态 | **所有节点**非持久化数据 |
| ------------ | ------------- | 
| **commitIndex** | 已经提交的最高日志项的编号（默认从0开始，单调递增） |  
| **lastApplied** | log中最高的日志项的编号（默认从0开始，单调递增） |


| 状态 | **Leader节点**的可变状态(选举后会重置) |
| ------------ | ------------- | 
| **nextIndex[]** | 对于每一个服务器，需要发送给他的下一个日志项的索引值（初始化为领导人最后索引值加一）  |  
| **matchIndex[]** |  对于每一个服务器，已经复制给它的日志的最高索引值 |

在定义节点的状态信息时，在**goraft**的状态信息与论文中的有些差异，**goraft**中状态信息总结如下：

| 状态 | **所有节点**保存的持久化数据 |
| ------------ | ------------- | 
| **commitIndex** |  最新任期数，第一次启动时为0，单调递增的 |  
| **Peer[]** |  集群中其他节点信息 |
|  **log[]** |  日志项(同上)|

| 状态 | **所有节点**非持久化数据 |
| ------------ | ------------- | 
| **currentTerm** |  最新任期数，第一次启动时为0，单调递增的 |  
| **voteFor** |  当前任期内，本节点投票目标节点 |

| 状态 | **Leader节点**的可变状态(选举后会重置) |
| ------------ | ------------- | 
| **prevLogIndex** |  **Leader节点**会维护一个**Peer[]**，存储集群中其他节点信息。其中每个节点信息中**prevLogIndex**表示上一次**leader**复制给它的最高索引编号 |  

**goraft**中并没有将**currentTerm**作为持久化数据保存，因为已经保存了**log[]**, 而每个**log entry**中都包含term信息，每次server重启是，都会获取最后一个**log entry**中的term作为当前term，所以**currentTerm**不需要存储。

### Raft的RPC

**Raft**的核心部分使用两个RPC进行节点间通信： **RequestVote**和**AppendEntries**:

* **RequestVote** RPC: 由candidate发送给其他节点，请求其他节点为自己投票，如果一个candidate获得了多数节点的投票，则该candidate转变为Leader
* **AppendEntries** RPC: 由Leader节点发送给其他节点，有两个作用，当其entries域为空时，该RPC作为Leader的心跳，当entries域不为空时，请求其他节点将其中的log添加到自己的log中

#### AppendEntries RPC

以下为**AppendEntries RPC**的格式和说明:

![](http://7xt5nc.com1.z0.glb.clouddn.com/pic/2016/2016-08-13-bigdata-raft-state-2.png)

从以上**AEs(AppendEntries RPC)**的请求、响应格式说明可以看到，Raft对于实现细节有非常清晰的界定与描述。对于RPC接受者的实现主要有以下几种情况：

* 如果 term < currentTerm 就返回 false
* 如果日志在 prevLogIndex 位置处的日志项的任期号和 prevLogTerm 不匹配，则返回 false
* 如果已经已经存在的日志项和新的产生冲突（相同Index但是term不同），删除这一条和之后所有的
* 附加任何在已有的日志中不存在的项
* 如果 leaderCommit > commitIndex，令 commitIndex 等于 leaderCommit 和 最新日志项索引值中较小的一个

**goraft**中的**AEs RPC**处理过程基本遵循上述处理流程，对应中的主要代码段如下：
~~~go
 func (s *server) processAppendEntriesRequest(req *AppendEntriesRequest){

      //如果AppendEntries请求的term小于该server当前term
      //返回失败
      if req.Term < s.currentTerm {
          s.debugln("server.ae.error: stale term")
          return false
      }

      if req.Term == s.currentTerm {

          // 当server处于candidate状态，则降为follower
          if s.state == Candidate {
              s.setState(Follower)
          }

      } else {
     
          // term 比 目前的大，则有新的leader产生
          // 更新 term 以及 leader
          s.updateCurrentTerm(req.Term, req.LeaderName)
      }

      // 将req.PrevLogIndex 编号后的log entry都删除了
      if err := s.log.truncate(req.PrevLogIndex, req.PrevLogTerm); err != nil {
          return false
      }

     // 加入该server节点的 log entries
      if err := s.log.appendEntries(req.Entries); err != nil {
          return false
      }

      // 提交至req.CommitIndex
      if err := s.log.setCommitIndex(req.CommitIndex); err != nil {
          s.debugln("server.ae.commit.error: ", err)
          return true
      }
      return true;
  }
~~~
**Leader**对于 **AppendEntries RPC Response**的处理流程:

* 如果在response中，有term大于当前leader的term，则当前leader角色转变为follower
* 如果收到大多数节点的**AEs**成功回应，后续会判断下次的提交编号，否则返回
* Leader根据大多数节点返回的上次log的索引编号，来决定这次提交的编号， 该提交编号将在下次随**AEs RPC**传给follower

~~~go
func (s *server) processAppendEntriesResponse(resp *AppendEntriesResponse) {
 
      // 如果发现AppendEntries的返回中term较大，则角色变为follower
      // 这个判断非常重要，能够保证网络分区恢复后的一致性
      if resp.Term() > s.Term() {
          s.updateCurrentTerm(resp.Term(), "")
          return
      }

      // 对于回应返回成功的，更新map表
      if resp.append == true {
          s.syncedPeer[resp.peer] = true
      }

      if len(s.syncedPeer) < s.QuorumSize() {
          return
      }

      // 计算此次需要提交的编号
      var indices []uint64
      indices = append(indices, s.log.currentIndex())
      for _, peer := range s.peers {
          indices = append(indices, peer.getPrevLogIndex())
      }
      sort.Sort(sort.Reverse(uint64Slice(indices)))

      commitIndex := indices[s.QuorumSize()-1]
      committedIndex := s.log.commitIndex

      if commitIndex > committedIndex {
          s.log.sync()
          s.log.setCommitIndex(commitIndex)
      }
  }
~~~

#### RequestVote RPC

以下为**RequestVote RPC**的格式和说明:

![](http://7xt5nc.com1.z0.glb.clouddn.com/pic/2016/2016-08-13-bigdata-raft-state-3.png)

对于**RequestVote RPC**接受者的处理流程：

* 如果term < currentTerm返回 false
* 如果votedFor为空或者就是candidateId，并且候选人的日志也自己一样新，那么就投票给它

**goraft**中的**RequestVote RPC**处理过程主要代码段如下：

~~~go

func (s *server) processRequestVoteRequest(req *RequestVoteRequest){

      // term小于当前的，则返回false
      if req.Term < s.Term() {
          s.debugln("server.rv.deny.vote: cause stale term")
		  return false
      }

      // 如果请求的term大于该节点的term，则更新该节点的term
      // 如果term相等，且我们已经投给了其他候选节点(votedFor参数),则不投给该候选节点candidate
      // 即一个任期内只投给一个候选节点，但是可以投多次（可能存在网络异常，候选节点再次发出投票请求）
      if req.Term > s.Term() {
          s.updateCurrentTerm(req.Term, "")
      } else if s.votedFor != "" && s.votedFor != req.CandidateName {
          return false
      }

      // 如果candidate中最新日志项编号小于 当前server的最新日志项编号，则不投票
      // 这里满足了Raft的安全性：必须要比大部分其它候选者的log新，才有机会成为leader
      lastIndex, lastTerm := s.log.lastInfo()
      if lastIndex > req.LastLogIndex || lastTerm > req.LastLogTerm {
          return false
      }

      s.votedFor = req.CandidateName

      return true
  }

~~~

**Candidate**对于**RequestVote RPC Response**的处理流程:

~~~go

 func (s *server) candidateLoop() {
	  //处于 Candidate 状态，直到状态改变为leader或者follower
	  //否则超时后再次发起投票请求     
      for s.State() == Candidate {

          if doVote {
              //自增term
              s.currentTerm++
              s.votedFor = s.name

              // 向每个servers发送 RequestVote RPCs
              respChan = make(chan *RequestVoteResponse, len(s.peers))
              for _, peer := range s.peers {
                  s.routineGroup.Add(1)
                  go func(peer *Peer) {
                      defer s.routineGroup.Done()
                      peer.sendVoteRequest(newRequestVoteRequest(s.currentTerm, s.name, lastLogIndex, lastLogTerm), respChan)
                  }(peer)
              }

              //发起请求后的变量初始化
              votesGranted = 1
              timeoutChan = afterBetween(s.ElectionTimeout(), s.ElectionTimeout()*2)
              doVote = false
           }

           //如果收到超过半数以上的投票支持，则状态变为leader
           if votesGranted == s.QuorumSize() {
              s.setState(Leader)
              return
           }

          select {
          //处理收到RequestVote RPC回应
          case resp := <-respChan:
              if success := s.processVoteResponse(resp); success {
                  s.debugln("server.candidate.vote.granted: ", votesGranted)
                  votesGranted++
              }
          //如果选举超时，则继续选举    	
          case <-timeoutChan:
              doVote = true
       }
~~~

### Raft的failure处理

Raft关于容错的处理是需要考虑的方面。主要的异常包括**Leader crash**、**Follower crash**、**Network Partition**等。

* **Leader crash**

**Leader crash**需要考虑**crash**后，log中未被提交的数据是否属于**脏数据**。 这个需要分多种情况考虑。(a) 客户端将某条**log entry**发送给**Leader**后**crash**；(b) **Leader**将**log entry**发送给**Follower**后**crash**，(3)**Leader**提交了该**entry**后**crash**等等。

对于情况(1)而言，该命令是未添加成功的(该命令在原leader中当做**脏数据**，将等待新**Leader**的覆盖)，客户端将超时后采取重试机制重新发送该命令，将会被新选举出的**Leader**处理。

对于情况(2)而言，该命令算添加成功么？这个有需要分情况了：

（a）如果大多数节点多收到了，添加到了各自的**log entries**中，那么此次添加算成功的。根据Raft的安全性原则，新选举出来的leader一定是包最新log的，并且新选出来的**leader**，term号一定大于上一轮的term。那么当新的日志提交以后，之前的commit就被间接地提交了；

(b) 如果只有少部分**Follower**添加到了各自的**log entries**中，那就存在该日志被覆盖的情况，要看新选出的**Leader**是否包含这条日志了。

下图为情况(2)中(a)的情形，即大多数节点都**AppendEntries**了，根据Raft安全性原则，后续的**Leader**在*F_1*或者*F_2* 中产生，那么 “Hello”命令也间接被提交了。

![](http://7xt5nc.com1.z0.glb.clouddn.com/pic/2016/2016-08-13-bigdata-raft-state-4.png)

对于情况(3)，类似于情况(2)中的(a)。

* **Follower crash**

**Follower crash**比较简单，主要是**crash**恢复后怎么保持log与**Leader**的一致性。具体如图示，*F_4*恢复后，怎么保持数据一致？

![](http://7xt5nc.com1.z0.glb.clouddn.com/pic/2016/2016-08-13-bigdata-raft-state-5.png)

在之前**节点状态数据**中我们看到，每个**节点**中会维护一个**Peer[]**, 存放集群中的节点信息。其中就有一个**prevLogIndex**，用于维护上一次该**Follower**最新添加的log的索引号。如果 *F_4* 恢复了，**Leader**中维护的**prevLogIndex=1**，后续将从索引2开始的所有**log entries**发送给 *F_4* 。

* **Network Partition**

**Network Partition**网络分区会导致**脑裂问题**，即每个分区都会出现一个**Leader**。这种情况随着分区的恢复，Raft很快能够恢复集群的一致性。

下图为网络分区的一种情形，其中*le_1* 为原来的**Leader**， *le_2*为分区二新选举出的**Leader**（**term**比分区一的大)。

![](http://7xt5nc.com1.z0.glb.clouddn.com/pic/2016/2016-08-13-bigdata-raft-state-6.png)

对于图中的**分区一**，由于通信的节点不满足大多数节点（这里假设没有机制去变化整个集群总共的节点数量），所以向该分区中添加的日志都不能提交，客户端将一直收到超时的回复。而对于**分区二**，满足提交的条件，该分区中的日志都能够被正常提交。

待分区恢复，*le_1*由于term小于*le_2*，则自动转为Follower状态，如下图所示，最终能够实现一致性。

![](http://7xt5nc.com1.z0.glb.clouddn.com/pic/2016/2016-08-13-bigdata-raft-state-7.png)

下图为网络分区的另一种情形，*le_1* 分区占有了大部分节点，能够正常的提交日志。但是**分区二**中的两个**Follower**节点，由于选票个数未过半，将持续处于**Candidate**状态，直到网络恢复。

![](http://7xt5nc.com1.z0.glb.clouddn.com/pic/2016/2016-08-13-bigdata-raft-state-8.png)

由于**分区二**的竞选，导致term不停增加，网络分区恢复后，集群中的term号会随着**leader**的**AppendEntries RPC**（参见**processAppendEntriesResponse**函数），将term一起同步到最新。

虽然Raft易于理解，但是工程实践还是需要考虑到各种异常情况。通过代码的阅读，也能够更加理解其背后的原理。

### 参考阅读

[In Search of an Understandable Consensus Algorithm](http://files.catwell.info/misc/mirror/raft/raft.pdf)

[https://github.com/goraft/raft](https://github.com/goraft/raft)

[从raft看failure的处理](http://www.tuicool.com/articles/aERnm2U)


