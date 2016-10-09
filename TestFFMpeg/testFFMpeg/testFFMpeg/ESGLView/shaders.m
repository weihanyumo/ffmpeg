#import "Shaders.h" 
#import <stdlib.h>
/* Create and compile a shader from the provided source(s) */ 
GLint compileShader(GLuint *shader, GLenum type, const GLchar *sources) 
{ 
    GLint status = GL_FALSE;     

    if (!sources) 
    { 
//        NSLog(@"Failed to load shader");
        return GL_FALSE; 
    } 
 
    *shader = glCreateShader(type);             // create shader 
    glShaderSource(*shader, 1, &sources, NULL); // set source code in the shader 
    glCompileShader(*shader);                   // compile shader 
     
#if defined(DEBUG) 
    GLint logLength; 
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength); 
//    if (logLength > 0) 
//    { 
//        GLchar *log = (GLchar *)malloc(logLength); 
//        glGetShaderInfoLog(*shader, logLength, &logLength, log); 
//        NSLog(@"Shader compile log:\n%s", log); 
//        free(log); 
//    } 
#endif
     
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status); 
    if (status == GL_FALSE) 
    { 
        
    } 
     
    return status; 
} 
  
  
/* Link a program with all currently attached shaders */ 
GLint linkProgram(GLuint prog) 
{ 
    GLint status = GL_FALSE; 
     
    glLinkProgram(prog); 
     
#if defined(DEBUG) 
//    GLint logLength; 
//    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
//    if (logLength > 0) 
//    { 
//        GLchar *log = (GLchar *)malloc(logLength); 
//        glGetProgramInfoLog(prog, logLength, &logLength, log); 
//        NSLog(@"Program link log:\n%s", log); 
//        free(log); 
//    } 
#endif
     
    glGetProgramiv(prog, GL_LINK_STATUS, &status); 
    if (GL_FALSE == status) 
    {
//        NSLog(@"Failed to link program %d", prog); 
    }
     
    return status; 
}   
  
/* Validate a program (for i.e. inconsistent samplers) */ 
GLint validateProgram(GLuint prog) 
{ 
    int32_t logLength = 0, status = GL_FALSE;
     
    glValidateProgram(prog); 
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength); 
    if (logLength > 0) 
    { 
        char *log = (char *)malloc((unsigned long)logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        free(log); 
    } 
     
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status); 
    if (GL_FALSE == status)
    {
    }
     
    return status; 
} 
  
/* delete shader resources */ 
void destroyShaders(GLuint vertShader, GLuint fragShader, GLuint prog) 
{    
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
    if (0 != prog) 
    { 
        glDeleteProgram(prog); 
        prog = 0; 
    }
    
    return;
} 
