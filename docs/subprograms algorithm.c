prog_t getProgram(line) {
    prog_t prog;
    uint8_t progIndex = amountOfPrograms;
    uint16_t outputLine = prog.endingLine - prog.startingLine;
    
    while (progIndex--) {
        prog = programs[progIndex - 1];
        
        if (line >= prog.startingLine && line <= prog.endingLine) {
            return prog;
        }
    }
}