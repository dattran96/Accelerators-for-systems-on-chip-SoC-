#include "CImg.h"
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<sys/types.h>
#include<sys/stat.h>
#include<sys/mman.h>
#include<fcntl.h>
#include<unistd.h>
#include <iostream>
#include <time.h>

using namespace cimg_library;
using namespace std;
#define BASE_ADDRESS 0x2000000000
#define PAGE_SIZE 4096


int8_t start_signal;
int8_t finish_polling;
int64_t address_1;

int main() { 
	CImg<unsigned char> image("saigon_gray.png");
	int length = image.width(); //length
	int width = image.height(); //width
	unsigned char sobel_img[length*width];
	int kernel_size = 7;
	unsigned char*ptr = image.data(0,0);

	int fd;
	char option;

	printf("Welcom to demo of character device driver...\n");
	fd = open("/dev/my_device",O_RDWR);
	if(fd < 0){
		printf("Cannot open device file...\n");
		return -1;
	}

	volatile unsigned long int * mapped_region;
	int memDescriptor = open("/dev/mem",O_RDWR | O_SYNC);
	mapped_region = (volatile unsigned long int*) mmap(NULL, PAGE_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, memDescriptor, BASE_ADDRESS);	
	

	while(1){
		printf("***Enter option***\n");
		printf("0.Set kernel size,image size and query config registers \n");
		printf("1.Write \n");
		printf("2.Read \n");
		printf("4.Exit \n");
		scanf(" %c", &option);
		printf("your options = %c\n",option);	
	
	switch(option){	
		case '1':
			pwrite(fd,ptr,width*length,0);
			printf("DONE...\n");
			break;
		case '2':
		{	printf("Data is reading...\n");
			pread(fd,sobel_img,(width-7+1)*(length-7+1),0);
			printf("Done...\n\n");
			CImg<unsigned char> gotback_image(sobel_img,length-7+1,width-7+1,1,1,true);
			gotback_image.save("lena_sobel.png");
			for (int c = 0; c < (width-7+1)*(length-7+1); c++)
                	{        
				cout << c << "="
                             	<< (int)sobel_img[c] << endl;
                	}
			break;
		}
		case '4':
			close(fd);
			exit(1);
			break;
		case '0':
			int x;
			cout << "Enter desired kernel size ( 3 or 5 or 7):";
			cin >> x;
			*(mapped_region+6) = x;
			*(mapped_region+4) = length;
			*(mapped_region+5) = width;							
			printf("Read back finish flag %d \n", *(mapped_region+3));
			printf("Read back start flag %d \n", *(mapped_region+2));
			printf("Read back length,width: %d,%d \n",*(mapped_region+4),*(mapped_region+5));			
			printf("Read back kernel size %d \n", *(mapped_region+6));		
			break;
		default:
			printf("Enter valid option = %c\n",option);
			break;
	}
	}

	return 0;
}
