/* dilithium.c
 *
 * Copyright (C) 2006-2023 wolfSSL Inc.
 *
 * This file is part of wolfSSL.
 *
 * wolfSSL is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * wolfSSL is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1335, USA
 */

/* Based on ed448.c and Reworked for Dilithium by Anthony Hu. */

#ifdef HAVE_CONFIG_H
    #include <config.h>
#endif

/* in case user set HAVE_PQC there */
#include <wolfssl/wolfcrypt/settings.h>

#include <wolfssl/wolfcrypt/asn.h>

#if defined(HAVE_PQC) && defined(HAVE_DILITHIUM)

#ifdef HAVE_LIBOQS
#include <oqs/oqs.h>
#endif

#include <wolfssl/wolfcrypt/dilithium.h>
#include <wolfssl/wolfcrypt/error-crypt.h>
#ifdef NO_INLINE
    #include <wolfssl/wolfcrypt/misc.h>
#else
    #define WOLFSSL_MISC_INCLUDED
    #include <wolfcrypt/src/misc.c>
#endif

/* Sign the message using the dilithium private key.
 *
 *  in          [in]      Message to sign.
 *  inLen       [in]      Length of the message in bytes.
 *  out         [in]      Buffer to write signature into.
 *  outLen      [in/out]  On in, size of buffer.
 *                        On out, the length of the signature in bytes.
 *  key         [in]      Dilithium key to use when signing
 *  returns BAD_FUNC_ARG when a parameter is NULL or public key not set,
 *          BUFFER_E when outLen is less than DILITHIUM_LEVEL2_SIG_SIZE,
 *          0 otherwise.
 */
int wc_dilithium_sign_msg(const byte* in, word32 inLen,
                          byte* out, word32 *outLen,
                          dilithium_key* key, WC_RNG* rng)
{
    int ret = 0;

    /* sanity check on arguments */
    if ((in == NULL) || (out == NULL) || (outLen == NULL) || (key == NULL)) {
        return BAD_FUNC_ARG;
    }

#ifdef WOLF_CRYPTO_CB
    #ifndef WOLF_CRYPTO_CB_FIND
    if (key->devId != INVALID_DEVID)
    #endif
    {
        ret = wc_CryptoCb_PqcSign(in, inLen, out, outLen, rng,
                                  WC_PQC_SIG_TYPE_DILITHIUM, key);
        if (ret != CRYPTOCB_UNAVAILABLE)
            return ret;
        /* fall-through when unavailable */
        ret = 0;
    }
#endif

#ifdef HAVE_LIBOQS
    OQS_SIG *oqssig = NULL;
    size_t localOutLen = 0;

    if ((ret == 0) && (!key->prvKeySet)) {
        ret = BAD_FUNC_ARG;
    }

    if (ret == 0) {
        if (key->level == 2) {
            oqssig = OQS_SIG_new(OQS_SIG_alg_dilithium_2);
        }
        else if (key->level == 3) {
            oqssig = OQS_SIG_new(OQS_SIG_alg_dilithium_3);
        }
        else if (key->level == 5) {
            oqssig = OQS_SIG_new(OQS_SIG_alg_dilithium_5);
        }
        else {
            ret = SIG_TYPE_E;
        }
    }

    if ((ret == 0) && (oqssig == NULL)) {
        ret = BUFFER_E;
    }

    /* check and set up out length */
    if (ret == 0) {
        if ((key->level == 2) && (*outLen < DILITHIUM_LEVEL2_SIG_SIZE)) {
            *outLen = DILITHIUM_LEVEL2_SIG_SIZE;
            ret = BUFFER_E;
        }
        else if ((key->level == 3) && (*outLen < DILITHIUM_LEVEL3_SIG_SIZE)) {
            *outLen = DILITHIUM_LEVEL3_SIG_SIZE;
            ret = BUFFER_E;
        }
        else if ((key->level == 5) && (*outLen < DILITHIUM_LEVEL5_SIG_SIZE)) {
            *outLen = DILITHIUM_LEVEL5_SIG_SIZE;
            ret = BUFFER_E;
        }
        localOutLen = *outLen;
    }

    if (ret == 0) {
        ret = wolfSSL_liboqsRngMutexLock(rng);
    }

    if ((ret == 0) &&
        (OQS_SIG_sign(oqssig, out, &localOutLen, in, inLen, key->k)
         == OQS_ERROR)) {
        ret = BAD_FUNC_ARG;
    }

    if (ret == 0) {
        *outLen = (word32)localOutLen;
    }

    wolfSSL_liboqsRngMutexUnlock();

    if (oqssig != NULL) {
        OQS_SIG_free(oqssig);
    }
#else
    ret = NOT_COMPILED_IN;
#endif
    return ret;
}

