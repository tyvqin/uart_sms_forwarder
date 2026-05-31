# 鐭俊UART杞彂鍣?
鍩轰簬 鍚堝畽Air780 XXX 绯诲垪璁惧鐨勭煭淇¤浆鍙戠郴缁燂紝鏀寔鎺ユ敹鐭俊骞堕€氳繃涓插彛杞彂鍒颁笂浣嶆満銆?
[椤圭洰璇存槑](https://blog.typesafe.cn/posts/air780e-giffgaff/)

**宸叉祴璇曡澶?*

- Air780EHV
- Air780EHM
- Air780E (鍙互浣跨敤锛屼絾灞炰簬杩囨椂璁惧锛屼笉寤鸿璐拱)
- Air780EPV (鍙互浣跨敤锛屼絾灞炰簬杩囨椂璁惧锛屼笉寤鸿璐拱)


## 馃専 鍔熻兘鐗规€?
- 鐭俊杞彂
- 鐭俊璁板綍
- 鍙戦€佺煭淇?- 鏉ョ數閫氱煡
- 鏀寔閽夐拤銆佷紒涓氬井淇°€侀涔︺€佽嚜瀹氫箟 webhook銆侀偖绠遍€氱煡
- 璁″垝浠诲姟鍙戦€佺煭淇?
## 鎴浘

![screenshot1.png](screenshots/screenshot1.png)
![screenshot2.png](screenshots/screenshot2.png)

## 馃殌 蹇€熷紑濮?
### 1. 纭欢鍑嗗

**璁惧鍑嗗**锛?- 鎻掑叆鏈夋晥鐨凷IM鍗?- 閫氳繃USB杩炴帴鐢佃剳

### 2. 鐑у綍 Lua 鑴氭湰

浣跨敤 [**LuaTools**](https://docs.openluat.com/air780epm/common/Luatools/) 鐑у綍 `main.lua` 鑴氭湰锛岀涓€娆＄儳褰曢渶瑕佺偣鍑?銆屼笅杞藉簳灞傚拰鑴氭湰銆?
![write.png](screenshots/write.png)

### 3. 娴嬭瘯

![test.png](screenshots/test.png)

### 4. 鎶婅澶囨彃鍏ュ埌浣犵殑灏忎富鏈虹瓑 Linux USB涓?

### 5. 杩愯涓婁綅鏈虹▼搴?
#### docker 鏂瑰紡瀹夎

```shell
# 鍒涘缓绌虹洰褰?mkdir /opt/uart_sms_forwarder
# 涓嬭浇 docker-compose.yml 鏂囦欢
wget https://raw.githubusercontent.com/dushixiang/uart_sms_forwarder/main/docker-compose.yml -O /opt/uart_sms_forwarder/docker-compose.yml
# 涓嬭浇 config.example.yaml 鏂囦欢
wget https://raw.githubusercontent.com/dushixiang/uart_sms_forwarder/main/config.example.yaml -O /opt/uart_sms_forwarder/config.yaml
```

淇敼 `docker-compose.yml` 鍜?`config.yaml` 鏂囦欢锛屼富瑕佹槸鏄犲皠 USB 璺緞鍜屼慨鏀瑰瘑鐮併€?
鍚姩鏈嶅姟

```shell
docker-compose up -d
```

鎵撳紑娴忚鍣ㄨ闂?8080 绔彛銆?
----

#### 鍘熺敓鏂瑰紡瀹夎

涓嬭浇

```shell
wget https://github.com/dushixiang/uart_sms_forwarder/releases/latest/download/uart_sms_forwarder-linux-amd64.tar.gz
```

瑙ｅ帇
```bash
tar -zxvf uart_sms_forwarder-linux-amd64.tar.gz -C /opt/
mv /opt/uart_sms_forwarder-linux-amd64 /opt/uart_sms_forwarder
```

鍒涘缓绯荤粺鏈嶅姟

```shell
cat <<EOF > /etc/systemd/system/uart_sms_forwarder.service
[Unit]
Description=uart_sms_forwarder service
After=network.target

[Service]
User=root
WorkingDirectory=/opt/uart_sms_forwarder
ExecStart=/opt/uart_sms_forwarder/uart_sms_forwarder
TimeoutSec=0
RestartSec=10
Restart=always
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
```

鍒涘缓 sqllite 鐩綍

```shell
mkdir /opt/uart_sms_forwarder/data
```

鍚姩鏈嶅姟

```shell
systemctl daemon-reload
systemctl enable uart_sms_forwarder
systemctl start uart_sms_forwarder
```

鎵撳紑娴忚鍣ㄨ闂?8080 绔彛銆?
淇敼瀵嗙爜绛夐厤缃」锛岃鍙傝€?[config.example.yaml](config.example.yaml) 鏂囦欢銆?
## 澶氭ā鍧楅儴缃?
澶氫釜 Air780 妯″潡鍚屾椂鎺ュ叆鏃讹紝涓嶈渚濊禆 `/dev/ttyUSB0` 杩欑被浼氬彉鍖栫殑缂栧彿锛屼篃涓嶈璁╁涓繘绋嬭嚜鍔ㄦ娴嬩覆鍙ｃ€傛帹鑽愮粰姣忎釜 USB Hub 鐗╃悊鍙ｅ缓绔嬬ǔ瀹氳矾寰勶紝渚嬪 `/dev/serial/by-path/...` 鎴?udev 鍒悕锛?
```yaml
App:
  Serial:
    Devices:
      - ID: sim1
        Name: "SIM 1"
        Port: "/dev/air780/sim1"
        ExpectedICCID: ""
      - ID: sim2
        Name: "SIM 2"
        Port: "/dev/air780/sim2"
        ExpectedICCID: ""
```

閰嶇疆浜?`Devices` 鍚庯紝姣忎釜妯″潡浼氬惎鍔ㄧ嫭绔嬩覆鍙ｆ湇鍔★紝鐭俊鍙戦€併€侀琛屾ā寮忋€侀噸鍚€佺姸鎬佺紦瀛樺拰璁″垝浠诲姟閮戒細鎸?`deviceId` 鎸囧悜鎸囧畾妯″潡銆俙ExpectedICCID` 鍙€夛紝鐢ㄤ簬鍙戠幇 SIM 鍗℃彃閿欐垨 Hub 鍙ｇ粦瀹氶敊璇€?
### 鑷姩鍙戠幇

寮€鍚?`AutoDiscover` 鍚庯紝绋嬪簭鍚姩鏃朵細鎵弿 `/dev/serial/by-path/*`銆?`/dev/ttyACM*` 鍜?`/dev/ttyUSB*`锛屽彧淇濈暀鑳借繑鍥?`uart_sms_forwarder`
鍗忚鐨勪覆鍙ｏ紝骞舵寜 ICCID 缁戝畾妯″潡銆?
```yaml
App:
  Serial:
    AutoDiscover: true
    Devices:
      - ID: sim1
        Name: "SIM 1"
        ExpectedICCID: "ICCID_SAMPLE_1"
      - ID: sim2
        Name: "SIM 2"
        ExpectedICCID: "ICCID_SAMPLE_2"
```

寮€鍚?`AutoDiscover` 鍚庡彲浠ヤ笉鍐?`Port`銆傞厤缃鐨勬柊妯″潡浼氳嚜鍔ㄨ拷鍔犱负
`sim3`銆乣sim4` 绛夈€?
