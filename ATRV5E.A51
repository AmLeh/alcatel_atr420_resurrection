
;****************************************************************************
;        ALCATEL ATR 421 VERSION DEBUG 2000 F8AZT
;        SENTETS MICHEL
;        VERSION MAQUETTE POUR TEST
;        DEBUT VERSION ATRV5A 18/02/2000
;        VERSION ATRVB DEBUT LE 23/02/2000 Pas de d‚bloquage Volume sur scan
;        R‚glage de extab debut 08/03/2000
;        Modif +frq relais foix -600K ok apres explo table 10/03/2000
;        Version valid‚e le 15/03/2000 reste bug liste de la V4
;        Debug debut le 18/03
;        Version ATRV5E OK mai 2000
;        Attention la version binaire a ‚t‚ modifi‚e sans r‚assemblage
;         directement par le programmateur d'EPROM pour la prise en charge
;         des relais R0 … R7 Fran‡ais !!!!
;****************************************************************************        



A  EQU 0E0H
B  EQU 0F0H
P1 EQU 090H
P3 EQU 0B0H
SP EQU 081H

oceP4_1 EQU 01001110B ;Octet commande ‚criture port 4 premier  8243
ocoP4_1 EQU 10001110B ;Octet commande ‚criture port 4 avec ou logique
ocaP4_1 EQU 11001110B ;Octet commande ‚criture port 4 avec et logique
oceP5_1 EQU 01011110B ;Octet commande ‚criture port 5 premier  8243   
oceP7_1 EQU 01111110B ;Octet commande ‚criture port 7 premier  8243

oceP4_2 EQU 01001111B ;Octet commande ‚criture port 4 deuxiŠme 8243
oceP5_2 EQU 01011111B ;Octet commande ‚criture port 5 deuxiŠme 8243   
oceP6_2 EQU 01101111B ;Octet commande ‚criture port 6 deuxiŠme 8243
oceP7_2 EQU 01111111B ;Octet commande ‚criture port 7 deuxiŠme 8243

oclP6_1 EQU 00101110B ;Octet commande lecture  port 6 premier  8243
oclP7_1 EQU 00111110B ;Octet commande lecture  port 7 premier  8243

SIM_RLY   EQU  07FH
;         EQU  07EH
;         EQU  07DH
;         EQU  07CH
;         EQU  07BH
FRQ_MOD   EQU  07AH
;         EQU  079H
;         EQU  078H
;         EQU  077H
;         EQU  076H
FRQ_ERL   EQU  075H
;         EQU  074H
;         EQU  073H
;         EQU  072H
;         EQU  071H
FRQ_ECR   EQU  070H
DAT_RS    EQU  06FH
DAT_AFF   EQU  06EH
CTR       EQU  06DH
;         EQU  06CH
DSR       EQU  06BH
;         EQU  06AH
;         EQU  069H
RST       EQU  068H
;         EQU  067H
;         EQU  066H
;         EQU  065H
DDE       EQU  064H
;         EQU  063H
;         EQU  062H
;         EQU  061H
QT        EQU  060H
INDX      EQU  05FH
TCH4      EQU  05EH
TCH3      EQU  05DH
TCH2      EQU  05CH
TCH1      EQU  05BH
SVR       EQU  05AH
SVA       EQU  059H
SVR1      EQU  058H
POS_CUR   EQU  057H
POS_FEN   EQU  056H
PAS_ECR   EQU  055H
;         EQU  054H
;         EQU  053H
;         EQU  052H
;         EQU  051H
FRQ_LHT   EQU  050H
;         EQU  04FH
;         EQU  04EH
;         EQU  04DH
;         EQU  04CH
;         EQU  04BH
;         EQU  04AH
;         EQU  049H
CHIFFRE   EQU  048H
NBRCHIF   EQU  047H
DAT_INV   EQU  046H
TOP       EQU  045H
TOP_LON   EQU  044H
SW        EQU  043H
;         EQU  042H
;         EQU  041H
AMR       EQU  040H
RET_MON   EQU  03FH
INV_NOR   EQU  03EH
T_SCA     EQU  03DH
KLAF1     EQU  03CH
TABFRQX   EQU  03BH
;         EQU  03AH
;         EQU  039H
;         EQU  038H
;         EQU  037H
FRQ_TAM   EQU  036H
SOUND     EQU  02FH    ; Cette adresse est utilisable par bit
TMOD       EQU 089H
TCON       EQU 088H
IE         EQU 0A8H

IP         EQU 0B8H
                ORG 00H
                LJMP ATR421
                ORG 0BH
                LJMP INT_TMP
               ; ORG 04006H
               ; LJMP INT_TMP
                
;****************************************************************************
;                    ZONE D'INITIALISATION                 
;****************************************************************************

                ORG 0100H
                ;ORG 04100H
;**************INITIALISATION
ATR421          MOV IE,#00H
                MOV IP,#00H               ;PRIORITE Normale TIMER 0
                MOV DPTR,#0000H
                MOV TOP,#00H             ;INI PETIT COMPTEUR 
                MOV TCH4,#00H
                MOV TCH3,#00H
                MOV TCH2,#00H
                MOV TCH1,#00H            ;INI COMPTEURS DE TOUCHES
                MOV P1,#oceP4_1
                CLR P3.5
                MOV P1,#00011110B        ;INI P4_1 ENR BLM A ZERO KLA A UN
                SETB P3.5
                MOV P1,#oceP5_1
                CLR P3.5
                MOV P1,#00001110B        ;INI VOLUME SILENCIEUX test OK
                SETB P3.5
                MOV SOUND,#00000010B     ;INI NIVEAU DE VOLUME + PARAM
                MOV POS_CUR,#00H
                MOV POS_FEN,#01H
                MOV RET_MON,#00H
                MOV PAS_ECR,#01H         ;MARQUE PAS 12,5K (Abandonn‚)
                MOV DAT_INV,#' '         ;INVERSION SUR RELAI
                MOV INV_NOR,#'I'         ;INVERSION PERMET BASCULE AFFICHAGE
                MOV T_SCA,#'N'
                MOV KLAF1,#' '
                MOV TABFRQX,#00H         ;FIN INI VAR

INI_LCD         MOV DAT_AFF,#0EH         ;LCD ES CURSEUR ES
                MOV DAT_RS,#00H
                LCALL CHA_REG
                LCALL ECR_LCD

                MOV DAT_AFF,#37H    ;LCD UNE LIGNE 5X10 PTS
                MOV DAT_RS,#00H
                LCALL CHA_REG
                LCALL ECR_LCD

                MOV DAT_AFF,#128    ;CURSEUR PREMIER CARACTERE
                MOV DAT_RS,#00H
                LCALL CHA_REG
                LCALL ECR_LCD
INI_TXT         MOV A,#00H
                MOV INDX,A
EXTTXT          LCALL LIT_TXT1           ;EXTRAIT UN CARACTERE DU TEXTE
                MOV DAT_AFF,A
                MOV DAT_RS,#01H
                LCALL CHA_REG
                LCALL ECR_LCD
                MOV A,INDX               ;RECUPERE INDEX
                INC A                    ;PLUS 1
                MOV INDX,A               ;SAUVE INDEX
                CJNE A,#80,EXTTXT        ;FIN EMISSION TEXTE 80 CAR ?
                
STO_MAM         MOV FRQ_MOD,#01H         ;INI FREQUENCE DEPART       
                MOV FRQ_MOD+1,#45H       ;DANS TAMPON
                MOV FRQ_MOD+2,#57H
                MOV FRQ_MOD+3,#50H
                MOV FRQ_MOD+4,#00H       ;FREQ INI
                MOV FRQ_LHT,#01H         ;INIFRQ MAX
                MOV FRQ_LHT+1,#46H
                MOV FRQ_LHT+2,#00H
                MOV FRQ_LHT+3,#00H
                MOV FRQ_LHT+4,#00H
                MOV SIM_RLY,#'S'
                LCALL BAS_FRQ            ;BASCULE MOD VERS ECR 
                LCALL REC_JOB            ;FIN INI

                
                MOV TMOD,#01H            ;MODE 1 POUR TIMER 0
                SETB TCON.4              ;DECLANCHE TIMER 0
                MOV IE,#10000010B        ;VALIDE INT TIMER
                                         ;VALIDE INTERRUPTION GLOBAL
