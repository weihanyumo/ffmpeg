#import "EAGLView.h"
#import "ESRenderer.h"
#import "ES2Renderer.h" 

//id <ESRenderer> renderer;

@implementation EAGLView  
  
+ (Class) layerClass 
{ 
    return [CAEAGLLayer class]; 
} 

- (id) initWithFrame:(CGRect)frame
{     
    if ((self = [super initWithFrame:frame])) 
    { 
        // Get the layer 
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer; 
         
        eaglLayer.opaque = TRUE; 
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:FALSE],
                                        kEAGLDrawablePropertyRetainedBacking,
                                        kEAGLColorFormatRGBA8,
                                        kEAGLDrawablePropertyColorFormat,
                                        nil];       
       
        renderer = [[ES2Renderer alloc] init];                      
        if (!renderer) 
        { 
            //[self release];
            return nil;
        }         

        if(NO == [renderer resizeFromLayer:(CAEAGLLayer*)self.layer])
        {
            //[self release];
            return nil;
        }
    } 
     
    NSLog(@"init successs!");
    return self; 
}

-(void) setDataSize:(int)newWidth andHeight:(int)newHeight
{
    if ((newWidth < 0) || (newHeight < 0))
    {
        NSLog(@"error params");
        return;
    }    
    [renderer setDataSize:newWidth andHeight:newHeight];
    return;
}

-(void) getDataSize:(int*)newWidth andHeight:(int*)newHeight
{
    [renderer getDataSize:newWidth andHeight:newHeight];
    return;
}

- (void) drawView:(unsigned char *)buff 
{ 
    //NSLog(@"ESGLView drawView...");
    [renderer render:buff];
    return;
}

- (void) moving2Foreground
{
    [renderer moving2Foreground:(CAEAGLLayer *)self.layer];
    return;
}

- (void) moving2Background
{
    [renderer moving2Background];
    return;
}

- (void) didMoving2Background
{
    [renderer didMoving2Background];
    return;
}

- (void) setLayerScale:(float)scale
{
    self.layer.contentsScale = scale;
    [renderer resizeFromLayer:(CAEAGLLayer*)self.layer];
    return;
}

/*
 * \brief set display direction
 * \param newDirection    the direction of display on surface
 *                          - 0  east direction for x-axis
 *                          - 1  north
 *                          - 2  west
 *                          - 3  south
 * \author xiezhigang @ kedacom.com on 2013/07/23
 */
- (void) setDirection:(int)newDirection
{
    [renderer setDirection:newDirection];
    return;
}


- (void) dealloc 
{
    NSLog(@"dealloc eaglview ok");
    //[renderer release];
    renderer = nil;
     
    //[super dealloc];
    
    return;
} 
  
@end 
