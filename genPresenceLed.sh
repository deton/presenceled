#!/bin/sh
cp -r Samp_PingPong PresenceLed
cd PresenceLed
rm PingPong/Build/Samp_PingPong_*.bin
cp -r PingPong PresenceLed
cp .project .project.dist
sed -e '3s/Samp_PingPong/PresenceLed/' .project.dist >.project
cp Makefile Makefile.dist
sed -e '/^DIRS/s/=.*$/= PresenceLed PingPong/' Makefile.dist >Makefile
# TWESDK/Tools/cygwin does not have 'patch' command
vim -u NONE --noplugin -e -s Common/Source/config.h << "DIFF"
32,33c
#define APP_ID              0x81004838 // XXX: set 0x80000000 + ToCoStick S/N
#define CHANNEL             16
.
x
DIFF
vim -u NONE --noplugin -e -s Common/Source/app_event.h << "DIFF"
29,34c
	E_STATE_APP_WAIT_TX,
	E_STATE_APP_LEDON,
	E_STATE_APP_SLEEP,
.
16,22d
x
DIFF
vim -u NONE --noplugin -e -s PingPong/Source/PingPong.c << "DIFF"
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
	} else if (!memcmp(pRx->auData, "P", 1)) {
		//vfPrintf(&sSerStream, LB "P from %08x at %d" LB, pRx->u32SrcAddr, u32TickCount_ms);
		// turn on Led a while
		sAppData.u32LedCt = u32TickCount_ms;
.
48a
#define PORT_LED_RECV 16 // DIO16 red LED of ToCoStick
//#define PORT_LED_RECV 18

.
x
DIFF

cd PresenceLed/Source
mv PingPong.h PresenceLed.h
mv PingPong.c PresenceLed.c
# no 'cat' command
head -n 999 >PresenceLed.c.diff << "DIFF"
606,608c
/**
 * イベント処理関数リスト
 */
static const tsToCoNet_Event_StateHandler asStateFuncTbl[] = {
	PRSEV_HANDLER_TBL_DEF(E_STATE_IDLE),
	PRSEV_HANDLER_TBL_DEF(E_STATE_RUNNING),
	PRSEV_HANDLER_TBL_DEF(E_STATE_APP_WAIT_TX),
	PRSEV_HANDLER_TBL_DEF(E_STATE_APP_LEDON),
	PRSEV_HANDLER_TBL_DEF(E_STATE_APP_SLEEP),
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
602a
			u32Periodms = sAppData.u32RetryWaitMs;
			sAppData.u32SentTime = 0; // 起床時に送信
		}

		V_PRINTF(LB"Sleeping...(bAlive=%d,ms=%d)", sAppData.bAlive, u32Periodms);
		SERIAL_vFlush(UART_PORT_SLAVE);

		// 周期スリープに入る
		//  - 初回は3秒あけて、次回以降はスリープ復帰を基点に3秒
		ToCoNet_vSleep(E_AHI_WAKE_TIMER_0, u32Periodms, sAppData.u16frame_count == 1 ? FALSE : TRUE, bRamOff);
.
600,601c
					sAppData.u32RetryWaitMs = MIN(sAppData.u32RetryWaitMs * 2, RETRYWAIT_MAX_ms);
					sAppData.u16frame_count = 0; // 再送なことをToCoStickに示す
				}
			}
			if (sAppData.u32RetryWaitMs >= RETRYWAIT_MAX_ms) {
				bRamOff = TRUE; // 5分待ちの場合はメモリ保持不要
.
595,598c
}

