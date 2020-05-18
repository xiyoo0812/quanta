/*
 * huffman_tree.cpp
 *
 *  Created on: 15 maj 2016
 *      Author: janne
 */

#include "huffman_tree.h"

HuffmanTree::HuffmanTree(HuffmanVectorT _huffmanVector)
{
	entry = nullptr;

	huffmanNodeStorage = _huffmanVector;

	BuildHuffmanTree(_huffmanVector);

	entry = _huffmanVector[0];
}

HuffmanTree::HuffmanTree(const char* _encodedBuffer, uint32_t& _byteOffset, uint32_t& _decodedSize)
{
	/*
	 * Create Huffman Tree from coded bit array.
	 * Format:
	 * char followed by 32 bit integer with its
	 * frequency in the uncoded source.
	 *
	 * The sum of all frequencies gives the decoded
	 * size.
	 */

	HuffmanVectorT huffmanVector;

	const char* currentByte = _encodedBuffer;
	_byteOffset = 0;

	uint16_t tableSize = *((uint16_t*)(&currentByte[_byteOffset]));

	//printf("Decoded table size: %d\n", tableSize);

	_byteOffset += 2;

	uint16_t handledBytes = 0;

	while(handledBytes < tableSize)
	{
		handledBytes++;

		HuffmanNode* currentNode = new HuffmanNode();
		currentByte = &_encodedBuffer[_byteOffset];
		currentNode->c = *currentByte;
		currentNode->left = nullptr;
		currentNode->right = nullptr;

		_byteOffset++;
		uint32_t* intPtr = (uint32_t*)(&_encodedBuffer[_byteOffset]);
		currentNode->frequency = *intPtr;
		//printf("Decoded: %c with frequency: %d\n", currentNode->c, currentNode->frequency);
		_decodedSize += currentNode->frequency;

		huffmanVector.push_back(currentNode);

		_byteOffset += sizeof(uint32_t);
		currentByte = &_encodedBuffer[_byteOffset];
	}

	huffmanNodeStorage = huffmanVector;

	BuildHuffmanTree(huffmanVector);

	entry = huffmanVector[0];
}

void HuffmanTree::BuildHuffmanTree(HuffmanVectorT& _huffmanVector)
{
	/*
	 * Build the Huffman Tree using the following algorithm:
	 *
	 * Remove the two leaves with the lowest occurance from the
	 * list of leaves.
	 *
	 * "Combine" them under a root node.
	 *
	 * Add the two combined leaves' frequencies to the root node.
	 *
	 * Add the root node to list of leaves.
	 *
	 * Repeat until only one element remains in the list of leaves.
	 * This will be the entry point to the Huffman Tree.
	 */
	while(_huffmanVector.size() > 1)
	{
		HuffmanNode* right = GetLowestWeight(_huffmanVector);
		HuffmanNode* left = GetLowestWeight(_huffmanVector);

		HuffmanNode* rootItem = new HuffmanNode();
		rootItem->frequency = left->frequency + right->frequency;
		rootItem->left = left;
		rootItem->right = right;

		/*printf("left: %c (%d), right: %c (%d)\n", left->c, left->frequency,
												  right->c, right->frequency); */

		_huffmanVector.push_back(rootItem);
		huffmanNodeStorage.push_back(rootItem);
	}
}

HuffmanTree::~HuffmanTree()
{
	for(unsigned int i = 0; i < huffmanNodeStorage.size(); ++i)
	{
		delete huffmanNodeStorage[i];
	}

	huffmanNodeStorage.clear();
}

HuffmanNode* HuffmanTree::FindByteInTree(const char& byte, std::string& code)
{
	return FindByteInTree(byte, entry, code);
}

HuffmanNode* HuffmanTree::FindByteInTree(const char& byte, HuffmanNode* entryPoint, std::string& code)
{
	/*
	 * This function performs a recursive search down through the
	 * Huffman Tree until it finds the byte.
	 *
	 * If nothing is found, it will return an empty string as code
	 * and a nullptr for the HuffmanNode pointer.
	 */

	if(entryPoint == nullptr)
	{
		return nullptr;
	}

	if(entryPoint->left == nullptr && entryPoint->right == nullptr)
	{
		/*
		 * We hit a leaf. Need to check if it contains our searchPattern.
		 */
		if(entryPoint->c == byte)
		{
			return entryPoint;
		}
		else
		{
			return nullptr;
		}
	}
	else
	{
		/*
		 * Continue searching down the tree.
		 */
		std::string tmpString;
		HuffmanNode* retVal = FindByteInTree(byte, entryPoint->left, tmpString);
		if(nullptr != retVal)
		{
			code += "0";
			code += tmpString;
		}
		else
		{
			tmpString.clear();
			retVal = FindByteInTree(byte, entryPoint->right, tmpString);
			if(nullptr != retVal)
			{
				code += "1";
				code += tmpString;
			}
		}
		return retVal;
	}
}

char* HuffmanTree::FindByteInTreeFromBitCode(const std::string& code)
{
	HuffmanNode* node = entry;
	for(unsigned int i = 0; i < code.length(); ++i)
	{
		if('0' == code.at(i))
		{
			node = node->left;
		}
		else
		{
			node = node->right;
		}
	}

	if(node->left != nullptr && node->right != nullptr)
	{
		/*
		 * No match for provided code. Return nullptr
		 */
		return nullptr;
	}

	return &node->c;
}

HuffmanNode* HuffmanTree::GetLowestWeight(HuffmanVectorT& huffmanVector)
{
	/*
	 * Help function for constructing the Huffman Tree.
	 *
	 * It returns the leaf with the lowest frequency
	 * and removes it from the list of leaves.
	 */

	HuffmanNode* retVal = nullptr;
	uint32_t lowestValue = 0xffffffff;

	HuffmanVectorT::iterator huffIter = huffmanVector.begin();
	HuffmanVectorT::iterator smallestEntry = huffmanVector.begin();

	for( ; huffIter != huffmanVector.end(); ++huffIter)
	{
		if(lowestValue > (*huffIter)->frequency)
		{
			lowestValue = (*huffIter)->frequency;
			smallestEntry = huffIter;
		}
	}

	retVal = (*smallestEntry);

	huffmanVector.erase(smallestEntry);

	return retVal;
}
