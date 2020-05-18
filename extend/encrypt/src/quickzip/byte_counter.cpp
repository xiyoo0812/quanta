/*
 * byte_counter.cpp
 *
 *  Created on: 15 maj 2016
 *      Author: janne
 */

#include "byte_counter.h"

ByteCounter::ByteCounter(const char* _bytes, uint32_t _size)
{
	for(uint32_t i = 0; i < 256; ++i)
	{
		huffmanArray[i].c = i;
		huffmanArray[i].code = "";
		huffmanArray[i].frequency = 0;
		huffmanArray[i].left = nullptr;
		huffmanArray[i].right = nullptr;
	}

	for(uint32_t i = 0; i < _size; ++i)
	{
		uint8_t index(_bytes[i]);

		huffmanArray[index].frequency++;
	}
}

HuffmanVectorT ByteCounter::GetHuffmanNodes()
{
	HuffmanVectorT huffmanVector;

	for(uint32_t i = 0 ; i < 256; ++i)
	{
		if(huffmanArray[i].frequency != 0)
		{
			HuffmanNode* newEntry = new HuffmanNode();
			*newEntry = huffmanArray[i];
			huffmanVector.push_back(newEntry);
		}
	}

	return huffmanVector;
}