/* Verify the message using the dilithium public key.
 *
 *  sig         [in]  Signature to verify.
 *  sigLen      [in]  Size of signature in bytes.
 *  msg         [in]  Message to verify.
 *  msgLen      [in]  Length of the message in bytes.
 *  res         [out] *res is set to 1 on successful verification.
 *  key         [in]  Dilithium key to use to verify.
 *  returns BAD_FUNC_ARG when a parameter is NULL or contextLen is zero when and
 *          BUFFER_E when sigLen is less than DILITHIUM_LEVEL2_SIG_SIZE,
 *          0 otherwise.
 */
int wc_dilithium_verify_msg(const byte* sig, word32 sigLen, const byte* msg,
                            word32 msgLen, int* res, dilithium_key* key)
{
    int ret = 0;

    if (key == NULL || sig == NULL || msg == NULL || res == NULL) {
        return BAD_FUNC_ARG;
    }

#ifdef WOLF_CRYPTO_CB
    #ifndef WOLF_CRYPTO_CB_FIND
    if (key->devId != INVALID_DEVID)
    #endif
    {
        ret = wc_CryptoCb_PqcVerify(sig, sigLen, msg, msgLen, res,
                                    WC_PQC_SIG_TYPE_DILITHIUM, key);
        if (ret != CRYPTOCB_UNAVAILABLE)
            return ret;
        /* fall-through when unavailable */
        ret = 0;
    }
#endif

#ifdef HAVE_LIBOQS
    OQS_SIG *oqssig = NULL;

    if ((ret == 0) && (!key->pubKeySet)) {
        ret = BAD_FUNC_ARG;
    }

    if (ret == 0) {
        if (key->level == 2) {
            oqssig = OQS_SIG_new(OQS_SIG_alg_dilithium_2);
        }
        else if (key->level == 3) {
            oqssig = OQS_SIG_new(OQS_SIG_alg_dilithium_3);
        }
        else if (key->level == 5) {
            oqssig = OQS_SIG_new(OQS_SIG_alg_dilithium_5);
        }
        else {
            ret = SIG_TYPE_E;
        }
    }

    if ((ret == 0) && (oqssig == NULL)) {
        ret = BUFFER_E;
    }

    if ((ret == 0) &&
        (OQS_SIG_verify(oqssig, msg, msgLen, sig, sigLen, key->p)
         == OQS_ERROR)) {
         ret = SIG_VERIFY_E;
    }

    if (ret == 0) {
        *res = 1;
    }

    if (oqssig != NULL) {
        OQS_SIG_free(oqssig);
    }
#else
    ret = NOT_COMPILED_IN;
#endif

    return ret;
}

/* Initialize the dilithium private/public key.
 *
 * key  [in]  Dilithium key.
 * returns BAD_FUNC_ARG when key is NULL
 */
int wc_dilithium_init(dilithium_key* key)
{
    return wc_dilithium_init_ex(key, NULL, INVALID_DEVID);
}

/* Initialize the dilithium private/public key.
 *
 * key  [in]  Dilithium key.
 * heap [in]  Heap hint.
 * devId[in]  Device ID.
 * returns BAD_FUNC_ARG when key is NULL
 */
int wc_dilithium_init_ex(dilithium_key* key, void* heap, int devId)
{
    if (key == NULL) {
        return BAD_FUNC_ARG;
    }

    ForceZero(key, sizeof(*key));

#ifdef WOLF_CRYPTO_CB
    key->devCtx = NULL;
    key->devId = devId;
#endif
#ifdef WOLF_PRIVATE_KEY_ID
    key->idLen = 0;
    key->labelLen = 0;
#endif

    (void) heap;
    (void) devId;

    return 0;
}

#ifdef WOLF_PRIVATE_KEY_ID
int wc_dilithium_init_id(dilithium_key* key, const unsigned char* id, int len,
                         void* heap, int devId)
{
    int ret = 0;

    if (key == NULL)
        ret = BAD_FUNC_ARG;
    if (ret == 0 && (len < 0 || len > DILITHIUM_MAX_ID_LEN))
        ret = BUFFER_E;

    if (ret == 0)
        ret = wc_dilithium_init_ex(key, heap, devId);
    if (ret == 0 && id != NULL && len != 0) {
        XMEMCPY(key->id, id, (size_t)len);
        key->idLen = len;
    }

    /* Set the maxiumum level here */
    wc_dilithium_set_level(key, 5);

    return ret;
}