;****************************************************************************
;                        ZONE MONITEUR                       
;****************************************************************************
                
LOOP            MOV A,SOUND               ;Volume
                ANL A,#11000000B
                JZ PACT_VOL
                CJNE A,#01000000B,V5M01
                LCALL ACT_VLU
                ANL SOUND,#00011111B      ;Efface interrup
                SJMP PACT_VOL
V5M01           CJNE A,#10000000B,PACT_VOL;Desactivation
                LCALL DSC_VLU
                ANL SOUND,#00011111B
                
PACT_VOL        MOV A,TCH4                ;TOUCHE FCT
                ANL A,#10000000B
                JZ TSTT3                  ;TESTE AUTRE TOUCHE
                LCALL FCT_JOB                 
                MOV A,TCH4
                ANL A,#00001111B          ;RAZ INTERRUPTION ET SAUVE COMPTEUR 
                MOV TCH4,A              
                AJMP FINTST

                                          
TSTT3           MOV A,TCH3                ;TOUCHE PLUS
                ANL A,#10000000B
                JZ TSTT2
                LCALL PLU_JOB
                MOV A,TCH3
                ANL A,#00001111B
                MOV TCH3,A
                AJMP FINTST


TSTT2           MOV A,TCH2                ;TOUCHE SUIVANT
                ANL A,#10000000B
                JZ TSTT1
                LCALL SUI_JOB
                MOV A,TCH2
                ANL A,#00001111B        ;RAZ INTERRUPTION ET SAUVE COMPTEUR 
                MOV TCH2,A              
                AJMP FINTST


TSTT1           MOV A,TCH1                ;TOUCHE VALIDATION
                ANL A,#10000000B
                JZ TESTPTT
                LCALL VAL_JOB
                MOV A,TCH1
                ANL A,#00001111B
                MOV TCH1,A
                AJMP FINTST

                                  ;Lecture du signal ALTT (PTT)
TESTPTT         LCALL LIP7_1              ;Version 2000 P71_1
                ANL A,#00100000B
                JNZ PTTUN
                MOV A,SW
                ANL A,#00001111B
                CJNE A,#00001001B,FINTST ;DOIT ETRE EN RECEPTION POUR 
                LCALL EM_JOB             ;PASSER EN EMISSION
                MOV A,SIM_RLY
                CJNE A,#'R',FINTST
                LCALL AFFFEN1
                AJMP FINTST

PTTUN           MOV A,SW
                ANL A,#00001111B
                CJNE A,#00001111B,FINTST  ;DOIT ETRE EN EMISSION POUR
                LCALL REC_JOB             ;PASSER EN RECEPTION
                MOV A,SIM_RLY
                CJNE A,#'R',FINTST
                LCALL AFFFEN1
                
FINTST          MOV A,RET_MON
                CJNE A,#081H,LOOP_RET

FIN             MOV IE,#00H             ;FIN DES INTERRUPTIONS
                LCALL DLD_FEN
                MOV POS_FEN,#01H
                MOV POS_CUR,#0
                LCALL REP_CUR
                LCALL CHA_REG
                LCALL ECR_LCD
                
                LJMP ATR421
LOOP_RET        AJMP LOOP


;****************************************************************************
;     MONITEUR SCAN RETOUR AU MONITEUR PRINCIPAL PAR TOUCHE PLUS
;****************************************************************************
INISCAN         MOV SIM_RLY,#'s'          ;POINT D'ENTREE DU SCAN
                MOV DAT_INV,#'c'
                LCALL REC_JOB
                LCALL AFFFEN1
                                       ;Lit signal DP sur P73_1
OCCTST          LCALL LIP7_1           ;Version 2000
                ANL A,#10000000B
                CJNE A,#10000000B,CPRSUIV
                MOV A,T_SCA
                CJNE A,#'N',SORTIESC
                AJMP ESPACMT
CPRSUIV         LCALL CRECRLHT
                MOV A,CTR
                CJNE A,#081H,AJTESCA
                LCALL ECR_LBS
                SJMP FSC125

AJTESCA         CLR C
                MOV A,#25H            ;AJOUTE 2,5k
                ADD A,FRQ_ECR+3
                DA A
                MOV FRQ_ECR+3,A
                MOV A,#01H                  
                ADDC A,FRQ_ECR+2      ;AJOUTE 10,0K
                DA A
                MOV FRQ_ECR+2,A
                JNC FSC125
                MOV A,#01H            ;ON AJOUTE ENCORE A FRQ_LHT+1 
                ADD A,FRQ_ECR+1       ;SI RETENUE
                DA A
                MOV FRQ_ECR+1,A
FSC125          LCALL REC_JOB
                LCALL AFFFEN1

ESPACMT         MOV A,TOP           ;PHOTO DE TOP TEMPO ATTENTE SYNTHE
                ADD A,#2
IATTEND         CJNE A,TOP,IATTEND


TSTEXIT         LCALL LIP7_1              ;PTT
                ANL A,#00100000B
                JZ SORTIESC

TSSIACT         MOV A,SOUND
                ANL A,#11000000B
                CJNE A,#01000000B,TSSIDES
                LCALL ACT_VLU             ;Ouvre HP
                ANL SOUND,#00011111B      ;desac inter
                SJMP TSSUIV5

TSSIDES         MOV A,SOUND
                ANL A,#11000000B
                CJNE A,#10000000B,TSSUIV5
                LCALL DSC_VLU             ;Ferme HP
                ANL SOUND,#00011111B
                
TSSUIV5         MOV A,TCH2                ;TOUCHE SUIVANT
                ANL TCH2,#00001111B       ;RAZ INTERR
                ANL A,#10000000B
                JNZ CPRSUIV               ;Force un pas de plus
                
                MOV A,TCH3                ;TOUCHE PLUS
                ANL TCH3,#00001111B       ;RAZ INTER
                ANL A,#10000000B
                JZ OCCTST                 ;RETOUR VERS BOUCLE

SORTIESC        MOV SIM_RLY,#'S'
                MOV DAT_INV,#' '
                MOV INV_NOR,#'I'
                LCALL REC_JOB
                LCALL AFFFEN1
                MOV TCH1,#01H
                MOV TCH4,#01H
                AJMP LOOP



                
;****************************************************************************
;     MONITEUR EXTAB RETOUR AU MONITEUR PRINCIPAL PAR TOUCHE PLUS
;****************************************************************************

EXTAB           MOV SIM_RLY,#'e'          ;POINT D'ENTREE DU SCAN
                MOV DAT_INV,#'t'
                LCALL REC_JOB
                LCALL AFFFEN1
                                       ;Lit signal DP sur P73_1
OCCTSET         LCALL LIP7_1           ;Version 2000
                ANL A,#10000000B
                CJNE A,#10000000B,CHANIDX
                MOV A,T_SCA
                CJNE A,#'N',SORTET
                AJMP ESPAMTT
                
CHANIDX         MOV A,TABFRQX
                ADD A,#5
                CJNE A,#80,NOFTAB
                MOV A,#0
NOFTAB          MOV TABFRQX,A
                LCALL TAB_ECR
                LCALL REC_JOB
                LCALL AFFFEN1

ESPAMTT         MOV A,TOP           ;PHOTO DE TOP TEMPO ATTENTE SYNTHE
                ADD A,#2
XATTEND         CJNE A,TOP,XATTEND


TSEXIET         LCALL LIP7_1              ;PTT
                ANL A,#00100000B
                JZ SORTET

TSACTET         MOV A,SOUND
                ANL A,#11000000B
                CJNE A,#01000000B,TSDESET
                LCALL ACT_VLU             ;Ouvre HP
                ANL SOUND,#00011111B      ;desac inter
                SJMP TSUIVET

TSDESET         MOV A,SOUND
                ANL A,#11000000B
                CJNE A,#10000000B,TSUIVET
                LCALL DSC_VLU             ;Ferme HP
                ANL SOUND,#00011111B
                
TSUIVET         MOV A,TCH2                ;TOUCHE SUIVANT
                ANL TCH2,#00001111B       ;RAZ INTERR
                ANL A,#10000000B
                JNZ CHANIDX               ;Force un pas de plus
                
                MOV A,TCH3                ;TOUCHE PLUS
                ANL TCH3,#00001111B       ;RAZ INTER
                ANL A,#10000000B
                JZ OCCTSET                 ;RETOUR VERS BOUCLE

