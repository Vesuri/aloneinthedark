// Shared Kalms span alignment body; adapter supplies width.

    r.left=int16_t(r.left&~15);
    r.right=int16_t(r.left+((r.right-r.left+31)&~31));
    if(r.right>width) {r.left-=r.right-width;r.right=width;}
