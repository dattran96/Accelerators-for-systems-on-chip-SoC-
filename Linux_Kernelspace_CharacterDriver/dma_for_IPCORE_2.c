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


#define mem_size 1572872   //1572864 bytes (for RGB img) + 8 bytes(for 2 registers start and finish_poll) = 1572872
#define IOSTART 0x200
#define IOEXTEND 0x40
//#define base_addr 0x00A0000000
//#define base_addr 0x0400000000
#define base_addr 0x2000000000
static void __iomem *mapped;
static unsigned long iostart = IOSTART,ioextend =IOEXTEND,ioend;

dev_t dev = 0;
static struct class*dev_class;
static struct cdev my_cdev;
uint8_t *driver_mem_pointer;
uint8_t *converted_img;
uint64_t  device_read;
//struct device* dev_struct;
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

static struct device dev_struct = {
	.init_name = "dev_dma",
	.coherent_dma_mask = ~0,
	.dma_mask = &dev_struct.coherent_dma_mask,
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

	mapped = ioremap(base_addr,40); //for 5 registers 
	printk(KERN_INFO"Got address of peripherals");

	dma_handle = dma_map_single(&dev_struct,driver_mem_pointer,786432,DMA_BIDIRECTIONAL);
	printk(KERN_INFO"dma mapping sucessfully");
	iowrite64(dma_handle,mapped);

	printk(KERN_INFO"Address 1 is %d \n",(uint64_t)dma_handle);

	dma_handle_2 = dma_map_single(&dev_struct,driver_mem_pointer + 786432 + 1024,786432,DMA_BIDIRECTIONAL);
	iowrite64((uint32_t)dma_handle_2,mapped + 8);

	printk(KERN_INFO"Address 2 is %d \n",(uint64_t)dma_handle_2);

	iowrite32(512,mapped + 32);

	iowrite32(1,mapped + 16);
	
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
	
	device_read = ioread64(mapped);
	printk(KERN_INFO"Address 1 get back is %d",device_read);
	device_read = ioread64 (mapped + 8);
	printk(KERN_INFO"Address 2 get back is %d",device_read);
	
	device_read= ioread32(mapped + 32);
	printk(KERN_INFO"Size  get back is %d",device_read);


	device_read= ioread32(mapped + 16);
	printk(KERN_INFO"Start  get back is %d",device_read);

	copy_to_user(buf,driver_mem_pointer + (*off) ,len); 
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
	
/*Allocating Major Number*/
	if((alloc_chrdev_region(&dev,0,1,"DMA_API_img")) < 0 )
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
MODULE_AUTHOR("Quang");
MODULE_DESCRIPTION("The characeter device driver");
