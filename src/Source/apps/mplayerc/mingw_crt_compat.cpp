#include "stdafx.h"

/*
 * MinGW 的 libmingwex（如 pformat.o）在链接到 MSVC 主程序时仍会引用 __get_output_format；
 * 该符号来自旧版 MS CRT，UCRT 中不提供。此处提供桩实现以满足链接，运行时 libavcodec 路径不依赖其语义。
 * 注意：x86 MSVC 会给 cdecl C 符号加前导下划线，源里写 _get_output_format 才会导出 __get_output_format。
 */
extern "C" unsigned int __cdecl _get_output_format(void)
{
	return 0u;
}
