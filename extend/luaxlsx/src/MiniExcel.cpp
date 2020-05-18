#include "MiniExcel.h"

#include <stdio.h>
#include <math.h>
#include <string>
#include <vector>
#include <map>

#ifndef PATH_MAX
#define PATH_MAX 260
#endif

namespace MiniExcel {

bool isDateFormat(std::string x) {
    for (size_t i = 0; i < x.size(); ++i) {
        switch (x[i]) {
        case 'd':
        case 'D':
        case 'm': // 'mm' for minutes
        case 'M':
        case 'y':
        case 'Y':
        case 'h': // 'hh'
        case 'H':
        case 's': // 'ss'
        case 'S':
            return true;
        default:
            break;
        }
    }
    return false;
}

bool isDateTime(int id, const std::set<int> custom) {
    if ((id >= 14 && id <= 22) ||
        (id >= 27 && id <= 36) ||
        (id >= 45 && id <= 47) ||
        (id >= 50 && id <= 58) ||
        (id >= 71 && id <= 81))
        return true;
    if (id < 164)
        return false;
    return custom.count(id) > 0;
}

struct ZipEntryInfo
{
    unz_file_pos pos;
    uLong uncompressed_size;
};

class Zip
{
public:
    ~Zip();

    bool open(const char* file);
    bool openXML(const char* filename, tinyxml2::XMLDocument& doc);

private:
    unsigned char* getFileData(const char* filename, unsigned long& size);
    std::map<std::string, ZipEntryInfo> _files;
    unzFile _zipFile;
};

Zip::~Zip()
{
    unzClose(_zipFile);
}

bool Zip::open(const char* file)
{
    _zipFile = unzOpen(file);

    if (!_zipFile)
        return false;

    char szCurrentFileName[PATH_MAX];
    unz_file_info64 fileInfo;

    int err = unzGoToNextFile2(_zipFile, &fileInfo,
        szCurrentFileName, sizeof(szCurrentFileName) - 1, nullptr, 0, nullptr, 0);
    while (err == UNZ_OK)
    {
        unz_file_pos posInfo;
        if (unzGetFilePos(_zipFile, &posInfo) == UNZ_OK)
        {
            std::string currentFileName = szCurrentFileName;

            ZipEntryInfo entry;
            entry.pos = posInfo;
            entry.uncompressed_size = (uLong)fileInfo.uncompressed_size;
            _files[currentFileName] = entry;
        }
        err = unzGoToNextFile2(_zipFile, &fileInfo,
            szCurrentFileName, sizeof(szCurrentFileName) - 1, nullptr, 0, nullptr, 0);
    }

    return true;
}

unsigned char* Zip::getFileData(const char* filename, unsigned long& size)
{
    unsigned char * pBuffer = NULL;

    auto it = _files.find(filename);

    if (it == _files.end()) return NULL;

    ZipEntryInfo fileInfo = it->second;

    int nRet = unzGoToFilePos(_zipFile, &fileInfo.pos);
    if (UNZ_OK != nRet) return NULL;

    nRet = unzOpenCurrentFile(_zipFile);
    if (UNZ_OK != nRet) return NULL;

    pBuffer = new unsigned char[fileInfo.uncompressed_size];
    unzReadCurrentFile(_zipFile, pBuffer, fileInfo.uncompressed_size);

    size = fileInfo.uncompressed_size;
    unzCloseCurrentFile(_zipFile);

    return pBuffer;
}

bool Zip::openXML(const char* filename, tinyxml2::XMLDocument& doc)
{
    unsigned long size = 0;
    unsigned char* data = getFileData(filename, size);

    if (!data) return false;

    doc.Parse((const char*)data, size);

    if (data)
        delete[] data;

    return true;
}


Sheet::~Sheet()
{
    for (unsigned i = 0; i < _cells.size(); i++)
    {
        delete _cells[i];
    }
}

Cell* Sheet::getCell(int row, int col)
{
    if (row < _dimension.firstRow || row > _dimension.lastRow)
        return nullptr;
    if (col < _dimension.firstCol || col > _dimension.lastCol)
        return nullptr;

    return _cells[toIndex(row, col)];
}


int Sheet::toIndex(int row, int col)
{
    return (row - 1) * (_dimension.lastCol - _dimension.firstCol + 1) + (col- _dimension.firstCol);
}

void ExcelFile::readWorkBook(const char* filename)
{
    tinyxml2::XMLDocument doc;

    _zip->openXML(filename, doc);

    tinyxml2::XMLElement* e;
    e = doc.FirstChildElement("workbook");
    e = e->FirstChildElement("sheets");
    e = e->FirstChildElement("sheet");

    while (e)
    {
        Sheet s;

        s._name = e->Attribute("name");
        s._rid = e->Attribute("r:id");
        s._sheetId = e->IntAttribute("sheetId");
        s._visible = (e->Attribute("state") && !strcmp(e->Attribute("state"), "hidden"));

        e = e->NextSiblingElement("sheet");

        _sheets.push_back(s);
    }
}

void ExcelFile::readWorkBookRels(const char* filename)
{
    tinyxml2::XMLDocument doc;

    _zip->openXML(filename, doc);
    tinyxml2::XMLElement* e = doc.FirstChildElement("Relationships");
    e = e->FirstChildElement("Relationship");

    while (e)
    {
        const char* rid = e->Attribute("Id");

        for (Sheet& sheet : _sheets)
        {
            if (sheet._rid == rid)
            {
                sheet._path = "xl/" + std::string(e->Attribute("Target"));
                
                break;
            }
        }

        e = e->NextSiblingElement("Relationship");
    }
}

void ExcelFile::readSharedStrings(const char* filename)
{
    tinyxml2::XMLDocument doc;

    if (!_zip->openXML(filename, doc)) return;

    tinyxml2::XMLElement* e;

    e = doc.FirstChildElement("sst");
    e = e->FirstChildElement("si");

    tinyxml2::XMLElement *t, *r;
    int i = 0;

    while (e)
    {
        t = e->FirstChildElement("t");
        i++;
        if (t)
        {
            const char* text = t->GetText();
            _sharedString.push_back(text ? text : "");
        }
        else
        {
            r = e->FirstChildElement("r");
            std::string value;
            while (r)
            {
                t = r->FirstChildElement("t");
                value += t->GetText();
                r = r->NextSiblingElement("r");
            }
            _sharedString.push_back(value);
        }
        e = e->NextSiblingElement("si");
    }
}

void ExcelFile::readStyles(const char* filename)
{
    tinyxml2::XMLDocument doc;
    if (!_zip->openXML(filename, doc)) return;

    tinyxml2::XMLElement *styleSheet = doc.FirstChildElement("styleSheet");
    if (styleSheet == NULL) return;

    std::set<int> customDateFormats;
    tinyxml2::XMLElement *numFmts = styleSheet->FirstChildElement("numFmts");
    if (numFmts == NULL) return;

    for (tinyxml2::XMLElement *numFmt = numFmts->FirstChildElement(); numFmt; numFmt = numFmt->NextSiblingElement())
    {
        int id = atoi(numFmt->Attribute("numFmtId"));
        if (isDateFormat(std::string(numFmt->Attribute("formatCode"))))
        {
            customDateFormats.insert(id);
        }
    }

    tinyxml2::XMLElement *cellXfs = styleSheet->FirstChildElement("cellXfs");
    if (cellXfs == NULL) return;

    int i = 0;
    for (tinyxml2::XMLElement *cellXf = cellXfs->FirstChildElement(); cellXf; cellXf = cellXf->NextSiblingElement())
    {
        const char *fi = cellXf->Attribute("numFmtId");
        if (fi)
        {
            int formatId = atoi(fi);
            if (isDateTime(formatId, customDateFormats))
                _dateFormats.insert(i);
        }
        ++i;
    }
}

void ExcelFile::parseCell(const std::string& value, int& row, int& col)
{
    int index = 0;
    col = 0;

    int arr[10];

    while (index < (int)value.length())
    {
        if (isdigit(value[index])) break;
        arr[index] = value[index] - 'A' + 1;
        index++;
    }

    for (int i = 0; i < index; i++)
    {
        col += (int)(arr[i] * pow(26, index - i - 1));
    }

    row = atoi(value.c_str() + index);
}

void ExcelFile::parseRange(const std::string& value, Range& range)
{
    int index = value.find_first_of(':');

    if (index != -1)
    {
        parseCell(value.substr(0, index), range.firstRow, range.firstCol);
        parseCell(value.substr(index+1), range.lastRow, range.lastCol);
    }
    else
    {
        parseCell(value, range.firstRow, range.firstCol);
        range.lastCol = range.firstCol;
        range.lastRow = range.firstRow;
    }
}

void ExcelFile::readCell(Cell* c, const char* t, const char* s, tinyxml2::XMLElement* v)
{
    if (!t && !v) 
    {
        c->type = "blank";
        return;
    }
    if ((!t || !strcmp(t, "n")) && v) 
    {
        if (s && _dateFormats.count(atoi(s)) > 0)
        {
            c->type = "date";
            //25569 => 1970.1.1 0:0:0
            char temp_value[256];
            sprintf(temp_value, "%.0f", 86400 * (atof(v->GetText()) - 25569) - 28800);
            c->value = temp_value;
        }
        else 
        {
            c->type = "number";
            c->value = v->GetText();
        }
        return;
    }
    if (t && !strcmp(t, "s")) 
    {
        c->type = "string";
        c->value = _sharedString[atoi(v->GetText())];
        return;
    }
    if (t && !strcmp(t, "inlineStr")) 
    {
        c->type = "string";
        c->value = v->GetText();
        return;
    }
    if (t && !strcmp(t, "str"))
    {
        c->type = "string";
        c->value = v->GetText();
        return;
    }
    if (t && !strcmp(t, "b"))
    {
        c->type = "bool";
        c->value = v->GetText();
        return;
    }
    c->type = "error";
}

void ExcelFile::readSheet(Sheet& sh)
{
    tinyxml2::XMLDocument doc;
    tinyxml2::XMLElement *root, *row, *c, *v, *d;

    _zip->openXML(sh._path.c_str(), doc);

    root = doc.FirstChildElement("worksheet");
        
    d = root->FirstChildElement("dimension");
    if (d)
        parseRange(d->Attribute("ref"), sh._dimension);

    row = root->FirstChildElement("sheetData");
    row = row->FirstChildElement("row");

    int vecsize = sh._dimension.lastCol * sh._dimension.lastRow;

    sh._cells.resize(vecsize);


    while (row)
    {
        int rowIdx = row->IntAttribute("r");
        c = row->FirstChildElement("c");

        while (c)
        {
            int colIdx = 0;
            parseCell(c->Attribute("r"), rowIdx, colIdx);
            int index = sh.toIndex(rowIdx, colIdx);
            
            v = c->FirstChildElement("v");
            const char *t = c->Attribute("t");
            const char *s = c->Attribute("s");

            Cell* cell = new Cell;
            readCell(cell, t, s, v);
            sh._cells[index] = cell;
            c = c->NextSiblingElement("c");
        }

        row = row->NextSiblingElement("row");
    }
}

ExcelFile::~ExcelFile()
{
    if (_zip) delete _zip;
}

bool ExcelFile::open(const char* filename)
{
    _zip = new Zip();

    if (!_zip->open(filename))
        return false;

    readWorkBook("xl/workbook.xml");
    readWorkBookRels("xl/_rels/workbook.xml.rels");
    readSharedStrings("xl/sharedStrings.xml");
    readStyles("xl/styles.xml");

    for (auto& s : _sheets)
    {
        readSheet(s);
    }

    return true;
}


Sheet* ExcelFile::getSheet(const char* name)
{
    for (Sheet& sh : _sheets)
    {
        if (sh._name == name)
            return &sh;
    }

    return nullptr;
}

}