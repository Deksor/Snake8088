;This file is part of Snake8088.

;Snake8088 is free software: you can redistribute it and/or modify
;it under the terms of the GNU General Public License as published by
;the Free Software Foundation, either version 3 of the License, or
;(at your option) any later version.
;
;Foobar is distributed in the hope that it will be useful,
;but WITHOUT ANY WARRANTY; without even the implied warranty of
;MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;GNU General Public License for more details.
;
;You should have received a copy of the GNU General Public License
;along with Foobar.  If not, see <https://www.gnu.org/licenses/>.

.model tiny

.stack 100h

.data
message db "Hello World $"

X       dw ?
Y       dw ?
Couleur db ?
X2      dw ?
Y2      dw ?

sdx		dw ?
sdy		dw ?
dxabs	dw ?
dyabs	dw ?

posHd   db  "X, Y : $"

;Game variables

snakeX    dw ?
snakeY    dw ?
snakeDir  db ?
snakeCoul db ?

SNAKE_MAX_LENGTH equ 100 ; twice the size of the snake
snakeLength      dw ?   ; twice the size of the snake
snakeBody        dw SNAKE_MAX_LENGTH DUP(0)
snakeHeadPtr     dw [snakeBody]
snakeOldHeadPtr  dw ?
snakeTailPtr     dw [snakeBody]

leftBorder   dw ?
rightBorder  dw ?
topBorder    dw ?
bottomBorder dw ?

lost      db ?
score     dw ?
fps       dw ?
clocksave dw ?
;Number to string buffer
numbuf  db  5 DUP(0),"$"

;Constants
VGA_GRAPHIC_MODE equ 0013h
VGA_ADDRESS      equ 0A000h
TEXT_MODE        equ 0003h

fCheckBuffer     equ 01h
fGetShiftStatus  equ 02h

fExitProgram     equ 4c00h

fReadClock       equ 00h

VIDEO_INT        equ 10h
KEYB_INT         equ 16h
CLOCKINT         equ 1ah
DOS_INT          equ 21h

SCREEN_WIDTH     equ 320
SCREEN_HEIGHT    equ 200

VIRGULE          db ", $"
RET_CAR          db 0dh,"$"



.code

	screenoffset macro
		shl dx,1
    	shl dx,1
    	shl dx,1
    	shl dx,1
    	shl dx,1			
    	shl dx,1			;12
    	add bx,dx			;3
    	shl dx,1			
    	shl dx,1			;4
    	add bx,dx			;3
	endm

    pixel macro
		screenoffset
    
        mov es:[bx],al      ;9+
							;=31+
    endm

	complementAx macro
		sar ax,1
		sar ax,1
		sar ax,1
		sar ax,1
		sar ax,1
		sar ax,1
		sar ax,1
		sar ax,1
		sar ax,1
		sar ax,1
		sar ax,1
		sar ax,1
		sar ax,1
		sar ax,1
		sar ax,1
	endm
	
	random macro
		mov ah,fReadClock    ; Retourne le temps dans CX DX
		int CLOCKINT
		mov ax,25173
		mul dx
		add ax, 13849
		add al,ah
		xor ah,ah
	endm

main proc near

	mov ax,@data
	mov ds,ax
    
    mov ax,VGA_GRAPHIC_MODE
    int VIDEO_INT
    
    mov ax,VGA_ADDRESS
    mov es,ax
                        
initgame:

	mov ax, 0
    mov score, ax
	mov ax, 3
	mov snakeDir, al
	mov al, 0
	mov lost, al
	mov ax, 160
    mov snakeX, ax
	mov ax, 100
    mov snakeY, ax
	mov al, 45
	mov snakeCoul, al
	
	mov ax, 0
	mov leftBorder, ax
	mov ax, 0
	mov topBorder, ax
	mov ax, SCREEN_WIDTH
	mov rightBorder, ax
	mov ax, SCREEN_HEIGHT
	mov bottomBorder, ax
	mov ax, 98
	mov snakeLength, ax
	
	mov ax, 0
	mov fps, ax
	mov ax, 0
	mov clocksave, 0
	
	;19886 = 60hz
	
	mov bx, 4daeh
	call setclockspeed
	
	call displayhead
    