int wc_dilithium_init_label(dilithium_key* key, const char* label, void* heap,
                            int devId)
{
    int ret = 0;
    int labelLen = 0;

    if (key == NULL || label == NULL)
        ret = BAD_FUNC_ARG;
    if (ret == 0) {
        labelLen = (int)XSTRLEN(label);
        if (labelLen == 0 || labelLen > DILITHIUM_MAX_LABEL_LEN)
            ret = BUFFER_E;
    }

    if (ret == 0)
        ret = wc_dilithium_init_ex(key, heap, devId);
    if (ret == 0) {
        XMEMCPY(key->label, label, (size_t)labelLen);
        key->labelLen = labelLen;
    }

    /* Set the maxiumum level here */
    wc_dilithium_set_level(key, 5);

    return ret;
}
#endif

/* Set the level of the dilithium private/public key.
 *
 * key   [out]  Dilithium key.
 * level [in]   Either 2,3 or 5.
 * returns BAD_FUNC_ARG when key is NULL or level is a bad values.
 */
int wc_dilithium_set_level(dilithium_key* key, byte level)
{
    if (key == NULL) {
        return BAD_FUNC_ARG;
    }

    if (level != 2 && level != 3 && level != 5) {
        return BAD_FUNC_ARG;
    }

    key->level = level;
    key->pubKeySet = 0;
    key->prvKeySet = 0;
    return 0;
}

/* Get the level of the dilithium private/public key.
 *
 * key   [in]  Dilithium key.
 * level [out] The level.
 * returns BAD_FUNC_ARG when key is NULL or level has not been set.
 */
int wc_dilithium_get_level(dilithium_key* key, byte* level)
{
    if (key == NULL || level == NULL) {
        return BAD_FUNC_ARG;
    }

    if (key->level != 2 && key->level != 3 && key->level != 5) {
        return BAD_FUNC_ARG;
    }

    *level = key->level;
    return 0;
}

/* Clears the dilithium key data
 *
 * key  [in]  Dilithium key.
 */
void wc_dilithium_free(dilithium_key* key)
{
    if (key != NULL) {
        ForceZero(key, sizeof(*key));
    }
}

/* Export the dilithium public key.
 *
 * key     [in]      Dilithium public key.
 * out     [in]      Array to hold public key.
 * outLen  [in/out]  On in, the number of bytes in array.
 *                   On out, the number bytes put into array.
 * returns BAD_FUNC_ARG when a parameter is NULL,
 *         BUFFER_E when outLen is less than DILITHIUM_LEVEL2_PUB_KEY_SIZE,
 *         0 otherwise.
 */
int wc_dilithium_export_public(dilithium_key* key,
                               byte* out, word32* outLen)
{
    /* sanity check on arguments */
    if ((key == NULL) || (out == NULL) || (outLen == NULL)) {
        return BAD_FUNC_ARG;
    }

    if ((key->level != 1) && (key->level != 5)) {
        return BAD_FUNC_ARG;
    }

    if (!key->pubKeySet) {
        return BAD_FUNC_ARG;
    }

    /* check and set up out length */
    if ((key->level == 2) && (*outLen < DILITHIUM_LEVEL2_PUB_KEY_SIZE)) {
        *outLen = DILITHIUM_LEVEL2_PUB_KEY_SIZE;
        return BUFFER_E;
    }
    else if ((key->level == 3) && (*outLen < DILITHIUM_LEVEL3_PUB_KEY_SIZE)) {
        *outLen = DILITHIUM_LEVEL3_PUB_KEY_SIZE;
        return BUFFER_E;
    }
    else if ((key->level == 5) && (*outLen < DILITHIUM_LEVEL5_PUB_KEY_SIZE)) {
        *outLen = DILITHIUM_LEVEL5_PUB_KEY_SIZE;
        return BUFFER_E;
    }

    if (key->level == 2) {
        *outLen = DILITHIUM_LEVEL2_PUB_KEY_SIZE;
        XMEMCPY(out, key->p, DILITHIUM_LEVEL2_PUB_KEY_SIZE);
    }
    else if (key->level == 3) {
        *outLen = DILITHIUM_LEVEL3_PUB_KEY_SIZE;
        XMEMCPY(out, key->p, DILITHIUM_LEVEL3_PUB_KEY_SIZE);
    }
    else if (key->level == 5) {
        *outLen = DILITHIUM_LEVEL5_PUB_KEY_SIZE;
        XMEMCPY(out, key->p, DILITHIUM_LEVEL5_PUB_KEY_SIZE);
    }

    return 0;
}

