/*****************************************************************************
 模块名      : OpenGL着色器 
 文件名      : shaders.h
 相关文件    :  shaders.m
 文件实现功能 : OpenGL着色器的编译，链接，使有效，销毁
 作者        : 朱美龙
 版本        : 
 -----------------------------------------------------------------------------
 修改记录:
 日  期      版本        修改人      修改内容
 2012/10/18  1.0         朱美龙      新建
 ******************************************************************************/

#ifndef __SHADERS_H__
#define __SHADERS_H__ 
  
#include <OpenGLES/ES2/gl.h> 
#include <OpenGLES/ES2/glext.h>  

/******************************************************************************
 函数名  :  compileShader
 功能名  :  编译OpenGL着色器
 参数名  :
     shader :  着色器ID值(output);
     type   :  着色器类型，可以是GL_VERTEX_SHADER或GL_FRAGMENT_SHADER;
     file   :  着色器源文件路径; 
 返回值  :  
      成功返回GL_TRUE; 失败返回GL_FALSE.
 *****************************************************************************/
GLint compileShader(GLuint *shader, GLenum type, const GLchar *sources);

/******************************************************************************
 函数名  :  linkProgram
 功能名  :  链接OpenGL程序
 参数名  :
     prog :  需要链接的程序的ID值; 
 返回值  :  
     成功返回GL_TRUE; 失败返回GL_FALSE.
 *****************************************************************************/
GLint linkProgram(GLuint prog); 

/******************************************************************************
 函数名  :  validateProgram
 功能名  :  检测OpenGL程序的有效性
 参数名  :
     prog :  OpenGL程序的ID值; 
 返回值  :  
    成功返回GL_TRUE; 失败返回GL_FALSE.
 *****************************************************************************/
GLint validateProgram(GLuint prog); 

/******************************************************************************
 函数名  :  destroyShaders
 功能名  :  销毁OpenGL资源
 参数名  :
    vertShader :  着色器ID值;
    fragShader :  着色器ID值;
        prog   :  OpenGL程序的ID值; 
 返回值  :  
 成功返回GL_TRUE; 失败返回GL_FALSE.
 *****************************************************************************/
void destroyShaders(GLuint vertShader, GLuint fragShader, GLuint prog); 
  
#endif /* __SHADERS_H__ */ 
