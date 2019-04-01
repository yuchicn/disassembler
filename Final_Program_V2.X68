*****************************************************************************
* Easy 68K Disassembler *****************************************************
* Spring CSS422 *************************************************************
* Coded By: Calvin Evans, Sujit Neupane, and Jay (Yu-Chi Chen) **************
*****************************************************************************

*****************************************************************************
*SET BASE VALUES*************************************************************
****************|***********|***************|********************************
PRG_SP          EQU         $00005000       Disassembler stack location
ST_DATA         EQU         $00008000       Start of user data (min address)
EN_DATA         EQU         $00FFFFFE       Last possible data address
CR              EQU         $0D
LF              EQU         $0A

*****************************************************************************
*LOAD PROGRAM START LOCATION*************************************************
****************|***********|***************|********************************
DISA_PRG        ORG         $00001000     
LD_A7           LEA         PRG_SP,SP       Set stack address  

*****************************************************************************
*WELCOME MESSAGE SPLASH PAGE*************************************************
****************|***********|***************|********************************
WELCOME         LEA         WELCOME_MSG,A1  Prepare welcome message
                MOVEQ       #14,D0          Move trap task to registry
                TRAP        #15             Perform output operation
                
*****************************************************************************
*USER INPUTS*****************************************************************
****************|***********|***************|********************************
START_PROMPT    LEA         START_IN,A1     Load start address message
                MOVEQ       #14,D0          Load task for user prompt message
                TRAP        #15             Display message
                LEA         USER_START,A1   Load input variable
                MOVEQ       #2,D0           Load user input trap task
                TRAP        #15             Get start of data
                JSR         DECODE_IN       Decode user input string
                CMP.B       #1,D4           Check for valid input
                BEQ         PASS1           Input is good
                
                LEA         ADDR_ERROR,A1   Load address range error message
                MOVEQ       #14,D0          Load task for message output
                TRAP        #15             Display error message
                JMP         START_PROMPT    Redo input
                
PASS1           JSR         CHK_ODD         Check odd or even input
                CMP.B       #$1,D3          Check if address was odd
                BEQ         START_PROMPT    Return to start address input
                MOVE.L      #ST_DATA,D6     Load starting address (Minimum)
                CMP.L       D6,D3           Check for valid address input
                BLT         S_ADDR_ERR      Address not in range (LOW)
                MOVE.L      #EN_DATA,D6     Load ending address (Maximum)
                CMP.L       D6,D3           Check for valid address input
                BGT         S_ADDR_ERR      Address not in range (HIGH)
                MOVEA.L     D3,A5           Move start address to A5
                
END_PROMPT      LEA         END_IN1,A1      Load end address message
                MOVEQ       #14,D0          Load task message output
                TRAP        #15             Display message
                LEA         USER_START,A1   Load start address for output
                MOVEQ       #1,D0           Load task code for address out
                MOVEQ       #8,D1           Load start address length
                TRAP        #15             Display start address
                LEA         END_IN2,A1      Load end address message 2
                MOVEQ       #14,D0          Load task code for prompt message
                TRAP        #15             Display input prompt message
                LEA         USER_END,A1     Load input variable
                MOVEQ       #2,D0           Load user input trap task
                TRAP        #15             Get end of data
                JSR         DECODE_IN       Decode user input string
                CMP.B       #1,D4           Check for valid input
                BEQ         PASS2           Input is good
                LEA         ADDR_ERROR,A1   Load address range error message
                MOVEQ       #14,D0          Load task for message output
                TRAP        #15             Display error message
                JMP         END_PROMPT      Redo input
                
PASS2           JSR         CHK_ODD         Check address for odd/even input
                CMP.B       #$1,D3          Check if address was odd
                BEQ         END_PROMPT      Return to end address input
                CMP.L       D6,D3           Check input within upper bound
                BGT         E_ADDR_ERROR    Address is not within range(HIGH)
                CMP.L       A5,D3           Check input within lower bound
                BLT         E_ADDR_ERROR    Address is not within range (LOW)
                MOVE.L      D3,D6           Copy end address to D6
                SUB.L       A5,D6           Calculate maximum instructions
                DIVU.W      #$2,D6          
                ANDI.L      #$0000FFFF,D6   
                
*****************************************************************************
*PREP CODE FOR DISASSEMBLY***************************************************
****************|***********|***************|********************************
IO_PROC         MOVE.L      A5,D5           Move start address to D5
                MOVEQ       #$1,D4          Set check value at D4
                MOVEQ       #$0,D3          Reset D3     
                LEA         GD_BUFF,A4      Load A4 buffer
                LEA         BD_BUFF,A3      Load A3 buffer
                JSR         SET_BUFFER      Set values to buffers
                MOVEQ       #$1,D4          Set check value at D4
                MOVEQ       #$0,D3          Reset D3
                JSR         FILL_A4         Prep A4 buffer for output
                JSR         FILL_A3         Prep A3 buffer for output
                JSR         BUFFER_A3       Move data to A3 buffer
                LEA         MAX_LINES,A0    Set value to max lines
                JSR         PG_CNTR         Handler for lines per page
                MOVE.B      #$00,(A3)       Push null char to A3
                MOVE.W      (A5)+,D7        Fetch next instruction
                JSR         DISASSEMBLE     Do work
                CMP.B       #$1,D4          Check error bit at D4
                BGE         PASSED          
FAILED          LEA         BD_BUFF,A1      Load buffer to display failed code
                BRA         PRINT_PAGE      Print contents of buffer
PASSED          MOVE.B      #$00,(A4)       Push null character to A4 buffer
                LEA         GD_BUFF,A1      Load buffer to display valid code
PRINT_PAGE      MOVEQ       #13,D0          Load trap code
                TRAP        #15             Execute trap task
                DBRA        D6,IO_PROC      Decrement and branch until match
RPT             LEA         REPEAT_MSG,A1   Prep repeat message
                MOVE.L      #14,D0          Move trap task to D0
                TRAP        #15             Display repeat message
                LEA         LINES,A2        Reset line counter
                MOVE.B      #00,(A2)        
                LEA         REPEAT,A1       Collect user input
                MOVE.L      #2,D0           
                TRAP        #15
                CMP.B       #$59,(A1)       Check if CAPITAL Y entered
                BEQ         START_PROMPT    
                CMP.B       #$79,(A1)       Check if little y entered
                BEQ         START_PROMPT
                CMP.B       #$4E,(A1)       Check if CAPITAL N entered
                BEQ         CMPLT
                CMP.B       #$6E,(A1)       Check if little n entered
                BEQ         CMPLT
                LEA         REPEAT_ERROR,A1 Prep error message
                MOVE.L      #14,D0          Move trap task to D0
                TRAP        #15             Display error message
                BRA         RPT
CMPLT           JSR         MISSION_CMP     Show ending and close program
                MOVE.B      #9,D0
                TRAP        #15

*****************************************************************************
*FILL DATA - PREP BUFFERS****************************************************
****************|***********|***************|********************************
FILL_A4         JSR         A4_6SPACES      Fill A4 spaces
                RTS
                
FILL_A3         MOVE.B      #' ',(A3)+      Invalid data tag
                MOVE.B      #' ',(A3)+
                MOVE.B      #'I',(A3)+ 
                MOVE.B      #'N',(A3)+ 
                MOVE.B      #'V',(A3)+ 
                MOVE.B      #'A',(A3)+ 
                MOVE.B      #'L',(A3)+ 
                MOVE.B      #'I',(A3)+ 
                MOVE.B      #'D',(A3)+ 
                MOVE.B      #' ',(A3)+ 
                MOVE.B      #'O',(A3)+ 
                MOVE.B      #'P',(A3)+ 
                MOVE.B      #'C',(A3)+ 
                MOVE.B      #'O',(A3)+ 
                MOVE.B      #'D',(A3)+ 
                MOVE.B      #'E',(A3)+
                MOVE.B      #' ',(A3)+ 
                MOVE.B      #' ',(A3)+ 
                MOVE.B      #'$',(A3)+ 
                RTS
                
*****************************************************************************
*I/O MESSAGES****************************************************************
****************|***********|***************|********************************
START_IN        DC.B        'Please enter your starting address'
                DC.B        ' ($00008000 to $00FFFFFE): ',CR,LF,0
END_IN1         DC.B        'Please enter your ending address ($',0
END_IN2         DC.B        ' to $00FFFFFE): ',CR,LF,0
ADDR_ERROR      DC.B        ' Address entered is not within the specified'
                DC.B        ' range',CR,LF,0
ODD_MSG         DC.B        ' You entered an odd address. Addresses must be'
                DC.B        ' even numbers',CR,LF,0
NXT_PAGE        DC.B        'When you finish looking at this data, press'
                DC.B        ' ENTER to go to next page ',CR,LF,0
REPEAT_MSG      DC.B        'This data has been disassembled. Do you have'
                DC.B        ' more data? (Y/N)',CR,LF,0
REPEAT_ERROR    DC.B        'You have not entered a valid command. '
                DC.B        '(Y/N)',CR,LF,0


*****************************************************************************
*VARIABLES AND BUFFERS*******************************************************
****************|***********|***************|********************************
LINES           DC.B        0
MAX_LINES       DC.B        80
BD_BUFF         DS.B        80
GD_BUFF         DS.B        80
USER_START      DS.B        80
USER_END        DS.B        80
CONTINUE        DS.B        80
REPEAT          DS.B        80

*****************************************************************************
*WELCOME MESSAGE SPLASH PAGE*************************************************
****************|***********|***************|********************************
WELCOME_MSG     DC.B        '***********************************************'
                DC.B        '*********************',CR,LF
                DC.B        '***********************************************'
                DC.B        '*********************',CR,LF
                DC.B        '**                   TTTTTT EEEE  AA  M   M    '
                DC.B        '                   **',CR,LF
                DC.B        '**                     TT   E    A  A MM MM    '
                DC.B        '                   **',CR,LF                                           
                DC.B        '**                     TT   EEE  AAAA M M M    '
                DC.B        '                   **',CR,LF                                       
                DC.B        '**                     TT   E    A  A M   M    '
                DC.B        '                   **',CR,LF                                    
                DC.B        '**                     TT   EEEE A  A M   M    '
                DC.B        '                   **',CR,LF                                    
                DC.B        '**                                             '
                DC.B        '                   **',CR,LF                                                       
                DC.B        '**                                             '
                DC.B        '                   **',CR,LF                                                
                DC.B        '**                          BBBB   11          '
                DC.B        '                   **',CR,LF                                                      
                DC.B        '**                          B   B 111          '
                DC.B        '                   **',CR,LF                                                 
                DC.B        '**                          BBBB   11          '
                DC.B        '                   **',CR,LF                                                   
                DC.B        '**                          B   B  11          '
                DC.B        '                   **',CR,LF                                                 
                DC.B        '**                          BBBB  11l1         '
                DC.B        '                   **',CR,LF                                                 
                DC.B        '**                                             '
                DC.B        '                   **',CR,LF                                              
                DC.B        '**                                             '
                DC.B        '                   **',CR,LF                                               
                DC.B        '**DDD  III  SSS   AA   SSS   SSS  EEEE M   M BB'
                DC.B        'BB  L    EEEE RRRR **',CR,LF
                DC.B        '**D  D  I  S     A  A S     S     E    MM MM B '
                DC.B        '  B L    E    R   R**',CR,LF
                DC.B        '**D  D  I   SSS  AAAA  SSS   SSS  EEE  M M M BB'
                DC.B        'BB  L    EEE  RRRR **',CR,LF
                DC.B        '**D  D  I      S A  A     S     S E    M   M B '
                DC.B        '  B L    E    R R  **',CR,LF
                DC.B        '**DDD  III SSSS  A  A SSSS  SSSS  EEEE M   M BB'
                DC.B        'BB  LLLL EEEE R  RR**',CR,LF
                DC.B        '***********************************************'
                DC.B        '*********************',CR,LF
                DC.B        '***********************************************'
                DC.B        '*********************',CR,LF
                DC.B        '  EASY 68K MOTOROLA DISASSEMBLER / CODED BY CAL'
                DC.B        'VIN, SUJIT, AND JAY  ',CR,LF,0

*****************************************************************************
*END MESSAGE SPLASH SCREEN***************************************************
****************|***********|***************|********************************
DARTH_ENDER     DC.B        '                       .-.                     ',CR,LF
                DC.B        '                      |_:_|                    ',CR,LF
                DC.B        '                     /(_Y_)\                   ',CR,LF
                DC.B        '                    ( \/M\/ )                  ',CR,LF
                DC.B        ' `.               _.|-/|-|\-|._                ',CR,LF
                DC.B        '   `:           _/.--|[[[[]|--.\_              ',CR,LF
                DC.B        '     `:        /_`  : |::"| :  `.\             ',CR,LF
                DC.B        '       `:     //   ./ |oUU| \.`  :\            ',CR,LF
                DC.B        '         `:  _:|..| \_|___|_/ :   :|           ',CR,LF
                DC.B        '           `:.  .`  |_[___]_|  :.`:\           ',CR,LF
                DC.B        '            [::\ |  :  | |  :   ; : \          ',CR,LF
                DC.B        '             |-|   \/`.| |.` \  .;.` |         ',CR,LF
                DC.B        '             |\_    \  |-|   :       |         ',CR,LF
                DC.B        '             |  \    \ .:    :   |   |         ',CR,LF
                DC.B        '             |   \    | `.   :    \  |         ',CR,LF
                DC.B        '             /       \   :. .;       |         ',CR,LF
                DC.B        '            /     |   |  :__/     :  \\        ',CR,LF
                DC.B        '           |  |   |    \:   | \   |   ||       ',CR,LF
                DC.B        '          /    \  : :  |:   /  |__|   /|       ',CR,LF
                DC.B        '          |     : : :_/_|  /`._\  `--|_\       ',CR,LF
                DC.B        '          /___.-/_|-`   \  \                   ',CR,LF
                DC.B        '                         ._.                   ',CR,LF
                DC.B        'Thank you for Disassembling with us, and...... ',CR,LF
                DC.B        'May The Force Be With You!                     ',CR,LF,0

*****************************************************************************
*DECODE_IN*******************************************************************
****************|***********|***************|********************************
DECODE_IN       CLR         D3              
                CLR         D5              
                CMP.B       D5,D1           Check input too low
                BEQ         INPUT_ERR       Bad input
                CMPI        #$9,D1          Check input too high
                BGE         INPUT_ERR       Bad input
DECODE          MOVE.B      (A1)+,D2        
                CMP.B       D5,D2           Check for null character
                BEQ         VALID_INPUT
                CMP.B       #$7A,D2         Check if lower case ASCII
                BGT         INPUT_ERR       
                CMP.B       #$61,D2         
                BGE         LWR_ASCII       Convert lower ASCII
                CMP.B       #$5A,D2         Check if upper case ASCII
                BGT         INPUT_ERR
                CMP.B       #$41,D2         
                BGE         UPR_ASCII       Convert upper ASCII
                CMP.B       #$39,D2         Check if ASCII numeral
                BGT         INPUT_ERR
                CMP.B       #$30,D2         
                BLT         INPUT_ERR
                SUBI.B      #$30,D2         Convert ASCII number
                BRA         CHAR_SHFT           
LWR_ASCII       SUBI.B      #$20,D2         Turn lower to upper
UPR_ASCII       SUBI.B      #$37,D2         
CHAR_SHFT       ASL.L       #4,D3           
                ADD.B       D2,D3           Fill decoded address
                BRA         DECODE          
INPUT_ERR       BRA         ERROR_1         
                RTS
VALID_INPUT     MOVEQ       #$1,D4          Decode Complete
                RTS

