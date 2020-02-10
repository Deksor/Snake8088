;This file is part of Snake8088.

;Snake8088 is free software: you can redistribute it and/or modify
;it under the terms of the GNU General Public License as published by
;the Free Software Foundation, either version 3 of the License, or
;(at your option) any later version.
;
;Snake8088 is distributed in the hope that it will be useful,
;but WITHOUT ANY WARRANTY; without even the implied warranty of
;MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;GNU General Public License for more details.
;
;You should have received a copy of the GNU General Public License
;along with Snake8088.  If not, see <https://www.gnu.org/licenses/>.

;Made by Deksor (2020)

.model tiny

.stack 100h

.data

;;Pixel plotting variables;;
X	  					dw ?
Y	   					dw ?
color 					dw ?

;;Line drawing variables;;
X2	  					dw ?
Y2	  					dw ?

sdx						dw ?
sdy						dw ?
dxabs					dw ?
dyabs					dw ?

;;Strings;;
posHeader   			db "X, Y : $"
coma		  			db ", $"
retCar		  			db 0dh,"$"
endMessage				db "Deksor's 8088snake alpha 0.1 (2020-02-10)", 0ah, 0dh, "$"

;;Game variables and constants;;

;snake's main attributes
snakeX					dw ?
snakeY					dw ?
snakeColor 				dw ?
snakeDirection 			db ?

SNAKE_DIR_RIGHT			equ 0
SNAKE_DIR_DOWN			equ 1
SNAKE_DIR_LEFT			equ 2
SNAKE_DIR_UP			equ 3

END_SNAKE_HIT_ITSELF	equ 1
END_QUIT_GAME			equ 2

;snake's body variables
SNAKE_MAX_LENGTH 		equ 100	; twice the size of the snake
snakeLength	  			dw ?	; twice the size of the snake
snakeBody				dw SNAKE_MAX_LENGTH DUP(0)
snakeHeadPtr	 		dw [snakeBody]
snakeOldHeadPtr  		dw ?
snakeTailPtr	 		dw [snakeBody]

;food variables
foodColor				dw ?
generateFoodNextTime	db ?
nextFoodCounter			dw ?
NEXT_FOOD_MAX_MASK		equ 01FFh

;invisible walls where the snake gets teleported 
leftBorder   			dw ?
rightBorder  			dw ?
topBorder				dw ?
bottomBorder 			dw ?

;main loop variables
lost	 				db ?
score					dw ?
fps	   					dw ?
clocksave 				dw ?

;Number to string buffer
numbuf  				db  5 DUP(0),"$"

;;Video related variables;;
videoMode				db ?
VGA_MODE				equ 0
PLANTRONICS_MODE		equ 1

VGA_GRAPHIC_MODE 		equ 0013h
VGA_ADDRESS	  			equ 0A000h
VGA_PIXEL_COUNT			equ 64000

CGA_GRAPHIC_MODE        equ 0004h
CGA_ADDRESS	  			equ 0B800h
CGA_2ND_ADDRESS	  		equ 0BC00h
CGA_2ND_PAGE_OFFSET		equ 04000h

PLANTRONICS_PORT        equ 03DDh
PLANTRONICS_16_COLORS   equ 10h
PLANTRONICS_CGA_MASK    equ 40h

TEXT_MODE				equ 0003h
VIDEO_INT				equ 10h

SCREEN_WIDTH	 		equ 320
SCREEN_HEIGHT			equ 200

;;Keyboard related constants;;
KEYB_INT				equ 16h
ESC_KEY                 equ 01
LEFT_KEY                equ 77
DOWN_KEY				equ 80
RIGHT_KEY				equ 75
UP_KEY					equ 72

;;OS function constants;;
fCheckBuffer	 		equ 01h
fGetShiftStatus  		equ 02h

fExitProgram	 		equ 4c00h

fReadClock	   			equ 00h

fPrint					equ 09h
fFlushSTDINBuffer		equ 0ch

;;Clock related constants;;
CLOCK_DIVIDER			equ 7fffh;9b5ch;4daeh
CLOCKINT				equ 1ah
DOS_INT		  			equ 21h


.code