/* Import a dilithium public key from a byte array.
 * Public key encoded in big-endian.
 *
 * in      [in]  Array holding public key.
 * inLen   [in]  Number of bytes of data in array.
 * key     [in]  Dilithium public key.
 * returns BAD_FUNC_ARG when a parameter is NULL or key format is not supported,
 *         0 otherwise.
 */
int wc_dilithium_import_public(const byte* in, word32 inLen,
                               dilithium_key* key)
{
    /* sanity check on arguments */
    if ((in == NULL) || (key == NULL)) {
        return BAD_FUNC_ARG;
    }

    if ((key->level != 2) && (key->level != 3) && (key->level != 5)) {
        return BAD_FUNC_ARG;
    }

    if ((key->level == 2) && (inLen != DILITHIUM_LEVEL2_PUB_KEY_SIZE)) {
        return BAD_FUNC_ARG;
    }
    else if ((key->level == 3) && (inLen != DILITHIUM_LEVEL3_PUB_KEY_SIZE)) {
        return BAD_FUNC_ARG;
    }
    else if ((key->level == 5) && (inLen != DILITHIUM_LEVEL5_PUB_KEY_SIZE)) {
        return BAD_FUNC_ARG;
    }

    XMEMCPY(key->p, in, inLen);
    key->pubKeySet = 1;

    return 0;
}

static int parse_private_key(const byte* priv, word32 privSz,
                             byte** out, word32 *outSz,
                             dilithium_key* key) {
    word32 idx = 0;
    int ret = 0;
    int length = 0;

    /* sanity check on arguments */
    if ((priv == NULL) || (key == NULL)) {
        return BAD_FUNC_ARG;
    }

    if ((key->level != 2) && (key->level != 3) && (key->level != 5)) {
        return BAD_FUNC_ARG;
    }

    /* At this point, it is still a PKCS8 private key. */
    if ((ret = ToTraditionalInline(priv, &idx, privSz)) < 0) {
        return ret;
    }

    /* Now it is a octet_string(concat(priv,pub)) */
    if ((ret = GetOctetString(priv, &idx, &length, privSz)) < 0) {
        return ret;
    }

    *out = (byte *)priv + idx;
    *outSz = privSz - idx;

    /* And finally it is concat(priv,pub). Key size check. */
    if ((key->level == 2) && (*outSz != DILITHIUM_LEVEL2_KEY_SIZE +
                                        DILITHIUM_LEVEL2_PUB_KEY_SIZE)) {
        return BAD_FUNC_ARG;
    }
    else if ((key->level == 3) && (*outSz != DILITHIUM_LEVEL3_KEY_SIZE +
                                             DILITHIUM_LEVEL3_PUB_KEY_SIZE)) {
        return BAD_FUNC_ARG;
    }
    else if ((key->level == 5) && (*outSz != DILITHIUM_LEVEL5_KEY_SIZE +
                                             DILITHIUM_LEVEL5_PUB_KEY_SIZE)) {
        return BAD_FUNC_ARG;
    }

    return 0;
}

/* Import a dilithium private key from a byte array.
 *
 * priv    [in]  Array holding private key.
 * privSz  [in]  Number of bytes of data in array.
 * key     [in]  Dilithium private key.
 * returns BAD_FUNC_ARG when a parameter is NULL or privSz is less than
 *         DILITHIUM_LEVEL2_KEY_SIZE,
 *         0 otherwise.
 */
int wc_dilithium_import_private_only(const byte* priv, word32 privSz,
                                     dilithium_key* key)
{
    int ret = 0;
    byte *newPriv = NULL;
    word32 newPrivSz = 0;

    if ((ret = parse_private_key(priv, privSz, &newPriv, &newPrivSz, key))
        != 0) {
         return ret;
    }

    XMEMCPY(key->k, newPriv, newPrivSz);
    key->prvKeySet = 1;

    return 0;
}

/* Import a dilithium private and public keys from byte array(s).
 *
 * priv    [in]  Array holding private key or private+public keys
 * privSz  [in]  Number of bytes of data in private key array.
 * pub     [in]  Array holding public key (or NULL).
 * pubSz   [in]  Number of bytes of data in public key array (or 0).
 * key     [in]  Dilithium private/public key.
 * returns BAD_FUNC_ARG when a required parameter is NULL or an invalid
 *         combination of keys/lengths is supplied, 0 otherwise.
 */
