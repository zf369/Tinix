// ; ==========================================
// ; string.h
// ; 导出string.asm的函数
// ; ==========================================

PUBLIC void *mem_cpy(void *p_dst, void *p_src, int size);
PUBLIC void  mem_set(void *p_dst, char ch, int size);
PUBLIC char *str_cpy(void *p_dst, char *p_src);
PUBLIC int   str_len(char* p_str);