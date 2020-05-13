/*
 * byte_counter.h
 *
 *  Created on: 15 maj 2016
 *      Author: janne
 */

#ifndef INC_BYTE_COUNTER_H_
#define INC_BYTE_COUNTER_H_

#include <cstdint>
#include "quick_zip_types.h"

class ByteCounter
{
public:
	ByteCounter(const char* _bytes, uint32_t _size);

	HuffmanVectorT GetHuffmanNodes();

protected:

private:
	HuffmanNode huffmanArray[256];
};



#endif /* INC_BYTE_COUNTER_H_ */
