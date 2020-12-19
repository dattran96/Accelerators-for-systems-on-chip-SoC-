 #include <linux/kernel.h>
//#include <linux/init.h>
#include <linux/module.h>
#include <linux/kdev_t.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/slab.h>
#include <linux/uaccess.h>
#include <linux/io.h>
#include <linux/dma-mapping.h>

#define 1minor_RGBimage_load 1 
#define 2minor_start_convert 2
#define 3minor_polling_finish 3
#define 4minor_Grayimage_read_back 4
#define major_imgProcessing 5

#define mem_size 1572872   //1572864 bytes (for RGB img) + 8 bytes(for 2 registers start and finish_poll) = 1572872
#define IOSTART 0x200
#define IOEXTEND 0x40
//#define base_addr 0x00A0000000
#define base_addr 0x0400000000
static void __iomem *mapped;
static unsigned long iostart = IOSTART,ioextend =IOEXTEND,ioend;

dev_t dev = 0;
static struct class*dev_class;
static struct cdev my_cdev;
uint8_t *driver_mem_pointer;
uint8_t *converted_img;
uint8_t  device_read;
struct device* dev_struct;
dma_addr_t dma_handle;
dma_addr_t dma_handle_2;
dma_addr_t dma_handle_3;
dma_addr_t dma_handle_4;


uint8_t *start_convert;
uint8_t *finish_convert;

static int __init chr_driver_init(void);
static void __exit chr_driver_exit(void);
static int my_open(struct inode*inode, struct file*file);
static int my_release(struct inode*inode,struct file * file);
static ssize_t my_read(struct file*filp, char __user*buf,size_t len,loff_t*off);
static ssize_t my_write(struct file*filp,const char *buf, size_t len,loff_t* off);


static struct file_operations fops = 
{
	.owner = THIS_MODULE,
	.read  = my_read,
	.write = my_write,
	.open  = my_open,
	.release = my_release,
};


////////////////////////////

static int my_open(struct inode*inode,struct file*file)
{
	/*Creating Physical Memory*/
	if ((driver_mem_pointer = kmalloc(mem_size,GFP_KERNEL)) == 0)
	{
		printk(KERN_INFO"Cannot allocate memory to the kernel\n");
		return -1;
	}
	
	
	/*DMA mapping*/
	//dma_handle = dma_map_single(dev_struct,driver_mem_pointer,mem_size,DMA_BIDIRECTIONAL);
	mapped = ioremap(base_addr,256); //for 4 registers 
	
	dma_handle = dma_map_single(dev_struct,driver_mem_pointer,786432,DMA_BIDIRECTIONAL);
	iowrite32((uint32_t)dma_handle,mapped);
	iowrite32((uint32_t)dma_handle >> 32,mapped + 32);
	
	dma_handle_2 = dma_map_single(dev_struct,driver_mem_pointer + 786432,786432,DMA_BIDIRECTIONAL);
	iowrite32((uint32_t)dma_handle_2,mappep + 64);
	iowrite32((uint32_t)dma_handle_2 >> 32,mapped + 96);
	
	dma_handle_3 = dma_map_single(dev_struct,driver_mem_pointer + 1572864,4,DMA_BIDIRECTIONAL);
	iowrite32((uint32_t)dma_handle_3,mappep + 128);
	iowrite32((uint32_t)dma_handle_3 >> 32,mapped + 160);
	
	dma_handle_4 = dma_map_single(dev_struct,driver_mem_pointer + 1572868,4,DMA_BIDIRECTIONAL);
	iowrite32((uint32_t)dma_handle_4,mappep + 192);
	iowrite32((uint32_t)dma_handle_4 >> 32,mapped + 224);	
	
	
	printk(KERN_INFO"Device File opened...");
	return 0;

}
static my_release(struct inode*inode,struct file*file)
{
	kfree(driver_mem_pointer);
	printk(KERN_INFO"Device FILE closed...\n");
	return 0;
}

static ssize_t my_read(struct file*filp, char __user*buf,size_t len, loff_t*off)
{
	
	//device_read = ioread32(mapped + *off);
	//printk(KERN_INFO"data is %d \n",device_read);
	copy_to_user(buf,driver_mem_pointer + (*off) ,len); // modify to device_read to get the data
	printk(KERN_INFO"Data read: DONE...\n");
	return len;
}
 
static ssize_t my_write(struct file*filp, const char __user*buf,size_t len, loff_t*off)
{
	copy_from_user(driver_mem_pointer + (*off),buf,len);
	printk(KERN_INFO"Data is written sucessfully \n");			
	return len;
}


static int __init chr_driver_init(void)
{


/*Check DMA capability*/
	if(dma_set_mask_and_coherent(dev_struct, DMA_BIT_MASK(64))){
		dev_warn(dev,"mydev: No suitable DMA availible");
	}


	
/*Allocating Major Number*/
	if((alloc_chrdev_region(&dev,0,1,"my_Dev")) < 0 )
	{
		printk(KERN_INFO"Can not allocate major number..\n");
		return -1;
	}

	printk(KERN_INFO"Major = %d Minor = %d..\n",MAJOR(dev),MINOR(dev));

/*Creating cdev structure*/
	cdev_init(&my_cdev,&fops);	


/*Adding character device to the system*/
	if((cdev_add(&my_cdev,dev,1)) < 0) {
		printk(KERN_INFO"Cannot add the device to the system");
		goto r_class;
	}

/*creating struct class*/
	if((dev_class = class_create(THIS_MODULE,"my_class")) == NULL)
	{
		printk(KERN_INFO"cannot create the struct class \n");
		goto r_class;
	}

/*creating device*/
	if((device_create(dev_class,NULL,dev,NULL,"my_device")) == NULL){
		printk(KERN_INFO "cannot create the device ..\n");
		goto r_device;
	}	
	printk(KERN_INFO"Device driver insert...done properly..\n");
	return 0;
r_device:
	class_destroy(dev_class);

r_class:
	unregister_chrdev_region(dev,1);
	return -1;
}

void __exit chr_driver_exit(void){
	device_destroy(dev_class,dev);
	class_destroy(dev_class);
	cdev_del(&my_cdev);
	unregister_chrdev_region(dev,1);
	printk(KERN_INFO"Device driver is removed succesfully");	
}

module_init(chr_driver_init);
module_exit(chr_driver_exit);


MODULE_LICENSE("GPL");
MODULE_AUTHOR("Dat");
MODULE_DESCRIPTION("The characeter device driver");
