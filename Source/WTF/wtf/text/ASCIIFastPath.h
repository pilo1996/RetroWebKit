/*
 * Copyright (C) 2011, 2012 Apple Inc. All rights reserved.
 * Copyright (C) 2011 Nokia Corporation and/or its subsidiary(-ies).
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this library; see the file COPYING.LIB.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 *
 */

#ifndef ASCIIFastPath_h
#define ASCIIFastPath_h

#include <stdint.h>
#include <unicode/utypes.h>
#include <wtf/StdLibExtras.h>
#include <wtf/text/LChar.h>

#if CPU(X86_SSE2)
#include <emmintrin.h>
#endif
#if CPU(PPC) || CPU(PPC64)
#ifndef __VECLIBTYPES__
#define __VECLIBTYPES__ // Hack to avoid problems with vecLibTypes.h from Accelerate framework
#endif
#include <altivec.h>
#undef vector
#undef pixel
#undef bool
#endif

namespace WTF {

template <uintptr_t mask>
inline bool isAlignedTo(const void* pointer)
{
    return !(reinterpret_cast<uintptr_t>(pointer) & mask);
}

#if (CPU(PPC) && defined(_ARCH_PPC64))
typedef uint64_t MachineWord;
#else
// Assuming that a pointer is the size of a "machine word", then
// uintptr_t is an integer type that is also a machine word.
typedef uintptr_t MachineWord;
#endif
const uintptr_t machineWordAlignmentMask = sizeof(MachineWord) - 1;

inline bool isAlignedToMachineWord(const void* pointer)
{
    return isAlignedTo<machineWordAlignmentMask>(pointer);
}

template<typename T> inline T* alignToMachineWord(T* pointer)
{
    return reinterpret_cast<T*>(reinterpret_cast<uintptr_t>(pointer) & ~machineWordAlignmentMask);
}

template<size_t size, typename CharacterType> struct NonASCIIMask;
template<> struct NonASCIIMask<4, UChar> {
    static inline uint32_t value() { return 0xFF80FF80U; }
};
template<> struct NonASCIIMask<4, LChar> {
    static inline uint32_t value() { return 0x80808080U; }
};
template<> struct NonASCIIMask<8, UChar> {
    static inline uint64_t value() { return 0xFF80FF80FF80FF80ULL; }
};
template<> struct NonASCIIMask<8, LChar> {
    static inline uint64_t value() { return 0x8080808080808080ULL; }
};
#if CPU(PPC) || CPU(PPC64)
template<> struct NonASCIIMask<16, UChar> {
    static inline __vector UChar value() { return (__vector UChar)vec_sll(vec_splat_u16(8), vec_splat_u16(4)); }
};
template<> struct NonASCIIMask<16, LChar> {
    static inline __vector LChar value() { return (__vector LChar)vec_sll(vec_splat_u8(8), vec_splat_u8(4)); }
};

template<typename CharacterType> static inline bool anyNonASCIIVecElems(__vector unsigned int inputVec);
template<> inline bool anyNonASCIIVecElems<UChar>(__vector unsigned int inputVec) {
    return vec_any_ge((__vector UChar)inputVec, (NonASCIIMask<sizeof(__vector UChar), UChar>::value()));
}
template<> inline bool anyNonASCIIVecElems<LChar>(__vector unsigned int inputVec) {
    return vec_any_ge((__vector LChar)inputVec, (NonASCIIMask<sizeof(__vector LChar), LChar>::value()));
}
#endif

template<typename CharacterType>
inline bool isAllASCII(MachineWord word)
{
    return !(word & NonASCIIMask<sizeof(MachineWord), CharacterType>::value());
}

// Note: This function assume the input is likely all ASCII, and
// does not leave early if it is not the case.
template<typename CharacterType>
inline bool charactersAreAllASCII(const CharacterType* characters, size_t length)
{
    MachineWord allCharBits = 0;
    const CharacterType* end = characters + length;

    // Prologue: align the input.
#if CPU(PPC) || CPU(PPC64)
    register __vector unsigned int allCharBitsVec = (__vector unsigned int)vec_splat_u8(0);

    const size_t loopIncrementVec = 2 * (sizeof(__vector unsigned int) / sizeof(CharacterType));
    uintptr_t memoryAccessSize = sizeof(__vector unsigned int);
    uintptr_t memoryAccessMask = memoryAccessSize - 1;
    size_t alignLen = length - std::min(length, (size_t)(-(intptr_t)characters & memoryAccessMask) / sizeof(CharacterType));
    const bool useVecs = length >= alignLen && length - alignLen > loopIncrementVec - 1;
    if (!useVecs) {
        memoryAccessSize = sizeof(MachineWord);
        memoryAccessMask = memoryAccessSize - 1;
        alignLen = std::min(length, (size_t)(-(intptr_t)characters & memoryAccessMask) / sizeof(CharacterType));
    }

    const CharacterType* alignStart = characters + alignLen;
    while (characters < alignStart) {
#else
    while (!isAlignedToMachineWord(characters) && characters != end) {
#endif
        allCharBits |= *characters;
        ++characters;
    }

#if CPU(PPC) || CPU(PPC64)
    // Compare the values of SIMD vector size (128 bit).
    if (useVecs) {
        const CharacterType* vecEnd = (const CharacterType*)((uintptr_t)end & ~memoryAccessMask);
        while (characters < vecEnd) {
            register __vector unsigned int charactersVec = vec_ld(0, (const unsigned int*)characters);
            register __vector unsigned int charactersVec2 = vec_ld(16, (const unsigned int*)characters);
            allCharBitsVec = vec_or(allCharBitsVec, charactersVec);
            allCharBitsVec = vec_or(allCharBitsVec, charactersVec2);
            characters += loopIncrementVec;
        }
    }

#endif
    // Compare the values of CPU word size.
    const CharacterType* wordEnd = alignToMachineWord(end);
    const size_t loopIncrement = sizeof(MachineWord) / sizeof(CharacterType);
    while (characters < wordEnd) {
        allCharBits |= *(reinterpret_cast_ptr<const MachineWord*>(characters));
        characters += loopIncrement;
    }

    // Process the remaining bytes.
    while (characters != end) {
        allCharBits |= *characters;
        ++characters;
    }

    MachineWord nonASCIIBitMask = NonASCIIMask<sizeof(MachineWord), CharacterType>::value();

#if CPU(PPC) || CPU(PPC64)
    return !((allCharBits & nonASCIIBitMask) || (useVecs && anyNonASCIIVecElems<CharacterType>(allCharBitsVec)));
#else
    return !(allCharBits & nonASCIIBitMask);
#endif
}

inline void copyLCharsFromUCharSource(LChar* destination, const UChar* source, size_t length)
{
#if CPU(X86_SSE2)
    const uintptr_t memoryAccessSize = 16; // Memory accesses on 16 byte (128 bit) alignment
    const uintptr_t memoryAccessMask = memoryAccessSize - 1;

    size_t i = 0;
    for (;i < length && !isAlignedTo<memoryAccessMask>(&source[i]); ++i) {
        ASSERT(!(source[i] & 0xff00));
        destination[i] = static_cast<LChar>(source[i]);
    }

    const uintptr_t sourceLoadSize = 32; // Process 32 bytes (16 UChars) each iteration
    const size_t ucharsPerLoop = sourceLoadSize / sizeof(UChar);
    if (length > ucharsPerLoop) {
        const size_t endLength = length - ucharsPerLoop + 1;
        for (; i < endLength; i += ucharsPerLoop) {
#ifndef NDEBUG
            for (unsigned checkIndex = 0; checkIndex < ucharsPerLoop; ++checkIndex)
                ASSERT(!(source[i+checkIndex] & 0xff00));
#endif
            __m128i first8UChars = _mm_load_si128(reinterpret_cast<const __m128i*>(&source[i]));
            __m128i second8UChars = _mm_load_si128(reinterpret_cast<const __m128i*>(&source[i+8]));
            __m128i packedChars = _mm_packus_epi16(first8UChars, second8UChars);
            _mm_storeu_si128(reinterpret_cast<__m128i*>(&destination[i]), packedChars);
        }
    }

    for (; i < length; ++i) {
        ASSERT(!(source[i] & 0xff00));
        destination[i] = static_cast<LChar>(source[i]);
    }
#elif COMPILER(GCC_OR_CLANG) && CPU(ARM64) && defined(NDEBUG)
    const LChar* const end = destination + length;
    const uintptr_t memoryAccessSize = 16;

    if (length >= memoryAccessSize) {
        const uintptr_t memoryAccessMask = memoryAccessSize - 1;

        // Vector interleaved unpack, we only store the lower 8 bits.
        const uintptr_t lengthLeft = end - destination;
        const LChar* const simdEnd = destination + (lengthLeft & ~memoryAccessMask);
        do {
            asm("ld2   { v0.16B, v1.16B }, [%[SOURCE]], #32\n\t"
                "st1   { v0.16B }, [%[DESTINATION]], #16\n\t"
                : [SOURCE]"+r" (source), [DESTINATION]"+r" (destination)
                :
                : "memory", "v0", "v1");
        } while (destination != simdEnd);
    }

    while (destination != end)
        *destination++ = static_cast<LChar>(*source++);
#elif COMPILER(GCC_OR_CLANG) && CPU(ARM_NEON) && !(CPU(BIG_ENDIAN) || CPU(MIDDLE_ENDIAN)) && defined(NDEBUG)
    const LChar* const end = destination + length;
    const uintptr_t memoryAccessSize = 8;

    if (length >= (2 * memoryAccessSize) - 1) {
        // Prefix: align dst on 64 bits.
        const uintptr_t memoryAccessMask = memoryAccessSize - 1;
        while (!isAlignedTo<memoryAccessMask>(destination))
            *destination++ = static_cast<LChar>(*source++);

        // Vector interleaved unpack, we only store the lower 8 bits.
        const uintptr_t lengthLeft = end - destination;
        const LChar* const simdEnd = end - (lengthLeft % memoryAccessSize);
        do {
            asm("vld2.8   { d0-d1 }, [%[SOURCE]] !\n\t"
                "vst1.8   { d0 }, [%[DESTINATION],:64] !\n\t"
                : [SOURCE]"+r" (source), [DESTINATION]"+r" (destination)
                :
                : "memory", "d0", "d1");
        } while (destination != simdEnd);
    }

    while (destination != end)
        *destination++ = static_cast<LChar>(*source++);
#elif CPU(PPC) || CPU(PPC64)
    const uintptr_t memoryAccessSize = 16; // Memory accesses on 16 byte (128 bit) alignment
    const uintptr_t memoryAccessMask = memoryAccessSize - 1;

    size_t alignLen = std::min(length, (size_t)(-(intptr_t)destination & memoryAccessMask) / sizeof(LChar));

    size_t i = 0;
    if (length >= alignLen && length - alignLen > 31) {
        for (;i < alignLen; i++) {
            ASSERT(!(source[i] & 0xff00));
            destination[i] = static_cast<LChar>(source[i]);
        }

        const uintptr_t sourceLoadSize = 64; // Process 64 bytes (32 UChars) each iteration
        const unsigned ucharsPerLoop = sourceLoadSize / sizeof(UChar);

        // maxIndex can underflow if length < 33!!!
        uint32_t maxIndex = length - (ucharsPerLoop + 1);

        // check for underflow
        if (maxIndex <= length && i < maxIndex) {
            const UChar *ourSource = &source[i];
            LChar *ourDest = &destination[i];
            register __vector unsigned char packed1, packed2;
            register __vector unsigned short source1, source2, source3, source4;
            if (((uintptr_t)ourSource & memoryAccessMask) == 0) {
                // Walk 64 bytes (four VMX registers) at a time.
                while (1) {
#ifndef NDEBUG
                    for (unsigned checkIndex = 0; checkIndex < ucharsPerLoop; checkIndex++)
                        ASSERT(!(ourSource[checkIndex] & 0xff00));
#endif
                    source1 = vec_ldl(0, (const unsigned short *)ourSource);
                    source2 = vec_ldl(16, (const unsigned short *)ourSource);
                    source3 = vec_ldl(32, (const unsigned short *)ourSource);
                    source4 = vec_ldl(48, (const unsigned short *)ourSource);
                    packed1 = vec_packsu(source1, source2);
                    packed2 = vec_packsu(source3, source4);
                    vec_st(packed1, 0, (unsigned char *)ourDest);
                    vec_st(packed2, 16, (unsigned char *)ourDest);
                    i += ucharsPerLoop;
                    if(i > maxIndex)
                        break;
                    ourDest += ucharsPerLoop;
                    ourSource += ucharsPerLoop;
                }
            } else {
                register __vector unsigned char mask = vec_lvsl(0, (const unsigned short *)ourSource);
                register __vector unsigned short vector1  = vec_ldl(0, (const unsigned short *)ourSource);
                register __vector unsigned short vector2;
                // Walk 64 bytes (four VMX registers) at a time.
                while (1) {
#ifndef NDEBUG
                    for (unsigned checkIndex = 0; checkIndex < ucharsPerLoop; checkIndex++)
                        ASSERT(!(ourSource[checkIndex] & 0xff00));
#endif
                    // Safe to use with aligned and unaligned addresses
                    #define LoadUnaligned(return, index, target, MSQ, LSQ, mask) \
                    { \
                        LSQ = vec_ldl(index + 15, target); \
                        return = vec_perm(MSQ, LSQ, mask); \
                    }
                    LoadUnaligned(source1, 0, (const unsigned short *)ourSource, vector1, vector2, mask);
                    LoadUnaligned(source2, 16, (const unsigned short *)ourSource, vector2, vector1, mask);
                    LoadUnaligned(source3, 32, (const unsigned short *)ourSource, vector1, vector2, mask);
                    LoadUnaligned(source4, 48, (const unsigned short *)ourSource, vector2, vector1, mask);
                    packed1 = vec_packsu(source1, source2);
                    packed2 = vec_packsu(source3, source4);
                    vec_st(packed1, 0, (unsigned char *)ourDest);
                    vec_st(packed2, 16, (unsigned char *)ourDest);
                    i += ucharsPerLoop;
                    if(i > maxIndex)
                        break;
                    ourDest += ucharsPerLoop;
                    ourSource += ucharsPerLoop;
                }
            }
        }
    }

    for (; i < length; ++i) {
        ASSERT(!(source[i] & 0xff00));
        destination[i] = static_cast<LChar>(source[i]);
    }
#else
    for (size_t i = 0; i < length; ++i) {
        ASSERT(!(source[i] & 0xff00));
        destination[i] = static_cast<LChar>(source[i]);
    }
#endif
}

} // namespace WTF

#endif // ASCIIFastPath_h