;;Macros;;
	;; Turns X (bx) and Y (dx) values into a VGA 13h mode screen offset
	vgaoffset macro
		shl dx, 1
		shl dx, 1
		shl dx, 1
		shl dx, 1
		shl dx, 1			
		shl dx, 1
		add bx, dx
		shl dx, 1			
		shl dx, 1
		add bx, dx
	endm

	cgaoffset macro
		xor di, di
		shr dx, 1
		sbb di, 0
		and di, 2000h
		shl dx, 1
		shl dx, 1
		shl dx, 1
		shl dx, 1
		add di, dx
		shl dx, 1
		shl dx, 1
		add di, dx
		shl di, 1
		shl di, 1

		add bx, di

	endm

	;; writes al to the screen memory
	vgapixel macro
		vgaoffset
	
		mov es:[bx], al

	endm

	plantronicspixel macro

	endm

	;; returns the sign of the number stored in ax
	complementAx macro
		sar ax, 1
		sar ax, 1
		sar ax, 1
		sar ax, 1
		sar ax, 1
		sar ax, 1
		sar ax, 1
		sar ax, 1
		sar ax, 1
		sar ax, 1
		sar ax, 1
		sar ax, 1
		sar ax, 1
		sar ax, 1
		sar ax, 1
	endm
	
	random macro
		mov ah,fReadClock	; Returns the time in CX DX
		int CLOCKINT
		mov ax, 25173
		mul dx
		add ax, 13849
	endm

main proc near

	mov ax, @data
	mov ds,ax

	mov al, VGA_MODE
	mov videoMode, al

	call initvideo
	jmp initgame

initvideo:
		mov al, VGA_MODE
		cmp videoMode, al
		je initvga
		mov al, PLANTRONICS_MODE
		cmp videoMode, al
		je initplantronics

	initplantronics:
		call initcga

		mov dx, PLANTRONICS_PORT
    	mov al, PLANTRONICS_16_COLORS
    	out dx, al

		xor ax, ax
        mov cx, 8192
        mov di, CGA_2ND_PAGE_OFFSET
        rep stosw

		mov ax, 0000000100000001b
		mov snakeColor, ax

		mov ax, 0000000100000010b
		mov foodColor, ax

		ret


	initcga:

		mov ax, CGA_GRAPHIC_MODE
		int VIDEO_INT

		mov ax, CGA_ADDRESS
		mov es, ax
		ret

	initvga:
		
		mov ax, VGA_GRAPHIC_MODE
		int VIDEO_INT
		
		mov ax, VGA_ADDRESS
		mov es, ax

		mov al, 45
		mov ah, al
		mov snakeColor, ax

		mov al, 39
		mov ah, al
		mov foodColor, ax

		ret
						
initgame:

	mov ax, 0
	mov score, ax
	mov ax, 3
	mov snakeDirection, al
	mov al, 0
	mov lost, al
	mov ax, 160
	mov snakeX, ax
	mov ax, 100
	mov snakeY, ax
	
	mov ax, 0
	mov leftBorder, ax
	mov ax, 0
	mov topBorder, ax
	mov ax, SCREEN_WIDTH
	mov rightBorder, ax
	mov ax, SCREEN_HEIGHT
	mov bottomBorder, ax
	mov ax, 20
	mov snakeLength, ax
	
	mov ax, 0
	mov fps, ax
	mov ax, 0
	mov clocksave, 0
	mov al, 0
	mov generateFoodNextTime, al

	mov ax, 0
	mov nextFoodCounter, ax

	
	
	;19886 = 60hz
	
	mov bx, CLOCK_DIVIDER
	call setclockspeed
	
	call displayhead
	
mainloop:
	
	xor ax, ax
	mov ah, fReadClock
	int CLOCKINT
	
	cmp dx, clocksave
	je samesecond
	mov clocksave,dx
	mov ax, fps

	;call printnum
	
	xor ax, ax
	mov ah, fPrint
	mov dx, offset retCar
	int DOS_INT
	
	xor dx, dx
	mov fps, dx
	
	call movesnake
	
	call collisioncheckfast
	cli
	call displayhead
	sti
	call tailhandler
	
	call keyboard

	call foodmaker
	
	samesecond:
	
	mov ax, fps
	inc ax
	mov fps, ax
	
	;call collisioncheck
	
	;call printpos
	
	mov al, lost
	cmp al, 0
	
	je mainloop
	
gameend:

	xor ax, ax
	mov ah, fFlushStdinBuffer
	int DOS_INT
	
	mov ax, TEXT_MODE
	int VIDEO_INT
	
	;mov ah, fGetShiftStatus
	;int DOS_INT
	xor ax, ax
	mov ah, fPrint
	mov dx, offset endMessage
	int DOS_INT
	
	xor bx, bx
	call setclockspeed
	
	mov ax,fExitProgram
	int DOS_INT
	endp

	ret

