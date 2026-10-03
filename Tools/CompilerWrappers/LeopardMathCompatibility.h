#ifndef RetroWebKit_LeopardMathCompatibility_h
#define RetroWebKit_LeopardMathCompatibility_h

#include <AvailabilityMacros.h>
#include <cmath>

// GCC 6's Objective-C front end predates Clang's modern Cocoa spelling and
// the ownership annotations added after the Leopard SDK. They are source
// annotations only, so use their pre-Clang equivalents while targeting 10.5.
#if defined(__APPLE__) && defined(MAC_OS_X_VERSION_MAX_ALLOWED) && MAC_OS_X_VERSION_MAX_ALLOWED < 1060
#if defined(__OBJC__) && !defined(instancetype)
#define instancetype id
#endif
#ifndef NS_RETURNS_RETAINED
#define NS_RETURNS_RETAINED
#endif
#ifndef CF_RETURNS_RETAINED
#define CF_RETURNS_RETAINED
#endif
#endif

// Leopard's libSystem exports these C99 functions, but its C++ headers do not
// make them visible in std. WebKit 604 and its third-party sources expect the
// later SDK behavior.
#if defined(__APPLE__) && defined(MAC_OS_X_VERSION_MAX_ALLOWED) && MAC_OS_X_VERSION_MAX_ALLOWED < 1060
namespace std {
using ::acosh;
using ::asinh;
using ::atanh;
using ::cbrt;
using ::expm1;
using ::log1p;
using ::log2;
using ::lround;
using ::nextafter;
using ::round;
inline float round(float value) { return ::roundf(value); }
inline long double round(long double value) { return ::roundl(value); }
using ::trunc;
}
#endif

#endif