boucle:
		
	
	
	mov ah,fReadClock
	int CLOCKINT
	
	cmp dx, clocksave
	je samesecond
	mov clocksave,dx
	mov ax, fps
	call printnum
	
	mov ah,09h
	mov dx,offset RET_CAR
	int DOS_INT
	
	mov dx, 0
	mov fps, dx
	
	call movesnake
	
	call collisioncheckfast
	cli
	call displayhead
	sti
	call tailhandler
	
	call keyboard
	
	
	samesecond:
	
	mov ax, fps
	inc ax
	mov fps, ax
	
	;call collisioncheck
	
	;call printpos
	
	mov al, lost
	cmp al, 0
	
	je boucle
	
gameend:

	mov ax, 0c00h
	int DOS_INT
    
    mov ax,TEXT_MODE
    int VIDEO_INT
    
    mov ah,fGetShiftStatus
    int DOS_INT
	
	mov bx, 0
	call setclockspeed
	
    mov ax,fExitProgram
    int DOS_INT
    endp

    ret
	
keyboard:
	mov ah, 01h
	int KEYB_INT
	je noinput
	
	cmp ah,01
	je gameend
	
	cmp ah, 77
	je leftkey
	cmp ah, 80
	je downkey
	cmp ah, 75
	je rightkey
	cmp ah, 72
	je upkey
	
	mov al, ah
	xor ah, ah
	
	call printnum
	
	mov ah,09h
	mov dx,offset RET_CAR
	int DOS_INT
	
	clearkeybbuf:
	mov ax, 0c00h
	int DOS_INT
	
	noinput:
	
	ret
	
leftkey:
	mov al, 0
	mov ah, snakedir
	cmp snakedir, 2
	je clearkeybbuf
	mov snakeDir, al
	jmp clearkeybbuf

downkey:
	mov al, 1
	mov ah, snakedir
	cmp snakedir, 3
	je clearkeybbuf
	mov snakeDir, al
	jmp clearkeybbuf
rightkey:
	mov al, 2
	mov ah, snakedir
	cmp snakedir, 0
	je clearkeybbuf
	mov snakeDir, al
	jmp clearkeybbuf
upkey:
	mov al, 3
	mov ah, snakedir
	cmp snakedir, 1
	je clearkeybbuf
	mov snakeDir, al
	jmp clearkeybbuf
	
collisioncheck:
	mov bx, snakeX
	mov dx, snakeY
	
	screenoffset
	
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
	
collisioncheckfast:
	mov bx, snakeX
	mov dx, snakeY
	
	screenoffset
	
	;mov si, bx
	mov al, es:[bx]
	cmp al, snakeCoul
	je collision
	
	ret
	
collision:
	mov al, 1
	mov lost, al
	
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
    mov al,Couleur      ;8+
    mov bx,X            ;8+
	mov dx,Y			;8+
	
	pixel               ;31+
    
    ret                 ;8
                        
ligne:
	;Calcul des variables X
    mov ax,X2
	sub ax,X			;ax = deltax
	mov bx,ax			;bx = deltax
	
	complementAx		;ax= ""signedeltax""
	
	xor bx,ax			
	sub bx,ax			;bx=abs deltax
	cmp ax,0
	jl negx
	inc ax      		;ax=sgn deltax
	negx:
	mov sdx,ax
	mov dxabs,bx      
	
	;Calcul des variables Y
	mov ax,Y2
	sub ax,Y
	mov bx,ax
	
	complementAx
	
	xor bx,ax
	sub bx,ax
	cmp ax,0
	jl negy
	inc ax
	negy:
	mov sdy,ax
	mov dyabs,bx
	
	mov al,Couleur
	mov bx,X
	mov dx,Y
	
	pixel
	
	mov ax,dxabs
	mov bx,dyabs
	cmp ax,bx
	jb vertical
		mov cx,ax	; boucle
		mov dx,ax 	
		shr dx,1	;dx=y
		loophoriz:
		    add dx,bx
		    push bx
			cmp dx,ax
			jb pasModifY
				sub dx,ax
				;mov dxabs,ax
				mov bx,sdy
				add Y,bx
			pasModifY:
			mov bx,X
			add bx,sdx
			mov X,bx
			push dx
			mov dx,Y
			push ax
			mov al,Couleur
			
			pixel
			
			pop ax
			pop dx
			pop bx
		loop loophoriz
			
		
	ret
	
	vertical:
	    mov cx,bx	; boucle
		mov dx,bx 	;bx=dyabs
		shr dx,1	;dx="x"
		loopverti:
		    add dx,ax
		    push ax
			cmp dx,bx
			jb pasModifX
				sub dx,bx
				;mov dxabs,ax
				mov ax,sdx
				add X,ax
			pasModifX:
			push dx
			mov dx,Y
			add dx,sdy
			mov Y,dx
			push bx
			mov bx,X
			mov al,Couleur
			
			pixel
			
			pop bx
			pop dx
			pop ax
		loop loopverti
		
		
	ret
	
