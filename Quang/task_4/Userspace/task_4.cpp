#include "CImg.h"
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<sys/types.h>
#include<sys/stat.h>
#include<fcntl.h>
#include<unistd.h>
#include<sys/mman.h>
#include <time.h>
#include <chrono>
#include <ctime>


#include <iostream>
#define IMG_HEIGHT 1243  
#define IMG_WIDTH 2048
using namespace cimg_library;
using namespace std;
unsigned char RGB_img[IMG_HEIGHT*IMG_WIDTH*3];
unsigned char Gray_img[IMG_HEIGHT*IMG_WIDTH];
int8_t start_signal;
int8_t finish_polling;
int64_t address_1;

int main() { 
	CImg<unsigned char> image("saigon.jpg");
	int width = image.width();
	int height = image.height();
	cout << "width " << width << endl;
	cout << "height " << height << endl;

	unsigned char*ptr = image.data(0,0);

	int fd;
	char option;

	fd = open("/dev/my_device",O_RDWR);
	if(fd < 0){
		printf("Cannot open device file...\n");
		return -1;
	}	
	
	volatile unsigned long int * mapped_region;
        int memDescriptor = open("/dev/mem",O_RDWR | O_SYNC);
        mapped_region = (volatile unsigned long int*) mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, memDescriptor, 0x2000000000);

        /*Measure time*/
        std::chrono::time_point<std::chrono::system_clock> start, end;
	
	while(1){
		printf("***Chose your option***\n");
		printf("1.Start conversion \n");
		printf("2.Get back result \n");
		printf("3.Exit program \n");
		scanf(" %c", &option);
		printf("your options = %c\n",option);	
	
	switch(option){	
		case '1':
		{
			printf("Conversion finish before: %d\n", *(mapped_region+3));
			start = std::chrono::system_clock::now();
			pwrite(fd,ptr,3*width*height,0);
            while (*(mapped_region+3) != 1);
			pread(fd,Gray_img,width*height,0);
            end = std::chrono::system_clock::now();
            std::chrono::duration<double> elapsed_seconds = end - start;
            std::time_t end_time = std::chrono::system_clock::to_time_t(end);
			printf("Conversion finish after: %d\n", *(mapped_region+3));
                        std::cout << "Convert time: " << elapsed_seconds.count() << "s\n";
			CImg<unsigned char> gotback_image(Gray_img,width,height,1,1,true);
                        gotback_image.save("saigon_gray.png");
			break;
		}
		case '2':
		{	printf("Data is printing...\n");
			for (int c = 0; c < width*height; c++)
            {        
				cout << c << "=" << (int)Gray_img[c] << endl;
            }
			break;
		}
		case '3':
			close(fd);
			exit(1);
		default:
			break;
	}
	}

	return 0;
}

