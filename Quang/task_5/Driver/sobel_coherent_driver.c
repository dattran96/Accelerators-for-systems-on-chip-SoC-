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

#define RGB_SIZE 8388608
#define GRAY_SIZE 3145728
#define base_addr 0x2000000000

dev_t dev = 0;
static struct class*dev_class;
static struct cdev my_cdev;
uint8_t *rgb_mem_pointer;
uint8_t *gray_mem_pointer;
uint8_t *converted_img;
uint64_t  device_read;

dma_addr_t dma_rgb;
dma_addr_t dma_gray;


static int __init chr_driver_init(void);
static void __exit chr_driver_exit(void);
static int device_open(struct inode*inode, struct file*file);
static int device_release(struct inode*inode,struct file * file);
static ssize_t device_read(struct file*filp, char __user*buf,size_t len,loff_t*off);
static ssize_t device_write(struct file*filp,const char *buf, size_t len,loff_t* off);


static struct file_operations fops = 
{
	.owner = THIS_MODULE,
	.read  = device_read,
	.write = device_write,
	.open  = device_open,
	.release = device_release,
};

static struct device dev_struct = {
	.init_name = "dev_dma",
	.coherent_dma_mask = ~0,
	.dma_mask = &dev_struct.coherent_dma_mask,
};


static int device_open(struct inode*inode,struct file*file)
{
	if ((rgb_mem_pointer = dma_alloc_coherent(&dev_struct, RGB_SIZE, &dma_rgb, GFP_KERNEL)) == 0)
	{
		printk(KERN_INFO"Cannot allocate memory\n");
		return -1;
	}

	if ((gray_mem_pointer = dma_alloc_coherent(&dev_struct, GRAY_SIZE, &dma_gray, GFP_KERNEL)) == 0)
	{
		printk(KERN_INFO"Cannot allocate memory\n");
		return -1;
	}

	printk(KERN_INFO"Device opened...\n");
	return 0;
}
static device_release(struct inode*inode,struct file*file)
{
	dma_free_coherent(&dev_struct, RGB_SIZE, rgb_mem_pointer, dma_rgb);
	dma_free_coherent(&dev_struct, GRAY_SIZE, gray_mem_pointer, dma_gray);
	printk(KERN_INFO"Device closed...\n");
	return 0;
}

static ssize_t device_read(struct file*filp, char __user*buf,size_t len, loff_t*off)
{
	
	copy_to_user(buf,gray_mem_pointer + (*off) ,len); 
	printk(KERN_INFO"Data read: DONE...\n");
	return len;
}
 
static ssize_t device_write(struct file*filp, const char __user*buf,size_t len, loff_t*off)
{
	copy_from_user(rgb_mem_pointer + (*off),buf,len);
	
	
	mapped = ioremap(base_addr,56); 
	
	iowrite64(dma_rgb,mapped);

	iowrite64((uint32_t)dma_gray,mapped + 8);
	iowrite32(1,mapped + 16);

	printk(KERN_INFO"Data is written sucessfully \n");	
	return len;
}


static int __init chr_driver_init(void)
{
	alloc_chrdev_region(&dev,0,1,"DMA_API_img");
	cdev_init(&my_cdev,&fops);	
	cdev_add(&my_cdev,dev,1);
	dev_class = class_create(THIS_MODULE,"my_class");
	device_create(dev_class,NULL,dev,NULL,"my_device");
	printk(KERN_INFO"driver installed succesfully..\n");
	return 0;
}

void __exit chr_driver_exit(void){
	device_destroy(dev_class,dev);
	class_destroy(dev_class);
	unregister_chrdev_region(dev,1);
	cdev_del(&my_cdev);
	printk(KERN_INFO"driver removed succesfully\n");	
}
module_init(chr_driver_init);
module_exit(chr_driver_exit);


MODULE_LICENSE("GPL");
MODULE_AUTHOR("Quang");
MODULE_DESCRIPTION("The characeter device driver");
