#include "CImg.h"
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<sys/types.h>
#include<sys/stat.h>
#include<fcntl.h>
#include<unistd.h>
#include <iostream>

using namespace cimg_library;
using namespace std;
unsigned char RGB_img[786432];
unsigned char Gray_img[262144];
int8_t start_signal;
int8_t finish_polling;
int16_t width = 512;
int16_t height = 512;
int64_t address_1;

int main() { 
	CImg<unsigned char> image("lena.png"), visu(500,400,1,3,0);
	int width = image.width();
	int height = image.height();
	cout << "width" << width << endl;
	cout << "height" << height << endl;
	/*
	for (int r = 0; r < height; r++)
	{	for (int c = 0; c < width; c++)
		{	 cout << "(" << r << "," << c << ") ="
		              << " R" << (int)image(c,r,0,0)
		              << " G" << (int)image(c,r,0,1)
		              << " B" << (int)image(c,r,0,2) << endl;					
		}
	}
	*/

	unsigned char*ptr = image.data(0,0);
	unsigned char r = ptr[0];
	unsigned char g = ptr[0+width*height];
	unsigned char b = ptr[0+2*width*height];

	int fd;
	char option;

	printf("Welcom to demo of character device driver...\n");
	fd = open("/dev/my_device",O_RDWR);
	if(fd < 0){
		printf("Cannot open device file...\n");
		return -1;
	}	

	while(1){
		printf("***Enter option***\n");
		printf("1.Write \n");
		printf("2.Read \n");
		printf("3.Exit \n");
		scanf(" %c", &option);
		printf("your options = %c\n",option);	
	
	switch(option){	
		case '1':
			pwrite(fd,ptr,3*width*height,0);
			printf("DONE...\n");
			break;
		case '2':
		{	printf("Data is reading...\n");
			pread(fd,Gray_img,width*height,786432 + 1024);
			printf("Done...\n\n");
			CImg<unsigned char> gotback_image(Gray_img,512,512,1,1,true);
			gotback_image.save("lena_gray.png");
			for (int c = 0; c < 262144; c++)
                	{        
				cout << c << "="
                             	<< (int)Gray_img[c] << endl;
                	}
			break;
		}
		case '3':
			close(fd);
			exit(1);
			break;
		default:
			printf("Enter valid option = %c\n",option);
			break;
	}
	}

	return 0;
}

