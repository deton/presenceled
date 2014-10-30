# PresenceLed (出退表示LED)

会社で使われている在・不在スライド付きの名札掛を、
出勤時と退勤時に手で操作するのが面倒になったのと、たまに操作するのを忘れるので、
自席PCの電源が入っている間だけLEDを点滅表示するものを作りました。

[TWE-Lite](http://www.tocos-wireless.com/jp/products/TWE-Lite-DIP/)(ZigBee)を使用。
PC側にはUSB接続のToCoStickを刺しておいて、
名札掛の方にはTWE-Lite DIPを貼っておきます。

![画像](https://github.com/deton/presenceled/raw/master/PresenceLed.jpg)

## 動作
5分おきにTWE-Lite DIPからToCoStickに送信。
ACKが返ってくればToCoStickの電源が入っていると判断して、
LEDを3秒おきに一瞬(8ms)点灯。

## 電源
名札掛に貼り付けたいので、電池駆動(コイン電池CR2032)にしています。

本当は太陽電池で動かしたかったのですが、現場が暗め(150lux)のため、
3秒間隔のLED点灯がコンパクトには実現できず断念。
(5秒間隔なら行けそうでしたが、点滅しているか見たい時に少し待つ必要があるのと、
太陽電池が少し大きいので断念)

## 部品
* [TWE-Lite DIP](http://tocos-wireless.com/jp/products/TWE-Lite-DIP/)
* LED (低電流。太陽電池動作時は2.0V程度の場合もあるので赤色。鈴商で購入)
* 抵抗 10kΩ。太陽電池で動かそうとして、電流量を減らすため少し大きめ。
  LEDが少し暗め
* [CR2032型コイン電池ホルダ(表面実装型)](http://www.switch-science.com/catalog/47/)
* [ToCoStick (TWE-Lite USB)](http://tocos-wireless.com/jp/products/TWE-Lite-USB/)

## ソース
太陽電池で動かそうとして、最低限の機能にしています。

ソースはSamp_PingPongをベースにしていますが、
Samp_PingPongのソースはTOCOSの許可が無いと公開禁止との記述があって面倒なので、
差分のみ公開。
(差分を小さくするためSamp_Monitorから持ってきた電池電圧取得・送信処理は削除しています)。
[ToCoNet SDK](http://www.tocos-wireless.com/jp/products/ToCoNet/TWESDK.html) 2014/8月号に対する差分です。

以下のように、TWESDK/Wks_ToCoNet/ディレクトリでgenPresenceLed.shを実行すると、
PresenceLedディレクトリを作ります。
TWESDK/Tools/cygwin/Cygwin.batで起動したcygwinのプロンプト上で、
```sh
cd /cygdrive/d/TWESDK/Wks_ToCoNet
/cygdrive/c/Users/deton/Downloads/genPresenceLed.sh
```

* PresenceLed/PingPong/    ToCoStick側ソース。ほぼSamp_PingPongと同じ。
* PresenceLed/PresenceLed/ TWE-Lite DIP側ソース

PresenceLed/Common/Source/config.hのAPP_IDは、
ToCoStickのシリアル番号(S/N)+0x80000000に変更する必要あり。

makeコマンドでのビルドのみ確認(Eclipseでは未確認)。

## 送信失敗対策
送信失敗時は、通常の5分後の送信でなく、1秒後送信を行います。
それでも失敗する場合は待ち時間を倍にしながら(1秒、2秒、4秒、8秒)送信を行います。
ログを見ていると、待ち時間が8秒になるごろにはだいたい送信に成功している模様。

使用現場では、対策無しだと、3分おき送信で試している時は20回に1回は送信失敗。
現場環境は、2.4GHz帯が混雑しているのが原因かも。
WiFi APが10個以上見えていて、Bluetoothも5,6個見えていて、
WiFi接続のノートPCやスマホが20台以上はありそうな環境。

* 再送回数(u8TxMacRetry)を4回に増やしてもあまり変わらない印象(デフォルト3回)
* ToCoNetのチャネルアジリティ機能を使っても改善されない印象
* ToCoNetのENERGYSCAN機能を使って、空いているチャネルを調査して、
  空いていそうなチャネルにしてもあまり変わらない印象。

## 拡張案
* PCの電源が入っているかだけでなく、会議中等のプレゼンス情報を取得・表示
* LED点滅でなく[LCD](http://www.aitendo.com/product/6225)で情報表示
* 名札掛全体を電子化して全員分の情報取得・表示。
  各人の出退表示LEDを貼り付けることになると面倒なので。
* 電子ペーパー化して電源を切っても状態が保存されるようにする
* 元の名札掛のスライド板をモータ等で物理的にスライドさせる

## 参考: 太陽電池
太陽電池は以下のものを試しました。

結局、現場ではAM-1816CAであれば、
5分おき(warm boot,)通信と3秒おき(warm boot,)LED点灯は実現できました。
が、サイズが大きいので、太陽電池は断念してコイン電池に変更。

![AM-1816CA使用画像](https://github.com/deton/presenceled/raw/master/PresenceLedSolar.jpg)

(AM-1815CAであれば、5秒おきのcold boot・通信・LED点灯なら行けそうでしたが、
5秒おきだと、点滅しているか見たい時に少し待つ必要があるのでいまいち)。

[TWE-EH-S](http://tocos-wireless.com/jp/products/TWE-EH-S/)で
目安として挙げられているのは「開放電圧4V~6V、最大出力電力300mW以下」。

* AM-5815。TWE-EH-S推奨ソーラーパネル
  現場では50秒間隔での送信は可能。センサとして使うならこれで十分かも。
* 結晶系。屋内ではほとんど発電されないので使えず。
  [aitendo 5.5V/50mA](http://www.aitendo.com/product/7408),
  [switch-science 5V/40mA](http://www.switch-science.com/catalog/932/),
  [秋月電子通商 4.5V/65mA](http://akizukidenshi.com/catalog/g/gM-06564/)
* アモルファスシリコン系。屋内で使うため。
 * 千石電商で
   [PowerFilm](http://www.powerfilmsolar.com/products/oem-comparison-chart/)
   社のぺらぺらなものを何種類か購入。
   屋内の場合、問題なく使える日もあるが、全然駄目な日もあり。
   また、使えている日でも、夜になると使えなくなる。
   [SP4.2-37](http://www.sengoku.co.jp/mod/sgk_cart/detail.php?code=3CGN-SSMU),
   [MPT3.6-75](http://www.sengoku.co.jp/mod/sgk_cart/detail.php?code=5CFN-TSMT),
   [SP3-37](http://www.sengoku.co.jp/mod/sgk_cart/detail.php?code=8CFN-SSMP),
   [MP3-25](http://www.sengoku.co.jp/mod/sgk_cart/detail.php?code=EEHD-047P)。
   (MPT3.6-75は、明るいとしっかり出力があるが、少し暗いと使えない印象。
   同じ場所でもSP4.2-37ならOK。)
 * [BP-617K09](http://www.wakamatsu-net.com/cgibin/biz/pageshousai.cgi?code=39030015&CATE=3903) (若松通商)
   ガラスではないので扱いやすい印象。SC-3722-9と同程度。
 * [SC-3722-9](http://wingsolar.shop-pro.jp/?pid=34934897)
 * 屋内用を使わないと駄目なのかも、ということで屋内用を購入。
   ガラスなので取り扱いに少し気を使う。
   RSオンライン通販で[Panasonic](http://panasonic.net/energy/amorton/jp/products/index.html)のを何種類か購入。
   [AM-1805CA](http://jp.rs-online.com/web/p/photovoltaic-solar-panels/7600216/),
   [AM-1815CA](http://jp.rs-online.com/web/p/photovoltaic-solar-panels/6646778/),
   [AM-1816CA](http://jp.rs-online.com/web/p/photovoltaic-solar-panels/6646772/)。
   デンシ電気店通販:
   [SINONAR SS9719(3V/25uA)](http://www.denshi-trade.co.jp/ct/index.php?main_page=product_info&cPath=103_129_659&products_id=6559),
   [SINONAR SS-6728(5V/15uA)](http://www.denshi-trade.co.jp/ct/index.php?main_page=product_info&cPath=103_129_659&products_id=6558)。

## SMDタイプのTWE-Lite
最初は、
[SMDタイプのTWE-Lite](http://www.tocos-wireless.com/jp/products/TWE-001Lite.html)
で作ろうとして、直接LED等をはんだ付けしようとしたが難しくて、
パターンをはがしてしまったりしたので、
[DIPタイプのTWE-Lite](http://www.tocos-wireless.com/jp/products/TWE-Lite-DIP/)に変更。

![SMDタイプ画像](https://github.com/deton/presenceled/raw/master/PresenceLedSMD.jpg)

TWE-EH-S用や独自アプリ書き込み用の引き出し線もはんだ付けしたので見苦しくなってます。
手ごろなソケットがあったりしないかと思ったけど見つけられず、
ICテストクリップあたりを使うのがいいのかとも思ったり。