SORTET          MOV SIM_RLY,#'R'
                MOV DAT_INV,#' '
                MOV INV_NOR,#'I'
                MOV TCH1,#01H
                MOV TCH4,#01H
                ;LCALL AFFFEN1
                LCALL SOUS600
                LCALL AFFFEN1
                AJMP LOOP

                

;****************************************************************************
;      ZONES DES SOUS PROGRAMMES DE COMMANDES
;****************************************************************************
;****************************************************************************
;     TOUCHE FCT EN DEMANDE POUSSE A DROITE UNE FENETRE SUR L'AFFICHEUR
;****************************************************************************
FCT_JOB        MOV A,POS_FEN           ;MISE A JOUR FENETRE EN COURS
               INC A
               CJNE A,#06H,NMAJ
               MOV A,#01H
NMAJ           MOV POS_FEN,A 
               LCALL DLD_FEN           ;POUSSE A DROITE D'UNE FENETRE
               LCALL INI_CUR           ;CALCULE POSITION INI DANS LA FENETRE
               LCALL REP_CUR
               RET
;****************************************************************************
;       TOUCHE SUIVANT EN DEMANDE
;****************************************************************************

SUI_JOB        MOV A,POS_FEN
               ADD A,#-1
               RL A                ;*2
               ANL A,#11111110B
               MOV DPTR,#SUI_TAB
               JMP @A+DPTR
SUI_TAB        AJMP SUIFEN1
               AJMP SUIFEN2
               AJMP SUIFEN3
               AJMP SUIFEN4
               AJMP SUIFEN5

;****************************************************************************
;      TOUCHE SUIVANT COMMANDES DES SAUTS DE CURSEURS
;****************************************************************************
SUIFEN1        MOV A,KLAF1
               CJNE A,#' ',DCRECR
               MOV A,SW
               CJNE A,#00001001B,CPAREC
               MOV A,SIM_RLY                            
               CJNE A,#'S',CPASSIM                 ;ON EST EN REC
               MOV SIM_RLY,#'R'
               LCALL AFFFEN1
               LCALL SOUS600
               RET

DCRECR         MOV A,SW
               CJNE A,#09H,CPAREC
               MOV A,SIM_RLY
               CJNE A,#'S',CPASSIM
               LCALL SOU125
               LCALL REC_JOB
               LCALL AFFFEN1
               RET

CPASSIM        MOV A,SIM_RLY
               CJNE A,#'R',CPASREL
               MOV A,DAT_INV
               CJNE A,#' ',CPASREL
               MOV SIM_RLY,#'S'
               LCALL AFFFEN1
               RET

CPASREL        RET

CPAREC         RET

SUIFEN2        INC POS_CUR             
               MOV A,POS_CUR
               CJNE A,#3,REGSI6
               INC POS_CUR
               SJMP AGILCD
REGSI6         CJNE A,#6,AGILCD
               MOV POS_CUR,#1
AGILCD         LCALL REP_CUR
               RET


SUIFEN3        LCALL BAS_LHT
               LCALL AFFFEN3
SF3FIN         RET             

SUIFEN4        MOV A,POS_CUR
               ADD A,#5
               MOV POS_CUR,A           ;PLUS QUATRE
               CJNE A,#13,V5A001
               MOV POS_CUR,#3
V5A001         LCALL REP_CUR
               RET

SUIFEN5        MOV POS_FEN,#01
               LCALL DLD_FEN
               LJMP EXTAB
               RET
;****************************************************************************
;       TOUCHE PLUS EN DEMANDE
;****************************************************************************
PLU_JOB        MOV A,POS_FEN
               ADD A,#-1
               RL A                ;*2
               ANL A,#11111110B
               MOV DPTR,#PLU_TAB
               JMP @A+DPTR
PLU_TAB        AJMP PLFEN1
               AJMP PLFEN2
               AJMP PLFEN3
               AJMP PLFEN4
               AJMP PLFEN5

;****************************************************************************
;      TOUCHE PLUS COMMANDES DES INCREMENTATIONS ET INVERSION
;****************************************************************************
PLFEN1          MOV A,KLAF1
                CJNE A,#' ',ICRECR
                MOV A,SIM_RLY
                CJNE A,#'R',CPALER
                
                MOV A,DAT_INV
                XCH A,INV_NOR
                MOV DAT_INV,A
                LCALL REC_JOB
                LCALL AFFFEN1
                RET
ICRECR          MOV A,SW
                CJNE A,#09H,ICRFIN
                MOV A,SIM_RLY
                CJNE A,#'S',ICRFIN
                LCALL P125ECR
                LCALL REC_JOB
                LCALL AFFFEN1
ICRFIN          RET

CPALER          RET

PLFEN2          MOV A,POS_CUR
                CJNE A,#01H,PLS1FEN2
                AJMP INCDZMG
PLS1FEN2        CJNE A,#02H,PLS2FEN2
                AJMP INCMG
PLS2FEN2        CJNE A,#04H,PLS3FEN2
                AJMP INCCK
PLS3FEN2        CJNE A,#05H,PLS4FEN2
                AJMP INCPAS
PLS4FEN2        RET
               
               
PLFEN3          NOP
PLF3FIN         RET

PLFEN4          MOV A,POS_CUR
                CJNE A,#8,REG_VOL
TT_SCA          MOV A,T_SCA              ;Suivant pos curseur (8)
                CJNE A,#'N',COUI
                MOV T_SCA,#'O'
ECR_ON          MOV DAT_AFF,T_SCA
                MOV DAT_RS,#01H
                LCALL CHA_REG
                LCALL ECR_LCD
                LCALL REP_CUR
                RET
COUI            MOV T_SCA,#'N'
                AJMP ECR_ON

REG_VOL         MOV A,SOUND
                ANL A,#0FH
                INC A
                CJNE A,#7,AFF_VOL
                MOV A,#1
AFF_VOL         ANL SOUND,#11110000B  ;Raz nombre
                ORL SOUND,A           ;Rangement des 4eb sans toucher … 7654
                ORL A,#030H
                MOV DAT_AFF,A
                MOV DAT_RS,#01H
                LCALL CHA_REG
                LCALL ECR_LCD
                LCALL REP_CUR
                RET
                


PLFEN5         LCALL TRA_FRQ           ;CHARGE UNE FRQ DANS FRQ_TAM
               LCALL TRAS_AFF
               LCALL AFF_CHI
               LCALL REP_CUR
               MOV A,TABFRQX
               ADD A,#5
               CJNE A,#80,PASFTAB
               MOV A,#0
PASFTAB        MOV TABFRQX,A            ;INDEX REPOSITIONNE
               RET
                



INCDZMG         MOV A,FRQ_MOD+1
                SWAP A                  ;PREND DZNE DE MEGA
                ANL A,#00001111B
                INC A
                CJNE A,#0AH,RGEDZM
                MOV A,#00H              ;TOP REDESCENDRE CHIFFRE DE BASE
RGEDZM          MOV CHIFFRE,A
                MOV NBRCHIF,#01H
                SWAP A
                MOV R0,A
                MOV A,FRQ_MOD+1
                ANL A,#00001111B        ;EFFACE ANCIEN DZM
                ORL A,R0                ;REMET
                MOV FRQ_MOD+1,A         ;RANGE EN MAM
                LCALL AFF_CHI           ;APPEL AFFICHAGE UN CHIFFRE
                RET

INCMG           MOV A,FRQ_MOD+1
                ANL A,#00001111B
                INC A
                CJNE A,#0AH,RGEUMG
                MOV A,#00H              ;TOP REDESCENDRE CHIFFRE DE BASE
RGEUMG          MOV CHIFFRE,A
                MOV NBRCHIF,#01H
                MOV R0,A
                MOV A,FRQ_MOD+1
                ANL A,#11110000B        ;EFFACE ANCIEN MG
                ORL A,R0                ;REMET
                MOV FRQ_MOD+1,A         ;RANGE EN MAM
                LCALL AFF_CHI           ;APPEL AFFICHAGE UN CHIFFRE
                RET

