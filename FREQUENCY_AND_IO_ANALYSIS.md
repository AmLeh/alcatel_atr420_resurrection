# Анализ установки частоты, приема и передачи данных

Файл-источник для этого этапа: `ST_M27256.HEX` / `ST_M27256_annotated.asm`.

## Короткий вывод

В прошивке прослеживаются три разные подсистемы:

1. Панель клавиатуры/индикации работает через UART 8051 (`SBUF`) и частично
   через отдельный синхронный интерфейс `P1.1/P1.2/P1.3/P3.4`.
2. Управление радиотрактом и, вероятно, PLL идет через внешние защелки:
   `P1` задает байт, `P3.5` стробирует запись.
3. Установка канала/частоты не выглядит как одна простая функция. Код сначала
   меняет состояние канала в RAM/XDATA, затем через event-dispatcher вызывает
   несколько низкоуровневых latch-операций.

## Главный event-dispatcher

Основной цикл оригинальной прошивки - это диспетчер флагов `L585F`.

Важные переходы:

| Флаг | Переход | Назначение |
| --- | --- | --- |
| `20h.3` | `L58DC` | прием 4-битного значения по sync-интерфейсу |
| `20h.2` | `L597C` | передача очереди `40h` по sync-интерфейсу |
| `25h.0` | `L568F` | обработка принятого UART байта от панели |
| `24h.0` | `L4CFD` | отправка следующего UART байта на панель |
| `24h.4` | `L06A6` или `L3C5E` | обработка принятой клавиши/команды |
| `25h.1` | `L534F` | чтение аппаратного статуса через latch-read |
| `2Eh.0` | `L5609` | битовая/импульсная последовательность на latch-линиях |

Адреса:

```text
585F: dispatcher
568F: panel UART RX queue consumer
4CFD: panel UART TX queue sender
58DC: sync RX start
597C: sync TX queue consumer
5609: радио/PLL-подобная последовательная latch-передача
```

## Прием данных от панели

UART инициализируется как в оригинале:

```text
026F: TMOD = 22h
0272: TCON = 50h
0275: SCON = 70h
0278: TH1  = E7h
027B: TL1  = E7h
027E: TH0  = 9Ch
0281: TL0  = 9Ch
0284: IE   = 92h
0287: IP   = 10h
028A: PCON = 80h
```

Serial ISR:

```text
59B8: JBC SCON.0,L59C4     ; RI
59CE: MOV R1,SBUF          ; принятый байт
59D0: MOV R0,#33h          ; очередь RX
59D7..59DC                 ; положить байт в очередь 33h
59CC: SETB 25h.0           ; событие "есть входной байт"
```

Обработчик очереди:

```text
568F: MOV R0,#33h
5691: LCALL L0379          ; pop queue
56A1: ANL A,#7Fh           ; убрать parity/старший бит
56AC: MOV R3,A             ; код панели
5724: MOV 7Bh,R3
5726: SETB 24h.4           ; дальше обработчик клавиши/команды
```

Практически подтверждено гибридной прошивкой:

- удержание клавиши показывает `KEY xx`;
- отпускание часто дает `2F`;
- функциональные кнопки доходят до оригинального dispatcher и могут запускать
  штатные функции радиостанции.

## Таблица кодов клавиш

Физический код панели попадает в `7Bh`. Для цифрового ввода `L06A6` использует
таблицу `068Dh`.

Таблица `068Dh`:

```text
raw:  00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F 10 11 12 13 14 15 16 17 18
map:  00 0F 0F 03 0F 02 01 0F 0F 0F 0F 0F 0F 0F 0F 04 0F 05 06 0F 07 0F 09 0F 08
```

С учетом `key_codes.txt`:

| Клавиша | Raw-код | Логическая цифра |
| --- | ---: | ---: |
| `0` | `00h` | `0` |
| `1` | `06h` | `1` |
| `2` | `05h` | `2` |
| `3` | `03h` | `3` |
| `4` | `0Fh` | `4` |
| `5` | `11h` | `5` |
| `6` | `12h` | `6` |
| `7` | `14h` | `7` |
| `8` | `18h` | `8` |
| `9` | `16h` | `9` |

Остальные кнопки в этой таблице дают `0Fh`, то есть "не цифровая клавиша".
Они обрабатываются отдельными ветками state-machine.

Дополнительно подтвержденные raw-коды функциональных клавиш:

| Клавиша | Raw-код |
| --- | ---: |
| `*` | `01h` |
| `#` | `02h` |
| `APPEL` | `04h` |
| `- volume` | `07h` |
| `ALARM` | `08h` |
| `BIS` | `09h` |
| `DIVA` | `0Ah` |
| `+ volume` | `0Bh` |
| `KEY lock` | `0Dh` |
| `MEM` | `0Eh` |
| release/idle | `2Fh` |

