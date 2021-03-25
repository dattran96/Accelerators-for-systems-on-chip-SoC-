#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/kdev_t.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/slab.h>
#include <linux/uaccess.h>
#include <linux/io.h>
#include <linux/dma-mapping.h>

static struct class*dev_class;
static struct cdev my_cdev;
uint8_t * data_buf;
uint64_t  value_read;
uint64_t *  write_buf;
static void __iomem *mapped;
dev_t dev = 0;
#define base_addr 0x0400000000

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
	if ((data_buf = kmalloc(100,GFP_KERNEL)) == 0)
	{
		printk(KERN_INFO"Cannot allocate memory \n");
		return -1;
	}
	printk(KERN_INFO"Device opened...\n");
	return 0;
}
static device_release(struct inode*inode,struct file*file)
{
	kfree(data_buf);
	printk(KERN_INFO"Device closed...\n");
	return 0;
}

static ssize_t device_read(struct file*filp, char __user*buf,size_t len, loff_t*off)
{
	value_read= ioread64(mapped + 16);
	copy_to_user(buf,&value_read + (*off) ,len); 
	printk(KERN_INFO"Data read finished\n");
	return len;
}
 
static ssize_t device_write(struct file*filp, const char __user*buf,size_t len, loff_t*off)
{
	mapped = ioremap(base_addr,24); 
	copy_from_user(data_buf,buf,len);
	write_buf = (uint64_t*)data_buf; 
	iowrite64(*(write_buf),mapped);
	iowrite64(*(write_buf+1),mapped + 8);
	return len;
}


static int __init chr_driver_init(void)
{
	/*Allocating Major Number*/
	alloc_chrdev_region(&dev,0,1,"DMA_API_img");
	/*Creating cdev structure*/
	cdev_init(&my_cdev,&fops);	
	/*Adding character device to the system*/
	cdev_add(&my_cdev,dev,1);
	/*creating struct class*/
	dev_class = class_create(THIS_MODULE,"my_class");
	/*creating device*/
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
MODULE_DESCRIPTION("characeter driver");
