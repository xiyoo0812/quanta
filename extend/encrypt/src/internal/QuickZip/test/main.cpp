/*
 * main.cpp
 *
 *  Created on: 15 maj 2016
 *      Author: janne
 */

#include "byte_counter.h"
#include "quick_zip.h"
#include <iostream>
#include <string>
#include <fstream>

#define ASSERT_EQ(_this, _that) \
if(_this != _that) \
{ \
	std::cout<<_this<<" is not "<<_that<<std::endl; \
	return 1; \
}

int main(int argc, char* argv[])
{
	std::string byteArray = "eebbeecdebeeebecceeeddebbbeceedebeeddeeeecceeeedeeedeeebeedeceedebeeedeceeedebee";

	ByteCounter bc(byteArray.c_str(), byteArray.length());

	QuickZip qz;
	ByteContainer zipped = qz.Zip(byteArray.c_str(), byteArray.length());

	ASSERT_EQ(39, zipped.size);

	ByteContainer unzipped = qz.Unzip(zipped.buffer, zipped.size);

	ASSERT_EQ(unzipped.size, byteArray.length());

	for(uint32_t i = 0; i < byteArray.length(); ++i)
	{
	ASSERT_EQ(byteArray.at(i), unzipped.buffer[i])
	}

	delete[] zipped.buffer;
	delete[] unzipped.buffer;

	if(argc == 0)
	{
		return 0;
	}

	std::streampos size;
	std::ifstream stream(argv[1], std::ios::in | std::ios::binary | std::ios::ate);
	size = stream.tellg();

	char* fileBuffer = new char[size];

	stream.seekg (0, std::ios::beg);
	stream.read (fileBuffer, size);
	stream.close();

	uint32_t fileSize = size;

	printf("Got size: %d\n", fileSize);

	ByteContainer zippedFile = qz.Zip(fileBuffer, size);

	printf("zippedFile.size: %d\n", zippedFile.size);

	ByteContainer unzippedFile = qz.Unzip(zippedFile.buffer, zippedFile.size);

	for(uint32_t i = 0; i < byteArray.length(); ++i)
	{
		ASSERT_EQ(fileBuffer[i], unzippedFile.buffer[i])
	}

	delete[] zippedFile.buffer;
	delete[] unzippedFile.buffer;

	return 0;
}