*****************************************************************************
*START ADDRESS NOT IN RANGE ERROR********************************************
****************|***********|***************|********************************
S_ADDR_ERR      LEA     ADDR_ERROR,A1       Load address input error message
                MOVEQ   #14,D0              Load output code
                TRAP    #15                 Display Message
                JMP     START_PROMPT        Prompt for new input
            
*****************************************************************************
*END ADDRESS NOT IN RANGE ERROR**********************************************
****************|***********|***************|********************************
E_ADDR_ERROR    LEA         ADDR_ERROR,A1   Load address input 
                MOVE.L      #14,D0          Load output code
                TRAP        #15             Display Message
                JMP         END_PROMPT      Prompt for new input
                
*****************************************************************************
*CHECK INPUT ADDRESS (ODD/EVEN)**********************************************
****************|***********|***************|********************************
CHK_ODD         CLR         D2              Clear data register
                MOVE.W      D3,D2           Place address into D2
                ANDI.W      #$1,D2          Find if address ends in a 1
                CMP.B       #$01,D2         Check if the value in D2 is 1
                BEQ         ODD_ERROR       Branch to error subroutine
                RTS                         Address is even 
ODD_ERROR       LEA         ODD_MSG,A1      Prep error message
                MOVEQ       #14,D0          Load task number
                TRAP        #15             Display error message
                MOVEQ       #$1,D3          Setup error state
                RTS

*****************************************************************************
*DISASSEMBLE*****************************************************************
****************|***********|***************|********************************
DISASSEMBLE     MOVE.W      D7,D5           Copy word data of OPCODE into D5
                LSR.W       #$8,D5          Shift first hex into LSB position
                LSR.W       #$4,D5          
                JSR         OPCODES         Decode first 4 bits
DISASSEMBLED    RTS                         Return to top function

*****************************************************************************
*OPCODES*********************************************************************
****************|***********|***************|********************************
OPCODES         CMPI.B      #$0,D5     
                BEQ         D_0000          OPCODES beginning with 0000
                CMPI.B      #$1,D5
                BEQ         D_0001          OPCODES beginning with 0001
                CMPI.B      #$2,D5
                BEQ         D_0010          OPCODES beginning with 0010
                CMPI.B      #$3,D5
                BEQ         D_0011          OPCODES beginning with 0011
                CMPI.B      #$4,D5
                BEQ         D_0100          OPCODES beginning with 0100
                CMPI.B      #$5,D5
                BEQ         D_0101          OPCODES beginning with 0101
                CMPI.B      #$6,D5
                BEQ         D_0110          OPCODES beginning with 0110
                CMPI.B      #$7,D5
                BEQ         D_0111          OPCODES beginning with 0111
                CMPI.B      #$8,D5
                BEQ         D_1000          OPCODES beginning with 1000
                CMPI.B      #$9,D5
                BEQ         D_1001          OPCODES beginning with 1001
                CMPI.B      #$B,D5
                BEQ         D_1011          OPCODES beginning with 1011
                CMPI.B      #$C,D5
                BEQ         D_1100          OPCODES beginning with 1100
                CMPI.B      #$D,D5
                BEQ         D_1101          OPCODES beginning with 1101
                CMPI.B      #$E,D5
                BEQ         D_1110          OPCODES beginning with 1110
                BRA         ERROR_1         Reset for error checking
                JMP         OPCODES_DONE

OPCODES_DONE    RTS

*****************************************************************************
*FILL MOVE*******************************************************************
****************|***********|***************|********************************
FILL_MOVE       MOVE.B      #'M',(A4)+      Push opcode into A4 buffer
                MOVE.B      #'O',(A4)+
                MOVE.B      #'V',(A4)+ 
                MOVE.B      #'E',(A4)+ 
                RTS
                
*****************************************************************************
*D_0000**********************************************************************
****************|***********|***************|********************************
D_0000          MOVE.W      D7,D5           Move word data of OPCODE to D5
                LSR.W       #$8,D5          Get 2nd hexabit
                ANDI        #$000F,D5       Isolate LSB
                JSR         BIT_TWO         
                JMP         OPCODES_DONE
                
*****************************************************************************
*D_0001 - MOVEQ**************************************************************
****************|***********|***************|********************************
D_0001          MOVEQ       #$1,D3          Set D3 for validation of MOVEQ
                JSR         FILL_MOVE 
                MOVE.B      #'.',(A4)+ 
                MOVE.B      #'B',(A4)+ 
                JSR         A4_6SPACES
                JSR         EFFECTIVE_ADDR  Find effective address
                CMPI.B      #$1,D3          Validate Mode
                BNE         ERROR_1         Branch to error state
VALID_0001      JMP         OPCODES_DONE

*****************************************************************************
*D_0010 - MOVE.L/MOVEA.L*****************************************************
****************|***********|***************|********************************
D_0010          MOVEQ       #$1,D3          Set check value in D3
                JSR         FILL_MOVE 
                JSR         GET_REG         Get reg number
                ADDQ        #$1,D4
                CMPI        #$1,D2          Check MOVE or MOVEA instruction
                BEQ         D_0010_A
                MOVE.B      #'.',(A4)+      Push size into A4 buffer
                MOVE.B      #'L',(A4)+
                MOVE.B      #' ',(A4)+
D_0010_SPACES   MOVE.B      #' ',(A4)+      Push spaces into A4 buffer
                MOVE.B      #' ',(A4)+
                MOVE.B      #' ',(A4)+
                MOVE.B      #' ',(A4)+
                MOVE.B      #' ',(A4)+
                JSR         EFFECTIVE_ADDR  Find effective address
                JMP         OPCODES_DONE
D_0010_A        MOVE.B      #'A',(A4)+      Push A into A4 buffer
                MOVE.B      #'.',(A4)+      Push size into A4 buffer
                MOVE.B      #'L',(A4)+
                JMP         D_0010_SPACES   Skips one space to account for A

*****************************************************************************
*D_0011 - MOVE.L/MOVEA.L*****************************************************
****************|***********|***************|********************************
D_0011          MOVEQ       #$1,D3          Set check value in D3
                JSR         FILL_MOVE
                JSR         GET_REG         Get reg number
                CMPI        #$1,D2          Check if MOVE or MOVEA instruction
                BEQ         D_0011_A        
                MOVE.B      #'.',(A4)+      Push size into A4 buffer
                MOVE.B      #'W',(A4)+
                MOVE.B      #' ',(A4)+
D_0011_SPACES   MOVE.B      #' ',(A4)+      Push spaces into A4 buffer
                MOVE.B      #' ',(A4)+
                MOVE.B      #' ',(A4)+
                MOVE.B      #' ',(A4)+
                MOVE.B      #' ',(A4)+
                JSR         EFFECTIVE_ADDR  Find effective address
                JMP         OPCODES_DONE
D_0011_A        MOVE.B      #'A',(A4)+      Push A into A4 buffer
                MOVE.B      #'.',(A4)+
                MOVE.B      #'W',(A4)+
                JMP         D_0011_SPACES   Skips one space to account for A

*****************************************************************************
*D_0100**********************************************************************
****************|***********|***************|********************************
D_0100          MOVE.W      D7,D5           Load instruction
                LSR.W       #$8,D5          
                ANDI        #$000F,D5       
                JSR         BIT_THREE       Jump to next disassembly step
                JMP         OPCODES_DONE
                
*****************************************************************************
*D_0101**********************************************************************
****************|***********|***************|********************************
D_0101          MOVE.W      D7,D2           Check if instruction is SUBQ
                ANDI.W      #$0100,D2
                CMP.W       #$0100,D2
                BEQ         ERROR_1         SUBQ will not be disassembled
                MOVE.B      #'A',(A4)+      Push ADDQ to A4 buffer   
                MOVE.B      #'D',(A4)+
                MOVE.B      #'D',(A4)+
                MOVE.B      #'Q',(A4)+
                JSR         A4_6SPACES      Push data to A4 buffer
                MOVE.B      #' ',(A4)+
                MOVE.B      #' ',(A4)+
                MOVE.B      #'#',(A4)+
                MOVE.B      #'$',(A4)+
                JSR         GET_REG2        Get immediate data (1-8)
                CMPI.B      #$0,D2
                BEQ         PRINT_8        
                JSR         PUSH_REG_NUM    
D_0101_FINISH   MOVE.B      #',',(A4)+
                BRA         EFFECTIVE_ADDR  Get effective address
PRINT_8         MOVE.B      #'8',(A4)+
                JMP         D_0101_FINISH

*****************************************************************************
*D_0110**********************************************************************
****************|***********|***************|********************************
D_0110          MOVE.W      D7,D5           Load instruction
                LSR.W       #$8,D5          
                ANDI        #$000F,D5
                JSR         BIT_FOUR        Continue disassembly
                JMP         OPCODES_DONE
                
*****************************************************************************
*D_0111**********************************************************************
****************|***********|***************|********************************
D_0111          MOVE.W      D7,D5           Load instruction
                LSR.W       #$8,D5           
                ANDI        #$0001,D5       Check for MOVEQ command
                CMPI.W      #$0,D5          
                BEQ         D_MOVEQ     
                BRA         ERROR_1         Cannot disassemble further
                RTS
D_MOVEQ         MOVE.B      #'M',(A4)+      Push MOVEQ into A4 buffer
                MOVE.B      #'O',(A4)+
                MOVE.B      #'V',(A4)+ 
                MOVE.B      #'E',(A4)+   
                MOVE.B      #'Q',(A4)+
                JSR         A4_6SPACES
                MOVE.B      #' ',(A4)+
                MOVE.B      #'#',(A4)+
                JSR         GET_OFFSET      Get 8-bit offset data
                MOVE.B      #',',(A4)+      Push data register into buffer A4
                MOVE.B      #'D',(A4)+ 
                JSR         GET_REG2 
                JSR         PUSH_REG_NUM    Get registry number     
                JMP         OPCODES_DONE
                
*****************************************************************************
*D_1000**********************************************************************
****************|***********|***************|********************************
D_1000          JSR         GET_REG         Get data registry
                JSR         BIT_FIVE        Continue decoding this OPCODE
                JMP         OPCODES_DONE
         
*****************************************************************************
*D_1001**********************************************************************
****************|***********|***************|********************************
D_1001          JSR         GET_REG         Get reg number
                JSR         BIT_NINE        Continue disassembly
                JMP         OPCODES_DONE
                
*****************************************************************************
*D_1011**********************************************************************
****************|***********|***************|********************************
D_1011          JSR         GET_REG         Get reg number
                JSR         BIT_SEVEN       Continue disassembly
                JMP         OPCODES_DONE

*****************************************************************************
*D_1100**********************************************************************
****************|***********|***************|********************************
D_1100          MOVE.W      D7,D2           Move current OPCODE from D7 to D2
                LSR.W       #$3,D2          
                ANDI        #$003F,D2       Chop off remaining bits
                JSR         GET_REG         Get registry data
                JSR         BIT_SIX         Continue decoding this OPCODE
                JMP         OPCODES_DONE

*****************************************************************************
*D_1101**********************************************************************
****************|***********|***************|********************************
D_1101          JSR         GET_REG         Get reg number
                JSR         BIT_EIGHT       Continue disassembly
                JMP         OPCODES_DONE
                
*****************************************************************************
*D_1110**********************************************************************
****************|***********|***************|********************************
D_1110          JSR         DATA_SIZE       Get size of data
                CMPI.B      #$0,D2         Check for shift byte data
                BEQ         D_S_BYTE
                CMPI.B      #$1,D2          Check for shift word data
                BEQ         D_S_WORD 
                CMPI.B      #$2,D2          Check for shift longword data
                BEQ         D_S_LONG 
                MOVE.W      D7,D2           Move current OPCODE to D2
                LSR.W       #$8,D2          Move bits 9-10 into position
                LSR.W       #$1,D2
                ANDI        #$0003,D2       Chop off unneeded data
                CMPI.B      #$0,D2          Check A(arithmetic) shift
                BEQ         D_ARITH
                CMPI.B      #$1,D2          Check L(logical) shift
                BEQ         D_LOGIC
                JSR         BIT_RANGE_8      
                CMPI.B      #$0,D2          Check rotate right instruction
                BEQ         D_ROR 
                MOVE.B      #'R',(A4)+      Push ROL to A4 buffer
                MOVE.B      #'O',(A4)+ 
                MOVE.B      #'L',(A4)+
                MOVE.B      #' ',(A4)+
                BRA         D_MEMSHFT       Branch to addressing 
D_ROR           MOVE.B      #'R',(A4)+      Push ROR to A4 buffer
                MOVE.B      #'O',(A4)+ 
                MOVE.B      #'R',(A4)+ 
                MOVE.B      #' ',(A4)+
                BRA         D_MEMSHFT       Branch to addressing
D_LOGIC         JSR         BIT_RANGE_8     
                CMPI.B      #$0,D2          Check if LSR instruction
                BEQ         D_LSR 
                MOVE.B      #'L',(A4)+      Push LSL to A4 buffer
                MOVE.B      #'S',(A4)+
                MOVE.B      #'L',(A4)+ 
                MOVE.B      #' ',(A4)+
                BRA         D_MEMSHFT       Branch to addressing
D_LSR           MOVE.B      #'L',(A4)+      Push LSR to A4 buffer
                MOVE.B      #'S',(A4)+
                MOVE.B      #'R',(A4)+ 
                MOVE.B      #' ',(A4)+
                BRA         D_MEMSHFT       Branch to addressing
D_ARITH         JSR         BIT_RANGE_8     
                CMPI.B      #$0,D2          Check if ASR instruction
                BEQ         D_ASR
                MOVE.B      #'A',(A4)+      Push ASL to A4 buffer
                MOVE.B      #'S',(A4)+
                MOVE.B      #'L',(A4)+
                MOVE.B      #' ',(A4)+
                BRA         D_MEMSHFT       Branch to addressing
D_ASR           MOVE.B      #'A',(A4)+      Push ASR to A4 buffer
                MOVE.B      #'S',(A4)+
                MOVE.B      #'R',(A4)+
                MOVE.B      #' ',(A4)+
                BRA         D_MEMSHFT       Branch to addressing
D_MEMSHFT       JSR         A4_6SPACES      Push spaces into A4 buffer
                MOVE.B      #' ',(A4)+
                MOVE.B      #' ',(A4)+
                JSR         EFFECTIVE_ADDR  Find effective address
                CMPI.B      #$1,D3          Check valid address mode
                BEQ         ERROR_1         Invalid mode
                JMP         OPCODES_DONE
D_S_BYTE        JSR         BIT_RANGE_3TO4  
                CMPI.B      #$0,D2          Check arithmetic shift
                BEQ         D_ASB
                CMPI.B      #$1,D2          Check logical shift
                BEQ         D_LSB
                JSR         BIT_RANGE_8     
                CMPI.B      #$0,D2          Check rotate right 
                BEQ         D_RORB
                MOVE.B      #'R',(A4)+      Push ROL.B to A4 buffer
                MOVE.B      #'O',(A4)+
                MOVE.B      #'L',(A4)+
                JSR         D_1110_B
                BRA         D_COMP_1110     Complete disassembly
D_RORB          MOVE.B      #'R',(A4)+      Push ROR.B to A4 buffer
                MOVE.B      #'O',(A4)+
                MOVE.B      #'R',(A4)+
                JSR         D_1110_B
                BRA         D_COMP_1110     Complete disassembly
D_LSB           JSR         BIT_RANGE_8     
                CMPI.B      #$0,D2          Check for LSR
                BEQ         D_LSRB
                MOVE.B      #'L',(A4)+      Push LSL.B to A4 buffer
                MOVE.B      #'S',(A4)+
                MOVE.B      #'L',(A4)+
                JSR         D_1110_B
                BRA         D_COMP_1110     Complete disassembly
