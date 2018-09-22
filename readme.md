# ICE Debugger
A debugger for ICE Compiler. It's not so stable though, and not done yet. Note that the output program will be slightly bigger than normal.

## Usage
When you compile a program with debug mode on, the compiled program automatically checks if the debugger is loaded on the calculator, and if so, sets up. *If the debugger is not present, the program will just quit without any warning!* To set a breakpoint anywhere in the code, use `dbd(0)` (which opens the debugger).

Empty lines (i.e. comments, Lbl) will be ignored and you won't be able to place a breakpoint on them nor step to it.

Main menu: press `[UP]` and `[DOWN]` to select an option and `[ENTER]` to go to that option. `[CLEAR]` will return to the program. Options: 
1. Step through code: this is probably the most interesting one. With this option you can step through your source code, allowing the program to run line by line. In between these lines you can look at and edit variables, view the screen and much more! Press `[UP]` or `[DOWN]` to select a line. If you press `[ENTER]` it will either insert a breakpoint at or remove it from this line. Suboptions:
    * _Step_: continue one line. If you're currently at an If, Repeat, While, For(, Goto or Call statement, it might jump to another line, like the call address. Otherwise it will just advance one line or return.
    * _Step Over_: this is pretty much the same as _Step_, except that Call's will be skipped, so a subroutine is called, it returns and then you can continue stepping.
    * _Step Next_: this is more useful: you always step to the next line. This looks similar to _Step_, but is different regarding to control flow statements. This is the only way to get out loops (press _Step Next_ at End). Note that the next line may not always be reached, for example when you Return or you pressed _Step Next_ on an If-statement which is false!
    * _Quit_: return from stepping and goes back to the main menu.
    
2. View/edit variables: another quite useful feature! Here you can take a look at all your variables, what their values are and change them. Press `[UP]` and `[DOWN]` to select a variable (note that if you have more than 25 used variables, you can scroll too), press `[ENTER]` to edit a variable and `[CLEAR]` to return. Editing a variable is very easy: just type in the digits and press `[ENTER]` again. Now the variable has a new value.

3. View/edit memory: here you can view and edit your memory (RAM-only). This might be useful if you want to look at the VAT or sneak peek at the OS code. Press the arrow keys to navigate through the memory, press `[ENTER]` to jump to a memory address (then type in the hexadecimals), or `[CLEAR]` to return to the main menu. If you press any of the hexadecimals, the byte will be immediately changed, without option to revert it, so be careful!

4. View OS strings: _not implemented yet._

5. View OS lists: _not implemented yet._

6. View opened slots: here you can see all information about the opened slots (used with file i/o operations). Take a look at the slot number, type, name, data pointer, size and offset directly! There is no way to change any of these values. Press any key to return to the main menu.

7. View screen: take a quick look at the current screen, how it looks like. Note that this is different from the buffer if you use double-buffering. Press any key to return to the main menu.

8. View buffer: take a quick look at the current buffer, how it looks like. If you use double-buffering, this is the place where all graphics will be drawn to. Press any key to return to the main menu.

9. Jump to label: instantly jump to any label within your program! Select `[UP]` and `[DOWN]` to select a label (if you have more than 25 labels, you can scroll too). Please be really careful with jumping to/from a subroutine, as this will mess up the stack. `[CLEAR]` will return to the main menu.

10. Save exit program: did you accidentally mess up the stack? No worries, this option directly returns to the OS without caring about the stack! This option will also immediately quit the debugger.

11. Quit: quit the debugger. Pressing any key doesn't help.
