/**
 * Common data structures of MStar decoder library
 */
#ifndef __MI_DECODER_COMMON__
#define __MI_DECODER_COMMON__

/******************************************************************************
* Data type macro
*******************************************************************************/
typedef signed char        INT8;
typedef signed short       INT16;
typedef signed int         INT32;
typedef unsigned char      UINT8;
typedef unsigned short     UINT16;
typedef unsigned int       UINT32;

#if defined(__GNUC__)
typedef          long long INT64;
typedef unsigned long long UINT64;
#else
typedef          __int64   INT64;
typedef unsigned __int64   UINT64;
#endif

typedef char               BOOL8;
typedef short              BOOL16;
typedef int                BOOL32;

#ifndef TRUE
#define TRUE               1
#endif

#ifndef FALSE
#define FALSE              0
#endif

typedef void* MI_DEC_HANDLE;   //Handle for H.264/H.265 decoder

/******************************************************************************
* Data struct
*******************************************************************************/
typedef enum emMI_DECODER_TYPE
{
	MI_DECODER_UNKNOWN = 0,
    MI_DECODER_H264,
    MI_DECODER_H265
} EM_MI_DECODER_TYPE;

typedef enum emMI_DEC_FRAMETYPE
{
	MI_DEC_FRAME_UNKNOWN = 0,
	MI_DEC_FRAME_I,
	MI_DEC_FRAME_P,
	MI_DEC_FRAME_B
} EM_MI_DEC_FRAMETYPE;

typedef enum emMI_DEC_DECODEMODE
{
    MI_DEC_DECODE     = 0,
    MI_DEC_DECODE_END
} EM_MI_DEC_DECODEMODE;

typedef enum emMI_DEC_DECODESTATUS
{
    MI_DEC_GETDISPLAY     = 0,
    MI_DEC_NEED_MORE_BITS,
    MI_DEC_NO_PICTURE,
    MI_DEC_ERR_HANDLE,
    MI_DEC_MAX_NUM
} EM_MI_DEC_DECODESTATUS;

typedef enum emMI_DEC_THREADTYPE
{
    MI_DEC_SINGLE_THREAD     = 0,
    MI_DEC_MULTI_THREAD
} EM_MI_DEC_THREADTYPE;

typedef struct stMI_DEC_INIT_PARAM
{
    UINT32                uiDebugLevel;

    EM_MI_DEC_THREADTYPE  eThreadType;
    UINT32                uiThreadCount;  //Attention: there are not the more threads, the better.
                                          //You should measure the count according the actual enviroment.

	UINT32                uiTimeScale;
} ST_MI_DEC_INIT_PARAM;

typedef struct stMI_DEC_INARGS
{
    UINT8  *pStream;
    UINT32 uiStreamLen;

    BOOL8  bTimeLog;  // print packet information and decoding time. TRUE: on; FALSE: off
} ST_MI_DEC_INARGS;

typedef struct stMI_DEC_OUTARGS
{
    UINT32                  uiBytsConsumed;

	UINT64                  uiFramePTS;

    EM_MI_DEC_FRAMETYPE     eFrameType;
    EM_MI_DEC_DECODESTATUS  eDecodeStatus;

    UINT32                  uiDecWidth;
    UINT32                  uiDecHeight;

    UINT8                   *pucOutYUV[3];
    UINT32                  uiLineSize[3];
} ST_MI_DEC_OUTARGS;

// Version rule: X1.X2.YYYYMMDD_X3
// X1 -> main version number
// X2 -> vice version number
// YYYYMMDD -> compile date
// X3 -> alpha or beta or release
// for example: 1.1.20160428_beta
#define MI_DEC_LIB_VERSION_LENGTH   32
typedef struct stMI_DEC_LIB_VERSION
{
    INT8 sVersion[MI_DEC_LIB_VERSION_LENGTH];   // library version string
} ST_MI_DEC_LIB_VERSION;

#endif //__MI_DECODER_COMMON__