D_LSRB          MOVE.B      #'L',(A4)+      Push LSR.B to A4 buffer
                MOVE.B      #'S',(A4)+
                MOVE.B      #'R',(A4)+
                JSR         D_1110_B
                BRA         D_COMP_1110     Complete disassembly
D_ASB           JSR         BIT_RANGE_8     
                CMPI.B      #$0,D2          Check for ASR
                BEQ         D_ASRB          
                MOVE.B      #'A',(A4)+      Push ASL.B to A4 buffer
                MOVE.B      #'S',(A4)+
                MOVE.B      #'L',(A4)+
                JSR         D_1110_B
                BRA         D_COMP_1110     Complete disassembly
D_ASRB          MOVE.B      #'A',(A4)+      Push ASR.B to A4 buffer
                MOVE.B      #'S',(A4)+
                MOVE.B      #'R',(A4)+
                JSR         D_1110_B
                BRA         D_COMP_1110     Complete disassembly
D_S_WORD        JSR         BIT_RANGE_3TO4  
                CMPI.B      #$0,D2          Check if arithmetic shift
                BEQ         D_ASW
                CMPI.B      #$1,D2          Check if logical shift
                BEQ         D_LSW
                JSR         BIT_RANGE_8     
                CMPI.B      #$0,D2          Check if rotate right
                BEQ         D_RORW
                MOVE.B      #'R',(A4)+      Push ROL.W to A4 buffer
                MOVE.B      #'O',(A4)+
                MOVE.B      #'L',(A4)+
                JSR         D_1110_W
                BRA         D_COMP_1110     Complete disassembly
D_RORW          MOVE.B      #'R',(A4)+      Push ROR.W to A4 buffer
                MOVE.B      #'O',(A4)+
                MOVE.B      #'R',(A4)+
                JSR         D_1110_W
                BRA         D_COMP_1110     Complete disassembly
D_LSW           JSR         BIT_RANGE_8     
                CMPI.B      #$0,D2          Check if LSR.W
                BEQ         D_LSRW
                MOVE.B      #'L',(A4)+      Push LSR.W to A4 buffer
                MOVE.B      #'S',(A4)+      
                MOVE.B      #'L',(A4)+ 
                JSR         D_1110_W
                BRA         D_COMP_1110     Complete disassembly
D_LSRW          MOVE.B      #'L',(A4)+      Push LSR.W to A4 buffer
                MOVE.B      #'S',(A4)+
                MOVE.B      #'R',(A4)+
                JSR         D_1110_W
                BRA         D_COMP_1110     Complete disassembly
D_ASW           JSR         BIT_RANGE_8     
                CMPI.B      #$0,D2          Check arithmetic shift right
                BEQ         D_ASRW
                MOVE.B      #'A',(A4)+      Push ASL.W into A4 buffer
                MOVE.B      #'S',(A4)+
                MOVE.B      #'L',(A4)+
                JSR         D_1110_W
                BRA         D_COMP_1110     Complete disassembly
D_ASRW          MOVE.B      #'A',(A4)+      Push ASL.W into A4 buffer
                MOVE.B      #'S',(A4)+
                MOVE.B      #'R',(A4)+
                JSR         D_1110_W
                BRA         D_COMP_1110     Complete disassembly
D_S_LONG        JSR         BIT_RANGE_3TO4  
                CMPI.B      #$0,D2          Check if arithmetic shift 
                BEQ         D_ASL
                CMPI.B      #$1,D2          Check if logical shift
                BEQ         D_LSL
                JSR         BIT_RANGE_8     
                CMPI.B      #$0,D2          Check if ROR.L
                BEQ         D_RORL
                MOVE.B      #'R',(A4)+      Push ROL.L to A4 buffer
                MOVE.B      #'O',(A4)+
                MOVE.B      #'L',(A4)+
                JSR         D_1110_L
                BRA         D_COMP_1110     Complete disassembly
D_RORL          MOVE.B      #'R',(A4)+      Push ROL.L to A4 buffer
                MOVE.B      #'O',(A4)+
                MOVE.B      #'R',(A4)+
                JSR         D_1110_L
                BRA         D_COMP_1110     Complete disassembly
D_LSL           JSR         BIT_RANGE_8     
                CMPI.B      #$0,D2          Check if LSR.L
                BEQ         D_LSRL
                MOVE.B      #'L',(A4)+      Push LSL.L to A4 buffer
                MOVE.B      #'S',(A4)+
                MOVE.B      #'L',(A4)+
                JSR         D_1110_L
                BRA         D_COMP_1110     Complete disassembly
D_LSRL          MOVE.B      #'L',(A4)+      Push LSR.L to A4 buffer
                MOVE.B      #'S',(A4)+
                MOVE.B      #'R',(A4)+
                JSR         D_1110_L
                BRA         D_COMP_1110     Complete disassembly
D_ASL           JSR         BIT_RANGE_8     
                CMPI.B      #$0,D2          Check if ASR.L
                BEQ         D_ASR_L
                MOVE.B      #'A',(A4)+      Push ASL.L to A4 buffer
                MOVE.B      #'S',(A4)+
                MOVE.B      #'L',(A4)+
                JSR         D_1110_L
                BRA         D_COMP_1110     Complete disassembly
D_ASR_L         MOVE.B      #'A',(A4)+      Push ASR.L to A4 buffer
                MOVE.B      #'S',(A4)+
                MOVE.B      #'L',(A4)+
                JSR         D_1110_L
                BRA         D_COMP_1110     Complete disassembly
D_1110_B        MOVE.B      #'.',(A4)+      Push Byte B to A4 buffer
                MOVE.B      #'B',(A4)+
                MOVE.B      #' ',(A4)+
                RTS
D_1110_W        MOVE.B      #'.',(A4)+      Push Word W to A4 buffer
                MOVE.B      #'W',(A4)+
                MOVE.B      #' ',(A4)+
                RTS
D_1110_L        MOVE.B      #'.',(A4)+      Push Longword L to A4 buffer
                MOVE.B      #'L',(A4)+
                MOVE.B      #' ',(A4)+
                RTS
D_COMP_1110     JSR         A4_6SPACES      Push spaces to A4 buffer
                MOVE.W      D7,D2           Move the current OPCODE to D2
                LSR.W       #$5,D2          Shift the 5th bit into position
                ANDI.W      #$0001,D2       Chop off unneeded data
                CMPI.B      #$1,D2          Check if shift size in register
                BEQ         D_REGSHIFT
                MOVE.W      D7,D2           Move current OPCODE to D2
                MOVE.B      #'#',(A4)+           
                LSL.W       #$4,D2          
	            LSR.W       #$8,D2
	            LSR.W       #$5,D2
                JSR         PUSH_REG_NUM        
                BRA         D_COMP2_1110    Complete disassembly
D_REGSHIFT      MOVE.B      #'D',(A4)+      Push D to A4 buffer
                JSR         GET_REG2        Registry number
                JSR         PUSH_REG_NUM    Get reg number
D_COMP2_1110    MOVE.B      #',',(A4)+      Push ,D to A4 buffer
                MOVE.B      #'D',(A4)+      
                MOVE.W      D7,D2           Move current OPCODE from D7 to D2
                ANDI        #$0007,D2       Chop off unneeded data
                JSR         PUSH_REG_NUM    Push registry number to A4 buffer
                JMP         OPCODES_DONE

*****************************************************************************
*BIT_TWO - DECODE SECOND HEX*************************************************
****************|***********|***************|********************************
BIT_TWO         CMPI.B      #$4,D5    
                BEQ         D2_0100         Decode SUBI   
                CMPI.B      #$6,D5
                BEQ         D2_0110

BIT_TWO_DONE    RTS

*****************************************************************************
*D2_0100 - SUBI**************************************************************
****************|***********|***************|********************************
D2_0100         MOVE.B      #'S',(A4)+      Push SUBI into A4 buffer
                MOVE.B      #'U',(A4)+
                MOVE.B      #'B',(A4)+
                MOVE.B      #'I',(A4)+
                MOVE.B      #'.',(A4)+
                JSR         IMM_DATA        Get immediate data
                JMP         BIT_TWO_DONE

*****************************************************************************
*D2_0110 - ADDI**************************************************************
****************|***********|***************|********************************
D2_0110         MOVE.B      #'A',(A4)+      Push ADDI into A4 buffer
                MOVE.B      #'D',(A4)+
                MOVE.B      #'D',(A4)+
                MOVE.B      #'I',(A4)+
                MOVE.B      #'.',(A4)+
                JSR         IMM_DATA        Get immediate data
                JMP         BIT_TWO_DONE         
                
*****************************************************************************
*BIT_THREE*******************************************************************
****************|***********|***************|********************************
BIT_THREE       CMPI.B      #$1,D5          Possible LEA instruction
                BEQ         D3_0001 
                CMPI.B      #$2,D5          CLR instruction
                BEQ         D3_0010
                CMPI.B      #$3,D5          Possible LEA instruction
                BEQ         D3_0001
                CMPI.B      #$5,D5          Possible LEA instruction
                BEQ         D3_0001
                CMPI.B      #$7,D5          Possible LEA instruction
                BEQ         D3_0001
                CMPI.B      #$8,D5          MOVEM instruction
                BEQ         D3_MOVEM
                CMPI.B      #$9,D5          Possible LEA instruction
                BEQ         D3_0001
                CMPI.B      #$B,D5          Possible LEA instruction
                BEQ         D3_0001
                CMPI.B      #$C,D5          MOVEM instruction
                BEQ         D3_MOVEM
                CMPI.B      #$D,D5          Possible LEA instruction
                BEQ         D3_0001
                CMPI.B      #$E,D5          Possible JMP/JSR/NOP/RTS
                BEQ         D3_1110
                CMPI.B      #$F,D5          Possible LEA instruction
                BEQ         D3_0001                
                BRA         ERROR_1
            
BIT_THREE_DONE  RTS

*****************************************************************************
*D3_0001 - LEA***************************************************************
****************|***********|***************|********************************
D3_0001         JSR         DATA_SIZE       Get size of data
                CMP.B       #$3,D2          Check if LEA instruction
                BEQ         LEA_INS         Decode LEA instruction
                BRA         ERROR_1
                RTS
                
*****************************************************************************
*D3_0010 - CLR***************************************************************
****************|***********|***************|********************************
D3_0010         MOVE.B      #'C',(A4)+      Push CLR to A4 buffer
                MOVE.B      #'L',(A4)+
                MOVE.B      #'R',(A4)+
                MOVE.B      #'.',(A4)+
                JSR         DATA_SIZE       Get size of data
                CMP.W       #$0,D2          Check if byte data
                BEQ         D3_0010B
                CMP.W       #$1,D2          Check if word data
                BEQ         D3_0010W
                CMP.W       #$2,D2          Check if longword data
                BEQ         D3_0010L
D3_0010E        BRA         ERROR_1         
                JMP         BIT_THREE_DONE 
D3_0010S        JSR         A4_6SPACES      Push spaces to A4 buffer
                MOVE.B      #' ',(A4)+ 
                JSR         EFFECTIVE_ADDR  Find effective address
                CMPI.B      #$1,D3          Check for valid mode
                BEQ         D3_0010E
                RTS
D3_0010B        MOVE.B      #'B',(A4)+      Push B to A4 buffer
                BRA         D3_0010S
D3_0010W        MOVE.B      #'W',(A4)+      Push W to A4 buffer
                BRA         D3_0010S
D3_0010L        MOVE.B      #'L',(A4)+      Push L to A4 buffer
                BRA         D3_0010S

*****************************************************************************
*D3_MOVEM - MOVEM SETUP FUNCTION*********************************************
****************|***********|***************|********************************
D3_MOVEM        JSR         FILL_MOVE       Push MOVEM to A4 buffer
                MOVE.B      #'M',(A4)+  
                MOVE.B      #'.',(A4)+    
                JSR         DATA_SIZE       Get size of data
                CMP.B       #$2,D2          Check if MOVEM.W
                BEQ         D3_MOVEMW
                CMP.B       #$3,D2          Check if MOVEM.L
                BEQ         D3_MOVEML
                BRA         ERROR_1
D3_MOVEMW       MOVE.B      #'W',(A4)+      Size info for word data
                BRA         MOVEM_SPACE
D3_MOVEML       MOVE.B      #'L',(A4)+      Size info for longword data
MOVEM_SPACE     MOVE.B      #' ',(A4)+
                MOVE.B      #' ',(A4)+
                MOVE.B      #' ',(A4)+
                MOVE.B      #' ',(A4)+
                MOVE.B      #' ',(A4)+
                MOVE.W      D7,D5
                AND.W       #$000F,D5
                CMP.W       #$0008,D5       Check if REG to PTR instruction
                BGE         MOVEM_CONT
                JSR         MOVEM_FLIP      Flip binary bits and store at D1
                BRA         MOVEM_CONT1
MOVEM_CONT      CLR         D1              Continue disassembly
                MOVE.W      (A5),D1
MOVEM_CONT1     MOVE.W      D7,D5
                ANDI.W      #$0F00,D5
                CMP.W       #$0800,D5
                BNE         MOVEM_CHKPTR    Check Address PTR instruction
                JSR         MOVEM_REG       Branch to Registries instruction
                RTS
MOVEM_CHKPTR    CMP.W       #$0C00,D5
                BNE         ERROR_1
                JSR         MOVEM_PTR       Branch to Address PTR instruction
                RTS
                
*****************************************************************************
*MOVEM_REG - CLONE REG TO MEMORY*********************************************
****************|***********|***************|********************************
MOVEM_REG       CMPI.W      #$0000,D1       Check valid register data
                BEQ         ERROR_1
                CLR         D3              Set local variable for 'D'
                CMPI.B      #$00,D1         Check if Data Registers in input
                BEQ         MOVEM_REGA      Branch input Address Registers
                JSR         MOVEM_PUSHR     Branch input Data Registers
                MOVE.W      D5,D1
                LSR.W       #$8,D1
                CMP.B       #$00,D1         Check Address Registers in input
                BEQ         MOVEM_REGM      Branch second half of instruction
                MOVE.B      #'/',(A4)+
MOVEM_REGA      MOVE.W      D5,D1
                LSR.W       #$8,D1
                CMP.B       #$00,D1         Check Address Registers in input
                BEQ         MOVEM_REGM      Branch second half of instruction
                MOVEQ       #$1,D3          Set local variable for 'A'
                JSR         MOVEM_PUSHR     Branch input Address Registers
MOVEM_REGM      MOVE.B      #',',(A4)+
                MOVE.W      D7,D5
                LSL.W       #$4,D5
                CMP.B       #$80,D5         Check Address or Register PTR
                BGE         MOVEM_S         Branch to Absolute Address
                LSR.B       #$4,D5
                CLR         D2
                MOVE.B      D5,D2
                JSR         GET_EA_100      Branch to Effective Address
                ADDA.L      #$2,A5
                SUBI        #$1,D6
                JMP         MOVEM_RET       Complete
MOVEM_S         MOVE.B      #'$',(A4)+
                MOVE.W      D7,D5
                ANDI.W      #$000F,D5
                CMP.B       #$08,D5
                BEQ         MOVEM_REGW      Fill output with word size data
                ADDA.L      #$2,A5
                SUBI        #$1,D6
                JSR         PUSH_L          Fill output longword size data
                ADDA.L      #$4,A5
                SUBI        #$2,D6
                RTS                         Complete
MOVEM_REGW      ADDA.L      #$2,A5
                SUBI        #$1,D6
                JSR         PUSH_W          Fill output with word size data
                ADDA.L      #$2,A5
                SUBI        #$1,D6
                JMP         MOVEM_RET       Complete

