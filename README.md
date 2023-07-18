# lua-basic

## Syntax



## Examples

### If 1 + 1 = 2, the Hello, else Bye

```text
ADD 1 1
SETVAL VAL1 $OUTPUT
CHGTYPE 2 NUM
EQ $OUTPUT $VAL1
IFGOTO $OUTPUT 1
GOTO 2
LBL 1
ECHO Hello\20World
HALT 0
LBL 2
ECHO Bye\20World
HALT 1
```

```text
Execution traceback:
#1 1: ADD | 1 | 1
        -> 2 (number)
#2 2: SETVAL | VAL1 | $OUTPUT
        @  $OUTPUT = 2 (number)
#3 3: CHGTYPE | 2 | NUM
        -> 2 (number)
#4 4: EQ | $OUTPUT | $VAL1
        @  $VAL1 = 2 (number)
        @  $OUTPUT = 2 (number)
        -> true (boolean)
#5 5: IFGOTO | $OUTPUT | 1
        @  $OUTPUT = true (boolean)
        -> GOTO 7
#6 8: ECHO | Hello World
#7 9: HALT | 0
```