Например APPEL:

```text
14F7: CJNE A,#04h,L1512
14FA: LCALL L384B
14FD: LCALL L3BAD
1503: MOV DPTR,#216Ah
1506: LCALL L3C05
150F: LJMP L08F8
```

Это объясняет, почему в гибриде APPEL запускал радио-передачу: мы оставляли
оригинальную state-machine активной.

## Передача данных на панель

Полный кадр экрана строится в `L4B07`.

```text
4B07: enqueue 78h
4B0C: enqueue RAM[79h]
4B11: enqueue RAM[75h]
4B16: enqueue RAM[78h]
4B1B: enqueue RAM[74h]
4B20: enqueue RAM[77h]
4B25: enqueue RAM[73h]
4B2A: enqueue RAM[76h]
4B2F: enqueue RAM[72h]
```

То есть логический буфер `72h..79h` отправляется в переставленном порядке:

```text
command 78h,
char7, char3, char6, char2, char5, char1, char4, char0
```

Физическая отправка UART:

```text
4CFD: MOV R0,#36h
4D02: LCALL L0379          ; взять байт из очереди 36h
4D13: ANL A,#7Fh
4D15: MOV C,PSW.0
4D17: MOV ACC.7,C          ; parity bit
4D19: MOV SBUF,A
```

Важная деталь: старший бит передаваемого байта не произвольный, а parity из
`PSW.0`. Это объясняет, почему автономная демо без parity могла не работать, а
гибрид с оригинальным `L4CFD` работал.

## Sync-интерфейс панели/статуса

Кроме UART есть отдельный 4-проводный обмен:

| Линия | Использование |
| --- | --- |
| `P1.1` | frame/select |
| `P1.2` | clock/ack |
| `P1.3` | data |
| `P3.4` | ready/handshake |

Передача байта:

```text
597C: очередь 40h -> L598E
598E: CLR P1.1
5994: SETB P1.1
5998..59AD: 8 бит, LSB first, data=P1.3, clock=P1.2, handshake=P3.4
```

Прием nibble:

```text
58DC: R2=04h
58E1: sample P1.3 when P3.4 low
58E7/58EC: pulse P1.2
5924..5927: записать nibble в младшие 4 бита RAM[68h]
```

Этот интерфейс может быть статусной/служебной линией панели или части радио.
Для клавиатуры практически подтвержден основной UART-путь.

## Radio/PLL control update: MC145156P2

Board inspection corrected the PLL identity: the chip is Motorola `MC145156P2`,
not `MC145152`. Therefore the PLL should be treated as a serially programmed
synthesizer. The previous parallel-input `N0..N13/RA0..RA2/T/R` assumptions are
obsolete for this board revision.

Current working hypothesis:

1. Frequency is programmed by a serial bit sequence from the main 8031.
2. `L55CB/L55D4/L55E8/L55F7/L5609` are high-priority candidates for
   data/clock/load-like control through latch writes on `P1` with `P3.5` strobe.
3. The explicit handshaked bit protocol around `L598E` using `P1.1/P1.2/P1.3`
   and `P3.4` is also a PLL/control-bus candidate until measurements separate it
   from panel or service traffic.
4. PLL `LD` should be probed if accessible; it is the best hardware confirmation
   that a decoded/programmed word produced lock.

Low-level latch write primitive:

```text
03CC: CLR P3.5
03CE: MOV P1,A
03D0: SETB P3.5
```

Short serial/latch candidate around `L5609`:

```text
5618: if R1==0 -> R1=0Ah
561D: DPTR = 2241h
5620: MOVX[2241h] = 04h
5623: LCALL L55CB
5626: A=R1
5627: RRC A
5628: R1=A
5629: LCALL L55D4      ; bit value from carry
562C: LCALL L55E8      ; strobe/clock candidate
562F: LCALL L55F1      ; decrement MOVX[DPTR]
5632: JNZ L5623
5634: LCALL L55CB
5637: LCALL L55F7
563A: LCALL L55E8
563D: MOVX[2240h] = 0Ah
5643: SETB 2Eh.5
```

Primary measurement targets for channel changes:

- `P1.0..P1.7` and `P3.5` to capture latch writes.
- `P1.1`, `P1.2`, `P1.3`, `P3.4` to capture the handshaked bit protocol.
- PLL pins for data/clock/load if reachable.
- PLL `LD` to verify lock after a programmed channel.
- Separate captures for channel `0..8` and for `APPEL`/PTT.

