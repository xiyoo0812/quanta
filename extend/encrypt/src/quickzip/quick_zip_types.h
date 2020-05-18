/*
 * quick_zip_types.h
 *
 *  Created on: May 17, 2016
 *      Author: janne
 */

#ifndef INC_QUICK_ZIP_TYPES_H_
#define INC_QUICK_ZIP_TYPES_H_

#include <map>
#include <vector>
#include <string>

struct HuffmanNode
{
	char c;
	std::string code;
	uint32_t frequency;
	HuffmanNode* left = nullptr;
	HuffmanNode* right = nullptr;
};

typedef std::vector<HuffmanNode*> HuffmanVectorT;

#endif /* INC_QUICK_ZIP_TYPES_H_ */
