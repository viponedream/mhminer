# mhminer



国内加密挖矿,矿池中转代理抽水软件  支持windows和ubuntu 20
也可到群里下载, QQ群: 140777161
电报群 https://t.me/+2vpGD-JpiEIxZDk9


#### 教学视频  https://www.youtube.com/watch?v=Yu3eOGwn2hU


##
## 可配套使用 -- 本地加密端(专业机建议使用)   https://github.com/viponedream/mhtunnel


###  已完成币种
###  eth - 使用eth协议的, 如ethw, ethf等
###  etc - 使用etc协议的
###  ethzil  etczil 
###  iron kas cfx rxd dnx alph nexa neox xmr tcc rvn ergo flux sero
###  grin pepew novo taft tcc clore skydoge
###  btc  zeph kls pyi fsc shui

### 关于新币, 比如今天新出一个币, octa, 它的算法跟已有的 eth一样, 则在coin中可以填 eth
### 同理, 出一个新币叫 argy, 它使用ghostrider, 那我们coin也可以填 taft (它们使用的是同一个算法,则通用)
### 其实兼容大部分币种, 币种随便填它会自动尝试, 大部分是可以中转的


##### 开发者抽水,  千1


##### ubuntu使用下面的一键脚本, windows的可以直接下载使用, 只须一个配置文件config.yml, 已经配置好了, 可改里面的抽水比例及抽水钱包, 不抽则改为0
##### ubuntu20 默认安装在 /root/mhminer下面,  win则随便你放哪都行.
##### 证书可以自己提供也可以使用默认的. cert.pem  key.pem这两个文件可以自己更换.

##### 矿机可选tcp, ssl, 矿池也可以选tcp, ssl 



&nbsp; 香港服务器上执行一键安装脚本 (ubuntu20)
```
bash <(curl -s -L https://raw.githubusercontent.com/viponedream/mhminer/main/scripts/inst_cn.sh)

```

&nbsp; 无法安装可以使用国内的镜像
```
bash <(curl -s -L https://down.minerhome.org/mhminer/scripts/inst_cn.sh )

```




mhminer 配置文件示例  config.yml,  不明白的地方不要改, 使用默认的即可.

```


global_proxy: ""      # 通用socks5代理, 如果矿池没有设置代理则使用这个代理, 如"127.0.0.1:8118", 如果安装在国内则一般要用代理


# 总在线矿机总数量限制
workers_limit: 1000
workers_limit_port: 1000    # 每个端口限制多少台矿机


monitor_config: true    # 监控此配置文件, 下面的端口信息更改,增加或删除或更改, 自动更新
monitor_port: true      # 监控端口异常退出, 异常退出则尝试重复开


# 证书, 亦可不提供使用默认的, 自己提供也行
# 默认放在软件同一个目录, 也可以放在其它目录, 如   /root/mhminer/cert.pem
cert: cert.pem
key: key.pem


servers:

  - name: IRON-英雄-tcp
    ip: 0.0.0.0:42280     # 给客人连接的端口, 前面固定为0.0.0.0
    ssl: false             # 给客人连接, 一般要开ssl
    coin: IRON            # 币种, 参数上面完成的
    pool: # 实际代理矿池
      ip: hk.ironfish.herominers.com:1145     # 英雄池的iron地址
      ssl: false                
    devfee: # 可开多个抽水, 可同池也可跨池
      - name: "测试一"
        worker_name: "devfee-1-1"
        fee_percent: 1     # 1%
        address: "你的钱包1"  #  改成你自己的钱包
        pool:  # 跨池抽
          ip: iron-asia.f2pool.com:1500
          ssl: false

  - name: IRON-英雄-ssl
    ip: 0.0.0.0:52280     # 给客人连接的端口, 前面固定为0.0.0.0
    ssl: true             # 给客人连接, 一般要开ssl
    coin: IRON            # 币种, 参数上面完成的
    pool: # 实际代理矿池
      ip: hk.ironfish.herominers.com:1145     # 英雄池的iron地址
      ssl: false                
    devfee: # 同池抽, 可多个抽水钱包
      - name: "测试一"
        worker_name: "devfee-1-1"
        fee_percent: 1     # 1%
        address: "你的钱包1"  #  改成你自己的钱包
      - name: "测试二"
        worker_name: "devfee-1-2"
        fee_percent: 0     # 0表示这个钱包不抽
        address: "你的钱包2"  #  改成你自己的钱包

  - name: 服务端解密 - 鱼池btc
    encrypt: true        # 服务端解密, 接收本地端发来的数据解密后再发给矿池
    ip: 0.0.0.0:50200    # 解密本地端发来的数据, 端口要对应
    coin: BTC
    pool:            
      ip:  btc-asia.f2pool.com:1314  #  鱼池的BTC地址
      ssl: false
    devfee: 
      - name: 抽水1                
        worker_name: "devfee-1-20230511"
        fee_percent: 1     # 1%
        address: "你的抽水钱包"  # 改成你自己的钱包


```