*****************************************************************************
*MOVEM_PTR - FILL REG FROM MEMORY********************************************
****************|***********|***************|********************************
MOVEM_PTR       MOVE.W      D7,D5
                AND.W       #$00F0,D5
                CMPI.B      #$B0,D5
                BEQ         MOVEM_PTR2
                CMPI.B      #$F0,D5
                BEQ         MOVEM_PTR2
                CLR         D2
                MOVE.W      D7,D2
                AND.W       #$000F,D2
                SUBI.B      #$8,D2
                JSR         GET_EA_011
                MOVE.W      (A5),D1
                ADDA.L      #$2,A5
                SUBI        #$1,D6
                BRA         MOVEM_PTRD
MOVEM_PTR2      MOVE.B      #'$',(A4)+
                MOVE.W      D7,D5
                ANDI.W      #$000F,D5
                CMP.B       #$08,D5
                BEQ         MOVEM_PTRW
                MOVE.W      (A5),D1
                ADDA.L      #$2,A5
                SUBI        #$1,D6
                JSR         PUSH_L
                ADDA.L      #$4,A5
                SUBI        #$2,D6
                JMP         MOVEM_PTRD
MOVEM_PTRW      MOVE.W      (A5),D1
                ADDA.L      #$2,A5
                SUBI        #$1,D6
                JSR         PUSH_W
                ADDA.L      #$2,A5
                SUBI        #$1,D6
MOVEM_PTRD      CLR         D3
                MOVE.B      #',',(A4)+
                CMPI.W      #$0000,D1
                BEQ         ERROR_1
                CMPI.B      #$00,D1
                BEQ         MOVEM_PTRA
                JSR         MOVEM_PUSHR
MOVEM_PTRA      MOVE.W      D5,D1
                LSR.W       #$8,D1
                MOVEQ       #$1,D3
                CMP.B       #$00,D1
                BEQ         MOVEM_PTRC
                MOVE.B      #'/',(A4)+
                JSR         MOVEM_PUSHR
MOVEM_PTRC      RTS       
             

*****************************************************************************
*MOVEM_PUSHR: PUSH REG TO A4 PRINT BUFFER************************************
****************|***********|***************|********************************
MOVEM_PUSHR     CLR         D0
                MOVE.W      D1,D5
                ANDI.W      #$000F,D1
                CMP.B       #$0,D1
                BEQ         MOVEM_R4
MOVEM_R0        ANDI.W      #$1,D1
                CMPI.B      #$1,D1
                BNE         MOVEM_R1       
                JSR         MOVEM_AORD
                MOVE.B      #'0',(A4)+
                MOVEQ       #$1,D0
MOVEM_R1        MOVE.W      D5,D1
                ANDI.W      #$0002,D1
                CMPI.B      #$2,D1
                BNE         MOVEM_R2
                CMPI.B      #$1,D0
                BNE         MOVEM_R1C
                MOVE.B      #$2,D0
                MOVE.W      D5,D1
                ANDI.W      #$0004,D1
                CMPI.B      #$4,D1
                BNE         MOVEM_R1CS
                JMP         MOVEM_R2
MOVEM_R1CS      MOVE.B      #'-',(A4)+
MOVEM_R1C       JSR         MOVEM_AORD
                MOVE.B      #$2,D0
                MOVE.B      #'1',(A4)+ 
MOVEM_R2        MOVE.W      D5,D1
                ANDI.W      #$0004,D1
                CMPI.B      #$4,D1
                BNE         MOVEM_R3
                CMPI.B      #$2,D0
                BNE         MOVEM_R2C
                MOVE.B      #$4,D0
                MOVE.W      D5,D1
                ANDI.W      #$0008,D1
                CMPI.B      #$8,D1
                BNE         MOVEM_R2CD
                JMP         MOVEM_R3
MOVEM_R2CD      MOVE.B      #'-',(A4)+
                JMP         MOVEM_R2C1
MOVEM_R2C       CMPI.B      #$0,D0
                BEQ         MOVEM_R2C1
                MOVE.B      #'/',(A4)+
MOVEM_R2C1      JSR         MOVEM_AORD
                MOVE.B      #$4,D0
                MOVE.B      #'2',(A4)+ 
MOVEM_R3        MOVE.W      D5,D1
                ANDI.W      #$0008,D1
                CMPI.B      #$8,D1
                BNE         MOVEM_R4
                CMPI.B      #$4,D0
                BNE         MOVEM_R3C
                MOVE.B      #$8,D0
                MOVE.W      D5,D1
                ANDI.W      #$0010,D1
                CMPI.B      #$10,D1
                BNE         MOVEM_R3CD
                JMP         MOVEM_R4
MOVEM_R3CD      MOVE.B      #'-',(A4)+
                JMP         MOVEM_R3C1
MOVEM_R3C       CMPI.B      #$0,D0
                BEQ         MOVEM_R3C1
                MOVE.B      #'/',(A4)+
MOVEM_R3C1      JSR         MOVEM_AORD
                MOVE.B      #$8,D0
                MOVE.B      #'3',(A4)+ 
MOVEM_R4        MOVE.W      D5,D1
                ANDI.W      #$0010,D1
                CMP.B       #$10,D1
                BNE         MOVEM_R5
                CMPI.B      #$8,D0
                BNE         MOVEM_R4C
                MOVE.B      #$10,D0
                MOVE.W      D5,D1
                ANDI.W      #$0020,D1
                CMP.B       #$20,D1
                BNE         MOVEM_R4CD
                JMP         MOVEM_R5
MOVEM_R4CD      MOVE.B      #'-',(A4)+
                JMP         MOVEM_R4C1
MOVEM_R4C       CMPI.B      #$0,D0
                BEQ         MOVEM_R4C1
                MOVE.B      #'/',(A4)+
MOVEM_R4C1      JSR         MOVEM_AORD
                MOVE.B      #$10,D0
                MOVE.B      #'4',(A4)+
MOVEM_R5        MOVE.W      D5,D1
                ANDI.W      #$0020,D1
                CMP.B       #$20,D1
                BNE         MOVEM_R6
                CMPI.B      #$10,D0
                BNE         MOVEM_R5C
                MOVE.B      #$20,D0
                MOVE.W      D5,D1
                ANDI.W      #$0040,D1
                CMP.B       #$40,D1
                BNE         MOVEM_R5CD
                JMP         MOVEM_R6
MOVEM_R5CD      MOVE.B      #'-',(A4)+
                JMP         MOVEM_R5C1
MOVEM_R5C       CMPI.B      #$0,D0
                BEQ         MOVEM_R5C1
                MOVE.B      #'/',(A4)+
MOVEM_R5C1      JSR         MOVEM_AORD
                MOVE.B      #$20,D0
                MOVE.B      #'5',(A4)+
MOVEM_R6        MOVE.W      D5,D1
                ANDI.W      #$0040,D1
                CMP.B       #$40,D1
                BNE         MOVEM_R7
                CMPI.B      #$20,D0
                BNE         MOVEM_R6C
                MOVE.B      #$40,D0
                MOVE.W      D5,D1
                ANDI.W      #$0080,D1
                CMP.B       #$80,D1
                BNE         MOVEM_R6CD
                JMP         MOVEM_R7
MOVEM_R6CD      MOVE.B      #'-',(A4)+
                JMP         MOVEM_R6C1
MOVEM_R6C       CMPI.B      #$0,D0
                BEQ         MOVEM_R6C1
                MOVE.B      #'/',(A4)+
MOVEM_R6C1      JSR         MOVEM_AORD
                MOVE.B      #$40,D0
                MOVE.B      #'6',(A4)+
MOVEM_R7        MOVE.W      D5,D1
                ANDI.W      #$0080,D1
                CMP.B       #$80,D1
                BNE         MOVEM_RET
                CMPI.B      #$40,D0
                BNE         MOVEM_R7C
                JMP         MOVEM_R7CD
                RTS
MOVEM_R7CD      MOVE.B      #'-',(A4)+
                JMP         MOVEM_R7C1
MOVEM_R7C       CMPI.B      #$0,D0
                BEQ         MOVEM_R7C1
                MOVE.B      #'/',(A4)+
MOVEM_R7C1      JSR         MOVEM_AORD
                MOVE.B      #'7',(A4)+
MOVEM_RET       RTS
                
MOVEM_AORD      CMPI.B      #$0,D3
                BNE         MOVEM_ANOTD
                MOVE.B      #'D',(A4)+
                RTS
MOVEM_ANOTD     MOVE.B      #'A',(A4)+
                RTS
     
*****************************************************************************
*MOVEM_FLIP: FLIPS THE BITS OF THE REGISTRY DATA FOR REG INTO POINTER********
****************|***********|***************|********************************
MOVEM_FLIP      CLR         D0
                CLR         D1
                MOVE.W      (A5),D0
                AND.W       #$000F,D0       Get least significant bit
                JSR         DO_FLIP         Flip binary bits
                ROL.W       #$4,D1          Move to most significant
                MOVE.W      (A5),D0         
                ROR.W       #$4,D0          
                AND.W       #$000F,D0       Get 3rd bit
                JSR         DO_FLIP         Flip binary bits
                ROL.W       #$4,D1          Move to bit 2
                MOVE.W      (A5),D0
                ROR.W       #$8,D0
                AND.W       #$000F,D0       Get 2nd bit
                JSR         DO_FLIP         Flip binary bits
                ROL.W       #$4,D1          Move to bit3
                MOVE.W      (A5),D0
                ROR.W       #$8,D0
                ROR.W       #$4,D0
                AND.W       #$000F,D0       Get most significant bit
                JSR         DO_FLIP         Flip binary bits
                RTS                         Return inverted binary code

DO_FLIP         CMPI.B      #$0,D0          Read 0
                BNE         DO_FLIP1
                ADD.B       #$00,D1         Write 0
                RTS      
DO_FLIP1        CMPI.B      #$1,D0          Read 1
                BNE         DO_FLIP2
                ADD.B       #$08,D1         Write 8
                RTS
DO_FLIP2        CMPI.B      #$2,D0          Read 2
                BNE         DO_FLIP3
                ADD.B       #$04,D1         Write 4
                RTS
DO_FLIP3        CMPI.B      #$3,D0          Read 3
                BNE         DO_FLIP4
                ADD.B       #$0C,D1         Write C
                RTS
DO_FLIP4        CMPI.B      #$4,D0          Read 4
                BNE         DO_FLIP5
                ADD.B       #$02,D1         Write 2
                RTS
DO_FLIP5        CMPI.B      #$5,D0          Read 5
                BNE         DO_FLIP6
                ADD.B       #$0A,D1         Write A
                RTS
DO_FLIP6        CMPI.B      #$6,D0          Read 6
                BNE         DO_FLIP7
                ADD.B       #$06,D1         Write 6
                RTS
DO_FLIP7        CMPI.B      #$7,D0          Read 7
                BNE         DO_FLIP8
                ADD.B       #$0E,D1         Write E
                RTS
DO_FLIP8        CMPI.B      #$8,D0          Read 8
                BNE         DO_FLIP9
                ADD.B       #$01,D1         Write 1
                RTS
DO_FLIP9        CMPI.B      #$9,D0          Read 9
                BNE         DO_FLIPA
                ADD.B       #$09,D1         Write 9
                RTS
DO_FLIPA        CMPI.B      #$A,D0          Read A
                BNE         DO_FLIPB
                ADD.B       #$05,D1         Write 5
                RTS
DO_FLIPB        CMPI.B      #$B,D0          Read B
                BNE         DO_FLIPC
                ADD.B       #$0D,D1         Write D
                RTS
DO_FLIPC        CMPI.B      #$C,D0          Read C
                BNE         DO_FLIPD
                ADD.B       #$03,D1         Write 3
                RTS
DO_FLIPD        CMPI.B      #$D,D0          Read D
                BNE         DO_FLIPE
                ADD.B       #$0B,D1         Write B
                RTS
DO_FLIPE        CMPI.B      #$E,D0          Read E
                BNE         DO_FLIPF
                ADD.B       #$07,D1         Write 7
                RTS
DO_FLIPF        CMPI.B      #$F,D0          Read F
                BNE         ERROR_1
                ADD.B       #$0F,D1         Write F
                RTS                
           
*****************************************************************************
*D3_1110*********************************************************************
****************|***********|***************|********************************
D3_1110         JSR         DATA_SIZE       Get size of data
                CMP.B       #$2,D2          Check if JSR instruction
                BEQ         D3_1110JSR
                CMP.B       #$3,D2          Check if JMP instruction
                BEQ         D3_1110JMP
                CMP.B       #$1,D2          Check if NOP or RTS instruction
                BEQ         D3_1110NOPRTS
                BRA         ERROR_1
                RTS         
D3_1110JMP      MOVE.B      #'J',(A4)+      Push JMP to A4 buffer
                MOVE.B      #'M',(A4)+ 
                MOVE.B      #'P',(A4)+ 
                JSR         A4_6SPACES 
                MOVE.B      #' ',(A4)+ 
                MOVE.B      #' ',(A4)+ 
                MOVE.B      #' ',(A4)+ 
                JSR         EFFECTIVE_ADDR  Find effective address
                CMP.B       #$0,D4          Check for error state
                BEQ         ERROR_1 
                CMP.B       #$0,D3          Check for valid addressing mode
                BEQ         ERROR_1         
                CMP.B       #$1,D3
                BEQ         ERROR_1
                CMP.B       #$3,D3
                BEQ         ERROR_1
                CMP.B       #$4,D3
                BEQ         ERROR_1
                RTS 
D3_1110JSR      MOVE.B      #'J',(A4)+      Push JSR to A4 buffer
                MOVE.B      #'S',(A4)+
                MOVE.B      #'R',(A4)+
                JSR         A4_6SPACES
                MOVE.B      #' ',(A4)+
                MOVE.B      #' ',(A4)+
                MOVE.B      #' ',(A4)+
                JSR         EFFECTIVE_ADDR  Find effective address
                CMP.B       #$0,D4          Check for error state
                BEQ         ERROR_1 
                CMP.B       #$0,D5          Check for valid addressing mode
                BEQ         ERROR_1
                CMP.B       #$1,D5
                BEQ         ERROR_1 
                CMP.B       #$3,D5
                BEQ         ERROR_1 
                CMP.B       #$4,D5
                BEQ         ERROR_1 
                RTS
D3_1110NOPRTS   MOVE.W      D7,D2           Move current OPCODE from D7 to D2
                ANDI        #$0007,D2       Chop off unneeded data
                CMP.B       #$1,D2          Check if NOP instruction
                BEQ         D3_1110NOP
                CMP.B       #$5,D2          Check if RTS instruction
                BEQ         D3_1110RTS  
                BRA         ERROR_1
                RTS
D3_1110NOP      MOVE.B      #'N',(A4)+      Push NOP to A4 buffer
                MOVE.B      #'O',(A4)+ 
                MOVE.B      #'P',(A4)+
                RTS
D3_1110RTS      MOVE.B      #'R',(A4)+      Push RTS to A4 buffer
                MOVE.B      #'T',(A4)+
                MOVE.B      #'S',(A4)+
                RTS

*****************************************************************************
*BIT_FOUR********************************************************************
****************|***********|***************|********************************
BIT_FOUR        CMPI.B      #$4,D5          Check if instruction is 0100      
                BEQ         D4_0100        
                CMPI.B      #$E,D5          Check if instruction is 1110
                BEQ         D4_1110
                CMPI.B      #$F,D5          Check if instruction is 1111                
                BEQ         D4_1111
                JSR         ERROR_1
BIT_FOUR_DONE   RTS

