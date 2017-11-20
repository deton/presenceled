# PresenceEpd (出退勤表示電子ペーパー)

会社で使われている行動予定表の出退勤表示マグネットの位置を、
出勤時と退勤時に手で操作するのが面倒なのと、たまに操作するのを忘れるので、
自席PCの電源が入っているかどうかに応じて
電子ぺーパーの表示内容を切り替えるものを作りました。

(参考:これまで作った同様のもの:
[LED点滅での表示](..)(ぱっと見わかりにくい)、
[サーボモータでの表示](https://github.com/deton/syuttaikin)(時々マイコンがハングアップしてて安定しない)、
[Androidスマホでの表示](https://github.com/deton/syuttaikinBoard)(時々Wi-Fiが切断されたままになる))

[TWELITE](https://mono-wireless.com/jp/products/TWE-Lite-DIP/index.html)を使用。
PC側にはUSB接続のMONOSTICKを刺しておいて、
行動予定表の方にはTWELITE DIPを貼っておきます。

![画像](PresenceEpd.jpg)

仮設置状態です。
(もう少しまともなケース等に入れるつもりなので、
電子ペーパーの保護シールも貼ったまま。)

## 動作
5分おきにTWELITE DIPからMONOSTICKに送信。
ACKが返ってくればMONOSTICKの電源が入っていると判断して、
(在室時画像を表示中でなければ)在室時画像に表示を切り替え。

何回か再送しても駄目な場合には帰宅と判断し、
(帰宅時画像を表示中でなければ)帰宅時画像に表示を切り替え。

## 部品
* [TWELITE DIP](https://mono-wireless.com/jp/products/TWE-Lite-DIP/index.html)
* [MONOSTICK](https://mono-wireless.com/jp/products/MoNoStick/index.html)。
  (実際に使っているのは前身のToCoStick)
* [2インチ電子ペーパー+制御基板 Y-Con P020](http://eleshop.jp/shop/g/gFCO121)。シリアルから操作可能
* 単三電池2本用ケース。Y-Con P020とほぼ同じ縦横サイズ
  (なお、ボタン電池(CR2032)でも動くようです。)

## 準備
### 表示する画像の登録
[在室時](zai.bmp)、[帰宅時](kitaku.bmp)のモノクロBMP画像(200x96)を作成して、
TeraTermを使ってY-Con P020に登録しておきます。
一度登録しておけば電源を切っても保持されているので、
コマンド動作モードで表示ページを指定すれば表示されます。

### 起動時画面をオフに設定
Y-Con P020の起動時画面表示がオンだと、表示されるまでに数秒かかり、
TWELITEからコマンドを送る前に表示完了を待つ必要があって面倒なので、
起動時画面をオフに設定しておきます。
一度設定しておけば、電源を切っても設定は保持されています。

## TWELITE用ソース
ソースはSamp_PingPongをベースにしていますが、
Samp_PingPongのソースはTOCOSの許可が無いと公開禁止との記述があって面倒なので、
差分のみ公開。
[TWELITE NET SDK](https://mono-wireless.com/jp/products/TWE-NET/TWESDK.html) 2014/8月号(TWESDK_201408-31)に対する差分です。

以下のように、TWESDK/Wks_ToCoNet/ディレクトリでgenPresenceEpd.shを実行すると、
PresenceEpdディレクトリを作ります。
TWESDK/Tools/cygwin/Cygwin.batで起動したcygwinのプロンプト上で、
```sh
cd /cygdrive/d/TWESDK/Wks_ToCoNet
/cygdrive/c/Users/deton/Downloads/genPresenceEpd.sh

cd PresenceEpd
make
```

* PresenceEpd/PingPong/    MONOSTICK側ソース。ほぼSamp_PingPongと同じ。
* PresenceEpd/PresenceEpd/ TWELITE DIP側ソース

PresenceEpd/Common/Source/config.hのAPP_IDは、
MONOSTICKのシリアル番号(S/N)+0x80000000に変更する必要あり。

makeコマンドでのビルドのみ確認(Eclipseでは未確認)。

## 改良案
* 消費電力を減らすため、Y-Con P020の電源を、
  電子ペーパーの書き換え時のみオンにして通常はオフにする。

## 関連
* [Androidスマホを貼りつけておいて、HTMLで出退勤表示](https://github.com/deton/syuttaikinBoard)
* [サーボモータを使った出退勤表示](https://github.com/deton/syuttaikin)
* [LED点滅で出退勤表示](..)

## 参考
* [Raspberry Pi用電子ペーパー PaPiRus ePaper/eInkディスプレイHAT](https://www.rs-online.com/designspark/papirus-epaper-hat-JP)
