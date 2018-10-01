{prog, line} = getProgAndLine(line) {
    prog_t prog;
    uint8_t progIndex = amountOfPrograms;
    uint16_t outputLine = prog.endingLine - prog.startingLine;
    
    while (progIndex--) {
        prog = programs[progIndex - 1];
        
        if (line >= prog.startingLine && line <= prog.endingLine) {
            while (++progIndex != amountOfPrograms) {
                prog_t prog2 = programs[progIndex];
                
                if (prog.depth + 1 == prog2.depth && prog2.startingLine >= prog.startingLine && prog2.endingLine <= prog.endingLIne) {
                    outputLine -= prog2.endingLine - prog2.startingLine + 1;
                }
            }
            
            return [prog, line];
        }
    }
}