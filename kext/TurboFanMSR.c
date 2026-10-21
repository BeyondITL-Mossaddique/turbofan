// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 CloudCoder Limited
// TurboFanMSR — tiny kext that toggles Intel Turbo Boost.
//
// Turbo is controlled by bit 38 of IA32_MISC_ENABLE (MSR 0x1A0). Setting the
// bit disables turbo; clearing it re-enables it. The write must happen on every
// logical CPU, so we use mp_rendezvous_no_intrs.
//
// Behaviour:
//   load   -> turbo disabled on all cores
//   unload -> turbo re-enabled on all cores
//   sysctl debug.turbofan_turbo        read: 1 = turbo on, 0 = off
//   sysctl -w debug.turbofan_turbo=0|1 (root) re-apply, e.g. after wake

#include <mach/mach_types.h>
#include <mach/kmod.h>
#include <libkern/libkern.h>
#include <sys/sysctl.h>
#include <sys/errno.h>

#define MSR_IA32_MISC_ENABLE 0x1A0
#define TURBO_DISABLE_BIT    (1ULL << 38)

extern void mp_rendezvous_no_intrs(void (*action_func)(void *), void *arg);

static inline uint64_t ts_rdmsr(uint32_t msr)
{
    uint32_t lo, hi;
    __asm__ volatile("rdmsr" : "=a"(lo), "=d"(hi) : "c"(msr));
    return ((uint64_t)hi << 32) | lo;
}

static inline void ts_wrmsr(uint32_t msr, uint64_t value)
{
    __asm__ volatile("wrmsr" : : "c"(msr), "a"((uint32_t)value), "d"((uint32_t)(value >> 32)));
}

static void ts_disable_turbo(__unused void *arg)
{
    ts_wrmsr(MSR_IA32_MISC_ENABLE, ts_rdmsr(MSR_IA32_MISC_ENABLE) | TURBO_DISABLE_BIT);
}

static void ts_enable_turbo(__unused void *arg)
{
    ts_wrmsr(MSR_IA32_MISC_ENABLE, ts_rdmsr(MSR_IA32_MISC_ENABLE) & ~TURBO_DISABLE_BIT);
}

static int ts_turbo_is_on(void)
{
    return (ts_rdmsr(MSR_IA32_MISC_ENABLE) & TURBO_DISABLE_BIT) ? 0 : 1;
}

static int ts_sysctl_turbo SYSCTL_HANDLER_ARGS
{
#pragma unused(oidp, arg1, arg2)
    int value = ts_turbo_is_on();
    int error = sysctl_handle_int(oidp, &value, 0, req);
    if (error || req->newptr == USER_ADDR_NULL) {
        return error;
    }
    if (value != 0 && value != 1) {
        return EINVAL;
    }
    mp_rendezvous_no_intrs(value ? ts_enable_turbo : ts_disable_turbo, NULL);
    printf("TurboFanMSR: turbo %s\n", value ? "enabled" : "disabled");
    return 0;
}

SYSCTL_PROC(_debug, OID_AUTO, turbofan_turbo,
            CTLTYPE_INT | CTLFLAG_RW | CTLFLAG_LOCKED,
            NULL, 0, ts_sysctl_turbo, "I", "Intel Turbo Boost: 1 = on, 0 = off");

kern_return_t ts_start(kmod_info_t *ki, void *d);
kern_return_t ts_stop(kmod_info_t *ki, void *d);

kern_return_t ts_start(__unused kmod_info_t *ki, __unused void *d)
{
    mp_rendezvous_no_intrs(ts_disable_turbo, NULL);
    sysctl_register_oid(&sysctl__debug_turbofan_turbo);
    printf("TurboFanMSR: loaded, turbo disabled\n");
    return KERN_SUCCESS;
}

kern_return_t ts_stop(__unused kmod_info_t *ki, __unused void *d)
{
    sysctl_unregister_oid(&sysctl__debug_turbofan_turbo);
    mp_rendezvous_no_intrs(ts_enable_turbo, NULL);
    printf("TurboFanMSR: unloaded, turbo enabled\n");
    return KERN_SUCCESS;
}

extern kern_return_t _start(kmod_info_t *, void *);
extern kern_return_t _stop(kmod_info_t *, void *);

KMOD_EXPLICIT_DECL(com.cloudcoder.TurboFanMSR, "1.0.0", _start, _stop)
__private_extern__ kmod_start_func_t *_realmain = ts_start;
__private_extern__ kmod_stop_func_t *_antimain = ts_stop;
__private_extern__ int _kext_apple_cc = __APPLE_CC__;