int wc_dilithium_import_private_key(const byte* priv, word32 privSz,
                                    const byte* pub, word32 pubSz,
                                    dilithium_key* key)
{
    int ret = 0;
    byte *newPriv = NULL;
    word32 newPrivSz = 0;

    if ((ret = parse_private_key(priv, privSz, &newPriv, &newPrivSz, key))
        != 0) {
         return ret;
    }

    if (pub == NULL) {
        if (pubSz != 0) {
            return BAD_FUNC_ARG;
        }

        if ((newPrivSz != DILITHIUM_LEVEL2_PRV_KEY_SIZE) &&
            (newPrivSz != DILITHIUM_LEVEL3_PRV_KEY_SIZE) &&
            (newPrivSz != DILITHIUM_LEVEL5_PRV_KEY_SIZE)) {
            return BAD_FUNC_ARG;
        }

        if (key->level == 2) {
            pub = newPriv + DILITHIUM_LEVEL2_KEY_SIZE;
            pubSz = DILITHIUM_LEVEL2_PUB_KEY_SIZE;
        }
        else if (key->level == 3) {
            pub = newPriv + DILITHIUM_LEVEL3_KEY_SIZE;
            pubSz = DILITHIUM_LEVEL3_PUB_KEY_SIZE;
        }
        else if (key->level == 5) {
            pub = newPriv + DILITHIUM_LEVEL5_KEY_SIZE;
            pubSz = DILITHIUM_LEVEL5_PUB_KEY_SIZE;
        }
    }
    else if ((pubSz != DILITHIUM_LEVEL2_PUB_KEY_SIZE) &&
             (pubSz != DILITHIUM_LEVEL3_PUB_KEY_SIZE) &&
             (pubSz != DILITHIUM_LEVEL5_PUB_KEY_SIZE)) {
        return BAD_FUNC_ARG;
    }

    /* import public key */
    ret = wc_dilithium_import_public(pub, pubSz, key);

    if (ret == 0) {
        /* make the private key (priv + pub) */
        XMEMCPY(key->k, newPriv, newPrivSz);
        key->prvKeySet = 1;
    }

    return ret;
}

/* Export the dilithium private key.
 *
 * key     [in]      Dilithium private key.
 * out     [in]      Array to hold private key.
 * outLen  [in/out]  On in, the number of bytes in array.
 *                   On out, the number bytes put into array.
 * returns BAD_FUNC_ARG when a parameter is NULL,
 *         BUFFER_E when outLen is less than DILITHIUM_LEVEL2_KEY_SIZE,
 *         0 otherwise.
 */
int wc_dilithium_export_private_only(dilithium_key* key, byte* out,
    word32* outLen)
{
    /* sanity checks on arguments */
    if ((key == NULL) || (out == NULL) || (outLen == NULL)) {
        return BAD_FUNC_ARG;
    }

    if ((key->level != 2) && (key->level != 3) && (key->level != 5)) {
        return BAD_FUNC_ARG;
    }

    /* check and set up out length */
    if ((key->level == 2) && (*outLen < DILITHIUM_LEVEL2_KEY_SIZE)) {
        *outLen = DILITHIUM_LEVEL2_KEY_SIZE;
        return BUFFER_E;
    }
    else if ((key->level == 3) && (*outLen < DILITHIUM_LEVEL3_KEY_SIZE)) {
        *outLen = DILITHIUM_LEVEL3_KEY_SIZE;
        return BUFFER_E;
    }
    else if ((key->level == 5) && (*outLen < DILITHIUM_LEVEL5_KEY_SIZE)) {
        *outLen = DILITHIUM_LEVEL5_KEY_SIZE;
        return BUFFER_E;
    }

    if (key->level == 2) {
        *outLen = DILITHIUM_LEVEL2_KEY_SIZE;
    }
    else if (key->level == 3) {
        *outLen = DILITHIUM_LEVEL3_KEY_SIZE;
    }
    else if (key->level == 5) {
        *outLen = DILITHIUM_LEVEL5_KEY_SIZE;
    }

    XMEMCPY(out, key->k, *outLen);

    return 0;
}

/* Export the dilithium private and public key.
 *
 * key     [in]      Dilithium private/public key.
 * out     [in]      Array to hold private and public key.
 * outLen  [in/out]  On in, the number of bytes in array.
 *                   On out, the number bytes put into array.
 * returns BAD_FUNC_ARG when a parameter is NULL,
 *         BUFFER_E when outLen is less than DILITHIUM_LEVEL2_PRV_KEY_SIZE,
 *         0 otherwise.
 */
