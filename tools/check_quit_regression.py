#!/usr/bin/env python3
"""Require original Quit, empty ownership ledgers and complete OS handback."""
import argparse
from pathlib import Path
import re
from check_menu_keyboard import require


def check(text, status, launch, reply=None):
    wb=int(launch=='workbench')
    require(status==0, f'runner exit {status}')
    require(not re.search(r'FAIL|TIMEOUT|Error in|Program received signal',text),'observer error')
    require(text.count(f'QUIT_START workbench={wb}')==1,'actual startup mode')
    menu=[tuple(map(int,x)) for x in re.findall(r'^QUIT_MENU stage=(\d+) ticks=(\d+) frames=(\d+)$',text,re.M)]
    require([x[0] for x in menu]==[9,10,11] and menu[0][2]>0,'published gameplay and original ExitToShell sequence')
    require(menu[0][1]<menu[1][1]<=menu[2][1],'ordered gameplay/exit/restoration')
    rows=re.findall(r'^QUIT_RETURN stage=(\d+) result=(\d+) workbench=(\d+) chip=(\d+) fast=(\d+) errors=(\d+) files=(\d+)$',text,re.M)
    require([tuple(map(int,r)) for r in rows]==[(2,0,wb,0,0,0,0),(3,0,wb,0,0,0,0)],'empty post-return ledgers and successful result')
    os_state=re.findall(r'^QUIT_OS view=(\d+) dma=([0-9A-F]+)/([0-9A-F]+) irq=([0-9A-F]+)/([0-9A-F]+) paula=(\d+)$',text,re.M)
    require(len(os_state)==1,'one OS restoration observation')
    view,dma,actual_dma,irq,actual_irq,paula=os_state[0]
    require(int(view)==1 and int(actual_dma,16)==(int(dma,16)&0x7ff)
            and int(actual_irq,16)==((int(irq,16)&0x7fff)|0x4000) and int(paula)==15,'View/DMA/IRQ/Paula restoration')
    require(text.count('QUIT_VECTORS linea=1 vertb=1 keyboard=1 timer=1')==1, 'restored vectors and released input/timer ownership')
    require(text.count('PASS QUIT original exit, empty ledgers, closed libraries and restored OS')==1
            and text.count('[Inferior 1 (Remote target) detached]')==1,'positive completion')
    if wb:
        require(reply is not None and reply.read_text()=='PASS Workbench startup reply received after game cleanup\n','launcher received startup reply')
    print(f'PASS quit regression: {launch} startup, original Quit, empty ledgers and restored OS'+('; startup reply received' if wb else ''))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True)
    p.add_argument('--launch',choices=('shell','workbench'),required=True)
    p.add_argument('--reply',type=Path)
    a=p.parse_args()
    try:check(a.log.read_text(),a.status,a.launch,a.reply)
    except (ValueError,OSError) as error:raise SystemExit('FAIL quit regression: '+str(error))