INCCK           MOV A,FRQ_MOD+2
                SWAP A                  ;PREND DZNE DE MEGA
                ANL A,#00001111B
                INC A
                CJNE A,#0AH,RGECKL
                MOV A,#00H              ;TOP REDESCENDRE CHIFFRE DE BASE
RGECKL          MOV CHIFFRE,A
                MOV NBRCHIF,#01H
                SWAP A
                MOV R0,A
                MOV A,FRQ_MOD+2
                ANL A,#00001111B        ;EFFACE ANCIEN 
                ORL A,R0                ;REMET
                MOV FRQ_MOD+2,A         ;RANGE EN MAM
                LCALL AFF_CHI           ;APPEL AFFICHAGE UN CHIFFRE
                RET

INCPAS          NOP 
ADD_PAS         MOV A,#25H              ;12,5K
                ADD A,FRQ_MOD+3
                DA A
                MOV FRQ_MOD+3,A         ;RANGE
                MOV A,FRQ_MOD+2
                ADDC A,#01H
                DA A
                ANL A,#00001111B
                MOV R0,A                ;SAUVE VALEUR
                MOV A,FRQ_MOD+2
                ANL A,#11110000B
                ORL A,R0
                MOV FRQ_MOD+2,A         ;FIN ADDITION
                MOV A,FRQ_MOD+2
                ANL A,#00001111B
                MOV CHIFFRE,A           ;CHIFFRE 
                MOV A,FRQ_MOD+3
                SWAP A
                ANL A,#00001111B
                MOV CHIFFRE+1,A
                MOV A,FRQ_MOD+3
                ANL A,#00001111B
                MOV CHIFFRE+2,A
                MOV NBRCHIF,#03H
                LCALL AFF_CHI
                ;MOV A,PAS_ECR              Version 5 pas de 12,5 fixe
                ;SUBB A,#01H
                ;MOV 030H,#3
;PAS_25          MOV A,FRQ_MOD+3
                ;ANL A,#00001111B       ;SI PAS DE 25K REFAIRE UN TOUR
                ;CJNE A,#00H,ADD_PAS    ;OU NON SUIVANT OU ON EST
PAS_FIN         RET



;****************************************************************************
;       TOUCHE VALIDATION EN DEMANDE
;****************************************************************************
VAL_JOB        MOV A,POS_FEN
               ADD A,#-1
               RL A                ;*2
               ANL A,#11111110B
               MOV DPTR,#VAL_TAB
               JMP @A+DPTR
VAL_TAB        AJMP VALFEN1
               AJMP VALFEN2
               AJMP VALFEN3
               AJMP VALFEN4
               AJMP VALFEN5

VALFEN1        MOV A,KLAF1
               CJNE A,#' ',DCCU
               MOV KLAF1,#'U'
               LCALL AFFFEN1
               RET
DCCU           MOV KLAF1,#' '
               LCALL AFFFEN1
               RET

VALFEN2        LCALL BAS_FRQ
               MOV POS_FEN,#01H  
               LCALL DLG_FEN
               MOV SIM_RLY,#'S'
               MOV DAT_INV,#' '
               MOV INV_NOR,#'I'
               LCALL REC_JOB
               LCALL AFFFEN1
               RET

VALFEN3        
               MOV POS_FEN,#2
               LCALL DLG_FEN
               MOV POS_FEN,#1
               LCALL DLG_FEN
               LCALL ECR_LBS
               LJMP INISCAN


               RET

VALFEN4        MOV POS_FEN,#3
               LCALL DLG_FEN
               MOV POS_FEN,#2
               LCALL DLG_FEN
               MOV POS_FEN,#1
               LCALL DLG_FEN
               MOV A,POS_CUR
               CJNE A,#8,FVALFE4
               LJMP INISCAN
               RET
FVALFE4        ANL SOUND,#11101111B
               RET

VALFEN5        MOV POS_FEN,#01H
               LCALL DLD_FEN
               MOV SIM_RLY,#'S'
               MOV DAT_INV,#' '
               MOV INV_NOR,#'I'
               LCALL BTAM_ECR
               JNZ FVAL5
               LCALL REC_JOB
               MOV SIM_RLY,#'R'
               LCALL SOUS600
               LCALL AFFFEN1
FVAL5          RET


;****************************************************************************
;     AFFICHAGE CHIFFRE DEMANDE A L'EMPLACEMENT CURSEUR
;****************************************************************************

AFF_CHI        MOV R0,#CHIFFRE
AFF_LOO        MOV A,@R0
               ORL A,#00110000B           ;PASSAGE EN ASCII
               MOV DAT_AFF,A
               MOV DAT_RS,#01H
               MOV INDX,R0
               LCALL CHA_REG
               LCALL ECR_LCD
               MOV R0,INDX
               INC R0
               DEC NBRCHIF
               MOV A,NBRCHIF
               JNZ AFF_LOO
               LCALL REP_CUR
               RET

AFF_DEM        MOV R0,#CHIFFRE
LOO_DEM        MOV A,@R0
               MOV DAT_AFF,A
               MOV DAT_RS,#01H
               MOV INDX,R0
               LCALL CHA_REG
               LCALL ECR_LCD
               MOV R0,INDX
               INC R0
               DEC NBRCHIF
               MOV A,NBRCHIF
               JNZ LOO_DEM
               RET

;****************************************************************************
;      DECALAGE VERS LA DROITE FENETRE LCD
;****************************************************************************

DLD_FEN         MOV R4,#16              ;SEQ DE 16 DECALAGES 
DLD_ENC         MOV DAT_AFF,#1BH        ;AFFICHAGE VERS LA DROITE
                MOV DAT_RS,#00H
                LCALL CHA_REG
                LCALL ECR_LCD
                DEC R4
                CJNE R4,#00H,DLD_ENC
                RET
;****************************************************************************
;       DECALAGE A GAUCHE FENETRE LCD
;****************************************************************************
DLG_FEN         MOV R4,#16              ;SEQ DE 16 DECALAGES 
DLG_ENC         MOV DAT_AFF,#1FH        ;AFFICHAGE VERS LA GAUCHE
                MOV DAT_RS,#00H
                LCALL CHA_REG
                LCALL ECR_LCD
                DEC R4
                CJNE R4,#00H,DLG_ENC
                RET

;****************************************************************************
;      TEXTE INITIAL DONNE SUR LE LCD AU DEMARRAGE
;****************************************************************************

LIT_TXT1        INC A
                MOVC A,@A+PC
                RET
                DB '145,5750 Mhz S  '
                DB '145,5750 Manuel '
                DB '146,0000 Fr Max '
                DB 'Vl 2 St N       '
                DB 'Liste        >  '
                             
;****************************************************************************
;     REPOSITIONNE LE CURSEUR
;****************************************************************************
REP_CUR                  ;REPOSITIONNE CURSEUR A LA DEMANDE
                         ;POS_CUR = POSITION DANS LA FENETRE
                CLR IE.7           ;INTERR NIET
                MOV A,POS_FEN
                ADD A,#-1
                SWAP A             ;X 16
                ANL A,#11110000B
                ORL A,POS_CUR
                ORL A,#10000000B
                MOV DAT_AFF,A
                MOV DAT_RS,#00H
                LCALL CHA_REG
                LCALL ECR_LCD
                RET

;****************************************************************************
;       AFFICHAGE FENETRE UNE
;****************************************************************************
AFFFEN1         MOV POS_CUR,#0
                LCALL REP_CUR
                MOV CHIFFRE,#'1'
                MOV A,FRQ_ECR+1
                MOV CHIFFRE+2,A
                SWAP A
                MOV CHIFFRE+1,A
                MOV CHIFFRE+3,#','
                MOV A,FRQ_ECR+2
                MOV CHIFFRE+5,A
                SWAP A
                MOV CHIFFRE+4,A
                MOV A,FRQ_ECR+3
                MOV CHIFFRE+7,A
                SWAP A
                MOV CHIFFRE+6,A
                ANL CHIFFRE+1,#0FH
                ORL CHIFFRE+1,#30H
                ANL CHIFFRE+2,#0FH
                ORL CHIFFRE+2,#30H
                ANL CHIFFRE+4,#0FH
                ORL CHIFFRE+4,#30H
                ANL CHIFFRE+5,#0FH
                ORL CHIFFRE+5,#30H
                ANL CHIFFRE+6,#0FH
                ORL CHIFFRE+6,#30H
                ANL CHIFFRE+7,#0FH       ;PASSE LES CHIFFRE EN ASCII
                ORL CHIFFRE+7,#30H
                MOV NBRCHIF,#8
                LCALL AFF_DEM
                MOV CHIFFRE,#' '
                MOV CHIFFRE+1,#'M'
                MOV CHIFFRE+2,#'h'
                MOV CHIFFRE+3,#'z'
                MOV CHIFFRE+4,#' '
                MOV CHIFFRE+5,SIM_RLY
                MOV CHIFFRE+6,DAT_INV
                MOV CHIFFRE+7,KLAF1
                MOV NBRCHIF,#8
                LCALL AFF_DEM
                RET

