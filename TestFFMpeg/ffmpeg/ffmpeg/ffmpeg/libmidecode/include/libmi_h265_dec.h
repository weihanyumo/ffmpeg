/**
 * Simplest decoder library for H.265
 */
#ifndef __MI_H265DECODER_LIB__
#define __MI_H265DECODER_LIB__

#ifdef _WIN32
//Windows
extern "C"
{
#else
//Linux...
#ifdef __cplusplus
extern "C"
{
#endif
#endif

#include "libmi_dec_common.h"

/******************************************************************************
* API
*******************************************************************************/
int mi_h265decoder_create(MI_DEC_HANDLE *phDecoder, ST_MI_DEC_INIT_PARAM *pstInitParam);
int mi_h265decoder_decodeframe(MI_DEC_HANDLE hDecoder, ST_MI_DEC_INARGS *pstInArgs, ST_MI_DEC_OUTARGS *pstOutArgs);
int mi_h265decoder_delete(MI_DEC_HANDLE hDecoder);
int mi_h265decoder_getversion(ST_MI_DEC_LIB_VERSION *psVersion);

#ifdef _WIN32
//Windows
};
#else
//Linux...
#ifdef __cplusplus
};
#endif
#endif

#endif //__MI_H265DECODER_LIB__