*****************************************************************************
*D4_0100 - BCC INSTRUCTION***************************************************
****************|***********|***************|********************************
D4_0100         MOVE.B      #'B',(A4)+      Push BCC to A4 buffer
                MOVE.B      #'C',(A4)+
                MOVE.B      #'C',(A4)+
                BRA         BRA_ADDR        Get branch address

*****************************************************************************
*D4_1110*********************************************************************
****************|***********|***************|********************************
D4_1110         MOVE.B      #'B',(A4)+      Push BGT into buffer A4
                MOVE.B      #'G',(A4)+      
                MOVE.B      #'T',(A4)+   
                BRA         BRA_ADDR        Get branch address

*****************************************************************************
*D4_1111*********************************************************************
****************|***********|***************|********************************
D4_1111         MOVE.B      #'B',(A4)+      Push BLE to A4 buffer
                MOVE.B      #'L',(A4)+
                MOVE.B      #'E',(A4)+
                BRA         BRA_ADDR        Get branch address

*****************************************************************************
*BIT_FIVE********************************************************************
****************|***********|***************|********************************
BIT_FIVE        CMPI.B      #$0,D2          Check if data at D2 is 000               
                BEQ         D5_000
                CMPI.B      #$1,D2          Check if data at D2 is 001               
                BEQ         D5_001
                CMPI.B      #$2,D2          Check if data at D2 is 010               
                BEQ         D5_010
                CMPI.B      #$3,D2          Check if data at D2 is 011
                BEQ         D5_011
                CMPI.B      #$4,D2          Check if data at D2 is 100               
                BEQ         D5_100
                CMPI.B      #$5,D2          Check if data at D2 is 101               
                BEQ         D5_101
                CMPI.B      #$6,D2          Check if data at D2 is 110               
                BEQ         D5_110
                JSR         ERROR_1
BIT_FIVE_DONE   RTS

*****************************************************************************
*FILL_OR: SAVES ON LINES OF CODE*********************************************
****************|***********|***************|********************************
FILL_OR         MOVE.B      #'O',(A4)+      Push OR to A4 buffer
                MOVE.B      #'R',(A4)+
                MOVE.B      #'.',(A4)+
                RTS
                
*****************************************************************************
*D5_000 - OR.B INSTRUCTION: INTO DATA REG************************************
****************|***********|***************|********************************
D5_000          JSR         FILL_OR      Push OR.B to A4 buffer
                MOVE.B      #'B',(A4)+
                MOVE.L      #$FFFFFFFF,D0
                JMP         D5_HLPR1
                
*****************************************************************************
*D5_001 - OR.W INSTRUCTION: INTO DATA REG************************************
****************|***********|***************|********************************
D5_001          JSR         FILL_OR      Push OR.W to A4 buffer
                MOVE.B      #'W',(A4)+
                JMP         D5_HLPR1

*****************************************************************************
*D5_010 - OR.L INSTRUCTION: INTO DATA REG************************************
****************|***********|***************|********************************
D5_010          JSR         FILL_OR      Push OR.L to A4 buffer
                MOVE.B      #'L',(A4)+
                ADDQ.W      #$1,D4
                JMP         D5_HLPR1
                
*****************************************************************************
*D5_011 - DIVU INSTRUCTION: INTO DATA REG************************************
****************|***********|***************|********************************
D5_011          MOVE.B      #'D',(A4)+      Push DIVU to A4 buffer
                MOVE.B      #'I',(A4)+
                MOVE.B      #'V',(A4)+
                MOVE.B      #'U',(A4)+
                JMP         D5_HLPR1

*****************************************************************************
*D5_HLPR: FILL IN SECOND PART OF INSTRUCTION*********************************
****************|***********|***************|********************************
D5_HLPR1        JSR         A4_6SPACES      Push spaces to A4 buffer
                MOVE.B      #' ',(A4)+
                MOVE.B      #' ',(A4)+
                JSR         EFFECTIVE_ADDR  Find effective address
                CMPI.B      #$0,D4          Check error state
                BEQ         ERROR_1
                CMPI.B      #$1,D3          Check valid address mode
                BEQ         ERROR_1
                MOVE.B      #',',(A4)+      Push data register to A4 buffer
                MOVE.B      #'D',(A4)+
                JSR         GET_REG2
                JSR         PUSH_REG_NUM    Push registry number to A4 buffer
                JMP         BIT_FIVE_DONE
                
D5_HLPR2        JSR         A4_6SPACES      Push spaces to A4 buffer
                MOVE.B      #' ',(A4)+
                MOVE.B      #' ',(A4)+
                MOVE.B      #'D',(A4)+
                JSR         GET_REG2        Get data reg number

                JSR         PUSH_REG_NUM    Push registry number to A4 buffer
                MOVE.B      #',',(A4)+
                JSR         EFFECTIVE_ADDR  Find effective address
                CMPI.B      #$0,D4          Check error state
                BEQ         ERROR_1
                CMPI.B      #$1,D3          Check valid address mode
                BEQ         ERROR_1
                JMP         BIT_FIVE_DONE

*****************************************************************************
*D5_100 - OR.B INSTRUCTION: INTO EFFECTIVE ADDRESS***************************
****************|***********|***************|********************************
D5_100          JSR         FILL_OR      Push OR.B to A4 buffer
                MOVE.B      #'B',(A4)+
                JMP         D5_HLPR2
                
*****************************************************************************
*D5_101 - OR.W INSTRUCTION: INTO EFFECTIVE ADDRESS***************************
****************|***********|***************|********************************
D5_101          JSR         FILL_OR      Push OR.W to A4 buffer
                MOVE.B      #'W',(A4)+
                JMP         D5_HLPR2

*****************************************************************************
*D5_110 - OR.L INSTRUCTION: INTO EFFECTIVEE ADDRESS**************************
****************|***********|***************|********************************
D5_110          JSR         FILL_OR      Push OR.L to A4 buffer
                MOVE.B      #'L',(A4)+
                JMP         D5_HLPR2

*****************************************************************************
*BIT_SIX*********************************************************************
****************|***********|***************|********************************
BIT_SIX         CMPI.B      #$0,D2          Check if data at D2 is 000
                BEQ         D6_000
                CMPI.B      #$1,D2          Check if data at D2 is 001
                BEQ         D6_001    
                CMPI.B      #$2,D2          Check if data at D2 is 010
                BEQ         D6_010
                CMPI.B      #$3,D2          Check if data at D2 is 011
                BEQ         D6_011        
                CMPI.B      #$4,D2          Check if data at D2 is 100
                BEQ         D6_100 
                CMPI.B      #$5,D2          Check if data at D2 is 101
                BEQ         D6_101 
                CMPI.B      #$6,D2          Check if data at D2 is 110
                BEQ         D6_110
                CMPI.B      #$7,D2
                BEQ         D6_111          
                JSR         ERROR_1
BIT_SIX_DONE    RTS

*****************************************************************************
*FILL_AND: SAVING LINES OF CODE**********************************************
****************|***********|***************|********************************
FILL_AND        MOVE.B      #'A',(A4)+      Push AND. to A4 buffer
                MOVE.B      #'N',(A4)+
                MOVE.B      #'D',(A4)+
                MOVE.B      #'.',(A4)+
                RTS

*****************************************************************************
*D6_000 - AND.B INSTRUCTION: INTO DATA REG***********************************
****************|***********|***************|********************************
D6_000          JSR         FILL_AND        Push AND.B to A4 buffer
                MOVE.B      #'B',(A4)+
                JMP         D6_HLPR1

*****************************************************************************
*D6_001 - AND.W INSTRUCTION: INTO DATA REG***********************************
****************|***********|***************|********************************
D6_001          JSR         FILL_AND        Push AND.W to A4 buffer
                MOVE.B      #'W',(A4)+
                JMP         D6_HLPR1

*****************************************************************************
*D6_010 - AND.L INSTRUCTION: INTO DATA REG***********************************
****************|***********|***************|********************************
D6_010          JSR         FILL_AND        Push AND.L to A4 buffer
                MOVE.B      #'L',(A4)+
                ADDI.W      #$1,D4
                JMP         D6_HLPR1
                
*****************************************************************************
*D6_011 - MULU INSTRUCTION: INTO DATA REG************************************
****************|***********|***************|********************************
D6_011          MOVE.B      #'M',(A4)+      Push MULU to A4 buffer
                MOVE.B      #'U',(A4)+
                MOVE.B      #'L',(A4)+
                MOVE.B      #'U',(A4)+
                MOVE.B      #' ',(A4)+
                JMP         D6_HLPR1

*****************************************************************************
*D6_HLPR: FILL IN SECOND PART OF INSTRUCTION*********************************
****************|***********|***************|********************************
D6_HLPR1        JSR         A4_6SPACES      Push spaces to A4 buffer
                MOVE.B      #' ',(A4)+
                JSR         EFFECTIVE_ADDR  Find effective address
                CMPI.B      #$0,D4          Check error state
                BEQ         ERROR_1
                CMPI.B      #$1,D3          Check valid address mode
                BEQ         ERROR_1         
                MOVE.B      #',',(A4)+      Push data register to A4 buffer
                MOVE.B      #'D',(A4)+ 
                JSR         GET_REG2        Get reg number
                JSR         PUSH_REG_NUM    Push registry number to A4 buffer
                JMP         BIT_SIX_DONE
                
D6_HLPR2        JSR         A4_6SPACES      Push spaces to A4 buffer
                MOVE.B      #' ',(A4)+
                MOVE.B      #'D',(A4)+ 
                JSR         GET_REG2        Get reg number
                JSR         PUSH_REG_NUM    Push registry number to A4 buffer
                MOVE.B      #',',(A4)+      Push data register to A4 buffer
                JSR         EFFECTIVE_ADDR  Find effective address
                CMPI.B      #$0,D4          Check error state
                BEQ         ERROR_1
                CMPI.B      #$1,D3          Check valid address mode
                BEQ         ERROR_1         
                JMP         BIT_SIX_DONE
                
*****************************************************************************
*D6_100 - AND.B INSTRUCTION: INTO EFFECTIVE ADDRESS**************************
****************|***********|***************|********************************
D6_100          JSR         FILL_AND        Push AND.B to A4 buffer
                MOVE.B      #'B',(A4)+
                JMP         D6_HLPR2

*****************************************************************************
*D6_101 - AND.W INSTRUCTION: INTO EFFECTIVE ADDRESS**************************
****************|***********|***************|********************************
D6_101          JSR         FILL_AND        Push AND.W to A4 buffer
                MOVE.B      #'W',(A4)+
                JMP         D6_HLPR2
                
*****************************************************************************
*D6_110 - AND.L INSTRUCTION: INTO EFFECTIVE ADDRESS**************************
****************|***********|***************|********************************
D6_110          JSR         FILL_AND        Push AND.L to A4 buffer
                MOVE.B      #'L',(A4)+
                JMP         D6_HLPR2
                
*****************************************************************************
*D6_111 - MULS INSTRUCTION: INTO DATA REG************************************
****************|***********|***************|********************************
D6_111          MOVE.B      #'M',(A4)+      Push MULS to A4 buffer
                MOVE.B      #'U',(A4)+
                MOVE.B      #'L',(A4)+
                MOVE.B      #'S',(A4)+
                MOVE.B      #' ',(A4)+
                JMP         D6_HLPR2
                
*****************************************************************************
*BIT_SEVEN*******************************************************************
****************|***********|***************|********************************
BIT_SEVEN       CMPI.B      #$0,D2          Check if data at D2 is 000
                BEQ         D7_000
                CMPI.B      #$1,D2          Check if data at D2 is 001
                BEQ         D7_001
                CMPI.B      #$2,D2          Check if data at D2 is 010
                BEQ         D7_010
                JSR         ERROR_1
BIT_SEVEN_DONE  RTS

*****************************************************************************
*FILL_CMP********************************************************************
****************|***********|***************|********************************
FILL_CMP        MOVE.B      #'C',(A4)+      Push CMP.B to A4 buffer
                MOVE.B      #'M',(A4)+
                MOVE.B      #'P',(A4)+
                MOVE.B      #'.',(A4)+
                RTS

*****************************************************************************
*D7_000 - CMP.B INSTRUCTION**************************************************
****************|***********|***************|********************************
D7_000          JSR         FILL_CMP        Push CMP.B to A4 buffer
                MOVE.B      #'B',(A4)+
                JMP         D7_HLPR
                
*****************************************************************************
*D7_001 - CMP.W INSTRUCTION**************************************************
****************|***********|***************|********************************
D7_001          JSR         FILL_CMP        Push CMP.W to A4 buffer
                MOVE.B      #'W',(A4)+
                JMP         D7_HLPR

*****************************************************************************
*D7_010 - CMP.L INSTRUCTION**************************************************
****************|***********|***************|********************************
D7_010          JSR         FILL_CMP        Push CMP.L to A4 buffer
                MOVE.B      #'L',(A4)+
                ADDI.B      #$1,D4
                JMP         D7_HLPR

*****************************************************************************
*D7_HLPR: FILL IN SECOND PART OF INSTRUCTION*********************************
****************|***********|***************|********************************
D7_HLPR         JSR         A4_6SPACES      Push spaces to A4 buffer
                MOVE.B      #' ',(A4)+
                JSR         EFFECTIVE_ADDR  Find effective address
                CMPI.B      #$0,D4          Check error state
                BEQ         ERROR_1         
                CMPI.B      #$1,D3          Check valid address mode
                BEQ         ERROR_1
                MOVE.B      #',',(A4)+      Push data register to A4 buffer
                MOVE.B      #'D',(A4)+
                JSR         GET_REG2        Get reg number
                JSR         PUSH_REG_NUM    Push registry number to A4 buffer
                JMP         BIT_SEVEN_DONE
                
*****************************************************************************
*BIT_EIGHT*******************************************************************
****************|***********|***************|********************************
BIT_EIGHT       CMPI.B      #$0,D2          Check if data at D2 is 000
                BEQ         D8_000
                CMPI.B      #$1,D2          Check if data at D2 is 001
                BEQ         D8_001
                CMPI.B      #$2,D2          Check if data at D2 is 010
                BEQ         D8_010
                CMPI.B      #$3,D2          Check if data at D2 is 011
                BEQ         D8_011
                CMPI.B      #$4,D2          Check if data at D2 is 100
                BEQ         D8_100
                CMPI.B      #$5,D2          Check if data at D2 is 101
                BEQ         D8_101
                CMPI.B      #$6,D2          Check if data at D2 is 110
                BEQ         D8_110
                CMPI.B      #$7,D2          Check if data at D2 is 111
                BEQ         D8_111
                JSR         ERROR_1
BIT_EIGHT_DONE  RTS

*****************************************************************************
*FILL_ADD********************************************************************
****************|***********|***************|********************************
FILL_ADD        MOVE.B      #'A',(A4)+      Push ADD. to A4 buffer
                MOVE.B      #'D',(A4)+
                MOVE.B      #'D',(A4)+
                MOVE.B      #'.',(A4)+
                RTS
                
*****************************************************************************
*D8_000 - ADD.B: TO DATA REG*************************************************
****************|***********|***************|********************************
D8_000          JSR         FILL_ADD        Push ADD.B to A4 buffer
                MOVE.B      #'B',(A4)+
                JMP         D8_HLPR1
                
*****************************************************************************
*D8_001 - ADD.W: TO DATA REG*************************************************
****************|***********|***************|********************************
D8_001          JSR         FILL_ADD        Push ADD.W to A4 buffer
                MOVE.B      #'W',(A4)+
                JMP         D8_HLPR1

