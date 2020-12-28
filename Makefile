TARGET_MODULE:=dma_for_IPCORE_2

ifneq ($(KERNELRELEASE),)
	#$(TARGET_MODULE)-objs := $(TARGET_MODULE).o
	obj-m:=$(TARGET_MODULE).o	
else	
	BUILDSYSTEM_DIR:=/home/stud/nt92homu/echo2/linux-xlnx
	PWD:=$(shell pwd)
all:
	$(MAKE) -C $(BUILDSYSTEM_DIR) M=$(PWD) modules
clean:
	$(MAKE) -C $(BUILDSYSTEM_DIR) M=$(PWD) clean
endif
