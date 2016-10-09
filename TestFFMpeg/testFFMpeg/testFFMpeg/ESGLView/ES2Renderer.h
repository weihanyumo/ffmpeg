/*****************************************************************************
 模块名      : ES2Renderer 
 文件名      : ES2Renderer.h
 相关文件    : ES2Renderer.m
 文件实现功能 : OpenGL实现绘图显示
 作者        : 朱美龙
 版本        : 
 -----------------------------------------------------------------------------
 修改记录:
 日  期      版本        修改人      修改内容
 2012/10/18  1.0         朱美龙      新建
 ******************************************************************************/

#import "ESRenderer.h"
#import <OpenGLES/ES2/gl.h> 
#import <OpenGLES/ES2/glext.h> 
#import <time.h>
 
// uniform index 
enum {
    UNIFORM_YTEXTURE, 
    UNIFORM_UTEXTURE,
    UNIFORM_VTEXTURE,
    UNIFORM_COLOR_MATRIX,
    NUM_UNIFORMS 
}; 
//GLint uniforms[NUM_UNIFORMS];

// attribute index 
enum { 
    ATTRIB_VERTEX, 
    ATTRIB_TEXCOORD, 
    NUM_ATTRIBUTES 
};
//GLint attributes[NUM_ATTRIBUTES];

@interface ES2Renderer : NSObject <ESRenderer> 
{ 
@private
    EAGLContext *context; 
     
    // The pixel dimensions of the CAEAGLLayer 
    GLint backingWidth; 
    GLint backingHeight; 
     
    // The OpenGL names for the framebuffer and renderbuffer used to render to this view 
    GLuint defaultFramebuffer; 
    GLuint colorRenderbuffer;
    GLuint vertexBuffer;
    GLuint indexBuffer;
    
    // the shader program object 
    GLuint program; 
    
    // the texture ID
    GLuint yTextureID;
    GLuint uTextureID;
    GLuint vTextureID;
    boolean_t m_bTextureValid;
    
    // the size of data intent to show
    GLint dataWidth;
    GLint dataHeight;
    boolean_t m_bDimensionApplied;
    
    // uniform IDs
    GLint uniforms[NUM_UNIFORMS];
    
    //attribute IDs
    GLint attributes[NUM_ATTRIBUTES];
    
    // vertices
    GLfloat m_vertices[20];
    boolean_t m_bDirectionApplied;
    int m_nDirection;
    
    // whether the resize from layer is applied.
    CAEAGLLayer * m_layer;
    boolean_t m_bResizeFromLayerApplied;
}

/******************************************************************************
 函数名  :  setDataSize
 功能名  :  设置显示数据的宽高
 参数名  :
 newWidth :  显示数据的宽;
 newHeight :  显示数据的高;
 返回值  :  
 
 *****************************************************************************/
-(void)setDataSize:(GLint)newWidth andHeight:(GLint)newHeight;

/******************************************************************************
 函数名  :  getDataSize
 功能名  :  获取显示数据的宽高
 参数名  :
 newWidth :  显示数据的宽;
 newHeight :  显示数据的高;
 返回值  :  
 
 *****************************************************************************/
-(void)getDataSize:(GLint*)newWidth andHeight:(GLint*)newHeight;

/******************************************************************************
 函数名  :  render
 功能名  :  绘图
 参数名  :
     buff  :  显示数据的指针;
 返回值  :  

 *****************************************************************************/
- (void) render:(unsigned char *)buff;

/******************************************************************************
 函数名  :  resizeFromLayer
 功能名  :  根据layer尺寸的变化调整底层buffer大小
 参数名  :  
     layer :  ;
 返回值  :  
     成功返回YES,失败返回NO
 *****************************************************************************/
- (BOOL) resizeFromLayer:(CAEAGLLayer *)layer; 

/******************************************************************************
 函数名  :  Moving2Foreground
 功能名  :  移到前台
 参数名  :
 
 返回值  :
 *****************************************************************************/
- (void) moving2Foreground:(CAEAGLLayer *)layer;

/******************************************************************************
 函数名  :  moving2Background
 功能名  :  即将移到后台
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

@end