PRSEV_HANDLER_DEF(E_STATE_APP_SLEEP, tsEvent *pEv, teEvent eEvent, uint32 u32evarg) {
	if (eEvent == E_EVENT_NEW_STATE) {
		uint32 u32Periodms = SLEEP_DUR_ms;
		bool_t bRamOff = FALSE;

		vPortSetHi(PORT_LED); // LED OFF
		if (sAppData.bAlive) { // alive中は3秒ごとにLED ON
			sAppData.u16SleepCt++;
		} else { // aliveでない場合、次回aliveチェックは再送待ち時間後。最大5分
			if (sAppData.u32RetryWaitMs < RETRYWAIT_MAX_ms) {
				if (sAppData.u32RetryWaitMs == 0) { // cold boot時
					sAppData.u32RetryWaitMs = RETRYWAIT_MAX_ms;
.
580,593c
PRSEV_HANDLER_DEF(E_STATE_APP_LEDON, tsEvent *pEv, teEvent eEvent, uint32 u32evarg) {
	if (eEvent == E_EVENT_NEW_STATE) {
		vPortSetLo(PORT_LED);
	} else if (ToCoNet_Event_u32TickFrNewState(pEv) >= LEDON_DUR_ms) {
		vPortSetHi(PORT_LED); // LED OFF
		ToCoNet_Event_SetState(pEv, E_STATE_APP_SLEEP);
.
575,576c
// 送信完了待ち。送信成功/失敗時はcbToCoNet_vTxEvent()からE_ORDER_KICKされる
PRSEV_HANDLER_DEF(E_STATE_APP_WAIT_TX, tsEvent *pEv, teEvent eEvent, uint32 u32evarg) {
	if (eEvent == E_ORDER_KICK) {
		ToCoNet_Event_SetState(pEv, u32evarg);
	} else if (ToCoNet_Event_u32TickFrNewState(pEv) > 28) {
		V_PRINTF(LB"! TIMEOUT");
		sAppData.bAlive = FALSE;
		ToCoNet_Event_SetState(pEv, E_STATE_APP_SLEEP);
.
573a
}
.
571,572c
PRSEV_HANDLER_DEF(E_STATE_RUNNING, tsEvent *pEv, teEvent eEvent, uint32 u32evarg) {
	if (eEvent == E_EVENT_NEW_STATE) {
		// センシングと送信は5分に1回
		if (sAppData.u32SentTime == 0 || sAppData.u16SleepCt > TX_DUR_ct) {
			vSendPing();
			sAppData.u32SentTime = u32TickCount_ms;
			if (sAppData.u32SentTime == 0) {
				// 1: cold start後のwarm start時のSendPing(*1)を回避するため
				// (cold start, SendPing, sleep, warm start, SendPing(*1))
				sAppData.u32SentTime = 1;
			}
			sAppData.u16SleepCt = 0;
			ToCoNet_Event_SetState(pEv, E_STATE_APP_WAIT_TX);
		} else {
			ToCoNet_Event_SetState(pEv, sAppData.bAlive ? E_STATE_APP_LEDON : E_STATE_APP_SLEEP);
		}
.
569c
	}
}
.
567c
	vfPrintf(&sSerStream, LB "Fire PING");
}

PRSEV_HANDLER_DEF(E_STATE_IDLE, tsEvent *pEv, teEvent eEvent, uint32 u32evarg) {
	if (eEvent == E_EVENT_START_UP) {
		if (u32evarg & EVARG_START_UP_WAKEUP_RAMHOLD_MASK) {
			V_PRINTF(LB "*** Warm starting. bAlive=%d, SleepCt=%d", sAppData.bAlive, sAppData.u16SleepCt);
			ToCoNet_Event_SetState(pEv, E_STATE_RUNNING);
		} else {
			V_PRINTF(LB "*** Cold starting. SentTime=%d, SleepCt=%d", sAppData.u32SentTime, sAppData.u16SleepCt);
			ToCoNet_Event_SetState(pEv, E_STATE_RUNNING);
.
563,565d
554,558c
	// 長さ0だと送信成功しないようなので
	tsTx.auData[0] = 'P';
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
452,539d
438,450c
static void vSendPing()
.
408,416d
402,405c
	vPortSetHi(PORT_LED);
	vPortAsOutput(PORT_LED);
.
395,396d
381,393d
370,378d
347,365d
329,344d
294,326d
286,290c
// 送信完了コールバック関数
void cbToCoNet_vTxEvent(uint8 u8CbId, uint8 u8Status) {
	V_PRINTF(LB"Tx(Tms:%d)", u32TickCount_ms - sAppData.u32SentTime);
	if (u8Status & 0x01) { // 送信成功
		V_PRINTF("OK");
		sAppData.bAlive = TRUE;
		// 次回aliveでなくなった時の再送待ち時間リセット
		sAppData.u32RetryWaitMs = 500;
		ToCoNet_Event_Process(E_ORDER_KICK, E_STATE_APP_LEDON, vProcessEvCore);
	} else {
		V_PRINTF("NG");
		sAppData.bAlive = FALSE;
		ToCoNet_Event_Process(E_ORDER_KICK, E_STATE_APP_SLEEP, vProcessEvCore);
.
234,284c
}
.
224,232c
// 受信コールバック関数
.
205,216d
201,202d
190,198d
184a
	}
.
181a
		if (sAppData.u32SentTime == 0 || sAppData.u16SleepCt > TX_DUR_ct) {
.
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
129d
121,125c
		// 1:2.0V(JN5164,default)
		vAHI_BrownOutConfigure(1, FALSE, FALSE, FALSE, FALSE);

		// for TWE-EH-Solar
		vPortSetLo(DIO_VOLTAGE_CHECKER);
		vPortAsOutput(DIO_VOLTAGE_CHECKER);
		vPortDisablePullup(DIO_VOLTAGE_CHECKER);
.
101,109d
79d
65,66c
    // aliveでなかった場合の再送待ち時間。1秒から倍々で増やして最大5分
    uint32 u32RetryWaitMs;
.
63c
    uint16 u16frame_count;

    // send packet time
    uint32 u32SentTime;

    // 送回送信以降にスリープした回数。前回送信からの経過時間計算用
    uint16 u16SleepCt;
.
55,60c
    // 在室かどうか。ToCoStickへの送信が成功したか(ACKが返ってきたか)
    bool_t bAlive;
.
47a
#define V_PRINTF(...) vfPrintf(&sSerStream,__VA_ARGS__)

//#define PORT_LED 4 // DIO4 (DO3 in App_Twelite)
#define PORT_LED 9 // DIO9 (DO4 in App_Twelite)

// for TWE-EH-Solar
#define DIO_VOLTAGE_CHECKER 18  // DIO18. DO1: 始動後速やかに LO になる

#define SLEEP_DUR_ms 3000
#define LEDON_DUR_ms 8
#define TX_DUR_ct 100 // 5[min] 定期送信間隔。単位はスリープ回数。
					  // スリープ中はu32TickCount_msが増えないので。
#define RETRYWAIT_MAX_ms ((TX_DUR_ct) * (SLEEP_DUR_ms))
.
22c
#include "PresenceLed.h"
.
x
DIFF
# use ':source' to avoid mojibake
echo 'so PresenceLed.c.diff' | vim -e -s PresenceLed.c
#vim -e -S PresenceLed.c.diff PresenceLed.c
rm PresenceLed.c.diff
