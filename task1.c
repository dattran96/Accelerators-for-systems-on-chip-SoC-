#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>

#define IP_BASE_ADDRESS 0x00A0000000
#define PAGE_SIZE (sysconf(_SC_PAGESIZE))

int main (int argc, char *argv[]){
        void *mapped_region;
        int memoryFileDescriptor = open("/dev/mem", O_RDWR | O_SYNC);
                if(memoryFileDescriptor == -1){
                        printf("Can't open /dev/mem. %d\n ",  memoryFileDescriptor);
                        exit(0);
                }

        mapped_region = mmap(NULL, PAGE_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, memoryFileDescriptor, IP_BASE_ADDRESS);

        //Write to the first register
        *((volatile int *)(mapped_region)) = 1;

        printf("Read back value 0: %d \n", *((volatile int *)(mapped_region)));

        //Write to the second register
        *((volatile int *)(mapped_region + 4)) = 2;

        printf("Read back value 4: %d \n", *((volatile int *)(mapped_region + 4)));

        //Write to the third register
        *((volatile int *)(mapped_region + 8)) = 3;
        
        printf("Read back value 8: %d \n", *((volatile int *)(mapped_region + 8)));

        //Write to the fourth register
        *((volatile int *)(mapped_region + 12)) = 4;

        printf("Read back value 12: %d \n", *((volatile int *)(mapped_region + 12)));

        printf("Pointer: %p \n",mapped_region);

}
