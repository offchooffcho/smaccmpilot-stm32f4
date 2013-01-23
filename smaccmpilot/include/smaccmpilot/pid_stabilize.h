/* This file has been autogenerated by Ivory
 * Compiler version  8a87cfc81413095ce219a5c6e50e7176daec6b25
 */
#ifndef __PID_STABILIZE_H__
#define __PID_STABILIZE_H__
#ifdef __cplusplus
extern "C" {
#endif
#include <ivory.h>
struct PID {
    float pid_pGain;
    float pid_iGain;
    float pid_iState;
    float pid_iMin;
    float pid_iMax;
};
float pid_update(struct PID* n_var0, float n_var1);
float stabilize_from_angle(struct PID* n_var0, struct PID* n_var1, float n_var2,
                           float n_var3, float n_var4, float n_var5,
                           float n_var6);
float stabilize_from_rate(struct PID* n_var0, float n_var1, float n_var2,
                          float n_var3, float n_var4);

#ifdef __cplusplus
}
#endif
#endif /* __PID_STABILIZE_H__ */