;;Changes snakeDir depending of the keyboard's input and dies if esc is pressed
keyboard:
	xor ax, ax
	mov ah, fCheckBuffer
	int KEYB_INT
	je noinput
	
	cmp ah, ESC_KEY
	je quitgame
	
	cmp ah, LEFT_KEY
	je leftkey
	cmp ah, DOWN_KEY
	je downkey
	cmp ah, RIGHT_KEY
	je rightkey
	cmp ah, UP_KEY
	je upkey
	
	mov al, ah
	xor ah, ah
	
	;call printnum
	
	xor ax, ax
	mov ah, fPrint
	mov dx, offset retCar
	int DOS_INT
	
	clearkeybbuf:
	xor ax,ax
	mov ah, fFlushStdinBuffer
	int DOS_INT
	
	noinput:
	
	ret
	
	leftkey:
		mov al, SNAKE_DIR_RIGHT
		mov ah, snakeDirection
		cmp snakeDirection, SNAKE_DIR_LEFT
		je clearkeybbuf
		mov snakeDirection, al
		jmp clearkeybbuf

	downkey:
		mov al, SNAKE_DIR_DOWN
		mov ah, snakeDirection
		cmp snakeDirection, SNAKE_DIR_UP
		je clearkeybbuf
		mov snakeDirection, al
		jmp clearkeybbuf
	rightkey:
		mov al, SNAKE_DIR_LEFT
		mov ah, snakeDirection
		cmp snakeDirection, SNAKE_DIR_RIGHT
		je clearkeybbuf
		mov snakeDirection, al
		jmp clearkeybbuf
	upkey:
		mov al, SNAKE_DIR_UP
		mov ah, snakeDirection
		cmp snakeDirection, SNAKE_DIR_DOWN
		je clearkeybbuf
		mov snakeDirection, al
		jmp clearkeybbuf
	quitgame:
		mov al, END_QUIT_GAME
		mov lost, al
		jmp clearkeybbuf

;;Checks if the head is touching any bodypart
collisioncheck:
	mov bx, snakeX
	mov dx, snakeY
	
	vgaoffset
	
	mov cx, SNAKE_MAX_LENGTH
	mov si, offset snakeBody
	mov dx, snakeOldHeadPtr
	checksnake:
		cmp si, dx
		je snakehead
		mov ax, [si]
		cmp ax, bx
		je collision
		snakehead:
		inc si
		inc si
	loop checksnake
	
	ret
;;Checks if the head is touching any bodypart faster	
collisioncheckfast:
	mov ax, snakeX
	mov X, ax
	mov ax, snakeY
	mov Y, ax

	call readpixel

	cmp ax, snakeColor
	je collision
	cmp ax, foodColor
	je grow
	
	ret
;;End game
collision:
	mov al, END_SNAKE_HIT_ITSELF
	mov lost, al
	
	ret

grow:
	mov ax, snakeLength
	cmp ax, SNAKE_MAX_LENGTH
	jge toobig
	inc ax
	inc ax
	mov snakeLength, ax

	;call printnum

	toobig:
	ret

setclockspeed:
	xor dx, dx
	mov al, 34h
	mov al, 43h
	out dx, al
	
	mov ax, bx
	mov dl, 40h
	out dx, al
	mov al, ah
	out dx, al
	
	ret
						 
putpixel:

	mov bx, X
	mov dx, Y

	mov al, videoMode
	cmp al, VGA_MODE
	je vgapix
	cmp al, PLANTRONICS_MODE
	je plantronicspix

	plantronicspix:

	cgaoffset
	mov di, bx

	jmp putpixeloffset

	vgapix:
	
	vgaoffset
	mov di, bx
	
	jmp putpixeloffset

putpixeloffset:

	mov al, videoMode
	cmp al, VGA_MODE
	je vgaputpixoffset
	cmp al, PLANTRONICS_MODE
	je plantronicsputpixoffset

	plantronicsputpixoffset:
	mov cl, bl
	shr di, 1
	shr di, 1
	inc cl
	and cl, 3
	shl cl, 1
	mov ax, color
	ror al, cl
	mov ch, 0fch
	ror ch, cl
	and ch, es:[di]
	or al, ch
	stosb
	dec di
	mov al, ah
	ror al, cl
	mov ch, 0fch
	ror ch, cl
	add di, CGA_2ND_PAGE_OFFSET
	and ch, es:[di]
	or al, ch
	stosb

	ret

	vgaputpixoffset:
	mov ax, color 

	mov es:[di], al

	ret

