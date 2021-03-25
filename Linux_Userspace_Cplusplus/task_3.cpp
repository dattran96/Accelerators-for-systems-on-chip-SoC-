#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<sys/types.h>
#include<sys/stat.h>
#include<fcntl.h>
#include<unistd.h>
#include <iostream>

using namespace std;
int main() {
	uint64_t [2] operand {1587, 956};
	uint64_t result; 
	fd = open("/dev/my_device",O_RDWR);
	if(fd < 0){
		printf("Cannot open device file...\n");
		return -1;
	}	

	printf("First operand is: %d \n", operand_1);
	printf("Second operand is: %d \n", operand_2);
	
	pwrite(fd, operand, 16, 0);
	pread(fd, &result, 8,0);

	printf("Result is %d \n", result);
	return 0;
}

