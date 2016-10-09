/*****************************************************************************
 模块名      : EAGLView
 文件名      : EAGLView.h
 相关文件    :  EAGLView.m
 文件实现功能 : 实现绘图显示
 作者        : 朱美龙
 版本        :
 -----------------------------------------------------------------------------
 修改记录:
 日  期      版本        修改人      修改内容
 2012/10/18  1.0         朱美龙      新建
 ******************************************************************************/

#import <UIKit/UIKit.h>

@protocol ESRenderer;

// This class wraps the CAEAGLLayer from CoreAnimation into a convenient UIView subclass.
// The view content is basically an EAGL surface you render your OpenGL scene into.
// Note that setting the view non-opaque will only work if the EAGL surface has an alpha channel.
@interface EAGLView : UIView
{
@private
    id <ESRenderer> renderer;
}

/******************************************************************************
 函数名  :  initWithFrame
 功能名  :  初始化
 参数名  :
 frame :  显示区域（x, y, width, height）;
 返回值  :
 成功返回id; 失败返回nil.
 *****************************************************************************/
- (id) initWithFrame:(CGRect)frame;

/******************************************************************************
 函数名  :  setDataSize
 功能名  :  设置显示数据的宽高
 参数名  :
 newWidth :  显示数据的宽;
 newHeight :  显示数据的高;
 返回值  :
 
 *****************************************************************************/
-(void) setDataSize:(int)newWidth andHeight:(int)newHeight;

/******************************************************************************
 函数名  :  getDataSize
 功能名  :  获取显示数据的宽高
 参数名  :
 newWidth :  显示数据的宽;
 newHeight :  显示数据的高;
 返回值  :
 
 *****************************************************************************/
-(void) getDataSize:(int*)newWidth andHeight:(int*)newHeight;

/******************************************************************************
 函数名  :  drawView
 功能名  :  绘图
 参数名  :
 buff  :  显示数据的指针;
 返回值  :
 成功返回id; 失败返回nil.
 *****************************************************************************/
- (void) drawView:(unsigned char *)buff;

/******************************************************************************
 函数名  :  moving2Foreground
 功能名  :  移到前台
 参数名  :
 
 返回值  :
 *****************************************************************************/
- (void) moving2Foreground;

/******************************************************************************
 函数名  :  moving2Background
 功能名  :  移到后台
 参数名  :
 
 返回值  :
 *****************************************************************************/
- (void) moving2Background;

/******************************************************************************
 函数名  :  didMoving2Background
 功能名  :  已经移到后台
 参数名  :
 
 返回值  :
 *****************************************************************************/
- (void) didMoving2Background;

/******************************************************************************
 函数名  :  setLayerScale
 功能名  :  设置缩放因子
 参数名  :
 
 返回值  :
 *****************************************************************************/
- (void) setLayerScale:(float)scale;

/*
 * \brief set display direction
 * \param newDirection    the direction of display on surface
 *                          - 0  east direction for x-axis
 *                          - 1  north
 *                          - 2  west
 *                          - 3  south
 * \author xiezhigang @ kedacom.com on 2013/07/23
 */
- (void) setDirection:(int)newDirection;

/******************************************************************************
 函数名  :  dealloc
 功能名  :  去初始化
 参数名  :
 
 返回值  :
 *****************************************************************************/
- (void) dealloc;

@end
