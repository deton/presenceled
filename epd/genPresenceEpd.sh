#!/bin/sh
cp -r Samp_PingPong PresenceEpd
cd PresenceEpd
find . -type d -exec chmod u+rwx '{}' \;
find . -type f -exec chmod u+rw  '{}' \;
rm PingPong/Build/Samp_PingPong_*.bin
cp -r PingPong PresenceEpd
sed -ie '/^DIRS/s/=.*$/= PresenceEpd PingPong/' Makefile
sed -ie '/^APPSRC/s/$/ yconp020.c/' PresenceEpd/Build/Makefile
# TWESDK/Tools/cygwin does not have 'patch' command
vim -u NONE -e -s Common/Source/config.h << "DIFF"
32,33c
#define APP_ID              0x81004838 // XXX: set 0x80000000 + ToCoStick S/N
#define CHANNEL             16
.
27,30d
x
DIFF
vim -u NONE -e -s Common/Source/app_event.h << "DIFF"
29,34c
	E_STATE_APP_WAIT_EPD_READY,
	E_STATE_APP_WAIT_TX,
	E_STATE_APP_TOSLEEP,
.
16,22d
x
DIFF
vim -u NONE -e -s PingPong/Source/PingPong.c << "DIFF"
435c
	sSerStream.u8Device = sSerPort.u8SerialPort;
.
430c
	sSerPort.u8SerialPort = E_AHI_UART_0;
.
404c
	vPortAsOutput(PORT_LED_RECV);
.
402c
	vPortSetLo(PORT_LED_RECV);
.
338c
  			vPortSetHi(PORT_LED_RECV);
.
336c
   			vPortSetLo(PORT_LED_RECV);
.
290a
	} else {
		//vfPrintf(&sSerStream, LB "P from %08x at %d" LB, pRx->u32SrcAddr, u32TickCount_ms);
		// turn on Led a while
		sAppData.u32LedCt = u32TickCount_ms;
.
244c
			pRx->u32Tick);
