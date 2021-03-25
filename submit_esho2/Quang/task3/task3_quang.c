#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<sys/types.h>
#include<sys/stat.h>
#include<fcntl.h>
#include<unistd.h>

int main() {
	unsigned long int operand[2] = {1587, 956};
	unsigned long int result; 
	int fd = open("/dev/my_character_device",O_RDWR);
	if(fd < 0){
		printf("Cannot open device file...\n");
		return -1;
	}	

	printf("First operand is: %d \n", operand[0]);
	printf("Second operand is: %d \n", operand[1]);
	
	pwrite(fd, operand, 16, 0);
	pread(fd, &result, 8,0);

	printf("Result is %d \n", result);
	return 0;
}
