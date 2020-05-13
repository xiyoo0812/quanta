/*
 * quick_zip.h
 *
 *  Created on: 15 maj 2016
 *      Author: janne
 */

#ifndef INC_QUICK_ZIP_H_
#define INC_QUICK_ZIP_H_

#include <cstdint>

struct ByteContainer
{
	uint32_t size;
	char* buffer;
};

/*
 * QuickZip - A byte compression class
 * using Huffman Coding as compression
 * algorithm.
 *
 * Coded bit array format:
 * 0 - 7 bits: Table size
 *
 * 8 - N bits: Table of all char (8 bits) followed by
 * 			   their frequency (32 bits) used to rebuild
 * 			   Huffman Tree at decode
 *
 * N - M bits: Payload/coded bit array
 */

class QuickZip
{
public:
	QuickZip();

	ByteContainer Zip(const char* _bytes, uint32_t _size);

	ByteContainer Unzip(const char* _bytes, uint32_t _size);

protected:

private:
	void SetBitInByte(char* _byteBuffer, uint32_t _bitNo, uint32_t _val);

	char GetBitInByte(const char* _byteBuffer, uint32_t _bitNo);
};



#endif /* INC_QUICK_ZIP_H_ */
