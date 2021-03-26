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
#include <chrono>
#include <ctime> 


using namespace cimg_library;
using namespace std;
#define BASE_ADDRESS 0x2000000000
#define PAGE_SIZE 4096


int main() { 
	CImg<unsigned char> image("saigon_gray.png");
	int kernel_size = 7;
	unsigned char*ptr = image.data(0,0);
	int length = image.width(); 
	int width = image.height(); 
	unsigned char sobel_img[length*width];
	int fd;
	char option;

	fd = open("/dev/my_device",O_RDWR);
	if(fd < 0){
		printf("Unable to open device file...\n");
		return -1;
	}
	
	std::chrono::time_point<std::chrono::system_clock> start_time, end_time; 
	volatile unsigned long int * mapped_region;
	int memDescriptor = open("/dev/mem",O_RDWR | O_SYNC);
	mapped_region = (volatile unsigned long int*) mmap(NULL, PAGE_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, memDescriptor, BASE_ADDRESS);	
	
   
	
	while(1){
		printf("***Enter option***\n");
		printf("1.Set kernel size \n");
		printf("2.Write gray image and read back sobel image \n");
		scanf(" %c", &option);
		printf("you choose option = %c\n",option);	
	
	switch(option){	
		
		case '1':
			int x;
			cout << "Enter desired kernel size ( 3 or 5 or 7):";
			cin >> x;
			*(mapped_region+6) = x;
			*(mapped_region+4) = length;
			*(mapped_region+5) = width;							
			printf("length,width: %d,%d \n",*(mapped_region+4),*(mapped_region+5));			
			printf("kernel size %d \n", *(mapped_region+6));		
			break;
		case '2':
		{
			start_time = std::chrono::system_clock::now();
			pwrite(fd,ptr,width*length,0);
			while (*(mapped_region+3) != 1);
 			pread(fd,sobel_img,(width-7+1)*(length-7+1),0);
	    	end_time = std::chrono::system_clock::now();
			std::chrono::duration<double> elapsed_seconds = end_time - start_time;
			std::time_t end_point = std::chrono::system_clock::to_time_t(end_time);    
			std::cout << "finished sobel at " << std::ctime(&end_point) << "elapsed time: " << elapsed_seconds.count() << "s\n"; 
			
			CImg<unsigned char> gotback_image(sobel_img,length-7+1,width-7+1,1,1,true);
			gotback_image.save("saigon_sobel.png");
			close(fd);
			exit(1);
			break;
		}
	}
	}

	return 0;
}
