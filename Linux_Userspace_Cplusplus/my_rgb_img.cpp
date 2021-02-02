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
unsigned char Gray_img[786432];
int8_t start_signal;
int8_t finish_polling;
int16_t width = 512;
int16_t height = 512;
int64_t address_1;

int main() { 
	CImg<unsigned char> image("lena.png"), visu(500,400,1,3,0);
	//image.display();
	//CImgDisplay main_disp(image,"Click a point"), draw_disp(visu,"Intensity profile");
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
	cout << "red:" <<(int) r << endl;	
	cout << "green:" << (int)g << endl;
	cout << "blue:"<< (int)b << endl;

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
			//printf("Enter String to write:\n");
			//scanf(" %s",write_buf);
			//printf("data written");
			pwrite(fd,ptr,3*width*height,0);
			printf("DONE...\n");
			break;
		case '2':
		{	printf("Data is reading...\n");
			pread(fd,RGB_img,3*width*height,786432);
			//pread(fd,address_1,8,786432);
			printf("Done...\n\n");
			CImg<unsigned char> gotback_image(RGB_img,512,512,1,3,true);
			gotback_image.save("lena_out.png");
			//gotback_image.display();
			for (int c = 0; c < 786432; c++)
                	{        
				cout << c << "="
                             	<< (int)RGB_img[c] << endl;
                	}

			//printf("Address 1 got back is = %d\n\n",RGB_img[0]);
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

	//const unsigned char red[] = { 255,0,0 }, green[] = { 0,255,0 }, blue[] = { 0,0,255 };
	//image.blur(2.5);
	//CImgDisplay main_disp(image,"Click a point"), draw_disp(visu,"Intensity profile");
	//while (!main_disp.is_closed() && !draw_disp.is_closed()) {
	//	main_disp.wait();
	//	if (main_disp.button() && main_disp.mouse_y()>=0) {
	//	const int y = main_disp.mouse_y();
	//	visu.fill(0).draw_graph(image.get_crop(0,y,0,0,image.width()-1,y,0,0),red,1,1,0,255,0);
	//	visu.draw_graph(image.get_crop(0,y,0,1,image.width()-1,y,0,1),green,1,1,0,255,0);
	//	visu.draw_graph(image.get_crop(0,y,0,2,image.width()-1,y,0,2),blue,1,1,0,255,0).display(draw_disp);
	//	}
	}

	return 0;
}

