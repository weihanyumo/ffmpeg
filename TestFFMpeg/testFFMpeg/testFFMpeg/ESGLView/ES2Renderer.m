#import "ES2Renderer.h" 
#import "Shaders.h"

// size of matrix (yuv to rgb translate matrix)
#define MATRIXSIZE (4)

// position(x, y, z) and texturecoord(s, t)
const GLfloat vertices[] = {
    -1.0f, 1.0f, 0.0f, 0.0f, 0.0f,
    1.0f, 1.0f, 0.0f, 1.0f, 0.0f,
    1.0f, -1.0f, 0.0f, 1.0f, 1.0f,
    -1.0f, -1.0f, 0.0f, 0.0f, 1.0f
};

// vertex index
const GLushort indices[] = {0, 1, 2, 3};

// yuv to rgb translate matrix
const GLfloat matrixYCbCr2RGB[MATRIXSIZE * MATRIXSIZE] =
{		
    1.164f,  1.164f, 1.164f, 0.0f,
      0.0f, -0.392f, 2.018f, 0.0f,
    1.597f, -0.813f,   0.0f, 0.0f,
      0.0f,    0.0f,   0.0f, 0.0f
};

// vertex shader
static const GLchar vShaderStr[] =
"attribute vec4 position;       \n"
"attribute vec2 inTexcoord;     \n"
"varying vec2 outTexcoord;      \n"
"void main()                    \n"
"{                              \n"
"   gl_Position = position;     \n"
"   outTexcoord = inTexcoord;   \n"    
"}                              \n";

// fragment shader
static const GLchar fShaderStr[] =
"precision mediump float;                                          \n"

"varying vec2 outTexcoord;                                         \n"
"uniform sampler2D yTexture;                                       \n"
"uniform sampler2D uTexture;                                       \n"
"uniform sampler2D vTexture;                                       \n"
"uniform mat4 colorMatrix;                                         \n"

"void main()                                                       \n"
"{                                                                 \n"
"  vec4 yuv;                                                       \n"
"  yuv.rgba = vec4((texture2D(yTexture, outTexcoord).r - 0.0625),  \n"
"                  (texture2D(uTexture, outTexcoord).r - 0.500),   \n"
"                  (texture2D(vTexture, outTexcoord).r - 0.500),   \n"
"                  0.0);                                           \n"
"  gl_FragColor = colorMatrix * yuv;                               \n"
"}                                                                 \n";

EAGLContext *firstContext = NULL;

@interface ES2Renderer (PrivateMethods) 
- (BOOL) loadShaders;
- (BOOL) loadColorMatrix;
- (void) deallocTexture;
- (BOOL) loadTextures:(NSInteger)width andHeight:(NSInteger)height;
 
@end 
  
@implementation ES2Renderer 

// set width and height of data
-(void)setDataSize:(GLint)newWidth andHeight:(GLint)newHeight
{
	if ((dataWidth != newWidth) || (dataHeight != newHeight))
    {
	    dataWidth  = newWidth;
        dataHeight = newHeight;
        m_bDimensionApplied = false;
    } 
    return;
}

// get width and height of data
-(void)getDataSize:(GLint*)width andHeight:(GLint*)height
{
    *width  = dataWidth;
    *height = dataHeight;
    return;
}

// Create an ES 2.0 context 
- (id <ESRenderer>) init 
{
    if (self = [super init]) 
    {
        if (!firstContext)
        {
            context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
#ifdef DEBUG
//    firstContext = [context retain];
#else
            firstContext = [context retain];
#endif
        }
        else
        {
            context = [[EAGLContext alloc] initWithAPI:[firstContext API] sharegroup: [firstContext sharegroup]];
        }
        
        if (!context || ![EAGLContext setCurrentContext:context] || ![self loadShaders])
        { 
            [self release]; 
            return nil; 
        }          

        dataWidth  = 1024;
        dataHeight = 768;
        m_bDimensionApplied = false;
        m_bTextureValid = false;
        
        // Create default framebuffer object. The backing will be allocated for the current layer in -resizeFromLayer 
        glGenFramebuffers(1, &defaultFramebuffer); 
        glGenRenderbuffers(1, &colorRenderbuffer); 
        glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer); 
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer); 
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer);
        
        // set vertices
        memcpy(m_vertices, vertices, sizeof(m_vertices));
        m_bDirectionApplied = false;
        m_nDirection = 0;
        
        // for resize from layer
        m_layer = nil;
        m_bResizeFromLayerApplied = false;
    }
    
    return self;
}

