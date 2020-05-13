/*
 * quick_zip.cpp
 *
 *  Created on: 15 maj 2016
 *      Author: janne
 */

#include "quick_zip.h"
#include "byte_counter.h"
#include "huffman_tree.h"
#include <string>
#include <iostream>
#include <stdio.h>
#include <string.h>

QuickZip::QuickZip()
{

}

ByteContainer QuickZip::Zip(const char* _bytes, uint32_t _size)
{
	//printf("Original size: %d\n", _size);

	/*
	 * Get frequencies of the different bytes
	 */
	ByteCounter bc(_bytes, _size);

	/*
	 * Calculate the size needed for all characters
	 */
	uint32_t bitSize = 0;

	bitSize += 16; //For table size

	HuffmanVectorT huffmanVector = bc.GetHuffmanNodes();

	HuffmanVectorT::iterator huffIter = huffmanVector.begin();

	for(; huffIter != huffmanVector.end(); ++huffIter)
	{
		bitSize += 40; //Character 8 bits plus frequency 32 bits
	}

	/*
	 * Construct a Huffman Tree
	 */
	HuffmanTree ht(huffmanVector);

	/*
	 * Get the total size of the coded bit array
	 * by counting the bits needed for each
	 * byte.
	 */

	std::string code;
	for(unsigned int i = 0; i < _size; ++i)
	{
		code.clear();
		ht.FindByteInTree(_bytes[i], code);
		//printf("%c, got code %s\n", _bytes[i], code.c_str());
		bitSize += code.length();
	}

	/*
	 * Byte align the bit size
	 */
	uint32_t byteAlignedBitSize = bitSize;
	while(byteAlignedBitSize % 8 != 0)
	{
		byteAlignedBitSize += 1;
	}
	//printf("Byte aligned bit size: %d\n", byteAlignedBitSize);
	uint32_t byteSize = byteAlignedBitSize / 8;

	/*
	 * Allocate memory and encode the byte to
	 * bit table
	 */
	char* byteBuffer = new char[byteSize];
	memset(byteBuffer, 0x0, byteSize);
	uint32_t byteOffset = 0;

	uint16_t* tableSize = ((uint16_t*)(&byteBuffer[0]));

	*tableSize = huffmanVector.size();

	//printf("Encoded table size: %d\n", *tableSize);

	huffIter = huffmanVector.begin();

	byteOffset += 2;

	for(; huffIter != huffmanVector.end(); ++huffIter)
	{
		byteBuffer[byteOffset] = (*huffIter)->c;
		byteOffset++;
		uint32_t* frequency = (uint32_t*)(&byteBuffer[byteOffset]);
		*frequency = (*huffIter)->frequency;
		byteOffset += sizeof(uint32_t);
		//printf("Encoded %c with frequency: %d\n",  (*huffIter)->c, *frequency);
	}

	/*
	 * Finally encode the byte array to a bit
	 * array as defined by the constructed
	 * Huffman Tree
	 */
	uint32_t bitNo = 0;
	for(unsigned int i = 0; i < _size; ++i)
	{
		code.clear();
		ht.FindByteInTree(_bytes[i], code);

		for(unsigned int n = 0; n < code.length(); ++n)
		{
			if('0' == code.at(n))
			{
				SetBitInByte(&byteBuffer[byteOffset], bitNo, 0);
			}
			else
			{
				SetBitInByte(&byteBuffer[byteOffset], bitNo, 1);
			}
			bitNo++;
			if(bitNo > 7)
			{
				bitNo = 0;
				byteOffset++;
			}
		}
	}

	//printf("Byte size at end of coding: %d\n", byteSize);

	ByteContainer retVal;
	retVal.buffer = byteBuffer;
	retVal.size = byteSize;

	return retVal;
}

ByteContainer QuickZip::Unzip(const char* _bytes, uint32_t _size)
{
	uint32_t startByteOffset = 0;
	uint32_t decodedSize = 0;
	HuffmanTree ht(_bytes, startByteOffset, decodedSize);

	//printf("Decoded size: %d\n", decodedSize);

	/*
	 * Decode bit array bit by bit.
	 */
	char* byteBuffer = new char[decodedSize];
	uint32_t byteOffset = 0;
	std::string code = "";
	for(unsigned int i = startByteOffset; i < _size && byteOffset != decodedSize; ++i)
	{
		for(unsigned int n = 0; n < 8 && byteOffset != decodedSize; ++n)
		{
			char bit = GetBitInByte(&_bytes[i], n);
			code += bit;

			char* c = ht.FindByteInTreeFromBitCode(code);

			if(nullptr != c)
			{
				/*
				 * Provided code gave a match
				 */
				code.clear();
				//printf("Decoded: %c\n", *c);
				byteBuffer[byteOffset] = *c;
				byteOffset++;
			}
		}
	}
	ByteContainer retVal;
	retVal.buffer = byteBuffer;
	retVal.size = decodedSize;

	return retVal;
}

void QuickZip::SetBitInByte(char* _byteBuffer, uint32_t _bitNo, uint32_t _val)
{
	//printf("Setting bit: %d in %p to: %d\n", _bitNo, _byteBuffer, _val);

	uint8_t* intPtr = (uint8_t*)(_byteBuffer);
	*intPtr |= _val << _bitNo;
}

char QuickZip::GetBitInByte(const char* _byteBuffer, uint32_t _bitNo)
{
	uint8_t intToCheck = *((uint8_t*)(_byteBuffer));

	intToCheck = intToCheck & (1 << _bitNo);

	if(intToCheck == 0)
	{
		return '0';
	}

	return '1';
}
