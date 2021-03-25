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



#define base_addr 0x0400000000
static void __iomem *mapped;

dev_t dev = 0;
static struct class*dev_class;
static struct cdev my_cdev;
uint8_t * mem_pointer;
uint64_t  device_read;
uint64_t *  write_value;

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
	if ((mem_pointer = kmalloc(100,GFP_KERNEL)) == 0)
	{
		printk(KERN_INFO"Cannot allocate memory \n");
		return -1;
	}
	printk(KERN_INFO"Device File opened...\n");
	return 0;
}
static my_release(struct inode*inode,struct file*file)
{
	kfree(mem_pointer);
	printk(KERN_INFO"Device FILE closed...\n");
	return 0;
}

static ssize_t my_read(struct file*filp, char __user*buf,size_t len, loff_t*off)
{
	device_read= ioread64(mapped + 16);
	copy_to_user(buf,&device_read + (*off) ,len); 
	printk(KERN_INFO"Data read: DONE...\n");
	return len;
}
 
static ssize_t my_write(struct file*filp, const char __user*buf,size_t len, loff_t*off)
{
	mapped = ioremap(base_addr,24); 
	copy_from_user(mem_pointer,buf,len);
	write_value = (uint64_t*)mem_pointer; 
	iowrite64(*(write_value),mapped);
	iowrite64(*(write_value+1),mapped + 8);
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
		printk(KERN_INFO"Cannot add the device to the system \n");
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
	printk(KERN_INFO"Device driver is removed succesfully\n");	
}

module_init(chr_driver_init);
module_exit(chr_driver_exit);


MODULE_LICENSE("GPL");
MODULE_AUTHOR("Dat");
MODULE_DESCRIPTION("The characeter device driver");