- (void)render:(unsigned char *) buff
{
//    NSLog(@"");
    boolean_t use_symchronization = false;
    [EAGLContext setCurrentContext:context];
    
    // apply the resizeFromLayer(...)
    if (!m_bResizeFromLayerApplied) {
        // Allocate color buffer backing based on the current layer size
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
        [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:m_layer];
        GLenum fbStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        if (GL_FRAMEBUFFER_COMPLETE != fbStatus)
        {
            NSLog(@"Failed to make complete framebuffer object %x", fbStatus);
            return;
        }
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
        m_bResizeFromLayerApplied = true;
    }
    
    glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
    glViewport(0, 0, backingWidth, backingHeight); 
    
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    // if buff is invalid, keep the screen clear.
    if (buff != NULL)
    {
        // use shader program
        glUseProgram(program);
        
        // Load the vertex position
        glVertexAttribPointer(attributes[ATTRIB_VERTEX], 3, GL_FLOAT,
                              GL_FALSE, 5 * sizeof(GLfloat), (const GLvoid*)0);
        glEnableVertexAttribArray(attributes[ATTRIB_VERTEX]);
        
        glVertexAttribPointer(attributes[ATTRIB_TEXCOORD], 2, GL_FLOAT,
                              GL_FALSE, 5 * sizeof(GLfloat),
                              (const GLvoid*)(3 * sizeof(GLfloat)));
        glEnableVertexAttribArray(attributes[ATTRIB_TEXCOORD]);
        
        // load vertices
        if (!m_bDirectionApplied)
        {
            glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
            glBufferData(GL_ARRAY_BUFFER, sizeof(m_vertices), m_vertices, GL_STATIC_DRAW);
            m_bDirectionApplied = true;
        }
        
        // generate texture
        if (!m_bDimensionApplied) {
            if (m_bTextureValid) {
                [self deallocTexture];
            }
            [self loadTextures:dataWidth andHeight:dataHeight];
            
            // IΩ  f the size changed, should synchronize the display at the first frame
            // to avoid unstable frame data, and clean the gpu command buffer.
            // Otherwise, asynchronize mode is faster in performance.
            // -- xiezhigang on 2013-08-11
            use_symchronization = true;
        }
        
        // Update vtexture
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, vTextureID);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, dataWidth >> 1,
                        dataHeight >> 1, GL_LUMINANCE, GL_UNSIGNED_BYTE,
                        buff + dataHeight * dataWidth * 5 / 4);
        
        // Update utexture
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, uTextureID);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, dataWidth >> 1,
                        dataHeight >> 1, GL_LUMINANCE, GL_UNSIGNED_BYTE,
                        buff + dataHeight * dataWidth);
        
        // Update ytexture
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, yTextureID);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, dataWidth,
                        dataHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE,
                        buff);
        
        // Validate program before drawing. This is a good check, but only really necessary in a debug build.
        // DEBUG macro must be defined in your debug configurations if that's not already the case.
#if defined(DEBUG)
        if (!validateProgram(program))
        { 
            NSLog(@"Failed to validate program: %d", program); 
            return; 
        } 
#endif
        
        // draw 
        glDrawElements(GL_TRIANGLE_FAN, 4, GL_UNSIGNED_SHORT, 0);        
    }
    
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    
    if (!use_symchronization) {
        glFlush();
    } else {
        glFinish();
    }
    
    [context presentRenderbuffer:GL_RENDERBUFFER];
}

// load yuv2rgb matrix
- (BOOL) loadColorMatrix
{
    float m[MATRIXSIZE][MATRIXSIZE];
    
    memcpy((void *)m, (const void *)matrixYCbCr2RGB, (unsigned)sizeof(matrixYCbCr2RGB));
    
    // load transform matrix to color_matrix in fragment shader
    uniforms[UNIFORM_COLOR_MATRIX] = glGetUniformLocation(program, "colorMatrix");
    glUniformMatrix4fv(uniforms[UNIFORM_COLOR_MATRIX], 1, 0, (float*)m);
    
    return YES;
}

