#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <unistd.h>



struct Change {
	int position;
	char origVal;
	char newVal;
};

struct Change changes[] = {
	{0xc8, 0x40, 0x60},
	{0xc7, 0x00, 0x02},
	{0xc6, 0xf2, 0x2f},

	{0xcf, 0x0d, 0x01},

	{0x1a9, 0x60, 0x60},
	{0x1a8, 0x02, 0x02},
	{0x1a7, 0x47, 0x2e},
};



int ChangeCmp(const void* change1, const void* change2) {
	if (((struct Change*)change1)->position < ((struct Change*)change2)->position) {
		return -1;
	} else 	if (((struct Change*)change1)->position == ((struct Change*)change2)->position) {
		return 0;
	} else {
		return 1;
	}
}


int FileSize(FILE* file) {
	assert(file != NULL);

	int backupPos = ftell(file);

	fseek(file, 0, SEEK_END);
	int res = ftell(file);
	fseek(file, backupPos, SEEK_SET);

	return res;
}


void PrintStringTimes(int count, char str[]) {
	for(int i = 0; i < count; ++i) {
		printf("%s", str);
	}
}


void GetCrackFName(char origFName[], char res[], int bufSize) {
	assert(origFName != NULL);

	const char postfix[] = "_cracked";
	assert(strlen(origFName) + sizeof(postfix) <= bufSize);

	char* dot = strchr(origFName, '.');
	if (dot == NULL) {
		dot = &origFName[strlen(origFName)];
	}
	int origFNameLen = dot - origFName;

	strncpy(res, origFName, origFNameLen);
	sprintf(res + origFNameLen, "%s%s", postfix, dot);

	assert(strlen(res) == strlen(origFName) + sizeof(postfix) - 1);
}


void CrackFile(FILE* origFile, FILE* crackFile) {
	assert(origFile != NULL);
	assert(crackFile != NULL);

	const int progressBarLen = 80;

	int NChanges = sizeof(changes) / sizeof(struct Change);
	qsort(changes, NChanges, sizeof(struct Change), ChangeCmp);
		
	int origFSize = FileSize(origFile);
	char* buf = (char*)calloc(origFSize + 1, sizeof(char));

	int curPos = 0;
	int curChangePos = 0;
	int printWarning = 0;
	int progressStep = progressBarLen / NChanges;

	PrintStringTimes(progressStep * (NChanges + 1), "▒");
	printf("\r");

	for (int i = 0; i <= NChanges; ++i) {

		if (i == NChanges) {
			curChangePos = origFSize;
		} else {
			curChangePos = changes[i].position;
		}
		assert(curPos <= curChangePos);

		if (curChangePos > origFSize) {
			fprintf(stderr, "\nError cracking file, check the input file\n");
			return;
		}
		if (fread(buf, sizeof(char), curChangePos - curPos, origFile) != curChangePos - curPos) {
			fprintf(stderr, "\nError reading original file\n");
			return;
		}
		if(fwrite(buf, sizeof(char), curChangePos - curPos, crackFile) != curChangePos - curPos) {
			fprintf(stderr, "\nError writing cracked file\n");
			return;
		}

		if (i != NChanges) {
			char curCh = fgetc(origFile);
			if (curCh != changes[i].origVal) {
				printWarning = 1;
			}
			fputc(changes[i].newVal, crackFile);
		}

		curPos = curChangePos + 1;

		PrintStringTimes(progressStep, "█");
		fflush(stdout);
		usleep(500000);
	}
	printf("\n");

	if (printWarning) {
		printf("Warning! Input file is not the required program!\n"
		       "An attempt to crack the file will still be made but it will probably not work.\n");
	}

	free(buf);
}


int main() {
	char crackFName[150] = "";
	char origFName[100] = "";
	const char imageBuf[] = "\n\
  ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────┐\n\
  │ ███╗   ███╗ ██╗   ██╗ ██████╗  ███╗   ███╗ ██╗   ██╗ ██████╗   ██████╗ ██████╗   █████╗   ██████╗ ██╗  ██╗ │\n\
  │ ████╗ ████║ ██║   ██║ ██╔══██╗ ████╗ ████║ ██║   ██║ ██╔══██╗ ██╔════╝ ██╔══██╗ ██╔══██╗ ██╔════╝ ██║ ██╔╝ │\n\
  │ ██╔████╔██║ ██║   ██║ ██████╔╝ ██╔████╔██║ ██║   ██║ ██████╔╝ ██║      ██████╔╝ ███████║ ██║      █████╔╝  │\n\
  │ ██║╚██╔╝██║ ██║   ██║ ██╔══██╗ ██║╚██╔╝██║ ██║   ██║ ██╔══██╗ ██║      ██╔══██╗ ██╔══██║ ██║      ██╔═██╗  │\n\
  │ ██║ ╚═╝ ██║ ╚██████╔╝ ██║  ██║ ██║ ╚═╝ ██║ ╚██████╔╝ ██║  ██║ ╚██████╗ ██║  ██║ ██║  ██║ ╚██████╗ ██║  ██╗ │\n\
  │ ╚═╝     ╚═╝  ╚═════╝  ╚═╝  ╚═╝ ╚═╝     ╚═╝  ╚═════╝  ╚═╝  ╚═╝  ╚═════╝ ╚═╝  ╚═╝ ╚═╝  ╚═╝  ╚═════╝ ╚═╝  ╚═╝ │\n\
  └────────────────────────────────────────────────────────────────────────────────────────────────────────────┘\n\
  \n";
	printf("%s", imageBuf);
	
	printf("Let's crack a program! Enter file name to crack: ");
	scanf("%99s%*c", origFName);

	FILE* origFile = fopen(origFName, "rb");
	if (origFile == NULL) {
		fprintf(stderr, "Error opening original file\n");
		getchar();
		return 1;
	}

	GetCrackFName(origFName, crackFName, sizeof(crackFName));
	FILE* crackFile = fopen(crackFName, "wb");
	if (crackFile == NULL) {
		fprintf(stderr, "Error creating cracked file\n");
		getchar();
		return 1;
	}

	printf("Cracking...\e[?25l\n");
	CrackFile(origFile, crackFile);
	printf("Cracked successfully\e[?25h\n");

	fclose(origFile);
	fclose(crackFile);
	getchar();
	return 0;
}