New continuity information:

| MC145156-2 pin | Connected to |
| ---: | --- |
| `11` | `SN54LS09J` pin `3` |
| `12` | `SN54LS09J` pin `6` |
| `13` | `SN54LS09J` pin `11` |
| `9` | capacitor-coupled to MC145156-2 pin `20` |

Because `SN54LS09J` is open-collector AND logic, the next useful continuity
step is to trace the paired LS09 inputs for outputs `3`, `6`, and `11`.
Measure both the PLL-side outputs and the LS09 inputs during channel changes.

## Канал и состояние частоты

Внутренние/внешние переменные, связанные с выбранным каналом:

| Адрес | Наблюдение |
| --- | --- |
| `7Bh` | последний принятый код панели |
| `72h` | текущая отображаемая/вводимая цифра канала |
| `7Ch` | текущий канал/индекс, часто копируется из `72h` |
| `7Dh` | дополнительный индекс/длина ввода |
| `21DAh` | XDATA зеркало текущего выбранного канала |
| `218Dh` | XDATA зеркало `7Ch` при подтверждении канала |
| `21F8h..21FEh` | состояние/параметры режима |
| `2240h/2241h` | таймеры/счетчики радио-последовательностей |
| `2253h/2254h` | параметры radio/PLL state-machine |
| `2256h` | сохранение/восстановление `65h` state |

Подтверждение канала проходит через `L3C0F`:

```text
3C0F: A = RAM[72h] & 0Fh
3C13: RAM[7Ch] = A
3C18: MOVX[218Dh] = A
3C1C: MOVX[21DAh] = A
3C1D: LCALL L0410
3C20: LCALL L045A
3C23: SETB 25h.2
3C25: CLR 2Ch.7
```

`L0410` и `L045A` выглядят как пересчет индекса канала в набор параметров,
которые затем используются другими обработчиками. Это следующий кандидат для
подробного разбора частотных таблиц.

## Oscilloscope / logic-analyzer checks

To isolate the PLL HAL, capture these signals while changing channels `0..8`:

1. `P3.5` - external latch strobe.
2. `P1[7:0]` - latch/control byte.
3. MC145156P2 serial pins if reachable: data, clock, load/enable, lock detect.
4. `P1.1/P1.2/P1.3/P3.4` - firmware handshaked bit protocol candidate.
5. `APPEL`/PTT as a separate capture, so TX enable is not mixed with channel programming.

Priority signals for MC145156P2:

- serial data/clock/load should carry a programming word when the channel changes.
- `LD` should indicate lock after the channel is programmed.
- `P1[7:0]` + `P3.5` may control PLL enable, TX/RX, mute, filters, or support logic.
- compare channel `0..8` captures and look for the bits that change with channel number.

Minimal firmware test after the autonomous demo:

- show the received raw key code;
- on `0..8`, change only an internal channel variable;
- manually call a small set of latch/serial candidates and watch which MC145156P2 or control-bus lines change.

## Подтвержденная граница собственной прошивки

Тест `ORIGINAL_INIT_CUSTOM_KEYCODE.HEX` подтвердил важную границу:

- оригинальный startup от `0026h` до `034Ch` нужен для оживления панели;
- после `034Ch` можно не запускать оригинальный dispatcher `L585F`;
- custom loop с прямым `RI/SBUF` и прямой отправкой кадров экрана работает;
- функциональные клавиши больше не обязаны запускать штатные радио-функции,
  если не передавать управление оригинальному обработчику `24h.4`.

Это означает, что текущий рабочий baseline для новой прошивки:

```text
original startup/init до 034Ch
-> custom firmware loop
```

Дальше нужно постепенно заменить startup-блок на документированные HAL-вызовы:

1. ранняя latch-последовательность;
2. инициализация внешней RAM/state, нужная панели;
3. Timer/UART setup;
4. минимальный wakeup/первый display frame.

Для поиска минимального нужного префикса startup собрана серия образов
`demo_panel/build/INITCUT_xxxx.HEX`. Каждый образ выполняет оригинальный startup
только до адреса `xxxx`, затем запускает тот же custom loop `DEMO 02` / `KEY xx`.
UART/timer init теперь выполняется внутри custom loop, поэтому срезы до `026Fh`
тоже валидны.

Рекомендуемый порядок проверки:

```text
INITCUT_0075.HEX
INITCUT_01B3.HEX
INITCUT_026F.HEX
INITCUT_0318.HEX
INITCUT_034C.HEX
```

После первого рабочего образа нужно проверить соседние срезы и сузить границу.
