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

#define base_addr 0x0400000000
static void __iomem *mapped_address;

dev_t dev = 0;
static struct class *mychardev_class ;
static struct cdev cdev;
uint8_t *data_pointer;


uint8_t *start_convert;
uint8_t *finish_convert;

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
	.init_name = "dev_task2",
};

static int device_open(struct inode*inode,struct file*file)
{
	printk("Device opened succesfully\n");
	return 0;
}
static device_release(struct inode*inode,struct file*file)
{
	
	printk("Device closed succesfully\n");
	return 0;
}

static ssize_t device_read(struct file*filp, char __user*buf,size_t len, loff_t*off)
{
	uint64_t data_read;
	data_read = ioread64(mapped_address + 16);


	if(copy_to_user(buf, &data_read, len))
		return -EFAULT;  

	printk(KERN_INFO"Data is read sucessfully \n");
	return len;
}
 
static ssize_t device_write(struct file*filp, const char __user*buf,size_t len, loff_t*off)
{
	size_t maxdatalen = 30;
	uint8_t databuf[maxdatalen];
	
	// Read data from user buffer to my driver buffer
	if(copy_from_user(databuf, buf, len))
		return -EFAULT;
		
	uint64_t *data_write = (uint64_t *) databuf;
	mapped_address = ioremap(base_addr, 24); 

	iowrite64(*data_write, mapped_address);
	iowrite64(*(data_write + 1), mapped_address + 8);
				
	printk(KERN_INFO"Data is written sucessfully \n");
	return len;
}


static int __init chr_driver_init(void)
{
	/*Allocating Major Number*/
	if((alloc_chrdev_region(&dev,0,1,"mychardev")) < 0 )
	{
		printk(KERN_INFO"Can not allocate major number..\n");
		return -1;
	}

	printk(KERN_INFO"Major = %d Minor = %d..\n",MAJOR(dev),MINOR(dev));

	/*Creating cdev structure*/
	cdev_init(&cdev,&fops);	


	/*Adding character device to the system*/
	if((cdev_add(&cdev,dev,1)) < 0) {
		printk(KERN_INFO"Cannot add the device to the system\n");
		goto remove_class;
	}

	/*creating struct class*/
	if((mychardev_class  = class_create(THIS_MODULE,"my_class")) == NULL)
	{
		printk(KERN_INFO"cannot create the struct class \n");
		goto remove_class;
	}

	/*creating device*/
	if((device_create(mychardev_class ,NULL,dev,NULL,"my_device")) == NULL){
		printk(KERN_INFO "cannot create the device ..\n");
		goto remove_device;
	}	
	printk(KERN_INFO"Device driver insert...done properly..\n");
	return 0;
remove_device:
	class_destroy(mychardev_class);

remove_class:
	unregister_chrdev_region(dev,1);
	return -1;
}

void __exit chr_driver_exit(void){
	device_destroy(mychardev_class ,dev);
	class_destroy(mychardev_class );
	cdev_del(&cdev);
	unregister_chrdev_region(dev,1);
	printk(KERN_INFO"Device driver is removed succesfully\n");	
}

module_init(chr_driver_init);
module_exit(chr_driver_exit);


MODULE_LICENSE("GPL");
MODULE_AUTHOR("Quang");
MODULE_DESCRIPTION("The characeter device driver");
