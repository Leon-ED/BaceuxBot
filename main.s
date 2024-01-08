; D�finition des registres GPIO
SYSCTL_PERIPH_GPIO EQU     0x400FE108 ; Adresse du registre SYSCTL_RCGC2_R (p291 datasheet de lm3s9b92.pdf)
GPIO_PORTF_BASE     EQU     0x40025000 ; Adresse de la base du port GPIO F
GPIO_O_DIR          EQU     0x00000400 ; Offset du registre de direction du port GPIO
GPIO_O_DR2R         EQU     0x00000500 ; Offset du registre de drive strength du port GPIO
GPIO_O_DEN          EQU     0x0000051C ; Offset du registre d'activation des pins du port GPIO

; Programme principal
		AREA    |.text|, CODE, READONLY
		ENTRY
		EXPORT	__main
		
		;; IMPORT sp�cifie que le symbole est d�fini dans un objet partag� � l'ex�cution.
		IMPORT	MOTEUR_INIT					; initialise les moteurs (configure les pwms + GPIO)
		
		IMPORT	MOTEUR_DROIT_ON				; activer le moteur droit
		IMPORT  MOTEUR_DROIT_OFF			; d�activer le moteur droit
		IMPORT  MOTEUR_DROIT_AVANT			; moteur droit tourne vers l'avant
		IMPORT  MOTEUR_DROIT_ARRIERE		; moteur droit tourne vers l'arri�re
		IMPORT  MOTEUR_DROIT_INVERSE		; inverse le sens de rotation du moteur droit
		
		IMPORT	MOTEUR_GAUCHE_ON			; activer le moteur gauche
		IMPORT  MOTEUR_GAUCHE_OFF			; d�activer le moteur gauche
		IMPORT  MOTEUR_GAUCHE_AVANT			; moteur gauche tourne vers l'avant
		IMPORT  MOTEUR_GAUCHE_ARRIERE		; moteur gauche tourne vers l'arri�re
		IMPORT  MOTEUR_GAUCHE_INVERSE		; inverse le sens de rotation du moteur gauche
        IMPORT  LED1_ON                     ; Allume la LED1
        IMPORT  LED1_OFF                    ; �teint la LED1
        IMPORT  LED2_ON                     ; Allume la LED2
        IMPORT  LED2_OFF                    ; �teint la LED2
        IMPORT  LED_INIT                    ; Initialise les LEDs
        IMPORT  SWITCH_INIT                 ; Initialise les interrupteurs (switches)
        IMPORT  BUMPERS_INIT                ; Initialise les pare-chocs
__main	
	; Activer l'horloge du p�riph�rique Port F & D (p291 datasheet de lm3s9B96.pdf)
    ldr r6, = SYSCTL_PERIPH_GPIO   ; Charger l'adresse du registre RCGC2
    mov r0, #0x00000038            ; Acitvation de la clock sur GPIO D, E, et F (0x28 == 0b111000)
    str r0, [r6]                    ; Stocker la valeur dans le registre RCGC2
    nop
    nop
    nop
	
	
    ; Initialisation des LED et des interrupteurs
    BL LED_INIT
    BL SWITCH_INIT
	BL BUMPERS_INIT

    ; Initialisation des moteurs
    BL MOTEUR_INIT
    

    ; D�marer le mode Course Poursuite
    BL LoopCoursePoursuite

LoopCoursePoursuite		
    ; Avancer tout droit et alterner les LED
	BL MOTEUR_DROIT_ON
    BL MOTEUR_GAUCHE_ON
    BL MOTEUR_DROIT_AVANT
    BL MOTEUR_GAUCHE_AVANT	
	; Allumage des leds
    BL LED1_ON
    BL LED2_OFF

    BL WAITWithBumper ; Attendre jusqu'� ce qu'un bumper ou un switch soit press�
	; Allumage de l'inverse des leds pour l'effet alternance
    BL LED1_OFF
    BL LED2_ON 
    BL WAITWithBumper

    B LoopCoursePoursuite ; Retour au d�but car rien n'a �t� press�

StandByMode
    ; Arr�t des moteurs et activation des LEDS
    BL MOTEUR_DROIT_OFF
    BL MOTEUR_GAUCHE_OFF
    BL LED1_ON
    BL LED2_ON

    ; Attente jusqu'� l'appui d'un switch pour passer dans le mode Course Poursuite
    B WAITSTANDBY

WAITSTANDBY
	LDR R2, =0x00FFFF
	
WAITSTANDBY_
	
	; Si le switch 2 est appuy�, on va � la Course poursuite
	ldr r0,[r10]
	CMP r0,#0x40
	BEQ LoopCoursePoursuite

    SUBS R2, #1
    BNE WAITSTANDBY_ ; Tant que le compteur n'est pas fini

    BX LR


WAITWithBumper
    LDR R2, =0x00FFFF ; D�lai rapide afin d'avoir une alternance rapide des LEDS
	
WAITWithBumper_
	; Si le switch 2 est appuy�, on va au Stand By
	ldr r0,[r10]
	CMP r0,#0x80
	BEQ StandByMode
	
	; Si le bumper gauche est appuy�
	ldr r0,[r11] 
	CMP r0,#0x01
	BEQ BumperLeftActivate
	
	; Si le bumper droit est appuy�
	ldr r0,[r11] 
	CMP r0,#0x02
	BEQ BumperRightActivate

    SUBS R2, #1
    BNE WAITWithBumper_ ; Tant que le compteur n'est pas fini

    BX LR
	
Wait_40cm
	LDR R2, =0xAFFFFF ; D�lai qui correspond � une marche arri�re de 40cm � peu pr�s

Wait_
	; Il n'y a aucune instructions ici car si le robot est en marche arri�re on ne peut pas changer de mode
	SUBS R2, #1
    BNE Wait_

    BX LR

BumperLeftActivate
	PUSH {LR}
	
	; Passage � la marche arri�re
	BL MOTEUR_GAUCHE_ARRIERE
	BL MOTEUR_DROIT_ARRIERE
	
	; Allumage de la LED du cot� ou le bumper est touch�
	BL LED2_ON
	BL LED1_OFF
	BL Wait_40cm ; Reculer sur 40cm
	
	; Rotation sur le cot� dans le sens du bumper
	BL MOTEUR_DROIT_OFF
	BL MOTEUR_GAUCHE_AVANT
	BL MOTEUR_DROIT_ON
	BL MOTEUR_DROIT_ARRIERE
	
	; Allumage de la LED du cot� ou le robot va tourner
	BL LED2_OFF
	BL LED1_ON
	LDR R2, =0x4FFFFF ; Stockage de la dur�e o� le robot va tourner
	BL Wait_ ; boucle d'attente	
	
	POP {LR}
    BX LR
	
BumperRightActivate
	PUSH {LR}
	; Passage � la marche arri�re
	BL MOTEUR_GAUCHE_ARRIERE
	BL MOTEUR_DROIT_ARRIERE
	
	; Allumage de la LED du cot� ou le bumper est touch�
	BL LED2_OFF
	BL LED1_ON
	BL Wait_40cm ; Reculer sur 40cm
	
	; Rotation sur le cot� dans le sens du bumper
	BL MOTEUR_GAUCHE_OFF
	BL MOTEUR_DROIT_AVANT
	BL MOTEUR_GAUCHE_ON
	BL MOTEUR_GAUCHE_ARRIERE
	
	; Allumage de la LED du cot� ou le robot va tourner
	BL LED1_OFF
	BL LED2_ON
	LDR R2, =0x4FFFFF ; Stockage de la dur�e o� le robot va tourner
	BL Wait_ ; boucle d'attente	
	POP {LR}
    BX LR

END