displayhead:           
    mov al, snakeCoul      ;8+
    mov bx, snakeX         ;8+
	mov dx, snakeY	       ;8+
	
	pixel                  ;31+ bx contains the head's pointer to the screen
	
	mov di, snakeHeadPtr   ;saves the head's pointer to the screen to the body array
	mov snakeOldHeadPtr, di
	mov [di], bx
	inc di
	inc di
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
	
tailhandler:
    mov ax, snakeTailPtr      ;Snake bigger than the absolute limit
	cmp ax, snakeHeadPtr
	je removetail
	add ax, snakeLength       ;Snake bigger than its own set size
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
        mov byte ptr es:[di],00h      ;9+
		mov di, bx
		inc di
		inc di
	    mov bx, di
	    sub bx, offset snakeBody
	    cmp bx, SNAKE_MAX_LENGTH
	    jg looptailpointer
	    mov snakeTailPtr, di
		ret
	looptailpointer:
		mov bx, offset snakeBody
		mov snakeTailPtr, bx
		ret
	looptailtemp:
	    sub ax, SNAKE_MAX_LENGTH
		jmp tailhandlerlabel
	
movesnake:
    mov al, snakeDir
	mov ah, 0
	cmp al, ah
	je snakeright
	mov ah, 1
	cmp al, ah
	je snakedown
	mov ah, 2
	cmp al, ah
	je snakeleft
	mov ah, 3
	cmp al, ah
	je snakeup
	
snakeright:
	mov bx, snakeX
	inc bx
	cmp bx, rightBorder
	jge overright
	mov snakeX, bx
	jmp moveend
	overright:
	    sub bx, rightBorder
		add bx, leftBorder
		mov snakeX, bx
    jmp moveend

snakedown:
    mov bx, snakeY
	inc bx
	cmp bx, bottomBorder
	jge overdown
	mov snakeY, bx
	jmp moveend
	overdown:
	    sub bx, bottomBorder
		add bx, topBorder
		mov snakeY, bx
    jmp moveend
	
snakeleft:
	mov bx, snakeX
	dec bx
	mov dx, leftBorder
	dec dx
	cmp bx, dx
	jle overleft
	mov snakeX, bx
	jmp moveend
	overleft:
	    add bx, rightBorder
		sub bx, leftBorder
		mov snakeX, bx
    jmp moveend
	
snakeup:
	mov bx, snakeY
	dec bx
	mov dx, topBorder
	dec dx
	cmp bx, dx
	jle overup
	mov snakeY, bx
	jmp moveend
	overup:
	    add bx, bottomBorder
		sub bx, topBorder
		mov snakeY, bx
    jmp moveend

moveend:
	;Will be used for collision checking
    ret
	
printnum:
    ;initilize count 
    mov cx,0 
    mov dx,0
	lea di,numbuf+5
	cmp ax,0
	je numzero
	
    numtochar: 
        ; if ax is zero 
        cmp ax,0 
        je print1       
          
        ;initilize bx to 10 
        mov bx,10         
          
        ; extract the last digit 
        div bx                   
          
        ; adds it at the tail of the string
		add dx,30h
		dec di
		mov [di],dl           
          
        ;increment the count 
        inc cx               
          
        ;set dx to 0  
        xor dx,dx 
        jmp numtochar 
    print1: 
        ;check if count  
        ;is greater than zero 
        cmp cx,0 
        je exit
		;print the string
		mov ah,09h
		mov dx,di
		int DOS_INT
		
    exit: 
        ret
	numzero:
		add ax,30h
		dec di
	    mov [di],al
		inc cx
		jmp print1
		
printpos:
    mov ax,0900h
	mov dx, offset posHd
	int DOS_INT
	
	mov ax,snakeX
	
	call printnum
	
	mov ax,0900h
	mov dx, offset VIRGULE
	int DOS_INT
	
	mov ax,snakeY
	
	call printnum
	
	mov ax,0900h
	mov dx, offset RET_CAR
	int DOS_INT
	
	ret
	
end main