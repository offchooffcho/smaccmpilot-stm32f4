/* This file has been autogenerated by Ivory
 * Compiler version  8a87cfc81413095ce219a5c6e50e7176daec6b25
 */
#ifndef __SERVO_TYPE_H__
#define __SERVO_TYPE_H__
#ifdef __cplusplus
extern "C" {
#endif
#include <ivory.h>
struct servo_result {
    bool valid;
    uint16_t servo[4U];
    uint32_t time;
};

#ifdef __cplusplus
}
#endif
#endif /* __SERVO_TYPE_H__ */