*****************************************************************************
*D8_010 - ADD.L: TO DATA REG*************************************************
****************|***********|***************|********************************
D8_010          JSR         FILL_ADD        Push ADD.L to A4 buffer
                MOVE.B      #'L',(A4)+
                JMP         D8_HLPR1

*****************************************************************************
*D8_HLPR1: FILL IN SECOND PART OF INSTRUCTION********************************
****************|***********|***************|********************************
D8_HLPR1        JSR         A4_6SPACES      Push spaces to A4 buffer
                MOVE.B      #' ',(A4)+
                JSR         EFFECTIVE_ADDR  Find effective address
                CMPI.B      #$0,D4          Check error state
                BEQ         ERROR_1
                CMPI.B      #$1,D3          Check valid address mode
                BEQ ERROR_1 
                MOVE.B      #',',(A4)+      Push data reg to A4 buffer
                MOVE.B      #'D',(A4)+
                JSR         GET_REG2        Get reg number
                JSR         PUSH_REG_NUM    Push registry number to A4 buffer
                JMP         BIT_EIGHT_DONE

*****************************************************************************
*D8_100 - ADD.B: TO EFFECTIVE ADDRESS****************************************
****************|***********|***************|********************************
D8_100          JSR         FILL_ADD        Push ADD.B to A4 buffer
                MOVE.B      #'B',(A4)+
                JMP         D8_HLPR2
                
*****************************************************************************
*D8_101 - ADD.B: TO EFFECTIVE ADDRESS****************************************
****************|***********|***************|********************************
D8_101          JSR         FILL_ADD        Push ADD.W to A4 buffer
                MOVE.B      #'W',(A4)+
                JMP         D8_HLPR2
                
*****************************************************************************
*D8_110 - ADD.B: TO EFFECTIVE ADDRESS****************************************
****************|***********|***************|********************************
D8_110          JSR         FILL_ADD        Push ADD.L to A4 buffer
                MOVE.B      #'L',(A4)+
                JMP         D8_HLPR2

*****************************************************************************
*D8_HLPR2: FILL IN SECOND PART OF INSTRUCTION********************************
****************|***********|***************|********************************
D8_HLPR2        JSR         A4_6SPACES      Push spaces to A4 buffer
                MOVE.B      #' ',(A4)+
                MOVE.B      #'D',(A4)+
                JSR         GET_REG2        Get reg number
                JSR         PUSH_REG_NUM    Push registry number to A4 buffer
                MOVE.B      #',',(A4)+
                JSR         EFFECTIVE_ADDR  Find effective address
                CMPI.B      #$0,D4          Check error state
                BEQ         ERROR_1
                CMPI.B      #$1,D3          Check valid address mode
                BEQ         ERROR_1
                JMP         BIT_EIGHT_DONE
                
*****************************************************************************
*D8_011 - ADDA.W*************************************************************
****************|***********|***************|********************************
D8_011          MOVE.B      #'A',(A4)+      Push ADDA.W to A4 buffer
                MOVE.B      #'D',(A4)+
                MOVE.B      #'D',(A4)+
                MOVE.B      #'A',(A4)+
                MOVE.B      #'.',(A4)+
                MOVE.B      #'W',(A4)+
                JMP         D8_HLPR3

*****************************************************************************
*D8_111 - ADDA.W*************************************************************
****************|***********|***************|********************************
D8_111          MOVE.B      #'A',(A4)+      Push ADDA.L to A4 buffer
                MOVE.B      #'D',(A4)+
                MOVE.B      #'D',(A4)+
                MOVE.B      #'A',(A4)+
                MOVE.B      #'.',(A4)+
                MOVE.B      #'L',(A4)+
                ADDI.B      #$1,D4
                JMP         D8_HLPR3
                
*****************************************************************************
*D8_HLPR3: FILL IN SECOND PART OF INSTRUCTION********************************
****************|***********|***************|********************************
D8_HLPR3        JSR         A4_6SPACES      Push spaces to A4 buffer
                JSR         EFFECTIVE_ADDR  Find effective address
                CMPI.B      #$0,D4          Check error state
                BEQ         ERROR_1         
                MOVE.B      #',',(A4)+      Move address reg to A4 buffer
                MOVE.B      #'A',(A4)+
                JSR         GET_REG2        Get reg number
                JSR         PUSH_REG_NUM    Push registry number to A4 buffer
                JMP         BIT_EIGHT_DONE
                
*****************************************************************************
*BIT_NINE********************************************************************
****************|***********|***************|********************************
BIT_NINE        CMPI.B      #$0,D2          Check if data at D2 is 000
                BEQ         D9_000
                CMPI.B      #$1,D2          Check if data at D2 is 001
                BEQ         D9_001
                CMPI.B      #$2,D2          Check if data at D2 is 010
                BEQ         D9_010          
                CMPI.B      #$3,D2          Check if data at D2 is 011
                BEQ         D9_011
                CMPI.B      #$4,D2          Check if data at D2 is 100
                BEQ         D9_100
                CMPI.B      #$5,D2          Check if data at D2 is 101
                BEQ         D9_101
                CMPI.B      #$6,D2          Check if data at D2 is 110
                BEQ         D9_110
                CMPI.B      #$7,D2          Check if data at D2 is 111
                BEQ         D9_111
                JSR         ERROR_1
BIT_NINE_DONE   RTS

*****************************************************************************
*FILL_SUB********************************************************************
****************|***********|***************|********************************
FILL_SUB        MOVE.B      #'S',(A4)+      Push SUB. to A4 buffer
                MOVE.B      #'U',(A4)+
                MOVE.B      #'B',(A4)+
                MOVE.B      #'.',(A4)+
                RTS
                
*****************************************************************************
*D9_000 - SUB.B INSTRUCTION: TO DATA REG*************************************
****************|***********|***************|********************************
D9_000          JSR         FILL_SUB        Push SUB.B to A4 buffer
                MOVE.B      #'B',(A4)+
                JMP         D9_HLPR1                
                
*****************************************************************************
*D9_001 - SUB.W INSTRUCTION: TO DATA REG*************************************
****************|***********|***************|********************************
D9_001          JSR         FILL_SUB        Push SUB.W to A4 buffer
                MOVE.B      #'W',(A4)+
                JMP         D9_HLPR1  

*****************************************************************************
*D9_010 - SUB.L INSTRUCTION: TO DATA REG*************************************
****************|***********|***************|********************************
D9_010          JSR         FILL_SUB        Push SUB.L to A4 buffer
                MOVE.B      #'L',(A4)+
                JMP         D9_HLPR1  

*****************************************************************************
*D9_HLPR1: FILL IN SECOND PART OF INSTRUCTION********************************
****************|***********|***************|********************************
D9_HLPR1        JSR         A4_6SPACES      Push spaces to A4 buffer
                MOVE.B      #' ',(A4)+
                JSR         EFFECTIVE_ADDR  Find effective address
                CMPI.B      #$0,D4          Check error state
                BEQ         ERROR_1
                CMPI.B      #$1,D3          Check valid address mode
                BEQ         ERROR_1         
                MOVE.B      #',',(A4)+      Push data reg to A4 buffer
                MOVE.B      #'D',(A4)+
                JSR         GET_REG2        Get reg number
                JSR         PUSH_REG_NUM    Push registry number to A4 buffer
                JMP         BIT_NINE_DONE
                
*****************************************************************************
*D9_100 - SUB.B INSTRUCTION: TO EFFECTIVE ADDRESS****************************
****************|***********|***************|********************************
D9_100          JSR         FILL_SUB        Push SUB.B to A4 buffer
                MOVE.B      #'B',(A4)+
                JMP         D9_HLPR2 
                
*****************************************************************************
*D9_101 - SUB.W INSTRUCTION: TO EFFECTIVE ADDRESS****************************
****************|***********|***************|********************************
D9_101          JSR         FILL_SUB        Push SUB.W to A4 buffer
                MOVE.B      #'W',(A4)+
                JMP         D9_HLPR2 
                
*****************************************************************************
*D9_110 - SUB.L INSTRUCTION: TO EFFECTIVE ADDRESS****************************
****************|***********|***************|********************************
D9_110          JSR         FILL_SUB        Push SUB.L to A4 buffer
                MOVE.B      #'L',(A4)+
                JMP         D9_HLPR2 
                
*****************************************************************************
*D9_011 - SUB.W INSTRUCTION: ADDR REGISTER***********************************
****************|***********|***************|********************************
D9_011          JSR         FILL_SUB        Push SUB.L to A4 buffer
                MOVE.B      #'W',(A4)+
                JMP         D9_HLPR3 
                
*****************************************************************************
*D9_111 - SUB.L INSTRUCTION: ADDR REGISTER***********************************
****************|***********|***************|********************************
D9_111          JSR         FILL_SUB        Push SUB.W to A4 buffer
                MOVE.B      #'L',(A4)+
                JMP         D9_HLPR3 

*****************************************************************************
*D9_HLPR2: FILL IN SECOND PART OF INSTRUCTION********************************
****************|***********|***************|********************************
D9_HLPR2        JSR         A4_6SPACES      Push spaces to A4 buffer
                MOVE.B      #' ',(A4)+
                MOVE.B      #'D',(A4)+
                JSR         GET_REG2        Get reg number
                JSR         PUSH_REG_NUM    Push registry number to A4 buffer
                MOVE.B      #',',(A4)+
                JSR         EFFECTIVE_ADDR  Find effective address
                CMPI.B      #$0,D4          Check error state
                BEQ         ERROR_1
                CMPI.B      #$1,D3          Check valid address mode
                BEQ         ERROR_1
                JMP         BIT_NINE_DONE
                
D9_HLPR3        JSR         A4_6SPACES      Push spaces to A4 buffer
                MOVE.B      #' ',(A4)+
                JSR         EFFECTIVE_ADDR  Find effective address
                CMPI.B      #$0,D4          Check error state
                BEQ         ERROR_1
                CMPI.B      #$1,D3          Check valid address mode
                BEQ         ERROR_1         
                MOVE.B      #',',(A4)+      Push data reg to A4 buffer
                MOVE.B      #'A',(A4)+
                JSR         GET_REG2        Get reg number
                JSR         PUSH_REG_NUM    Push registry number to A4 buffer
                JMP         BIT_NINE_DONE
                
*****************************************************************************
*BRA_ADDR********************************************************************
****************|***********|***************|********************************
BRA_ADDR        JSR         A4_6SPACES      Push branch address
                MOVE.B      #' ',(A4)+ 
                MOVE.B      #' ',(A4)+ 
                MOVE.B      #' ',(A4)+
                MOVE.B      #'$',(A4)+
                CMP.B       #$0,D7          Check 16 bit offset
                BEQ         B_16
                CMP.B       #$FF,D7         Check 32 bit offset
                BEQ         B_32
                BRA         GET_OFFSET      Get 8 bit offset data
B_16            CMPI.L      #$0,D6          Check for word data
                BLE         ERROR_1
                JSR         PUSH_W          Convert to ASCII and push to A4
                ADD.L       #$2,A5          Increment A5 to next instruction
                SUBI.L      #$1,D6          Decrement data remaining
                RTS
B_32            CMPI.L      #$1,D6          Check for longword data
                BLE         ERROR_1
                JSR         PUSH_L          Convert to ASCII and push to A4
                ADD.L       #$4,A5          Increment A5 to next instruction
                SUBI.L      #$2,D6          Decrement data remaining
                RTS

*****************************************************************************
*GET_OFFSET******************************************************************
****************|***********|***************|********************************
GET_OFFSET      CLR         D5              Empty D5 register
                MOVE.W      D7,D5           Move instruction at D7 to D5
                ANDI        #$00FF,D5       Chop off two  word data bits
                LSR.W       #$4,D5          Get 4 bits of offset
                JSR         CVT_ASCII2      Convert to ASCII and push
                MOVE.W      D7,D5           Move instruction at D7 to D5
                ANDI        #$000F,D5       Chop off threeword data bits
                JSR         CVT_ASCII2      Convert to ASCII and push
                RTS         

*****************************************************************************
*LEA INSTRUCTION*************************************************************
****************|***********|***************|********************************
LEA_INS         MOVE.B      #'L',(A4)+      Push LEA to A4 buffer
                MOVE.B      #'E',(A4)+
                MOVE.B      #'A',(A4)+
                JSR         A4_6SPACES
                MOVE.B      #' ',(A4)+
                MOVE.B      #' ',(A4)+
                MOVE.B      #' ',(A4)+
                JSR         EFFECTIVE_ADDR  Find effective address
                CMP.B       #$1,D5          Check addressing mode
                BLE         LEA_ERROR
                CMP.B       #$3,D5          
                BEQ         LEA_ERROR
                CMP.B       #$4,D5 
                BEQ         LEA_ERROR
                MOVE.B      #',',(A4)+      Push ,A to A4 buffer
                MOVE.B      #'A',(A4)+
                JSR         GET_REG2        Get registry code
                JSR         PUSH_REG_NUM    Push registry number to A4 buffer
                RTS
LEA_ERROR       JSR         ERROR_1
                RTS

*****************************************************************************
*IMM_DATA********************************************************************
****************|***********|***************|********************************
IMM_DATA        CMPI.L      #$0,D6          Check if there is data remaining
                BEQ         IMM_ERROR       
                JSR         DATA_SIZE       Get size of data
                CMP.W       #$0,D2          Check if byte data
                BEQ         IMM_B
                CMP.W       #$1,D2          Check if word data
                BEQ         IMM_W
                CMP.W       #$2,D2          Check if longword data          
                BEQ         IMM_L
IMM_ERROR       BRA         ERROR_1
                RTS
IMM_PUSH        JSR         PUSH_W          Convert to ASCII and push
                ADDQ        #$2,A5          Increment address at A5
                SUBQ        #$1,D6          Decrement remaining data
                MOVE.B      #',',(A4)+      Push , to A4 buffer
                JSR         EFFECTIVE_ADDR  Find effective address
                CMPI.L      #$0,D4          Error checking
                BEQ         IMM_BACK
                CMPI.B      #$1,D3          Check for valid address mode
                BEQ         IMM_BACK
                RTS
IMM_BACK        ADDQ        #$1,D6          Reset registers
                SUBQ        #$2,A5
                JMP         IMM_ERROR
IMM_B           MOVE.B      #'B',(A4)+      Push byte immediate data
                JSR         IMM_SPACES
                JMP         IMM_PUSH        
IMM_W           MOVE.B      #'W',(A4)+      Push word immediate data
                JSR         IMM_SPACES
                JMP         IMM_PUSH
IMM_L           CMPI.L      #$1,D6          Check sufficient data
                BLE         IMM_ERROR
                MOVE.B      #'L',(A4)+      Push longword immediate data
                JSR         IMM_SPACES
                JSR         PUSH_L          Convert to ASCII and push to A4
                ADDQ        #$4,A5          Increment address at A5
                SUBQ        #$2,D6          Decrement remaining data
                MOVE.B      #',',(A4)+      Push , to A4 buffer
                JSR         EFFECTIVE_ADDR  Find effective address
                CMPI.L      #$0,D4          Error checking
                BEQ         IMM_BACK2
                CMPI.B      #$1,D3          Check for valid address mode
                BEQ         IMM_BACK2
                RTS
IMM_BACK2       ADDQ        #$2,D6          Reset registers
                SUBQ        #$4,A5
                JMP         IMM_ERROR
IMM_SPACES      JSR         A4_6SPACES      Push spaces to A4 buffer
                MOVE.B #'#',(A4)+ 
                MOVE.B #'$',(A4)+ 
                RTS

*****************************************************************************
*DATA_SIZE - VALUE IN D2*****************************************************
****************|***********|***************|********************************
DATA_SIZE       MOVE.W      D7,D2           Move opcode from D7 to D2
                LSR.W       #$6,D2          Move 7th bit into position
                ANDI        #$0003,D2       Isolate size bits
                RTS

