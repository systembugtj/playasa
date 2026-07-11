#pragma once

// Picture flag bits shared by CMpeg2DecFilter modern output metadata.
#define PIC_MASK_CODING_TYPE 7
#define PIC_FLAG_CODING_TYPE_I 1
#define PIC_FLAG_CODING_TYPE_P 2
#define PIC_FLAG_CODING_TYPE_B 3
#define PIC_FLAG_CODING_TYPE_D 4

#define PIC_FLAG_TOP_FIELD_FIRST 8
#define PIC_FLAG_PROGRESSIVE_FRAME 16
#define PIC_FLAG_REPEAT_FIRST_FIELD 256