;****************************************************************************
;       AFFICHAGE FENETRE TROIS  
;****************************************************************************

AFFFEN3         MOV DAT_AFF,#160
                MOV DAT_RS,#0
                LCALL CHA_REG
                LCALL ECR_LCD        ;REPOSITIONNE SUR FEN 3 MASQUE
                                     ;AFFICHE FRQ_MAX SCAN
                MOV CHIFFRE,#'1'
                MOV A,FRQ_LHT+1
                MOV CHIFFRE+2,A
                SWAP A
                MOV CHIFFRE+1,A
                MOV CHIFFRE+3,#','
                MOV A,FRQ_LHT+2
                MOV CHIFFRE+5,A
                SWAP A
                MOV CHIFFRE+4,A
                MOV A,FRQ_LHT+3
                MOV CHIFFRE+7,A
                SWAP A
                MOV CHIFFRE+6,A
                ANL CHIFFRE+1,#0FH
                ORL CHIFFRE+1,#30H
                ANL CHIFFRE+2,#0FH
                ORL CHIFFRE+2,#30H
                ANL CHIFFRE+4,#0FH
                ORL CHIFFRE+4,#30H
                ANL CHIFFRE+5,#0FH
                ORL CHIFFRE+5,#30H
                ANL CHIFFRE+6,#0FH
                ORL CHIFFRE+6,#30H
                ANL CHIFFRE+7,#0FH       ;PASSE LES CHIFFRE EN ASCII
                ORL CHIFFRE+7,#30H
                MOV NBRCHIF,#8
                LCALL AFF_DEM
                MOV CHIFFRE,#' '
                MOV CHIFFRE+1,#'F'
                MOV CHIFFRE+2,#'r'
                MOV CHIFFRE+3,#' '
                MOV CHIFFRE+4,#'M'
                MOV CHIFFRE+5,#'a'
                MOV CHIFFRE+6,#'x'
                MOV CHIFFRE+7,#' '
                MOV NBRCHIF,#8
                LCALL AFF_DEM
                RET

;****************************************************************************
;      PASSAGE EN RECEPTION
;****************************************************************************
REC_JOB         CLR IE.7
                MOV A,SIM_RLY
                CJNE A,#'R',RECNORM
                AJMP RECRLY
RECNORM         LCALL PREP_REC
SYNREC          LCALL SYN_JOB         ;PREP_REC A TOUT INITIALISE
                SETB P3.5
                MOV P1,#ocaP4_1
                CLR P3.5
                MOV P1,#10111110B
                SETB P3.5             ;Desactivation de BLM seul
                SETB IE.7
                RET

;****************************************************************************
;      PASSAGE EN RECEPTION RELAI
;****************************************************************************

RECRLY          LCALL PREP_RRL
                AJMP SYNREC
;****************************************************************************
;     PASSAGE EN EMISSION 
;****************************************************************************
EM_JOB          CLR IE.7              ;PAS D'INTERRUPTION
                MOV A,SIM_RLY
                CJNE A,#'R',EMNORM
                AJMP EMRL
                
EMNORM          LCALL PREP_EMN
AGISYN          LCALL SYN_JOB         ;PREP_EM OU PREP_ERL 
                                      ; A TOUT INITIALISE
                SETB P3.5       ;Activation de BLM
                MOV P1,#ocoP4_1
                CLR P3.5
                MOV P1,#01001110B      ;P42_1 = BLM
                SETB P3.5
                SETB IE.7
                RET
;****************************************************************************
;     PASSAGE EN EMISSION SUR RELAI -600 K
;****************************************************************************
EMRL            LCALL PREP_ERL
                AJMP AGISYN
                


;****************************************************************************
;       ZONE SP MATERIELS
;            *   *  *  * * * * * * * * * * * * *
;            * * * * *  *  * *   * *   * * *   *
;            *   **   * *  * * * *  ** * * * * * * *
;****************************************************************************
;****************************************************************************
;    CHARGEMENT SERIE DU SYNTHETISEUR
;****************************************************************************

                                   ;DS P3.3
                                   ;CLK ECRITURE A L'ADRESSE E000
                                   ;ENB P1.2

SYN_JOB       MOV A,AMR+1
              SWAP A             ;PRESENTE LES EB 3.2.1.0
              RL A
              RL A               ;POSITIONNE eb 9 eb 8       du COMPTEUR N
              MOV R0,A           ;PRET !
              MOV A,AMR          ;PREPARE eb 7 6 5 4 3 2 1 0 du COMPTEUR N
              MOV R1,A           ;PRET !
              MOV A,AMR+2        ;RESTE
              RL A               ;PREPARE eb 6 5 4 3 2 1 0   du COMPTEUR A
              MOV R2,A           ;PRET !
              MOV DPTR,#0E000H

              ;ZONE D'ENVOI

              MOV A,SW
              RLC A
              MOV P3.3,C
              LCALL HORLOGE
              RLC A
              MOV P3.3,C
              LCALL HORLOGE       ;SW1 SW2

              MOV A,R0
              RLC A
              MOV P3.3,C
              LCALL HORLOGE
              RLC A
              MOV P3.3,C
              LCALL HORLOGE       ;N9 N8

              MOV A,R1
              RLC A
              MOV P3.3,C
              LCALL HORLOGE
              RLC A
              MOV P3.3,C
              LCALL HORLOGE
              RLC A
              MOV P3.3,C
              LCALL HORLOGE
              RLC A
              MOV P3.3,C
              LCALL HORLOGE
              RLC A
              MOV P3.3,C
              LCALL HORLOGE
              RLC A
              MOV P3.3,C
              LCALL HORLOGE
              RLC A
              MOV P3.3,C
              LCALL HORLOGE
              RLC A
              MOV P3.3,C
              LCALL HORLOGE     ;N7 A N0

              MOV A,R2
              RLC A
              MOV P3.3,C
              LCALL HORLOGE
              RLC A
              MOV P3.3,C
              LCALL HORLOGE
              RLC A
              MOV P3.3,C
              LCALL HORLOGE
              RLC A
              MOV P3.3,C
              LCALL HORLOGE
              RLC A
              MOV P3.3,C
              LCALL HORLOGE
              RLC A
              MOV P3.3,C
              LCALL HORLOGE
              RLC A
              MOV P3.3,C
              LCALL HORLOGE       ;A6 A A0

              MOV P1,#ocoP4_1   ;_/  Validation P43_1
              CLR P3.5
              MOV P1,#10001110B ;garde les eb 2,1,0 idem
              SETB P3.5
              MOV A,#12
AUENB         DJNZ A,AUENB      ;Signal ENR 20æs   Emission complete 500æs
              MOV P1,#ocaP4_1   ;et pour consever les autres eb
              CLR P3.5
              MOV P1,#01111110B ;Remet P43_1 … zero
              SETB P3.5
              RET

       
HORLOGE       MOVX @DPTR,A        ;Signal CLK 1æs
              MOV R4,#10
TPS2X         DJNZ R4,TPS2X     ; 25æs entre donn‚es
              RET                
         

;****************************************************************************
;    CHARGEMENT REGISTRES DE 8243 (2) MISE A DISPO DES DATA POUR LE LCD
;****************************************************************************
       ;DAT_AFF Vers Port 6 et 7 de 8243(2)