*****************************************************************************
*PUSH_LW*********************************************************************
****************|***********|***************|********************************
PUSH_LW         SUBI.B      #$1,D4        
                JSR         PUSH_W
                JMP         ABS_100_CONT
                
*****************************************************************************
*PUSH_B**********************************************************************
****************|***********|***************|********************************
PUSH_B          CLR         D5              Empty D5 registry
                MOVE.W      (A5),D5         Move word data from A5 to D5
                ANDI        #$00FF,D5       Chop off leading two characters
                LSR.W       #$4,D5          Shift next character
                JSR         CVT_ASCII2      Convert character to ASCII
                MOVE.W      (A5),D5         Move word data from A5 to D5
                ANDI        #$000F,D5       Chop off leading characters
                JSR         CVT_ASCII2      Convert character to ASCII
                MOVEQ       #$2,D0
                JMP         ABS_100_CONT

*****************************************************************************
*PUSH_W**********************************************************************
****************|***********|***************|********************************
PUSH_W          CLR         D5              Empty D5 registry
                MOVE.W      (A5),D5         Move word data from A5 to D5
                LSR.W       #$8,D5          Shift leading character
                LSR.W       #$4,D5
                JSR         CVT_ASCII2      Convert character to ASCII
                MOVE.W      (A5),D5         Move word data from A5 to D5
                ANDI        #$0FFF,D5       Chop off leading character
                LSR.W       #$8,D5          Shift next character
                JSR         CVT_ASCII2      Convert character to ASCII
                MOVE.W      (A5),D5         Move word data from A5 to D5
                ANDI        #$00FF,D5       Chop off leading two characters
                LSR.W       #$4,D5          Shift next character
                JSR         CVT_ASCII2      Convert character to ASCII
                MOVE.W      (A5),D5         Move word data from A5 to D5
                ANDI        #$000F,D5       Chop off leading three characters
                JSR         CVT_ASCII2      Convert character to ASCII 
                RTS

*****************************************************************************
*PUSH_L**********************************************************************
****************|***********|***************|********************************
PUSH_L          CLR         D5              Empty D5 registry
                MOVE.L      (A5),D5         Move longword data from A5 to D5
                LSR.L       #$8,D5          Shift leading character
                LSR.L       #$8,D5           
                LSR.L       #$8,D5
                LSR.L       #$4,D5
                JSR         CVT_ASCII2      Convert character to ASCII
                MOVE.L      (A5),D5         Move longword data from A5 to D5
                ANDI.L      #$0FFFFFFF,D5   Chop off leading character
                LSR.L       #$8,D5          Shift next character
                LSR.L       #$8,D5
                LSR.L       #$8,D5
                JSR         CVT_ASCII2      Convert character to ASCII
                MOVE.L      (A5),D5         Move longword data from A5 to D5
                ANDI.L      #$00FFFFFF,D5   Chop off leading two characters
                LSR.L       #$8,D5          Shift next character
                LSR.L       #$8,D5 
                LSR.L       #$4,D5
                JSR         CVT_ASCII2      Convert character to ASCII
                MOVE.L      (A5),D5         Move longword data from A5 to D5
                ANDI.L      #$000FFFFF,D5   Chop off leading three characters
                LSR.L       #$8,D5          Shift next character
                LSR.L       #$8,D5          
                JSR         CVT_ASCII2      Convert character to ASCII
                MOVE.L      (A5),D5         Move longword data from A5 to D5
                ANDI.L      #$0000FFFF,D5   Chop off leading four characters
                LSR.L       #$8,D5          Shift next character
                LSR.L       #$4,D5
                JSR         CVT_ASCII2      Convert character to ASCII
                MOVE.L      (A5),D5         Move longword data from A5 to D5
                ANDI.L      #$00000FFF,D5   Chop off leading 5 characters
                LSR.L       #$8,D5          Shift next character
                JSR         CVT_ASCII2      Convert character to ASCII
                MOVE.L      (A5),D5         Move longword data from A5 to D5
                ANDI.L      #$000000FF,D5   Chop off leading six characters
                LSR.L       #$4,D5          Shift next character
                JSR         CVT_ASCII2      Convert character to ASCII
                MOVE.L      (A5),D5         Move longword data from A5 to D5
                ANDI.L      #$0000000F,D5   Chop off leading seven characters
                JSR         CVT_ASCII2      Convert character to ASCII
                RTS

*****************************************************************************
*GET_REG - VALUE IN D2*******************************************************
****************|***********|***************|********************************
GET_REG         MOVE.W      D7,D2           Move the registry OPCODE into D2
                LSR.W       #$6,D2          Move input registry bits
                ANDI        #$0007,D2       Chop off unneeded data
                RTS         

*****************************************************************************
*GET SECOND REGISTER - VALUE IN D2*******************************************
****************|***********|***************|********************************
GET_REG2        MOVE.W      D7,D2           Move the registry OPCODE into D2
                LSR.W       #$8,D2          Move output registry bits
                LSR.W       #$1,D2           
                ANDI.W      #$0007,D2       Chop off unneeded data
                RTS

*****************************************************************************
*BIT_RANGE_8 - VALUE IN D2***************************************************
****************|***********|***************|********************************
BIT_RANGE_8     MOVE.W      D7,D2           Move current OPCODE to D2
                LSR.W       #$8,D2          Move bit 8 into correct position
                ANDI        #$0001,D2       Chop off unneeded data
                RTS

*****************************************************************************
*BIT_RANGE_3TO4 - VALUE IN D2************************************************
****************|***********|***************|********************************
BIT_RANGE_3TO4  MOVE.W      D7,D2           Move current OPCODE to D2
                LSR.W       #$3,D2          Move bits 3-4
                ANDI        #$0003,D2       Chop off unneeded data
                RTS

*****************************************************************************
*EFFECTIVE_ADDR - D3: MODE; D6: REMAINING DATA; D7: OPCODE; A5 EA BUFFER*****
****************|***********|***************|********************************
EFFECTIVE_ADDR  MOVE.B      D7,D5           Move current OPCODE to D5
                LSL.B       #$2,D5          Chop off first two binary bits
                LSR.B       #$5,D5          Move the three addressing bits
                MOVE.B      D7,D2           Move current OPCODE to D2
                LSL.B       #$5,D2          Chop off first five bits
                LSR.B       #$5,D2           
                CMP.B       #$1,D3          Check if move operation
                BEQ         EFF_ADDR_MOVE   
                CMP.B       #$0,D3          Check effective addressing
                BEQ         EFFECTIVE_HLPR  Find mode
                RTS
                
*****************************************************************************
*EFFECTIVE_HLPR - HELPER FUNCTION********************************************
****************|***********|***************|********************************
EFFECTIVE_HLPR  JSR         GET_EA_MODE     Get the effective addressing mode
                RTS

*****************************************************************************
*GET_EA_MODE*****************************************************************
****************|***********|***************|********************************
GET_EA_MODE     CMPI.B      #$0,D5
                BEQ         GET_EA_000      mode is Dn
                CMPI.B      #$1,D5
                BEQ         GET_EA_001      mode is An
                CMPI.B      #$2,D5
                BEQ         GET_EA_010      mode is (An)
                CMPI.B      #$3,D5
                BEQ         GET_EA_011      mode is (An)+
                CMPI.B      #$4,D5
                BEQ         GET_EA_100      mode is -(An)
                CMPI.B      #$5,D5
                BEQ         GET_EA_101      mode is (d16,An)
                CMPI.B      #$6,D5
                BEQ         GET_EA_110      mode is (d8,An,Xn)
                CMPI.B      #$7,D5
                BEQ         GET_EA_111      mode is (XXX).W or (XXX).L
                JMP         ERROR_1
GET_EA_DONE     RTS

*****************************************************************************
*GET_EA_000 - DATA REGISTER**************************************************
****************|***********|***************|********************************
GET_EA_000      MOVE.B      #'D',(A4)+      Push D to A4 buffer
                JSR         PUSH_REG_NUM    Push registry number to A4 buffer
                JMP         GET_EA_DONE
                
*****************************************************************************
*GET_EA_001 - ADDRESS REGISTER***********************************************
****************|***********|***************|********************************
GET_EA_001      MOVE.B      #'A',(A4)+      Push A to A4 buffer
                JSR         PUSH_REG_NUM    Push registry number to A4 buffer
                JMP         GET_EA_DONE
                
*****************************************************************************
*GET_EA_010 - EFFECTIVE ADDRESS**********************************************
****************|***********|***************|********************************
GET_EA_010      MOVE.B      #'(',(A4)+      Push (A#) to A4 buffer
                MOVE.B      #'A',(A4)+      
                JSR         PUSH_REG_NUM    Push registry number to A4 buffer
                MOVE.B      #')',(A4)+      
                JMP         GET_EA_DONE

*****************************************************************************
*GET_EA_011 - EFFECTIVE ADDRESS POST INCREMENT*******************************
****************|***********|***************|********************************
GET_EA_011      MOVE.B      #'(',(A4)+      Push (A#)+ to A4 buffer
                MOVE.B      #'A',(A4)+      
                JSR         PUSH_REG_NUM    Push registry number
                MOVE.B      #')',(A4)+      
                MOVE.B      #'+',(A4)+ 
                JMP         GET_EA_DONE
*****************************************************************************
*GET_EA_100 - EFFECTIVE ADDRESS PRE DECREMENT********************************
****************|***********|***************|********************************
GET_EA_100      MOVE.B      #'-',(A4)+      Push -(A#) to A4 buffer
                MOVE.B      #'(',(A4)+      
                MOVE.B      #'A',(A4)+
                JSR         PUSH_REG_NUM    Push registry number
                MOVE.B      #')',(A4)+
                JMP         GET_EA_DONE
                
*****************************************************************************
*GET_EA_101******************************************************************
****************|***********|***************|********************************
GET_EA_101      MOVE.B      #'(',(A4)+      Push ( to A4 buffer
                MOVE.W      (A5),D0         Move next address data to D0
                CMPI.L      #$0,D6          Check if there is data to read
                BEQ         ERROR_1         
                SUBI.L      #$1,D6          Decrement counter
                MOVE.B      #'$',(A4)+      Push $ to A4 buffer
                LSR.W       #$8,D0          Get first digit of address
                LSR.W       #$4,D0
                JSR         CVT_ASCII       Push digit to A4 buffer
                MOVE.W      (A5),D0         Move next address data to D0
                LSL.W       #$4,D0          Knock off first digit
                LSR.W       #$8,D0          Get second digit of address
                LSR.W       #$4,D0
                JSR         CVT_ASCII       Push digit to A4 buffer
                MOVE.W      (A5),D0         Move next address data to D0
                LSL.W       #$8,D0          Knock off first two digits
                LSR.W       #$8,D0          Get third digit of address
                LSR.W       #$4,D0
                JSR         CVT_ASCII       Push digit to A4 buffer
                MOVE.W      (A5),D0         Move next address data to D0
                LSL.W       #$8,D0          Knock off first three digits
                LSL.W       #$4,D0          
                LSR.W       #$8,D0          Get fourth digit of address
                LSR.W       #$4,D0           
                JSR         CVT_ASCII       Push digit to A4 buffer
                MOVE.W      (A5),D0         Move next address data to D0
                CMP.W       #$FFFF,D0       Check size of data
                BGE         ERROR_2         Instruction is invalid
                MOVE.B      #',',(A4)+      Push ),A# to A4 buffer
                MOVE.B      #'A',(A4)+      
                JSR         PUSH_REG_NUM    Push registry number
                MOVE.B      #')',(A4)+
                ADDA.L      #$2,A5          Increment the current address
                JMP         GET_EA_DONE
                
*****************************************************************************
*GET_EA_110******************************************************************
****************|***********|***************|********************************
GET_EA_110      MOVE.B      #'(',(A4)+      Push ( to A4 buffer
                MOVE.W      (A5),D0         Move next address data to D0
                CMPI.L      #$0,D6          Check if there is data to read
                BEQ         ERROR_1         
                SUBI.L      #$1,D6          Decrement counter
                MOVE.B      #'$',(A4)+      Push $ to A4 buffer
                LSL.W       #$8,D0          Get first digit of address
                LSR.W       #$8,D0 
                LSR.W       #$4,D0
                JSR         CVT_ASCII       Push digit to A4 buffer
                MOVE.W      (A5),D0         Move next address data to D0
                LSL.W       #$8,D0          Get second digit of address
                LSL.W       #$4,D0           
                LSR.W       #$8,D0           
                LSR.W       #$4,D0 
                JSR         CVT_ASCII       Push digit to A4 buffer
                MOVE.B      #',',(A4)+      Push ,A### to A4 buffer
                MOVE.B      #'A',(A4)+
                JSR         PUSH_REG_NUM    Push registry number to A4 buffer
                MOVE.B      #',',(A4)+      
                MOVE.W      (A5),D0         Move next address data to D0
                LSL.W       #$8,D0          Get the register type code
                LSL.W       #$7,D0           
                JSR         INS_D_A         Push the register code
                MOVE.W      (A5),D0         Move next address data to D0
                LSL.W       #$1,D0          Shift data to get registry number
                LSR.W       #$8,D0           
                LSR.W       #$5,D0          
                MOVE.L      D0,D2           Move the data for PUSH_REG_NUM
                JSR         PUSH_REG_NUM    Push registry number to A4 buffer
                MOVE.B      #')',(A4)+      
                ADDA.L      #2,A5           Increment the current address
                JMP         GET_EA_DONE

*****************************************************************************
*GET_EA_111******************************************************************
****************|***********|***************|********************************
GET_EA_111      JSR         GET_ABSOLUTE    Locate and push absolute address
                JMP         GET_EA_DONE

*****************************************************************************
*EFF_ADDR_MOVE***************************************************************
****************|***********|***************|********************************
EFF_ADDR_MOVE   JSR         GET_EA_MODE     Get the effective address mode
                MOVE.B      #',',(A4)+      Push , to A4 buffer
                MOVE.W      D7,D2           Move current opcode to D2
                LSL.W       #$4,D2          Format OPCODE data PUSH_REG_NUM
                LSR.W       #$8,D2
                LSR.W       #$5,D2
                MOVE.W      D7,D5           Move current opcode GET_EA_MODE
                LSL.W       #$7,D5          Format the opcode data at D5
                LSR.W       #$8,D5
                LSR.W       #$5,D5
                JSR         GET_EA_MODE     Get second EA mode
                RTS

*****************************************************************************
*GET_ABSOLUTE****************************************************************
****************|***********|***************|********************************
GET_ABSOLUTE    CMPI.B      #$0,D2          Check if mode is 000     
                BEQ         GET_ABS_000       
                CMPI.B      #$1,D2          Check if mode is 001
                BEQ         GET_ABS_001       
                CMPI.B      #$4,D2          Check if mode is 100
                BEQ         GET_ABS_100
                JMP         ERROR_1
GET_ABS_DONE    RTS