- (BOOL)loadShaders
{ 
    GLuint vertShader = 0, fragShader = 0;
    
    program = 0;
     
    // create and compile vertex shader 
    if (!compileShader(&vertShader, GL_VERTEX_SHADER, vShaderStr)) 
    { 
        destroyShaders(vertShader, fragShader, program); 
        return NO; 
    } 
     
    // create and compile fragment shader 
    if (!compileShader(&fragShader, GL_FRAGMENT_SHADER, fShaderStr)) 
    { 
        destroyShaders(vertShader, fragShader, program); 
        return NO; 
    }    
    
    // create shader program 
    program = glCreateProgram();
    if (0 == program)
    {
        destroyShaders(vertShader, fragShader, program);
        NSLog(@"Failed to create program");
        return NO;
    }
    
    // attach vertex shader to program 
    glAttachShader(program, vertShader); 
     
    // attach fragment shader to program 
    glAttachShader(program, fragShader); 
    
    // link program 
    if (!linkProgram(program)) 
    { 
        destroyShaders(vertShader, fragShader, program);        
        return NO; 
    } 

    // Use the program
    glUseProgram(program);
    
    // get uniform locations    
    uniforms[UNIFORM_YTEXTURE] = glGetUniformLocation(program, "yTexture");
    uniforms[UNIFORM_UTEXTURE] = glGetUniformLocation(program, "uTexture");
    uniforms[UNIFORM_VTEXTURE] = glGetUniformLocation(program, "vTexture");
    
    // Get the attribute locations
    attributes[ATTRIB_VERTEX]   = glGetAttribLocation(program, "position");
    attributes[ATTRIB_TEXCOORD] = glGetAttribLocation(program, "inTexcoord");

    // Set ytexture to use texture0, utexture to use texture1...
    glUniform1i(uniforms[UNIFORM_YTEXTURE], 0);
    glUniform1i(uniforms[UNIFORM_UTEXTURE], 1);
    glUniform1i(uniforms[UNIFORM_VTEXTURE], 2);

    // load color matrix
    [self loadColorMatrix];
    
    // generate vertex buffer for position and texture coord    
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    //glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    glBufferData(GL_ARRAY_BUFFER, sizeof(m_vertices), m_vertices, GL_STATIC_DRAW);
    m_bDirectionApplied = true;
    
    // generate vertex buffer for vertex index    
    glGenBuffers(1, &indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
    
    // Stop the program
    glUseProgram(0); 
    
    // release vertex and fragment shaders 
    if (0 != vertShader) 
    { 
        glDeleteShader(vertShader); 
        vertShader = 0; 
    } 
    if (0 != fragShader) 
    { 
        glDeleteShader(fragShader); 
        fragShader = 0; 
    }
    
//    NSLog(@"loadShaders: program: %u", program);
    return YES;
}

// load y u v three textures
- (BOOL) loadTextures:(NSInteger)width andHeight:(NSInteger)height
{
    if (m_bTextureValid) {
        NSLog(@"[ERROR] previous valid textures are not deallocated");
        return NO;
    }
    
    GLuint texture[3] = {0};
    GLint textureWidth  = 0;
    GLint textureHeight = 0;
   
    // generate 3 textures
    glGenTextures(3, texture);
    
    for(GLuint i = 0; i < 3; i++)
    {
        textureWidth  = (int)width;
        textureHeight = (int)height;
        
        if (0 != i)
        {
            textureWidth  = (int)width >> 1;
            textureHeight = (int)height >> 1;
        }         
        
        glBindTexture(GL_TEXTURE_2D, texture[i]);
    
        // malloc memory for texture
        glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE,
                     textureWidth, textureHeight, 0, 
                     GL_LUMINANCE, GL_UNSIGNED_BYTE, 0);
    
        // set the texture params
        // if use GL_NEAREST, users will complaint that the text or title
        // is not clear enough. because the text stroke is 1 piont and it will
        // be ignored by GL_NEAREST. GL_LINEAR is to interpolate the 1 point pixel
        // and remains it on surface.
        // -- xiezhigang at kedacom, on 2013/08/05
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
        
    glBindTexture(GL_TEXTURE_2D, 0);

    yTextureID = texture[0];
    uTextureID = texture[1];
    vTextureID = texture[2];
    
    m_bDimensionApplied = true;
    m_bTextureValid = true;
    
    return YES;    
}

// release y u v three textures
- (void) deallocTexture
{
    if (m_bTextureValid)
    {
        glDeleteTextures(1, &yTextureID);
        glDeleteTextures(1, &uTextureID);
        glDeleteTextures(1, &vTextureID);
        yTextureID = 0;
        uTextureID = 0;
        vTextureID = 0;
        m_bTextureValid = false;
    }
    
    return;
}
  
- (BOOL) resizeFromLayer:(CAEAGLLayer *)layer 
{
    //[[xiezhigang
    //  -- FIXBUG: can't display shared desktop from remote sometimes.
    //  -- 2013-08-12
    m_layer = layer;
    m_bResizeFromLayerApplied = false;
    /*
    // Allocate color buffer backing based on the current layer size
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer); 
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer]; 
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth); 
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight); 
     
    if (GL_FRAMEBUFFER_COMPLETE != glCheckFramebufferStatus(GL_FRAMEBUFFER)) 
    { 
        NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER)); 
        return NO; 
    }
    return YES;
    */
    //xiezhigang]]
    return YES;
} 
  
- (void) dealloc 
{ 
    // tear down GL
    if (0 != defaultFramebuffer) 
    { 
        glDeleteFramebuffers(1, &defaultFramebuffer); 
        defaultFramebuffer = 0; 
    } 
     
    if (0 != colorRenderbuffer) 
    { 
        glDeleteRenderbuffers(1, &colorRenderbuffer); 
        colorRenderbuffer = 0; 
    } 
    
    if (0 != vertexBuffer)
    {
        glDeleteBuffers(1, &vertexBuffer);
        vertexBuffer = 0;
    }
    
    if (0 != indexBuffer)
    {
        glDeleteBuffers(1, &indexBuffer);
        indexBuffer = 0;
    }
    
    // release the texture
    [self deallocTexture];
     
    // realease the shader program object 
    if (0 != program) 
    { 
        glDeleteProgram(program); 
        program = 0; 
    } 
     
    // tear down context 
    if ([EAGLContext currentContext] == context) 
    {
        [EAGLContext setCurrentContext:nil]; 
    }
     
    [context release]; 
    context = nil; 
     
    [super dealloc];
    
    return;
} 

- (void) moving2Foreground:(CAEAGLLayer *)layer 
{
    glUseProgram(program);
    
    // generate vertex buffer for position and texture coord
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    
    // generate vertex buffer for vertex index
    glGenBuffers(1, &indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
    
    //暂时注销
//    glGenFramebuffers(1, &defaultFramebuffer);
//    glGenRenderbuffers(1, &colorRenderbuffer);
//    glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
//    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
//    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, backingWidth, backingHeight);
//    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer);    
//    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
      
//    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER) ;
//    if(status != GL_FRAMEBUFFER_COMPLETE)
//    {
//        NSLog(@"failed to make complete framebuffer object %x", status);
//    }
    
    glUseProgram(0);
    glFinish();
    return;
}

- (void) moving2Background
{
    glUseProgram(program);
    
    if (0 != vertexBuffer)
    {
        glDeleteBuffers(1, &vertexBuffer);
        vertexBuffer = 0;
    }
    
    if (0 != indexBuffer)
    {
        glDeleteBuffers(1, &indexBuffer);
        indexBuffer = 0;
    }
    
    //这部分代码暂时注销，不然回复到前台时有问题
//    if (0 != defaultFramebuffer)
//    {
//        glDeleteFramebuffers(1, &defaultFramebuffer);
//        defaultFramebuffer = 0;
//    }
//
    
//    if (0 != colorRenderbuffer)
//    {
//        glDeleteRenderbuffers(1, &colorRenderbuffer);
//        colorRenderbuffer = 0;
//    }
    
    glUseProgram(0);
    glFinish();
    NSLog(@"glFinish...");
    return;
}

- (void) didMoving2Background
{
    glFinish();
    return;
}

/*
 * \brief set the display direction on surface
 * \note  the algorithm is to use the vertices-texture mapping, 
 *      plus the direction into the original texture x-axis,
 *      is equialant to rotate the x-axis by 90 x n.
 * \author xiezhigang @ kedacom.com on 2013/07/23
 */
- (void) setDirection:(int)newDirection
{
    if (newDirection != m_nDirection && newDirection >= 0 && newDirection < 4)
    {
        const int nStep = 5;
        const GLfloat *psx = vertices + 3;
        const GLfloat *psy = vertices + 4;
        GLfloat * px = m_vertices + 3;
        GLfloat * py = m_vertices + 4;
        for (int i = 0; i < 4; ++i) {
            int index = (i + newDirection) % 4;
            px[i * nStep] = psx[index * nStep];
            py[i * nStep] = psy[index * nStep];
        }
        m_nDirection = newDirection;
        m_bDirectionApplied = false;
    }
}

@end 