CHA_REG CLR IE.7           ;Pas d'interruptions
        SETB P3.5
        MOV A,DAT_AFF
        MOV P1,#oceP7_2
        CLR P3.5           ;Prog \_
        MOV SVA,A
        ORL A,#00000001B   ;Selection 8243(2) Conserv‚e
        MOV P1,A           ;Data
        SETB P3.5          ;D7 a D4 Dans Port 7 8243(2)
        MOV A,SVA
        SWAP A
        MOV P1,#oceP6_2
        CLR P3.5
        ORL A,#00000001B   ;Selection 8243(2) Conserv‚e
        MOV P1,A           ;Data
        SETB P3.5          ;D3 … D0 Dans Port 6 8243(2)
        MOV A,DAT_RS
        SWAP A
        MOV P1,#oceP5_2
        CLR P3.5           ;Prog \_
        ORL A,#00000001B
        MOV P1,A           ;Data RS
        SETB P3.5          ;Data RS Dans Port 5 8243(2)
        RET 

;****************************************************************************
;      LECTURE DU PORT 7 DE 8243(1) Renvoie DP ET ALTT DANS A
;****************************************************************************
      ; A = DP NC ALTT NC X X X X 

LIP7_1  CLR IE.7           ;Pas d'interruptions
        SETB P3.5
        MOV P1,#oclP7_1
        CLR P3.5           ;Prog \_
        MOV P1,#11111110B  ;Stabilit‚ des data
        MOV A,P1
        SETB P3.5          ;Fin de lecture
        SETB IE.7          ;Fin interdiction inter
        RET

;****************************************************************************
;    ACTIVATION DU VOLUME
;****************************************************************************
ACT_VLU        CLR IE.7
               ORL SOUND,#00010000B    ;Marque SA son actif
               MOV A,SOUND
               SWAP A                  ;Prepare la data
               RL A
               ORL A,#00001110B
               ANL A,#11111110B
                SETB P3.5
                MOV P1,#oceP5_1
                CLR P3.5
                MOV P1,A       
                SETB P3.5
               SETB IE.7
               RET
;****************************************************************************
;  DESACTIVATION DU VOLUME
;****************************************************************************
DSC_VLU        CLR IE.7
               ANL SOUND,#11101111B     ;Marque SA son non actif
               SETB P3.5
               MOV P1,#oceP5_1
               CLR P3.5
               MOV P1,#00001110B
               SETB P3.5                ;RAZ VOL
               SETB IE.7
               RET
;****************************************************************************
;    TRANSFERT DES DATA REGISTRE VERS LCD
;****************************************************************************

ECR_LCD        MOV P1,#oceP4_2       ;Commande EAF P40_2
               CLR P3.5              ;Prog \_
               MOV P1,#00010001B     ;
               SETB P3.5             ;Mise … un P40_2
               MOV R0,#50
WT1ini         DJNZ R0,WT1ini             ;TEMPS _/    \_
               MOV P1,#oceP4_2
               CLR P3.5
               MOV P1,#00000001B
               SETB P3.5             ;Mise … zero de P40_2
               SETB IE.7           ;AUTORISE INTERR
               RET



;****************************************************************************
;     ZONE SP INTERRUPTION
;****************************************************************************
INT_TMP         INC TOP
                MOV SVA,A
                MOV SVR1,R1
                MOV A,TOP
                CJNE A,#100,SCRUT
                INC TOP_LON        ;ENVIRON TOUTES LES 6 SECONDES
SCRUT           NOP                ;TEST SANS KLA PREPARE SCRUTATION 

LIT_KLA         MOV P1,#ocaP4_1    ;commande et logique
                CLR P3.5           ;\_ Prog
                MOV P1,#11101110B  ;P40_1 … zero
                SETB P3.5          ;Clicq
                MOV P1,#oclP6_1
                CLR P3.5           ;\_ Prog
                MOV P1,#11111110B  ;pr‚pare la lecture
                MOV A,P1           ;lecture
                SETB P3.5
                MOV P1,#ocoP4_1    ;ou logique
                CLR P3.5
                MOV P1,#00011110B  ;repositionne P40_1 en gardant 
                SETB P3.5          ;P41_1 P42_1 P43_1

                CPL A
                MOV R1,#TCH4
LOOPEX          CLR C
                RLC A             ;TEST EB 
                JNC RAZ
                INC @R1
                SJMP AUTRE
RAZ             MOV @R1,#00H
AUTRE           DEC R1
                CJNE R1,#TCH1-1,LOOPEX

                MOV R1,#TCH4                  ;RECHERCHE DES ER
ERLOOP          MOV A,@R1                     ;PREND LE COMPTEUR
                CJNE A,#07H,CHER1             ;TEMPO
                MOV A,#01H
                MOV @R1,A
CHER1           CJNE A,#01H,NOER
                MOV @R1,A                     ;ER TROUVE LE MARQUER
                MOV A,#10000000B
                ORL A,@R1
                MOV @R1,A

NOER            DEC R1                        ;NO ER OU ER TRAITE
                CJNE R1,#TCH1-1,ERLOOP        ;SUIVANT ?
                MOV A,SOUND
                ANL A,#00010000B
                SWAP A
                MOV R1,A
TESTP1          MOV A,P1
                CPL A
                ANL A,#00000100B              ;eb de P1
                JZ TSTDPV5
                MOV A,R1
                ORL A,#00000100B
                MOV R1,A


TSTDPV5         SETB P3.5
                MOV P1,#oclP7_1
                CLR P3.5
                MOV P1,#11111110B
                MOV A,P1
                SETB P3.5
                ANL A,#10000000B              ;P73_1
                JZ EVAL
                MOV A,#00000010B              ;eval de dp
                ADD A,R1
                MOV R1,A
EVAL            MOV A,R1
                CJNE A,#01H,EVAL2
                ORL SOUND,#10000000B          ;Marque even desactiver
                SJMP FIN_SP
EVAL2           CJNE A,#02H,EVAL4     
                ORL SOUND,#01000000B          ;Marque even activer
                SJMP FIN_SP
EVAL4           CJNE A,#04H,EVAL6
                ORL SOUND,#01000000B          ;Idem
                SJMP FIN_SP
EVAL6           CJNE A,#06H,FIN_SP
                ORL SOUND,#01000000B          ;Idem
                
FIN_SP          MOV A,SVA
                MOV R1,SVR1
                RETI                          ;FIN INTERRUPTION

;****************************************************************************
;
;      ZONE DES SOUS PROGRAMMES LOGIQUES
;      
;****************************************************************************
                
;****************************************************************************
;     ADITIONNE SUR 32 eb
;****************************************************************************
ADD_32        MOV A,CTR
              JZ ADD_FIN
              CLR C
              MOV A,DDE            ;OCTET DE PDS FAIBLE VERS PDS FORT
              ADDC A,QT            ;AJOUTE
              MOV DDE,A            ;RANGE
              MOV A,DDE+1          
              ADDC A,QT+1          ;AJOUTE
              MOV DDE+1,A
              MOV A,DDE+2
              ADDC A,QT+2
              MOV DDE+2,A
              MOV A,DDE+3
              ADDC A,QT+3
              MOV DDE+3,A           ;RANGE
              DJNZ CTR,ADD_32
ADD_FIN       RET


;****************************************************************************
;     PREPARE LA RECEPTION SIMPLEX
;****************************************************************************
PREP_REC        LCALL BIN_FRQ
                LCALL ADD_214
                LCALL CHA_DIV
                LCALL DIV_32
                LCALL MAM_AMR
                MOV SW,#00001001B
                RET
;****************************************************************************
;     PREPARE LA RECEPTION SUR RELAI
;****************************************************************************
PREP_RRL        LCALL XCHANG          ;RECUPERE FREQUENCE EN COURS
                AJMP PREP_REC
;****************************************************************************
;     PREPARE L EMISSION  SIMPLEX
;****************************************************************************
PREP_EMN        LCALL BIN_FRQ
                LCALL CHA_DIV
                LCALL DIV_32
                LCALL MAM_AMR
                MOV SW,#11001111B
                RET
;****************************************************************************
;     PREPARE L EMISSION SUR RELAI
;****************************************************************************
PREP_ERL        LCALL SOUS600       ;SOUSTRAIT 600K DE FRQ_ECR > FRQ_ERL
                LCALL XCHANG        ;PASSE FRQ_ERL <> FRQ_ECR
                LCALL BIN_FRQ
                LCALL CHA_DIV
                LCALL DIV_32
                LCALL MAM_AMR
                MOV SW,#11001111B
                RET