int wc_dilithium_export_private(dilithium_key* key, byte* out, word32* outLen)
{
    /* sanity checks on arguments */
    if ((key == NULL) || (out == NULL) || (outLen == NULL)) {
        return BAD_FUNC_ARG;
    }

    if ((key->level != 2) && (key->level != 3) && (key->level != 5)) {
        return BAD_FUNC_ARG;
    }

    if ((key->level == 2) && (*outLen < DILITHIUM_LEVEL2_PRV_KEY_SIZE)) {
        *outLen = DILITHIUM_LEVEL2_PRV_KEY_SIZE;
        return BUFFER_E;
    }
    else if ((key->level == 3) && (*outLen < DILITHIUM_LEVEL3_PRV_KEY_SIZE)) {
        *outLen = DILITHIUM_LEVEL3_PRV_KEY_SIZE;
        return BUFFER_E;
    }
    else if ((key->level == 5) && (*outLen < DILITHIUM_LEVEL5_PRV_KEY_SIZE)) {
        *outLen = DILITHIUM_LEVEL5_PRV_KEY_SIZE;
        return BUFFER_E;
    }


    if (key->level == 2) {
        *outLen = DILITHIUM_LEVEL2_PRV_KEY_SIZE;
        XMEMCPY(out, key->k, DILITHIUM_LEVEL2_KEY_SIZE);
        XMEMCPY(out + DILITHIUM_LEVEL2_KEY_SIZE, key->p,
                DILITHIUM_LEVEL2_PUB_KEY_SIZE);
    }
    else if (key->level == 3) {
        *outLen = DILITHIUM_LEVEL3_PRV_KEY_SIZE;
        XMEMCPY(out, key->k, DILITHIUM_LEVEL3_KEY_SIZE);
        XMEMCPY(out + DILITHIUM_LEVEL3_KEY_SIZE, key->p,
                DILITHIUM_LEVEL3_PUB_KEY_SIZE);
    }
    else if (key->level == 5) {
        *outLen = DILITHIUM_LEVEL5_PRV_KEY_SIZE;
        XMEMCPY(out, key->k, DILITHIUM_LEVEL5_KEY_SIZE);
        XMEMCPY(out + DILITHIUM_LEVEL5_KEY_SIZE, key->p,
                DILITHIUM_LEVEL5_PUB_KEY_SIZE);
    }

    return 0;
}

/* Export the dilithium private and public key.
 *
 * key     [in]      Dilithium private/public key.
 * priv    [in]      Array to hold private key.
 * privSz  [in/out]  On in, the number of bytes in private key array.
 * pub     [in]      Array to hold  public key.
 * pubSz   [in/out]  On in, the number of bytes in public key array.
 *                   On out, the number bytes put into array.
 * returns BAD_FUNC_ARG when a parameter is NULL,
 *         BUFFER_E when privSz is less than DILITHIUM_LEVEL2_PRV_KEY_SIZE or pubSz is less
 *         than DILITHIUM_LEVEL2_PUB_KEY_SIZE,
 *         0 otherwise.
 */
int wc_dilithium_export_key(dilithium_key* key, byte* priv, word32 *privSz,
                            byte* pub, word32 *pubSz)
{
    int ret = 0;

    /* export private part */
    ret = wc_dilithium_export_private(key, priv, privSz);
    if (ret == 0) {
        /* export public part */
        ret = wc_dilithium_export_public(key, pub, pubSz);
    }

    return ret;
}

/* Check the public key of the dilithium key matches the private key.
 *
 * key     [in]      Dilithium private/public key.
 * returns BAD_FUNC_ARG when key is NULL,
 *         PUBLIC_KEY_E when the public key is not set or doesn't match,
 *         other -ve value on hash failure,
 *         0 otherwise.
 */
int wc_dilithium_check_key(dilithium_key* key)
{
    if (key == NULL) {
        return BAD_FUNC_ARG;
    }

    int ret = 0;

    /* The public key is also decoded and stored within the private key buffer
     * behind the private key. Hence, we can compare both stored public keys. */
    if (key->level == 2) {
        ret = XMEMCMP(key->p, key->k + DILITHIUM_LEVEL2_KEY_SIZE,
                      DILITHIUM_LEVEL2_PUB_KEY_SIZE);
    }
    else if (key->level == 3) {
        ret = XMEMCMP(key->p, key->k + DILITHIUM_LEVEL3_KEY_SIZE,
                      DILITHIUM_LEVEL3_PUB_KEY_SIZE);
    }
    else if (key->level == 5) {
        ret = XMEMCMP(key->p, key->k + DILITHIUM_LEVEL5_KEY_SIZE,
                      DILITHIUM_LEVEL5_PUB_KEY_SIZE);
    }

    if (ret != 0) {
        ret = PUBLIC_KEY_E;
    }

    return ret;

}

/* Returns the size of a dilithium private key.
 *
 * key     [in]      Dilithium private/public key.
 * returns BAD_FUNC_ARG when key is NULL,
 *         DILITHIUM_LEVEL2_KEY_SIZE otherwise.
 */