readpixel:
	mov bx, X
	mov dx, Y

	mov al, videoMode
	cmp al, VGA_MODE
	je vgareadpix
	cmp al, PLANTRONICS_MODE
	je plantronicsreadpix
	

	plantronicsreadpix:

	cgaoffset

	mov di, bx

	jmp readpixeloffset	

	vgareadpix:

	vgaoffset

	mov di, bx

	jmp readpixeloffset	

readpixeloffset:

	mov al, videoMode
	cmp al, VGA_MODE
	je vgareadpixoffset
	cmp al, PLANTRONICS_MODE
	je plantronicsreadpixoffset

	plantronicsreadpixoffset:

	mov cl, bl
	shr di, 1
	shr di, 1
	inc cl
	and cl, 3
	shl cl, 1
	mov al, 3
	ror al, cl
	and al, es:[di]
	rol al, cl
	mov ah, 3
	ror ah, cl
	add di, CGA_2ND_PAGE_OFFSET
	and ah, es:[di]
	rol ah, cl

	ret

	vgareadpixoffset:
	mov al, es:[di]
	mov ah, al

	ret
						
ligne:
	;Calcul des variables X
	mov ax, X2
	sub ax, X			;ax = deltax
	mov bx, ax			;bx = deltax
	
	complementAx		;ax= ""signedeltax""
	
	xor bx, ax			
	sub bx, ax			;bx=abs deltax
	cmp ax, 0
	jl negx
	inc ax	  		;ax=sgn deltax
	negx:
	mov sdx, ax
	mov dxabs, bx	  
	
	;Calcul des variables Y
	mov ax, Y2
	sub ax, Y
	mov bx, ax
	
	complementAx
	
	xor bx, ax
	sub bx, ax
	cmp ax, 0
	jl negy
	inc ax
	negy:
	mov sdy, ax
	mov dyabs, bx
	
	mov ax, color
	mov bx, X
	mov dx, Y
	
	vgapixel
	
	mov ax, dxabs
	mov bx, dyabs
	cmp ax, bx
	jb vertical
		mov cx, ax	; boucle
		mov dx, ax 	
		shr dx, 1	;dx=y
		loophoriz:
			add dx, bx
			push bx
			cmp dx, ax
			jb pasModifY
				sub dx, ax
				;mov dxabs,ax
				mov bx, sdy
				add Y, bx
			pasModifY:
			mov bx, X
			add bx, sdx
			mov X, bx
			push dx
			mov dx, Y
			push ax
			mov ax, color
			
			vgapixel
			
			pop ax
			pop dx
			pop bx
		loop loophoriz
			
		
	ret
	
	vertical:
		mov cx, bx	; boucle
		mov dx, bx 	;bx=dyabs
		shr dx, 1	;dx="x"
		loopverti:
			add dx, ax
			push ax
			cmp dx, bx
			jb pasModifX
				sub dx, bx
				;mov dxabs,ax
				mov ax, sdx
				add X, ax
			pasModifX:
			push dx
			mov dx, Y
			add dx, sdy
			mov Y, dx
			push bx
			mov bx, X
			mov ax, color
			
			vgapixel
			
			pop bx
			pop dx
			pop ax
		loop loopverti
		
		
	ret
	

;;Displays the snake's head to the screen
displayhead:
	mov ax, snakeColor
	mov color, ax
	mov ax, snakeX
	mov X, ax
	mov ax, snakeY
	mov Y, ax		   
	
	call putpixel				  	
	
	;bx now contains the head's pointer to the screen
	
	mov di, snakeHeadPtr	;saves the head's pointer to the screen to the body array
	mov snakeOldHeadPtr, di
	mov [di], bx
	add di, 2
	mov bx, di
	sub bx, offset snakeBody
	cmp bx, SNAKE_MAX_LENGTH
	jg loopheadpointer
	mov snakeHeadPtr, di
	
	ret
	loopheadpointer:
		mov bx, offset snakeBody
		mov snakeHeadPtr, bx
		ret

