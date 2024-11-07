#include "sha_256.h"

#define ROTRIGHT(word,bits) (((word) >> (bits)) | ((word) << (32-(bits))))

#define CH(x,y,z) (((x) & (y)) ^ (~(x) & (z)))
#define MAJ(x,y,z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define EP0(x) (ROTRIGHT(x,2) ^ ROTRIGHT(x,13) ^ ROTRIGHT(x,22))
#define EP1(x) (ROTRIGHT(x,6) ^ ROTRIGHT(x,11) ^ ROTRIGHT(x,25))
#define SIG0(x) (ROTRIGHT(x,7) ^ ROTRIGHT(x,18) ^ ((x) >> 3))
#define SIG1(x) (ROTRIGHT(x,17) ^ ROTRIGHT(x,19) ^ ((x) >> 10))

static const uint32_t K[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

static void sha_256_transform(struct Sha_256* sha, const uint8_t* data) {
    uint32_t a, b, c, d, e, f, g, h, t1, t2, m[64];
    int i, j;

    // Copy data into message schedule
    for (i = 0, j = 0; i < 16; ++i, j += 4) {
        m[i] = ((uint32_t)data[j] << 24) | ((uint32_t)data[j + 1] << 16) |
               ((uint32_t)data[j + 2] << 8) | ((uint32_t)data[j + 3]);
    }
    for (; i < 64; ++i) {
        m[i] = SIG1(m[i - 2]) + m[i - 7] + SIG0(m[i - 15]) + m[i - 16];
    }

    // Initialize working variables
    a = sha->state[0];
    b = sha->state[1];
    c = sha->state[2];
    d = sha->state[3];
    e = sha->state[4];
    f = sha->state[5];
    g = sha->state[6];
    h = sha->state[7];

    // Main loop
    for (i = 0; i < 64; ++i) {
        t1 = h + EP1(e) + CH(e,f,g) + K[i] + m[i];
        t2 = EP0(a) + MAJ(a,b,c);
        h = g;
        g = f;
        f = e;
        e = d + t1;
        d = c;
        c = b;
        b = a;
        a = t1 + t2;
    }

    // Update state
    sha->state[0] += a;
    sha->state[1] += b;
    sha->state[2] += c;
    sha->state[3] += d;
    sha->state[4] += e;
    sha->state[5] += f;
    sha->state[6] += g;
    sha->state[7] += h;
}

void sha_256_init(struct Sha_256* sha, uint8_t hash[32]) {
    sha->curlen = 0;
    sha->length = 0;
    sha->state[0] = 0x6a09e667;
    sha->state[1] = 0xbb67ae85;
    sha->state[2] = 0x3c6ef372;
    sha->state[3] = 0xa54ff53a;
    sha->state[4] = 0x510e527f;
    sha->state[5] = 0x9b05688c;
    sha->state[6] = 0x1f83d9ab;
    sha->state[7] = 0x5be0cd19;
}

void sha_256_write(struct Sha_256* sha, const void* data, size_t length) {
    const uint8_t* in = (const uint8_t*)data;
    uint32_t n;

    while (length > 0) {
        if (sha->curlen == 0 && length >= 64) {
            sha_256_transform(sha, in);
            sha->length += 64 * 8;
            in += 64;
            length -= 64;
        } else {
            n = 64 - sha->curlen;
            if (n > length) {
                n = length;
            }
            memcpy(sha->buffer + sha->curlen, in, n);
            sha->curlen += n;
            in += n;
            length -= n;
            if (sha->curlen == 64) {
                sha_256_transform(sha, sha->buffer);
                sha->length += 64 * 8;
                sha->curlen = 0;
            }
        }
    }
}

void sha_256_close(struct Sha_256* sha) {
    int i;
    uint8_t finalcount[8];

    for (i = 0; i < 8; i++) {
        finalcount[i] = (uint8_t)((sha->length >> ((7 - i) * 8)) & 255);
    }

    sha_256_write(sha, "\x80", 1);
    while (sha->curlen != 56) {
        sha_256_write(sha, "\0", 1);
    }
    sha_256_write(sha, finalcount, 8);

    // Store hash in result pointer
    for (i = 0; i < 8; i++) {
        uint32_t t = sha->state[i];
        uint8_t* out = sha->buffer + (i * 4);
        out[0] = (t >> 24) & 0xff;
        out[1] = (t >> 16) & 0xff;
        out[2] = (t >> 8) & 0xff;
        out[3] = t & 0xff;
    }
}