int wc_dilithium_size(dilithium_key* key)
{
    if (key == NULL) {
        return BAD_FUNC_ARG;
    }

    if (key->level == 2) {
        return DILITHIUM_LEVEL2_KEY_SIZE;
    }
    else if (key->level == 3) {
        return DILITHIUM_LEVEL3_KEY_SIZE;
    }
    else if (key->level == 5) {
        return DILITHIUM_LEVEL5_KEY_SIZE;
    }

    return BAD_FUNC_ARG;
}

/* Returns the size of a dilithium private plus public key.
 *
 * key     [in]      Dilithium private/public key.
 * returns BAD_FUNC_ARG when key is NULL,
 *         DILITHIUM_LEVEL2_PRV_KEY_SIZE otherwise.
 */
int wc_dilithium_priv_size(dilithium_key* key)
{
    if (key == NULL) {
        return BAD_FUNC_ARG;
    }

    if (key->level == 2) {
        return DILITHIUM_LEVEL2_PRV_KEY_SIZE;
    }
    else if (key->level == 3) {
        return DILITHIUM_LEVEL3_PRV_KEY_SIZE;
    }
    else if (key->level == 5) {
        return DILITHIUM_LEVEL5_PRV_KEY_SIZE;
    }

    return BAD_FUNC_ARG;
}

/* Returns the size of a dilithium public key.
 *
 * key     [in]      Dilithium private/public key.
 * returns BAD_FUNC_ARG when key is NULL,
 *         DILITHIUM_LEVEL2_PUB_KEY_SIZE otherwise.
 */
int wc_dilithium_pub_size(dilithium_key* key)
{
    if (key == NULL) {
        return BAD_FUNC_ARG;
    }

    if (key->level == 2) {
        return DILITHIUM_LEVEL2_PUB_KEY_SIZE;
    }
    else if (key->level == 3) {
        return DILITHIUM_LEVEL3_PUB_KEY_SIZE;
    }
    else if (key->level == 5) {
        return DILITHIUM_LEVEL5_PUB_KEY_SIZE;
    }

    return BAD_FUNC_ARG;
}

/* Returns the size of a dilithium signature.
 *
 * key     [in]      Dilithium private/public key.
 * returns BAD_FUNC_ARG when key is NULL,
 *         DILITHIUM_LEVEL2_SIG_SIZE otherwise.
 */
int wc_dilithium_sig_size(dilithium_key* key)
{
    if (key == NULL) {
        return BAD_FUNC_ARG;
    }

    if (key->level == 2) {
        return DILITHIUM_LEVEL2_SIG_SIZE;
    }
    else if (key->level == 3) {
        return DILITHIUM_LEVEL3_SIG_SIZE;
    }
    else if (key->level == 5) {
        return DILITHIUM_LEVEL5_SIG_SIZE;
    }

    return BAD_FUNC_ARG;
}

int wc_Dilithium_PrivateKeyDecode(const byte* input, word32* inOutIdx,
                                  dilithium_key* key, word32 inSz)
{
    int ret = 0;
    byte privKey[DILITHIUM_MAX_PRV_KEY_SIZE];
    byte pubKey[DILITHIUM_MAX_PUB_KEY_SIZE];
    word32 privKeyLen = (word32)sizeof(privKey);
    word32 pubKeyLen = (word32)sizeof(pubKey);
    int keytype = 0;

    if (input == NULL || inOutIdx == NULL || key == NULL || inSz == 0) {
        return BAD_FUNC_ARG;
    }

    if (key->level == 2) {
        keytype = DILITHIUM_LEVEL2k;
    }
    else if (key->level == 3) {
        keytype = DILITHIUM_LEVEL3k;
    }
    else if (key->level == 5) {
        keytype = DILITHIUM_LEVEL5k;
    }
    else {
        return BAD_FUNC_ARG;
    }

    ret = DecodeAsymKey(input, inOutIdx, inSz, privKey, &privKeyLen,
                        pubKey, &pubKeyLen, keytype);
    if (ret == 0) {
        if (pubKeyLen == 0) {
            ret = wc_dilithium_import_private_only(input, inSz, key);
        }
        else {
            ret = wc_dilithium_import_private_key(privKey, privKeyLen,
                                               pubKey, pubKeyLen, key);
        }
    }
    return ret;
}