;;Removes the snake's oldest body part
tailhandler:
	mov ax, snakeTailPtr		;Snake bigger than the absolute limit
	cmp ax, snakeHeadPtr
	je removetail
	add ax, snakeLength			;Snake bigger than its own set size
	mov bx, offset snakeBody
	add bx, SNAKE_MAX_LENGTH
	cmp ax, bx
	jge removetail
	tailhandlerlabel:
	cmp ax, snakeHeadPtr
	je removetail
	ret
	
	removetail:
		mov bx, snakeTailPtr
		mov di, [bx]
		mov bx, [bx]

		xor ax, ax
		mov color, ax

		call putpixeloffset
		mov bx, snakeTailPtr
		add bx, 2
		mov ax, bx
		sub bx, offset snakeBody
		cmp bx, SNAKE_MAX_LENGTH
		jg looptailpointer
		mov snakeTailPtr, ax
		ret

	looptailpointer:
		mov bx, offset snakeBody
		mov snakeTailPtr, bx
		ret
	looptailtemp:
		sub ax, SNAKE_MAX_LENGTH
		jmp tailhandlerlabel

;; Moves the snake in the direction determined by snakeDirection
movesnake:
	mov al, snakeDirection
	mov ah, SNAKE_DIR_RIGHT
	cmp al, ah
	je snakeright
	mov ah, SNAKE_DIR_DOWN
	cmp al, ah
	je snakedown
	mov ah, SNAKE_DIR_LEFT
	cmp al, ah
	je snakeleft
	mov ah, SNAKE_DIR_UP
	cmp al, ah
	je snakeup
	
	snakeright:
		mov bx, snakeX
		inc bx
		cmp bx, rightBorder
		jge overright
		mov snakeX, bx
		ret
		overright:
			sub bx, rightBorder
			add bx, leftBorder
			mov snakeX, bx
		ret

	snakedown:
		mov bx, snakeY
		inc bx
		cmp bx, bottomBorder
		jge overdown
		mov snakeY, bx
		ret
		overdown:
			sub bx, bottomBorder
			add bx, topBorder
			mov snakeY, bx
		ret
		
	snakeleft:
		mov bx, snakeX
		dec bx
		mov dx, leftBorder
		dec dx
		cmp bx, dx
		jle overleft
		mov snakeX, bx
		ret
		overleft:
			add bx, rightBorder
			sub bx, leftBorder
			mov snakeX, bx
		ret
	
	snakeup:
		mov bx, snakeY
		dec bx
		mov dx, topBorder
		dec dx
		cmp bx, dx
		jle overup
		mov snakeY, bx
		ret
		overup:
			add bx, bottomBorder
			sub bx, topBorder
			mov snakeY, bx
		ret

;; Prints AX' content to the screen
printnum:
	;initialize count 
	mov cx, 0 
	mov dx, 0
	lea di, numbuf+5
	cmp ax, 0
	je numzero
	
	numtochar: 
		; if ax is zero 
		cmp ax, 0 
		je print1	   
		  
		;initilize bx to 10 
		mov bx, 10		 
		  
		; extract the last digit 
		div bx				   
		  
		; adds it at the tail of the string
		add dx, 30h
		dec di
		mov [di], dl		   
		  
		;increment the count 
		inc cx			   
		  
		;set dx to 0  
		xor dx, dx 
		jmp numtochar 
	print1: 
		;check if count  
		;is greater than zero 
		cmp cx, 0 
		je exit
		;print the string
		xor ax, ax
		mov ah, fPrint
		mov dx,di
		int DOS_INT
		
	exit: 
		ret
	numzero:
		add ax, 30h
		dec di
		mov [di], al
		inc cx
		jmp print1

;; Prints X and Y to the screen	
printpos:
	xor ax, ax
	mov ah, fPrint
	mov dx, offset posHeader
	int DOS_INT
	
	mov ax, snakeX
	
	call printnum
	
	xor ax, ax
	mov ah, fPrint
	mov dx, offset coma
	int DOS_INT
	
	mov ax, snakeY
	
	call printnum
	
	xor ax, ax
	mov ah, fPrint
	mov dx, offset retCar
	int DOS_INT
	
	ret

; Generates food at random intervals
foodmaker:

	mov cx, nextFoodCounter
	dec nextFoodCounter
	cmp cx, 0
	jne nofood

	random

	checkoverlimit:
	cmp ax, VGA_PIXEL_COUNT
	jge nooverlimit
	sub ax, VGA_PIXEL_COUNT

	nooverlimit:

	mov di, ax
	mov bx, ax

	call readpixeloffset

	xor ah, ah
	cmp ax, snakeColor
	jne notsnake
	inc bx
	jmp checkoverlimit

	notsnake:
	cmp ax, foodColor
	jne notfood
	inc bx
	jmp checkoverlimit
	notfood:
	
	mov ax, foodColor
	mov Color, ax

	call putpixeloffset

	and bx, NEXT_FOOD_MAX_MASK
	mov nextFoodCounter, bx

	nofood:
	ret
	
	
end main