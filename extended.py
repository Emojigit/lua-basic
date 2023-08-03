# This Python script handles extended Lua BASIC syntax.
# It transforms extended Lua BASIC codes into simple codes.

# FUNC syntax:
#  FUNC <name>: start of the function
#  FUNCEND: end of the function
#  FUNCRTN <val>: Set val $FUNCRTN to <val> and do FUNCEND
#  CALLFUNC <name> [<param> ...]: call FUNC <name> with params
#  $FUNCPARAM<int>: params, <int> start from 1
# Reserved vars:
#  $FUNCRTNGOTO, $FUNCRTN, $FUNCPARAM<int>

import sys

input, output = sys.stdin, sys.stdout

if len(sys.argv) >= 2:
    input = open(sys.argv[1],"r")
    if len(sys.argv) >= 3:
        output = open(sys.argv[2],"w")

func_to_lbl = {}
infunc = False
funclbl = 0
funcrtnlbl = 0

all_lines = [l.strip() for l in input.readlines()]
input.close()

outputs = []
def out(cmd): 
    outputs.append(cmd)

for line in all_lines:
    if line == "" or line[0] == "#":
        out(line)
        continue
    cmd = line.split()
    if cmd[0] == "FUNC":
        if infunc == True:
            raise Exception("FUNC in FUNC")
        if cmd[1] in func_to_lbl:
            raise Exception("two FUNC with same name")
        infunc = True
        out("# FUNC " + cmd[1])
        out("GOTO SKIPFUNC" + str(funclbl))
        out("LBL FUNC" + str(funclbl))
        func_to_lbl[cmd[1]] = funclbl
    elif cmd[0] == "FUNCRTN":
        out("SETVAL FUNCRTN " + cmd[1])
        out("GOTO $FUNCRTNGOTO")
    elif cmd[0] == "FUNCEND":
        if infunc == False:
            raise Exception("FUNCEND not after FUNC")
        out("GOTO $FUNCRTNGOTO")
        out("LBL SKIPFUNC" + str(funclbl))
        out("# FUNCEND")
        infunc = False
        funclbl += 1
    elif cmd[0] == "CALLFUNC":
        if cmd[1] not in func_to_lbl:
            raise Exception("FUNC " + cmd[1] + "Not found")
        for i,v in enumerate(cmd[2:]):
            out("SETVAL FUNCPARAM" + str(i+1) + " " + v)
        lbl = "FUNCRTNGOTO" + str(funcrtnlbl)
        out("SETVAL FUNCRTNGOTO " + lbl)  
        out("GOTO FUNC" + str(func_to_lbl[cmd[1]]))   
        out("LBL " + lbl)
        funcrtnlbl += 1
    else:
        out(line)

if infunc == True: 
    raise Exception("FUNC never ended")

out("")
output.write("\n".join(outputs))
output.close()