int wc_Dilithium_PublicKeyDecode(const byte* input, word32* inOutIdx,
                                 dilithium_key* key, word32 inSz)
{
    int ret = 0;
    byte pubKey[DILITHIUM_MAX_PUB_KEY_SIZE];
    word32 pubKeyLen = (word32)sizeof(pubKey);
    int keytype = 0;

    if (input == NULL || inOutIdx == NULL || key == NULL || inSz == 0) {
        return BAD_FUNC_ARG;
    }

    ret = wc_dilithium_import_public(input, inSz, key);
    if (ret == 0) {
        return 0;
    }

    if (key->level == 2) {
        keytype = DILITHIUM_LEVEL2k;
    }
    else if (key->level == 3) {
        keytype = DILITHIUM_LEVEL3k;
    }
    else if (key->level == 5) {
        keytype = DILITHIUM_LEVEL5k;
    }
    else {
        return BAD_FUNC_ARG;
    }

    ret = DecodeAsymKeyPublic(input, inOutIdx, inSz, pubKey, &pubKeyLen,
                              keytype);
    if (ret == 0) {
        ret = wc_dilithium_import_public(pubKey, pubKeyLen, key);
    }
    return ret;
}

#ifdef WC_ENABLE_ASYM_KEY_EXPORT
/* Encode the public part of an Dilithium key in DER.
 *
 * Pass NULL for output to get the size of the encoding.
 *
 * @param [in]  key       Dilithium key object.
 * @param [out] output    Buffer to put encoded data in.
 * @param [in]  outLen    Size of buffer in bytes.
 * @param [in]  withAlg   Whether to use SubjectPublicKeyInfo format.
 * @return  Size of encoded data in bytes on success.
 * @return  BAD_FUNC_ARG when key is NULL.
 * @return  MEMORY_E when dynamic memory allocation failed.
 */
int wc_Dilithium_PublicKeyToDer(dilithium_key* key, byte* output, word32 inLen,
                                int withAlg)
{
    int    ret;
    byte   pubKey[DILITHIUM_MAX_PUB_KEY_SIZE];
    word32 pubKeyLen = (word32)sizeof(pubKey);
    int    keytype = 0;

    if (key == NULL || output == NULL) {
        return BAD_FUNC_ARG;
    }

    if (key->level == 2) {
        keytype = DILITHIUM_LEVEL2k;
    }
    else if (key->level == 3) {
        keytype = DILITHIUM_LEVEL3k;
    }
    else if (key->level == 5) {
        keytype = DILITHIUM_LEVEL5k;
    }
    else {
        return BAD_FUNC_ARG;
    }

    ret = wc_dilithium_export_public(key, pubKey, &pubKeyLen);
    if (ret == 0) {
        ret = SetAsymKeyDerPublic(pubKey, pubKeyLen, output, inLen, keytype,
                                  withAlg);
    }

    return ret;
}
#endif

int wc_Dilithium_KeyToDer(dilithium_key* key, byte* output, word32 inLen)
{
    if (key == NULL) {
        return BAD_FUNC_ARG;
    }

    if (key->level == 2) {
        return SetAsymKeyDer(key->k, DILITHIUM_LEVEL2_KEY_SIZE, key->p,
                             DILITHIUM_LEVEL2_KEY_SIZE, output, inLen,
                             DILITHIUM_LEVEL2k);
    }
    else if (key->level == 3) {
        return SetAsymKeyDer(key->k, DILITHIUM_LEVEL3_KEY_SIZE, key->p,
                             DILITHIUM_LEVEL3_KEY_SIZE, output, inLen,
                             DILITHIUM_LEVEL3k);
    }
    else if (key->level == 5) {
        return SetAsymKeyDer(key->k, DILITHIUM_LEVEL5_KEY_SIZE, key->p,
                             DILITHIUM_LEVEL5_KEY_SIZE, output, inLen,
                             DILITHIUM_LEVEL5k);
    }

    return BAD_FUNC_ARG;
}

int wc_Dilithium_PrivateKeyToDer(dilithium_key* key, byte* output, word32 inLen)
{
    if (key == NULL) {
        return BAD_FUNC_ARG;
    }

    if (key->level == 2) {
        return SetAsymKeyDer(key->k, DILITHIUM_LEVEL2_KEY_SIZE, NULL, 0, output,
                             inLen, DILITHIUM_LEVEL2k);
    }
    else if (key->level == 3) {
        return SetAsymKeyDer(key->k, DILITHIUM_LEVEL3_KEY_SIZE, NULL, 0, output,
                             inLen, DILITHIUM_LEVEL3k);
    }
    else if (key->level == 5) {
        return SetAsymKeyDer(key->k, DILITHIUM_LEVEL5_KEY_SIZE, NULL, 0, output,
                             inLen, DILITHIUM_LEVEL5k);
    }

    return BAD_FUNC_ARG;
}
#endif /* HAVE_PQC && HAVE_DILITHIUM */