;****************************************************************************
;     ECHANGE FRQ_CR AVEC FRQ_ERL
;****************************************************************************
XCHANG          MOV A,FRQ_ECR
                XCH A,FRQ_ERL
                MOV FRQ_ECR,A
                MOV A,FRQ_ECR+1
                XCH A,FRQ_ERL+1
                MOV FRQ_ECR+1,A
                MOV A,FRQ_ECR+2
                XCH A,FRQ_ERL+2
                MOV FRQ_ECR+2,A
                MOV A,FRQ_ECR+3
                XCH A,FRQ_ERL+3
                MOV FRQ_ECR+3,A
                MOV A,FRQ_ECR+4
                XCH A,FRQ_ERL+4
                MOV FRQ_ECR+4,A
                RET
;****************************************************************************
;     MET DANS ECR LA FREQUENCE EN ATTENTE DANS FRQ_TAM
;****************************************************************************
BTAM_ECR        MOV A,FRQ_TAM
                CJNE A,#01H,FISRF ;controle coherence 
                MOV R0,#FRQ_ECR
                MOV R1,#FRQ_TAM
                MOV CTR,#5
BCL_ENC         MOV A,@R1         ;PRISE FRQ_TAM
                MOV @R0,A         ;MISE DANS FRQ_ENC
                DEC CTR
                INC R0
                INC R1
                MOV A,CTR
                JNZ BCL_ENC       
                RET               
FISRF           MOV A,#081H
                RET
;****************************************************************************
;      TRANFERE UNE FREQUENCE DANS FRQ_ECR DEPUIS TABLE
;****************************************************************************
TAB_ECR         MOV A,TABFRQX
                MOV DPTR,#FRQ_TAB
                MOV SVA,A           ;SAUVEGARDE A
                MOVC A,@A+DPTR
                MOV FRQ_ECR,A
                INC SVA
                MOV A,SVA
                MOVC A,@A+DPTR
                MOV FRQ_ECR+1,A
                INC SVA
                MOV A,SVA
                MOVC A,@A+DPTR
                MOV FRQ_ECR+2,A
                INC SVA
                MOV A,SVA
                MOVC A,@A+DPTR
                MOV FRQ_ECR+3,A
                INC SVA
                MOV A,SVA
                MOVC A,@A+DPTR
                MOV FRQ_ECR+4,A
                RET

;****************************************************************************
;     BASCULAGE FRQ_MOD VERS FRQ_ECR
;****************************************************************************
BAS_FRQ         MOV R0,#FRQ_ECR
                MOV R1,#FRQ_MOD
                MOV CTR,#5
BAS_ENC         MOV A,@R1         ;PRISE FRQ_MOD
                MOV @R0,A         ;MISE DANS FRQ_ENC
                DEC CTR
                INC R0
                INC R1
                MOV A,CTR
                JNZ BAS_ENC       
                RET               
;****************************************************************************
;      TRANFERE UNE FREQUENCE DANS FRQ_TAM
;****************************************************************************
TRA_FRQ         MOV A,TABFRQX
                MOV DPTR,#FRQ_TAB
                MOV SVA,A           ;SAUVEGARDE A
                MOVC A,@A+DPTR
                MOV FRQ_TAM,A
                INC SVA
                MOV A,SVA
                MOVC A,@A+DPTR
                MOV FRQ_TAM+1,A
                INC SVA
                MOV A,SVA
                MOVC A,@A+DPTR
                MOV FRQ_TAM+2,A
                INC SVA
                MOV A,SVA
                MOVC A,@A+DPTR
                MOV FRQ_TAM+3,A
                INC SVA
                MOV A,SVA
                MOVC A,@A+DPTR
                MOV FRQ_TAM+4,A
                RET
;****************************************************************************
;    TRANSFERE CHIFFRES POUR AFFICHAGE FEN 5
;****************************************************************************
TRAS_AFF        MOV NBRCHIF,#07H
                MOV CHIFFRE,#31H
                MOV A,FRQ_TAM+1
                MOV CHIFFRE+2,A
                SWAP A
                MOV CHIFFRE+1,A
                MOV A,FRQ_TAM+2
                MOV CHIFFRE+4,A
                SWAP A
                MOV CHIFFRE+3,A
                MOV A,FRQ_TAM+3
                MOV CHIFFRE+6,A
                SWAP A
                MOV CHIFFRE+5,A
                MOV R0,#CHIFFRE+1
                MOV R1,#0
BCASCII         MOV A,@R0
                ANL A,#3FH
                MOV @R0,A
                INC R1
                INC R0
                CJNE R1,#6,BCASCII
                RET

;****************************************************************************
;     ECR_LBS CALCULE FRQ_LHT MOINS 1 Mhz
;****************************************************************************
ECR_LBS         MOV FRQ_ECR,FRQ_LHT
                MOV FRQ_ECR+1,FRQ_LHT+1
                MOV FRQ_ECR+2,FRQ_LHT+2
                MOV FRQ_ECR+3,FRQ_LHT+3
                MOV FRQ_ECR+4,FRQ_LHT+4
                MOV A,#99H
                ADD A,FRQ_ECR+1
                DA A
                MOV FRQ_ECR+1,A
                RET

;****************************************************************************
;     BASCULAGE FRQ_MOD VERS FRQ_LHT LIMITE HAUTE     !!!
;****************************************************************************
BAS_LHT         MOV R0,#FRQ_LHT
                MOV R1,#FRQ_MOD
                MOV CTR,#5
BAS_ENCH        MOV A,@R1         ;PRISE FRQ_MOD
                MOV @R0,A         ;MISE DANS FRQ_LHT
                DEC CTR
                INC R0
                INC R1
                MOV A,CTR
                JNZ BAS_ENCH
                RET

;****************************************************************************
;      600K EN MOINS DANS FRQ_ERL PAR RAPPORT A FRQ_ENC EN DCB
;****************************************************************************
SOUS600         MOV FRQ_ERL,FRQ_ECR
                MOV FRQ_ERL+1,FRQ_ECR+1
                MOV FRQ_ERL+2,FRQ_ECR+2
                MOV FRQ_ERL+3,FRQ_ECR+3
                MOV FRQ_ERL+4,FRQ_ECR+4  ;BASCULE FRQ VERS TAMPON POUR CALCUL

                CLR C
                MOV A,#40H
                ADD A,FRQ_ERL+2       ;SOUSTRAIT 600k
                DA A
                MOV FRQ_ERL+2,A
                CPL C
                JNC SOU600F           ;
                MOV A,#99H            ;ON SOUSTRAIT ENCORE A FRQ_ECR+1 
                ADD A,FRQ_ERL+1       ;SI RETENUE
                DA A
                MOV FRQ_ERL+1,A       ;A ESSAYER
SOU600F         RET

;****************************************************************************
;     UP DOWN SOUSTRACTION ADDITION SUR FREQUENCE ECR
;****************************************************************************
SOU125          CLR C
                MOV A,#75H            ;SOUSTRAIT 2,5k
                ADD A,FRQ_ECR+3
                DA A
                MOV FRQ_ECR+3,A
                CPL C
                JC SOUS20
                MOV A,#99H
                ADD A,FRQ_ECR+2       ;SOUSTRAIT 10,0K
                DA A
                MOV FRQ_ECR+2,A
                AJMP SIRET
SOUS20          MOV A,#98H                  
                ADD A,FRQ_ECR+2       ;SOUSTRAIT 20,0K
                DA A
                MOV FRQ_ECR+2,A
SIRET           CPL C
                JNC SOU125F           ;
                MOV A,#99H            ;ON SOUSTRAIT ENCORE A FRQ_ECR+1 
                ADD A,FRQ_ECR+1       ;SI RETENUE
                DA A
                MOV FRQ_ECR+1,A       ;A ESSAYER
SOU125F         RET

P125ECR         CLR C
                MOV A,#25H            ;AJOUTE 2,5k
                ADD A,FRQ_ECR+3
                DA A
                MOV FRQ_ECR+3,A
                MOV A,#01H                  
                ADDC A,FRQ_ECR+2      ;AJOUTE 10,0K
                DA A
                MOV FRQ_ECR+2,A
                JNC FINPECR
                MOV A,#01H            ;ON AJOUTE ENCORE A FRQ_LHT+1 
                ADD A,FRQ_ECR+1       ;SI RETENUE
                DA A
                MOV FRQ_ECR+1,A
