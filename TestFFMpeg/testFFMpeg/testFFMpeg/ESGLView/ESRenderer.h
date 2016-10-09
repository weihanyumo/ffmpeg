#import <QuartzCore/QuartzCore.h> 
  
#import <OpenGLES/EAGL.h> 
#import <OpenGLES/EAGLDrawable.h> 
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
  
@protocol ESRenderer <NSObject> 
  
- (void)render:(unsigned char *)buff;

- (BOOL)resizeFromLayer:(CAEAGLLayer*)layer;

-(void)setDataSize:(GLint)newWidth andHeight:(GLint)newHeight;

-(void)getDataSize:(GLint *)newWidth andHeight:(GLint *)newHeight;

- (void) moving2Foreground:(CAEAGLLayer *)layer;

- (void) moving2Background;

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