.
239c
	vfPrintf(&sSerStream, LB"[PKT Ad:%04x,Ln:%03d,Seq:%03d,Lq:%03d,Tms:%d \"",
.
48a
#define PORT_LED_RECV 16 // DIO16 red LED of ToCoStick
//#define PORT_LED_RECV 18

.
x
DIFF

cd PresenceEpd/Source
mv PingPong.h PresenceEpd.h
mv PingPong.c PresenceEpd.c
# no 'cat' command
head -n 999 >PresenceEpd.c.diff << "DIFF"
606,608c
/**
 * イベント処理関数リスト
 */
static const tsToCoNet_Event_StateHandler asStateFuncTbl[] = {
	PRSEV_HANDLER_TBL_DEF(E_STATE_IDLE),
	PRSEV_HANDLER_TBL_DEF(E_STATE_APP_WAIT_EPD_READY),
	PRSEV_HANDLER_TBL_DEF(E_STATE_RUNNING),
	PRSEV_HANDLER_TBL_DEF(E_STATE_APP_WAIT_TX),
	PRSEV_HANDLER_TBL_DEF(E_STATE_APP_TOSLEEP),
	PRSEV_HANDLER_TBL_TRM
};

/**
 * イベント処理関数
 * @param pEv
 * @param eEvent
 * @param u32evarg
 */
static void vProcessEvCore(tsEvent *pEv, teEvent eEvent, uint32 u32evarg) {
	ToCoNet_Event_StateExec(asStateFuncTbl, pEv, eEvent, u32evarg);
}
.
580,601c
// 電子ペーパー書き換え。
// 事前に手動で、ページ1に在室画像、ページ5に不在画像を登録しておく想定
// (画像は一度登録すれば電源を切っても保持されている)
static void vUpdateEpd(void)
{
	if (sAppData.bAlive) {
		// 既に対象ページの画像表示中なら、書換時消費電力減らすため何もしない
		if (sAppData.u8EpdPage != 1) {
			YCONP020_bTxCommand("D 1"); // display image of page 1
			sAppData.u8EpdPage = 1;
			V_PRINTF(LB"vUpdateEpd: D 1");
		}
	} else { // 不在画像への書き換え
		if (sAppData.u8EpdPage != 5) {
			YCONP020_bTxCommand("D 5"); // display image of page 5
			sAppData.u8EpdPage = 5;
			V_PRINTF(LB"vUpdateEpd: D 5");
.
577a

	uint32 u32Periodms;
	if (sAppData.bAlive) { // aliveの場合、次回は5分後に起きてチェック
		u32Periodms = POLLING_ms;
	} else { // aliveでない場合、次回aliveチェックは再送待ち時間後。最大5分
		if (sAppData.u32RetryWaitMs < POLLING_ms) {
			sAppData.u32RetryWaitMs = MIN(sAppData.u32RetryWaitMs * 2, POLLING_ms);
			sAppData.u16frame_count = 0; // 再送なことをToCoStickに示す
		}
		u32Periodms = sAppData.u32RetryWaitMs;
	}

	// 電子ペーパー書き換え。ただし、不在画像への書き換えは、何回かPing再送して
	// それでもaliveにならない場合のみ(書換の消費電力を減らすため)
	if (u32Periodms >= POLLING_ms) {
		vUpdateEpd();
	}

#ifdef DEBUG_UART
	V_PRINTF(LB"Sleeping...(bAlive=%d,ms=%d)", sAppData.bAlive, u32Periodms);
	SERIAL_vFlush(sSerStreamDbg.u8Device);
#endif

	//  - RAM保持(+0.3μA): 何を表示中かを保持して、
	//    電子ペーパー書換え(消費電流大:10mA)の回数を減らすため
	ToCoNet_vSleep(E_AHI_WAKE_TIMER_0, u32Periodms, FALSE, FALSE);
.
575,576c
PRSEV_HANDLER_DEF(E_STATE_APP_TOSLEEP, tsEvent *pEv, teEvent eEvent, uint32 u32evarg) {
	if (eEvent != E_EVENT_NEW_STATE) {
		return;
.
573a
}
.
571,572c
// 送信完了待ち。送信成功/失敗時はcbToCoNet_vTxEvent()からE_ORDER_KICKされる
PRSEV_HANDLER_DEF(E_STATE_APP_WAIT_TX, tsEvent *pEv, teEvent eEvent, uint32 u32evarg) {
	if (eEvent == E_ORDER_KICK) {
		ToCoNet_Event_SetState(pEv, E_STATE_APP_TOSLEEP);
	} else if (ToCoNet_Event_u32TickFrNewState(pEv) > 28) { // timeout
		V_PRINTF(LB"! TIMEOUT");
		sAppData.bAlive = FALSE;
		ToCoNet_Event_SetState(pEv, E_STATE_APP_TOSLEEP);
.
569c
	ToCoNet_Event_Process(E_ORDER_KICK, 0, vProcessEvCore);
}
.
566,567c
// 送信完了コールバック関数
void cbToCoNet_vTxEvent(uint8 u8CbId, uint8 u8Status) {
	if (u8Status & 0x01) { // 送信成功
		V_PRINTF(LB"Tx OK");
		sAppData.bAlive = TRUE;
		// 次回aliveでなくなった時の再送待ち時間リセット
		sAppData.u32RetryWaitMs = RETRYWAIT_INIT_ms;
	} else {
		V_PRINTF(LB"Tx NG");
		sAppData.bAlive = FALSE;
.
563,564c
	V_PRINTF(LB "Fire PING");
}
.
554,558c
	// 長さ0だと送信成功しないようなので。
	// u8EpdPage: 0, 1, 5
	tsTx.auData[0] = '0' + sAppData.u8EpdPage + (sAppData.bAlive ? 2 : 0);
	tsTx.u8Len = 1;
.
548,551c
	tsTx.bAckReq = TRUE; // ACKによって宛先ToCoStickの電源オンを確認
	tsTx.u8Retry = 0;
	tsTx.u8CbId = sAppData.u16frame_count & 0xFF;
	tsTx.u8Seq = sAppData.u16frame_count & 0xFF;
.
546c
	tsTx.u32DstAddr = APP_ID; // XXX: 手元にあるToCoStickのアドレス
.
543c
	sAppData.u16frame_count++;
.
537,539c
static void vSendPing(void)
{
.
535c
	vSendPing();
	ToCoNet_Event_SetState(pEv, E_STATE_APP_WAIT_TX);
}
.
532,533c
PRSEV_HANDLER_DEF(E_STATE_RUNNING, tsEvent *pEv, teEvent eEvent, uint32 u32evarg) {
	if (eEvent != E_EVENT_NEW_STATE) {
		return;
.
522,530c
	// cold start
	V_PRINTF(LB "*** Cold starting.");
	// Y-Con P020初期化:コマンド動作モードにするため、"+++"をシリアルに書く。
	// 最初の'+'を書いた後、waitを入れるためsleepに入った後、warm startされる。
	//
	// Y-Con P020のパワーオン・リセット時待機画面表示有効だと画面書換に数秒
	// かかって、その間はシリアルを読んでくれないようなので、
	// Y-Con P020のSTANDBY設定を事前に手動で0に設定しておく想定
	// (STANDBY設定は一度設定すれば電源を切っても保持されている)
	//
	// 電源投入直後は'+'を受け付ける状態になっていないので少し待つ
	// (TODO:通常モードプロンプト'>'を待つ。またはP37がHighになるのを待つ)
	//YCONP020_bInit(UART_PORT_YCONP020);
	ToCoNet_vSleep(E_AHI_WAKE_TIMER_0, 200, FALSE, FALSE);
}

PRSEV_HANDLER_DEF(E_STATE_APP_WAIT_EPD_READY, tsEvent *pEv, teEvent eEvent, uint32 u32evarg) {
	if (YCONP020_bIsReady()) {
		V_PRINTF(LB"EPD Ready");
		ToCoNet_Event_SetState(pEv, E_STATE_RUNNING);
	}
}
.
508,520c
		// Y-Con P020の準備完了を待つ必要あり
		ToCoNet_Event_SetState(pEv, E_STATE_APP_WAIT_EPD_READY);
		return;
.
491,506c
	if (u32evarg & EVARG_START_UP_WAKEUP_RAMHOLD_MASK) { // warm start
		V_PRINTF(LB "*** Warm starting. bAlive=%d", sAppData.bAlive);
		if (YCONP020_bInit(UART_PORT_YCONP020)) {
			ToCoNet_Event_SetState(pEv, E_STATE_RUNNING);
			return;
.
489c
PRSEV_HANDLER_DEF(E_STATE_IDLE, tsEvent *pEv, teEvent eEvent, uint32 u32evarg) {
	if (eEvent != E_EVENT_START_UP) {
		return;
.
472,487c
	sSerStreamDbg.bPutChar = SERIAL_bTxChar;
	sSerStreamDbg.u8Device = sSerPortDbg.u8SerialPort;
}
.
423,470c
	sSerPortDbg.pu8SerialRxQueueBuffer = au8SerialRxBufferDbg;
	sSerPortDbg.pu8SerialTxQueueBuffer = au8SerialTxBufferDbg;
	sSerPortDbg.u32BaudRate = u32Baud;
	sSerPortDbg.u16AHI_UART_RTS_LOW = 0xffff;
	sSerPortDbg.u16AHI_UART_RTS_HIGH = 0xffff;
	sSerPortDbg.u16SerialRxQueueSize = sizeof(au8SerialRxBufferDbg);
	sSerPortDbg.u16SerialTxQueueSize = sizeof(au8SerialTxBufferDbg);
	sSerPortDbg.u8SerialPort = UART_PORT_PC;
	sSerPortDbg.u8RX_FIFO_LEVEL = E_AHI_UART_FIFO_LEVEL_1;
	SERIAL_vInitEx(&sSerPortDbg, pUartOpt);
.
419,420c
	static uint8 au8SerialTxBufferDbg[96];
	static uint8 au8SerialRxBufferDbg[32];
.
401,416d
399a
#endif
}
.
397,398c
	ToCoNet_vDebugInit(&sSerStreamDbg);
.
395d
381,393c
#ifdef DEBUG_UART
.
370,378d
347,365d
329,344d
310,326d
294,307c
// 受信コールバック関数
void cbToCoNet_vRxEvent(tsRxDataApp *pRx) {
.
286,291c
void cbToCoNet_vNwkEvent(teEvent eEvent, uint32 u32arg) {
.
279,284c
}
.
276,277c
	// PCに接続するdebug用serial portからの入力を、そのままY-Con P020に出力
	while (!SERIAL_bRxQueueEmpty(sSerPortDbg.u8SerialPort)) {
		int16 i16Char = SERIAL_i16RxChar(sSerPortDbg.u8SerialPort);
		YCONP020_bTxChar(i16Char);
.
269,274c
#ifdef DEBUG_UART
	YCONP020_vHandleSerialInput(TRUE, UART_PORT_PC);
#else
	YCONP020_vHandleSerialInput(FALSE, 0);
#endif
.
205,267c
static void vHandleSerialInput(void)
{
	// PCに接続するdebug用serial portと、Y-Con P020を中継
.
190,198d
178a
		// disable brown out detect
		// 1:2.0V(JN5164,default)
		vAHI_BrownOutConfigure(1, FALSE, FALSE, FALSE, FALSE);

.
167,177d
151,161d
135c
		sToCoNet_AppContext.u8MacInitPending = TRUE; // 起動時の MAC 初期化を省略する(送信する時に初期化する)
.
133a
		//sToCoNet_AppContext.u8TxMacRetry = 4; // 0-7 (default: 3)

		sToCoNet_AppContext.bRxOnIdle = FALSE;
.
129c
		sAppData.u32RetryWaitMs = RETRYWAIT_INIT_ms;
.
121,125c
		// 1:2.0V(JN5164,default)
		vAHI_BrownOutConfigure(1, FALSE, FALSE, FALSE, FALSE);
.
112d
101,109d
95,99c
#ifdef DEBUG_UART
PUBLIC tsFILE sSerStreamDbg;
tsSerialPortSetup sSerPortDbg;
#endif
.
79a
static void vSendPing(void);
static void vUpdateEpd(void);
.
65,66c
	// Y-Con P020に表示中のページ番号
	uint8 u8EpdPage;
.
63c
	uint16 u16frame_count;

	// aliveでなかった場合の再送待ち時間。1秒から倍々で増やして最大5分
	uint32 u32RetryWaitMs;
.
55,60c
	// 在室かどうか。ToCoStickへの送信が成功したか(ACKが返ってきたか)
	bool_t bAlive;
.
47a
#define DEBUG_UART

#ifdef DEBUG_UART
#define V_PRINTF(...) vfPrintf(&sSerStreamDbg,__VA_ARGS__)
#else
#define V_PRINTF(...)
#endif

#define UART_PORT_YCONP020	E_AHI_UART_0 // TX:DIO6, RX:DIO7
// PCに接続するdebug用serial port
#define UART_PORT_PC		E_AHI_UART_1 // TX:DIO14, RX:DIO15

#define POLLING_ms 300000 // 5[min] 定期送信間隔
#define RETRYWAIT_INIT_ms 500 // 再送待ち時間初期値
.
25a
#include "yconp020.h"

.
22c
#include "PresenceEpd.h"
.
x
DIFF
# use ':source' to avoid mojibake
echo 'so PresenceEpd.c.diff' | vim -u NONE -N -e -s PresenceEpd.c
#vim -e -S PresenceEpd.c.diff PresenceEpd.c
rm PresenceEpd.c.diff

head -n 999 >yconp020.h << "EOF"
#ifndef __YCONP020_H__
#define __YCONP020_H__

/**
 * Y-Con P020初期化。
 * @return TRUE:準備完了、
 * FALSE:準備未完。YCONP020_bIsReady()がTRUEになるまで待つ必要あり。
 */
bool_t YCONP020_bInit(uint8 u8SerialPort);

/**
 * Y-Con P020の準備ができているかどうか
 * @return TRUE:準備ができている場合
 */
bool_t YCONP020_bIsReady(void);

/**
 * Y-Con P020とのシリアルの読み取り処理
 * @param bEnableDebug Y-Con P020からシリアルで読み取った内容を、
 * u8DebugSerialPortに出力するかどうか
 * @param u8DebugSerialPort PCに接続したデバッグ用シリアルポート。
 * bEnableDebugがTRUEの場合に書き込む。
 */
void YCONP020_vHandleSerialInput(bool_t bEnableDebug, uint8 u8DebugSerialPort);

/**
 * Y-Con P020に対しコマンドをシリアル出力。
 * 内部では、SERIAL_bTxString(pu8Cmd)後、
 * SERIAL_bTxChar('\r')して、SERIAL_vFlush()する。
 * @param pu8Cmd 出力するコマンド文字列
 * @return FALSE:キューがいっぱいの場合
 */
bool_t YCONP020_bTxCommand(uint8 *pu8Cmd);

/**
 * Y-Con P020に対し指定バイトをシリアル出力。
 * 内部では、SERIAL_bTxChar(u8Chr)する。
 * @param u8Chr 出力するバイト
 * @return FALSE:キューがいっぱいの場合
 */
bool_t YCONP020_bTxChar(uint8 u8Chr);

#endif // __YCONP020_H__
EOF
head -n 999 >yconp020.c << "EOF"
#include <jendefs.h>
#include <AppHardwareApi.h>
#include "serial.h"
#include "ToCoNet.h"
#include "yconp020.h"

static void vSerialInit(uint8 u8SerialPort);
static bool_t bWriteEpdCmd(void);
static bool_t bTxCr(void);

// Y-Con P020へのシリアル送信中状態。
// "+++"を送信してコマンド動作モードにする際に、waitを入れる必要があるので、
// 今どこまで送信したかの状態。
typedef enum {
	E_EPD_CMD_NONE = 0,
	E_EPD_CMD_PLUS1,
	E_EPD_CMD_PLUS2,
	E_EPD_CMD_PLUS3,
	E_EPD_CMD_PROMPT,
} teEpdCmdState;

// TODO: 複数のY-Con P020の同時接続への対応
static tsSerialPortSetup sSerPort;

// Y-Con P020への送信中シリアルコマンド状態
static uint8 u8EpdCmdState;

/**
 * 初期化
 * @return TRUE:準備完了、
 * FALSE:準備未完。YCONP020_bIsReady()がTRUEになるまで待つ必要あり。
 */
bool_t YCONP020_bInit(uint8 u8SerialPort)
{
	vSerialInit(u8SerialPort);

	if (YCONP020_bIsReady()) {
		return TRUE;
	}
	if (u8EpdCmdState == E_EPD_CMD_PLUS3) { // +++書き込み済?
		bTxCr();
		return FALSE;
	}
	return bWriteEpdCmd();
}

static void vSerialInit(uint8 u8SerialPort)
{
	/* Create the Y-Con P020 port transmit and receive queues */
	static uint8 au8SerialTxBuffer[3072]; // Y-Con P020用BMP(200x96)は2750バイト
	// コマンド動作モード移行時、Usageメッセージが800バイト程度送られてくる
	static uint8 au8SerialRxBuffer[1024];

	/* Initialise the serial port to be used for Y-Con P020 output */
	sSerPort.pu8SerialRxQueueBuffer = au8SerialRxBuffer;
	sSerPort.pu8SerialTxQueueBuffer = au8SerialTxBuffer;
	sSerPort.u32BaudRate = 115200;
	sSerPort.u16AHI_UART_RTS_LOW = 0xffff;
	sSerPort.u16AHI_UART_RTS_HIGH = 0xffff;
	sSerPort.u16SerialRxQueueSize = sizeof(au8SerialRxBuffer);
	sSerPort.u16SerialTxQueueSize = sizeof(au8SerialTxBuffer);
	sSerPort.u8SerialPort = u8SerialPort;
	sSerPort.u8RX_FIFO_LEVEL = E_AHI_UART_FIFO_LEVEL_1;
	SERIAL_vInit(&sSerPort);
}

// Y-Con P020がコマンド動作モードかどうか
bool_t YCONP020_bIsReady(void)
{
	return (u8EpdCmdState >= E_EPD_CMD_PROMPT);
}

// Y-Con P020をコマンド動作モードにするため、sleepしながら+++をシリアルに書く。
// '+' (wait) '+' (wait) '+' (CR)
// waitは100-500msの範囲
//
// Y-Con P020のパワーオン・リセット時待機画面表示有効だと画面書換に数秒
// かかって、その間はシリアルを読んでくれないようなので、
// Y-Con P020のSTANDBY設定を事前に手動で0に設定しておく想定
// (STANDBY設定は一度設定すれば電源を切っても保持されている)
// @return TRUE:書き込み完了しsleepしない場合, FALSE:sleepに入る場合
static bool_t bWriteEpdCmd(void)
{
	SERIAL_bTxChar(sSerPort.u8SerialPort, '+');
	SERIAL_vFlush(sSerPort.u8SerialPort);
	u8EpdCmdState++;
	//vfPrintf(&sSerStreamDbg, LB"bWriteEpdCmd: + (%d)", u8EpdCmdState);
	if (u8EpdCmdState == E_EPD_CMD_PLUS3) { // 書き込み完了?
		bTxCr();
		return FALSE;
	}
	//SERIAL_vFlush(sSerStreamDbg.u8Device);
	// 次の'+'を書く前に200msのwaitを入れる
	ToCoNet_vSleep(E_AHI_WAKE_TIMER_0, 200, FALSE, FALSE);
	return TRUE;
}

// Y-Con P020に対しCRをシリアル出力してflush
static bool_t bTxCr(void)
{
	bool_t b = SERIAL_bTxChar(sSerPort.u8SerialPort, '\r');
	SERIAL_vFlush(sSerPort.u8SerialPort);
	return b;
}

/**
 * Y-Con P020とのシリアルの読み取り処理
 * @param bEnableDebug Y-Con P020からシリアルで読み取った内容を、
 * u8DebugSerialPortに出力するかどうか
 */
void YCONP020_vHandleSerialInput(bool_t bEnableDebug, uint8 u8DebugSerialPort)
{
	// handle UART input from Y-Con P020
	while (!SERIAL_bRxQueueEmpty(sSerPort.u8SerialPort)) {
		int16 i16Char = SERIAL_i16RxChar(sSerPort.u8SerialPort);
		if (bEnableDebug) {
			SERIAL_bTxChar(u8DebugSerialPort, i16Char); // debug portに出力
		}
		switch(i16Char) {
		case '!': // Y-Con P020 command mode prompt
			u8EpdCmdState = E_EPD_CMD_PROMPT;
			break;

		default:
			break;
		}
	}
}

/**
 * Y-Con P020に対しコマンドをシリアル出力。
 * 内部では、SERIAL_bTxString(pu8Cmd)後、
 * SERIAL_bTxChar('\r')して、SERIAL_vFlush()する。
 * @param pu8Cmd 出力するコマンド文字列
 * @return FALSE:キューがいっぱいの場合
 */
bool_t YCONP020_bTxCommand(uint8 *pu8Cmd)
{
	if (!SERIAL_bTxString(sSerPort.u8SerialPort, pu8Cmd)) {
		return FALSE;
	}
	return bTxCr();
}

/**
 * Y-Con P020に対し指定バイトをシリアル出力。
 * 内部では、SERIAL_bTxChar(u8Chr)する。
 * @param u8Chr 出力するバイト
 * @return FALSE:キューがいっぱいの場合
 */
bool_t YCONP020_bTxChar(uint8 u8Chr)
{
	return SERIAL_bTxChar(sSerPort.u8SerialPort, u8Chr);
}

/*
MIT License
Copyright (c) 2017 KIHARA, Hideto

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
EOF