FINPECR         RET

;****************************************************************************
;     PLUS 21,4 Mhz EN BINAIRE
;****************************************************************************

ADD_214         MOV QT,#0C0H
                MOV QT+1,#089H
                MOV QT+2,#046H
                MOV QT+3,#01H
                MOV CTR,#01H                         ;+21,4Mhz
                LCALL ADD_32
                RET


;****************************************************************************
;   CALCULE LORS DU BASCULEMENT DE FENETRE LA POSITION INI DU CURSEUR
;****************************************************************************
INI_CUR        MOV A,POS_FEN             ;LANCE POUR FCT POUR PLACER
               CJNE A,#01H,INICUR2       ;CURSEUR
               MOV POS_CUR,#00H
               SJMP INICRFIN
INICUR2        CJNE A,#02H,INICUR3
               MOV POS_CUR,#01H
               SJMP INICRFIN
INICUR3        CJNE A,#03H,INICUR4
               MOV POS_CUR,#0
               SJMP INICRFIN
INICUR4        CJNE A,#04H,INICUR5
               MOV POS_CUR,#3
               SJMP INICRFIN
INICUR5        CJNE A,#05H,INICRFIN
               MOV POS_CUR,#0
INICRFIN       RET

;****************************************************************************
;     MET EN MEMOIRE LES REGISTRES DU SYNTHETISEUR
;****************************************************************************

MAM_AMR          MOV DDE,QT
                 MOV DDE+1,QT+1
                 MOV DDE+2,QT+2
                 MOV DDE+3,QT+3      ;PASSE LE RESULTAT DE LA DIVISION
                                     ;EN DDE POUR DIVISER A NOUVEAU
                                     ;PAR 40
                 MOV DSR,#40
                 MOV DSR+1,#0
                 MOV RST,#0
                 MOV RST+1,#0
                 MOV RST+2,#0
                 LCALL DIV_32         ;DIVISION PAR 40
                 
                 MOV AMR,QT
                 MOV AMR+1,QT+1
                 MOV AMR+2,RST       ;RESULTAT DANS AMR ( N 10 eb A 7 eb )

FAMR               RET

;****************************************************************************
;     CHARGEMENT DU DIVISEUR
;****************************************************************************

CHA_DIV         MOV DSR,#0D4H
                MOV DSR+1,#30H
                
                RET

;****************************************************************************
;     DIVISION 32eb
;****************************************************************************

DIV_32    MOV RST,#0
          MOV RST+1,#0
          MOV RST+2,#0
          MOV CTR,#32

DIV_T1    LCALL SH_DIVI
          CLR C
          MOV A,RST
          SUBB A,DSR
          MOV A,RST+1
          SUBB A,DSR+1
          MOV A,RST+2
          SUBB A,#0
          JNC SUB_T             ;RESTE SUPERIEUR AU DIVISEUR ?
          SJMP QUOT_T

SUB_T     CLR C                 ;SOUSTRAIRE DIVISEUR DU RESTE PARTIEL
          MOV A,RST
          SUBB A,DSR
          MOV RST,A
          MOV A,RST+1
          SUBB A,DSR+1
          MOV RST+1,A
          MOV A,RST+2
          SUBB A,#0
          MOV RST+2,A

QUOT_T    CPL C                 ;RESTE PARTIEL < OU >
          MOV A,QT
          RLC A
          MOV QT,A
          MOV A,QT+1
          RLC A
          MOV QT+1,A
          MOV A,QT+2
          RLC A
          MOV QT+2,A
          MOV A,QT+3
          RLC A
          MOV QT+3,A
          DJNZ CTR,DIV_T1       ;MOINS UN ET TEST FIN ?
          RET                   ;FIN DIVISION

SH_DIVI   CLR C                 ;DECALE LE DIVIDENDE VERS GAUCHE
          MOV A,DDE
          RLC A
          MOV DDE,A
          MOV A,DDE+1
          RLC A
          MOV DDE+1,A
          MOV A,DDE+2
          RLC A
          MOV DDE+2,A
          MOV A,DDE+3
          RLC A
          MOV DDE+3,A
          MOV A,RST            ;POUSSE LE DIVIDENDE A GAUCHE
          RLC A                ;A TRAVERS LE RESTE
          MOV RST,A
          MOV A,RST+1
          RLC A
          MOV RST+1,A
          MOV A,RST+2
          RLC A
          MOV RST+2,A
          RET


;****************************************************************************
;      PASSE LA FREQUENCE DE DCB EN BINAIRE POUR LA DIVISION
;****************************************************************************



BIN_FRQ         MOV DDE,#00H
                MOV DDE+1,#0E1H
                MOV DDE+2,#0F5H
                MOV DDE+3,#05H                     ;100000000 > DDE
                MOV QT,#80H
                MOV QT+1,#96H
                MOV QT+2,#98H
                MOV QT+3,#00H
                MOV A,FRQ_ECR+1
                SWAP A
                ANL A,#00001111B
                MOV CTR,A
                LCALL ADD_32                        ;10000000 * X 1)
                MOV QT,#40H
                MOV QT+1,#42H
                MOV QT+2,#0FH
                MOV QT+3,#00H
                MOV A,FRQ_ECR+1
                ANL A,#00001111B
                MOV CTR,A          
                LCALL ADD_32                        ;1000000 * X  2)

                MOV QT,#0A0H
                MOV QT+1,#86H
                MOV QT+2,#01H
                MOV QT+3,#00H
                MOV A,FRQ_ECR+2
                SWAP A
                ANL A,#00001111B
                MOV CTR,A
                LCALL ADD_32                        ;100000 * X    3)
                MOV QT,#010H
                MOV QT+1,#27H
                MOV QT+2,#00H
                MOV QT+3,#00H
                MOV A,FRQ_ECR+2
                ANL A,#00001111B
                MOV CTR,A                           
                LCALL ADD_32                        ;10000 * X      4)   
                MOV QT,#0E8H
                MOV QT+1,#03H
                MOV QT+2,#00H
                MOV QT+3,#00H
                MOV A,FRQ_ECR+3
                SWAP A
                ANL A,#00001111B
                MOV CTR,A                           
                LCALL ADD_32                        ;1000 * X      5)   
                MOV QT,#064H
                MOV QT+1,#00H
                MOV QT+2,#00H
                MOV QT+3,#00H
                MOV A,FRQ_ECR+3
                ANL A,#00001111B
                MOV CTR,A                           
                LCALL ADD_32                        ;100 * X      6)   
                RET
         
;****************************************************************************
;       COMPARAISON DE FRQ_ECR ET FRQ_LHT
;****************************************************************************

CRECRLHT        MOV A,FRQ_LHT+3 
                XRL A,FRQ_ECR+3
                JZ CFRSUI1
                SJMP PASEGAL
CFRSUI1         MOV A,FRQ_LHT+2
                XRL A,FRQ_ECR+2
                JZ CFRSUI2
                SJMP PASEGAL
CFRSUI2         MOV A,FRQ_LHT+1
                XRL A,FRQ_ECR+1
                JZ CTEGAL
PASEGAL         MOV CTR,#0
                RET
CTEGAL          MOV CTR,#081H
                RET
;****************************************************************************
;        TABLE DES FREQUENCES RELAIS A ENTREE DIRECTE
;****************************************************************************
FRQ_TAB         DB 01H,45H,60H,00H,00H
                DB 01H,45H,61H,25H,00H
                DB 01H,45H,62H,00H,00H
                DB 01H,45H,63H,75H,00H
                DB 01H,45H,65H,00H,00H
                DB 01H,45H,66H,25H,00H
                DB 01H,45H,67H,50H,00H
                DB 01H,45H,68H,75H,00H
                DB 01H,45H,70H,00H,00H
                DB 01H,45H,71H,25H,00H
                DB 01H,45H,72H,50H,00H
                DB 01H,45H,73H,75H,00H
                DB 01H,45H,75H,00H,00H
                DB 01H,45H,76H,25H,00H
                DB 01H,45H,77H,50H,00H
                DB 01H,45H,78H,75H,00H
                
         END

