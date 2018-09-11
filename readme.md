# ICE Debugger
A debugger for ICE Compiler. It's not so stable though, and not done yet. Note that the output program will be slightly bigger than normal.

## Usage
When you compile a program with debug mode on, the compiled program automatically checks if the debugger is loaded on the calculator, and if so, sets up. *If the debugger is not present, the program will just quit without any warning!* To set a breakpoint anywhere in the code, use `dbd(0)`.

Empty lines (i.e. comments, Lbl) will be ignored and you won't be able to place a breakpoint on them nor step to it.