*****************************************************************************
*GET_ABS_000*****************************************************************
****************|***********|***************|********************************
GET_ABS_000     MOVE.B      #'$',(A4)+      Push $ followed by word address
                MOVE.W      (A5),D0         Move next word data to D0
                CMPI.L      #$0,D6          Check if any data remaining
                BEQ         ERROR_1
                SUBI.L      #$1,D6          Decrement counter
                LSR.W       #$8,D0          Get first digit
                LSR.W       #$4,D0
                JSR         CVT_ASCII       Push first digit to A4 buffer
                MOVE.W      (A5),D0         Move next word data to D0
                LSL.W       #$4,D0          Get second digit
                LSR.W       #$8,D0
                LSR.W       #$4,D0
                JSR         CVT_ASCII       Push second digit to A4 buffer
                MOVE.W      (A5),D0         Move next word data to D0
                LSL.W       #$8,D0          Get third digit
                LSR.W       #$8,D0
                LSR.W       #$4,D0
                JSR         CVT_ASCII       Push third digit to A4 buffer
                MOVE.W      (A5),D0         Move next word data to D0
                LSL.W       #$8,D0          Get fourth digit
                LSL.W       #$4,D0           
                LSR.W       #$8,D0
                LSR.W       #$4,D0
                JSR         CVT_ASCII       Push fourth digit to A4 buffer
                ADDA.L      #$2,A5          Increment the current address
                JMP         GET_ABS_DONE
                
*****************************************************************************
*GET_ABS_001*****************************************************************
****************|***********|***************|********************************
GET_ABS_001     MOVE.B      #'$',(A4)+      Push $ followed by longword
                MOVE.W      (A5),D0         Move next word data to D0
                CMPI.L      #$1,D6          Check if there is any data
                BLE         ERROR_1
                SUBI.L      #$2,D6          Decrement counter
                LSR.W       #$8,D0          Get first digit
                LSR.W       #$4,D0           
                JSR         CVT_ASCII       Push first digit to A4 buffer
                MOVE.W      (A5),D0         Move next word data to D0
                LSL.W       #$4,D0          Get second digit
                LSR.W       #$8,D0           
                LSR.W       #$4,D0
                JSR         CVT_ASCII       Push second digit to A4 buffer
                MOVE.W      (A5),D0         Move next word data to D0
                LSL.W       #$8,D0          Get third digit
                LSR.W       #$8,D0           
                LSR.W       #$4,D0           
                JSR         CVT_ASCII       Push third digit to A4 buffer
                MOVE.W      (A5)+,D0        Move next word data to D0
                LSL.W       #$8,D0          Get fourth digit
                LSL.W       #$4,D0          
                LSR.W       #$8,D0
                LSR.W       #$4,D0
                JSR         CVT_ASCII       Push fourth digit to A4 buffer
                MOVE.W      (A5),D0         Move next word data to D0
                LSR.W       #$8,D0          Get fifth digit
                LSR.W       #$4,D0
                JSR         CVT_ASCII       Push fifth digit to A4 buffer
                MOVE.W      (A5),D0         Move next word data to D0
                LSL.W       #$4,D0          Get sixth digit
                LSR.W       #$8,D0
                LSR.W       #$4,D0
                JSR         CVT_ASCII       Push sixth digit to A4 buffer
                MOVE.W      (A5),D0         Move next word data to D0
                LSL.W       #$8,D0          Get seventh digit
                LSR.W       #$8,D0
                LSR.W       #$4,D0
                JSR         CVT_ASCII       Push seventh digit to A4 buffer
                MOVE.W      (A5),D0         Move next word data to D0
                LSL.W       #$8,D0          Get eigth digit
                LSL.W       #$4,D0           
                LSR.W       #$8,D0
                LSR.W       #$4,D0
                JSR         CVT_ASCII       Push eigth digit to A4 buffer
                ADDA.L      #$2,A5          Increment the current address
                JMP         GET_ABS_DONE
                
*****************************************************************************
*GET_ABS_100*****************************************************************
****************|***********|***************|********************************
GET_ABS_100     MOVE.B      #'#',(A4)+      Push # to A4 buffer
                MOVE.B      #'$',(A4)+      Push HEX identifier to A4 buffer
                CMPI.L      #$0,D6          Check if there is data remaining
                BEQ         ERROR_1
                CMPI.W      #$FFFF,D0
                BEQ         PUSH_B
                JSR         PUSH_W          Convert to ASCII and push to A4
ABS_100_CONT    SUBI.L      #$1,D6          Decrement counter
                ADDA.L      #$2,A5          Increment the current address
                CMP.B       #$1,D4
                BGT         PUSH_LW
                JMP         GET_ABS_DONE
                
*****************************************************************************
*PUSH REGISTER NUMBER********************************************************
****************|***********|***************|********************************
PUSH_REG_NUM    CMPI.B      #$0,D2          Check if register is 0     
                BEQ         PUSH_REG_000      
                CMPI.B      #$1,D2          Check if register is 1     
                BEQ         PUSH_REG_001      
                CMPI.B      #$2,D2          Check if register is 2     
                BEQ         PUSH_REG_010      
                CMPI.B      #$3,D2          Check if register is 3     
                BEQ         PUSH_REG_011      
                CMPI.B      #$4,D2          Check if register is 4     
                BEQ         PUSH_REG_100      
                CMPI.B      #$5,D2          Check if register is 5     
                BEQ         PUSH_REG_101      
                CMPI.B      #$6,D2          Check if register is 6     
                BEQ         PUSH_REG_110      
                CMPI.B      #$7,D2          Check if register is 7     
                BEQ         PUSH_REG_111      
PUSH_REG_DONE   RTS

*****************************************************************************
*PUSH_REG_000****************************************************************
****************|***********|***************|********************************
PUSH_REG_000    MOVE.B      #'0',(A4)+      Push 0 to A4 buffer
                JMP         PUSH_REG_DONE
                
*****************************************************************************
*PUSH_REG_001****************************************************************
****************|***********|***************|********************************
PUSH_REG_001    MOVE.B      #'1',(A4)+      Push 1 to A4 buffer
                JMP         PUSH_REG_DONE
                
*****************************************************************************
*PUSH_REG_010****************************************************************
****************|***********|***************|********************************
PUSH_REG_010    MOVE.B      #'2',(A4)+      Push 2 to A4 buffer
                JMP         PUSH_REG_DONE
                
*****************************************************************************
*PUSH_REG_011****************************************************************
****************|***********|***************|********************************
PUSH_REG_011    MOVE.B      #'3',(A4)+      Push 3 to A4 buffer
                JMP         PUSH_REG_DONE
                
*****************************************************************************
*PUSH_REG_100****************************************************************
****************|***********|***************|********************************
PUSH_REG_100    MOVE.B      #'4',(A4)+      Push 4 to A4 buffer
                JMP         PUSH_REG_DONE
                
*****************************************************************************
*PUSH_REG_101****************************************************************
****************|***********|***************|********************************
PUSH_REG_101    MOVE.B      #'5',(A4)+      Push 5 to A4 buffer
                JMP         PUSH_REG_DONE
                
*****************************************************************************
*PUSH_REG_110****************************************************************
****************|***********|***************|********************************
PUSH_REG_110    MOVE.B      #'6',(A4)+      Push 6 to A4 buffer
                JMP         PUSH_REG_DONE
                
*****************************************************************************
*PUSH_REG_111****************************************************************
****************|***********|***************|********************************
PUSH_REG_111    MOVE.B      #'7',(A4)+      Push 7 to A4 buffer
                JMP         PUSH_REG_DONE

*****************************************************************************
*ERROR_1 - CANNOT BE DISASSEMBLED********************************************
****************|***********|***************|********************************
ERROR_1         CLR         D4              Set error state registry D4
                RTS
                
*****************************************************************************
*ERROR_2 - ERROR WITH INCREMENT ADDRESS**************************************
****************|***********|***************|********************************
ERROR_2         CLR         D4              Set to error state
                ADDI.L      #$1,D6          Increment current address
                RTS

*****************************************************************************
*ERROR_3 - ERROR WITH DECREMENT WORD ADDRESS*********************************
****************|***********|***************|********************************
ERROR_3         CLR         D4              Set to error state
                ADDI.L      #$1,D6          Increment current address
                SUB.L       #$2,A5          Step next address back
                RTS

*****************************************************************************
*ERROR_4 - ERROR WITH DECREMENT LONGWORD ADDRESS*****************************
****************|***********|***************|********************************
ERROR_4         CLR         D4              Set to error state
                ADDI.L      #$2,D6          Increment current working address
                SUB.L       #$4,A5          Step next address back
                RTS

*****************************************************************************
*CONVERT ASCII CHARACTER*****************************************************
****************|***********|***************|********************************
CVT_ASCII       CMP.B       #$9,D0          Check if character
                BGT         CHAR_ASCII
DEC_ASCII       ADDI.B      #$30,D0         Convert to ASCII number
                JMP         PUSH_ASCII
CHAR_ASCII      ADDI.B      #$37,D0         Convert to ASCII character
PUSH_ASCII      MOVE.B      D0,(A4)+        Push character to A4 buffer
                MOVE.B      D0,(A3)+        Push character to A3 buffer
                RTS

*****************************************************************************
*CONVERT ASCII CHARACTER 2 - SAME AS ABOVE BUT D5 REGISTER*******************
****************|***********|***************|********************************
CVT_ASCII2      CMP.B       #$A,D5          Check if input is character
                BGE         CHAR_ASCII2
DEC_ASCII2      ADDI.B      #$30,D5         Convert to ASCII number
                JMP         PUSH_ASCII2 
CHAR_ASCII2     ADDI.B      #$37,D5         Convert to ASCII character
PUSH_ASCII2     MOVE.B      D5,(A4)+        Push character to A4 buffer
                RTS

*****************************************************************************
*INSERT D OR A***************************************************************
****************|***********|***************|********************************
INS_D_A         CMP.B       #$0,D0          Check if DATA registry
                BEQ         INS_D 
                CMP.B       #$1,D0          Check if ADDRESS registry
                BEQ         INS_A
INS_D           MOVE.B      #'D',(A4)+      Push D to A4 buffer
                RTS
INS_A           MOVE.B      #'A',(A4)+      Push A to A4 buffer
                RTS

*****************************************************************************
*SET BUFFERS WITH ADDRESSES**************************************************
****************|***********|***************|********************************
SET_BUFFER      MOVE.B      #$30,D3         ASCII '0' into D3
                MOVE.B      D3,(A4)+        
                MOVE.B      D3,(A4)+        
                MOVE.B      D3,(A3)+        
                MOVE.B      D3,(A3)+        
                MOVE.L      D5,D3           Move address at D5 to D3
                
                LSL.L       #$8,D3          Move most significant
                JSR         CVT_HEX_ASCII   Convert Hex value to ASCII text
                MOVE.L      D5,D3           Move address at D5 to D3
                
                LSL.L       #$8,D3          Move 2nd most significant
                LSL.L       #$4,D3          Shifting Complete
                JSR         CVT_HEX_ASCII   Convert Hex value to ASCII text
                MOVE.L      D5,D3           Move address at D5 to D3
                
                LSL.L       #$8,D3          Move 3rd most significant
                LSL.L       #$8,D3          Shifting complete
                JSR         CVT_HEX_ASCII   Convert Hex value to ASCII text
                MOVE.L      D5,D3           Move address at D5 to D3
                
                LSL.L       #$8,D3          Move 4th most significant
                LSL.L       #$8,D3 
                LSL.L       #$4,D3          Shifting Complete
                JSR         CVT_HEX_ASCII   Convert Hex value to ASCII text
                MOVE.L      D5,D3           Move address at D5 to D3

                LSL.L       #$8,D3          Move 5th most significant
                LSL.L       #$8,D3 
                LSL.L       #$8,D3          Shifting Complete
                JSR         CVT_HEX_ASCII   Convert Hex value to ASCII text
                MOVE.L      D5,D3           Move address at D5 to D3

                LSL.L       #$8,D3          Move 6th most significant
                LSL.L       #$8,D3
                LSL.L       #$8,D3
                LSL.L       #$4,D3          Shifting Complete
                JSR         CVT_HEX_ASCII   Convert Hex value to ASCII text
                
                RTS                         Decode complete

*****************************************************************************
*CVT_HEX_ASCII***************************************************************
****************|***********|***************|********************************
CVT_HEX_ASCII   LSR.L       #$8,D3          Shift data in D3
                LSR.L       #$8,D3          
                LSR.L       #$8,D3     
                LSR.L       #$4,D3          Shifting complete
                
                CMP.B       #$09,D3         Check if value is a number
                BGT         CVT_CHR         convert to ASCII Character
                ADDI.B      #$30,D3         Add 48 to get ASCII number value
                JMP         SET_GB_BUF      Move to set buffers

CVT_CHR         ADDI.B      #$37,D3         Add 55 to get ASCII letter value

SET_GB_BUF      MOVE.B      D3,(A4)+        Load D3 ASCII value into buffers
                MOVE.B      D3,(A3)+        
                RTS                         Return to set buffers subroutine
                
*****************************************************************************
*PG_CNTR*********************************************************************
****************|***********|***************|********************************
PG_CNTR         LEA         LINES,A2        Move LINES to address register A2   
                ADDI.B      #$1,(A2)        Increment number of lines    
                CMP.B       #30,(A2)        Check if LINES is at max value
                BEQ         SCRN_FULL       Stop printing to screen
                RTS 
SCRN_FULL       MOVE.B      #00,(A2)        Reset line counter at A2
                LEA         NXT_PAGE,A1     Prep continue message
                MOVEQ       #14,D0          Load I/O trap task into D0
                TRAP        #15             Display instruction to user
                LEA         CONTINUE,A1     Load storage for user input
                MOVEQ       #2,D0           Load trap task into D0
                TRAP        #15             Capture user input
                RTS
                
*****************************************************************************
*MISSION_COMPLETE: THE DARTH ENDING******************************************
****************|***********|***************|********************************
MISSION_CMP    
                LEA         DARTH_ENDER,A1  Prep ending art
                MOVEQ       #14,D0          Load trap task into D0
                TRAP        #15             Display ending message and art
                RTS

*****************************************************************************
*BUFFER_A3*******************************************************************
****************|***********|***************|********************************
BUFFER_A3       MOVE.W      (A5),D1         Move A5 data to D1 for load
                JSR         B_A3_HLP        Memory conversion for I/O process
                MOVE.W      (A5),D1         Move A5 data to D1 for load
                LSL.W       #$4,D1          Shift data at D1 by one hex
                JSR         B_A3_HLP        Memory conversion for I/O process
                MOVE.W      (A5),D1         Move A5 data to D1 for load
                LSL.W       #$8,D1          Shift data at D1 by 2 hex
                JSR         B_A3_HLP        Memory conversion for I/O process
                MOVE.W      (A5),D1         Move A5 data to D1 for load
                LSL.W       #$8,D1          3 hex value shift
                LSL.W       #$4,D1           
                JSR         B_A3_HLP        Memory conversion for I/O process
                MOVE.B      #$00,(A3)       End value for buffer load
                RTS
            
*****************************************************************************
*B_A3_HLP********************************************************************
****************|***********|***************|********************************
B_A3_HLP        LSR.W       #$8,D1          3 hex value shift
                LSR.W       #$4,D1           
                CMP.B       #$0A,D1         Check if value is decimal number
                BLT         DEC_NUM         
                ADD.W       #$37,D1         Convert to ASCII char
                MOVE.B      D1,(A3)+        Add to A3 buffer
                RTS 
DEC_NUM         ADD.W       #$30,D1         Convert to ASCII number
                MOVE.B      D1,(A3)+        Add to A3 buffer
                RTS 

*****************************************************************************
*A4_6SPACES******************************************************************
****************|***********|***************|********************************               
A4_6SPACES      MOVE.B #' ',(A4)+           Push spaces to A4 buffer
                MOVE.B #' ',(A4)+ 
                MOVE.B #' ',(A4)+ 
                MOVE.B #' ',(A4)+ 
                MOVE.B #' ',(A4)+ 
                MOVE.B #' ',(A4)+
                RTS

*****************************************************************************
*END PROGRAM*****************************************************************
****************|***********|***************|********************************
                END         DISA_PRG




*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
