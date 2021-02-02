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

#define mem_size 1024
#define IOSTART 0x200
#define IOEXTEND 0x40
//#define base_addr 0x00A0000000
#define base_addr 0x0400000000
static void __iomem *mapped;
static unsigned long iostart = IOSTART,ioextend =IOEXTEND,ioend;

dev_t dev = 0;
static struct class*dev_class;
static struct cdev my_cdev;
uint8_t *kernel_buffer;
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

/////////////////////////////////
/*Minor 1, load image to RAM and write two  adresses to Zynq_PL */
static int my_open_1minor_RGBimage(struct inode * inode, struct file * filp)
{	
	/*Creating Physical Memory*/
	if ((kernel_buffer = kmalloc(mem_size,GFP_KERNEL)) == 0)
	{
		printk(KERN_INFO"Cannot allocate memory to the kernel\n");
		return -1;
	}
	if ((converted_img = kmalloc(mem_size,GFP_KERNEL)) == 0)
	{

		printk(KERN_INFO"Cannor allocate memory to the converted image\n");
	}
	printk(KERN_INFO"File 1 is open");
	return 0;
}

static ssize_t my_write_1minor_RGBimage(struct file*filp, const char __user*buf,size_t len, loff_t* off)
{
	copy_from_user(kernel_buffer,buf,len);
	dma_handle = dma_map_single(dev_struct,kernel_buffer,mem_size,DMA_BIDIRECTIONAL);
	dma_handle_2 = dma_map_single(dev_struct,converted_img,mem_size,DMA_BIDIRECTIONAL);
	mapped = ioremap(base_addr,8); //for 2 register
	iowrite64(dma_handle,mapped);
	iowrite64(dma_handle_2,mapped);
	printk(KERN_INFO"Image is loaded to RAM sucessfully, waiting for converting \n");		
	return len;
}


static my_release_1minor_RGBimage(struct inode*inode,struct file*file)
{
	kfree(kernel_buffer);
	kfree(converted_img);
	printk(KERN_INFO"FILE 1 is closed...\n");
	return 0;
}

static ssize_t my_read_1minor_RGBimage(struct file*filp, char __user*buf,size_t len,loff_t*off)
{	
	//mapped = ioport_map(iostart,ioextend);
	//mapped = ioremap(base_addr,3);
	//device_read = ioread32(mapped+4);
	//printk(KERN_INFO"data is %d \n",device_read);
	//printk(KERN_INFO"string length is %d \n",strlen(buf));
	copy_to_user(buf,convert_image,mem_size); // modify to device_read to get the data
	printk(KERN_INFO"Data read: DONE...\n");
	return mem_size;
}



//////////////////////////////////////////////////////

static int my_open_2minor_startConvert(struct inode * inode, struct file * filp)
{
	/*Creating Physical Memory*/
	if ((start_convert = kmalloc(4,GFP_KERNEL)) == 0)
	{
		printk(KERN_INFO"Cannot allocate memory to the kernel\n");
		return -1;
	}
}

static ssize_t my_write_2minor_startConvert(struct file*filp, const char __user*buf,size_t len, loff_t* off)
{	
	copy_from_user(start_convert,buf,len);
	dma_handle_3 = dma_map_single(dev_struct,start_convert,4,DMA_BIDIRECTIONAL);	
	mapped = ioremap(base_addr,4); //for 1 register
	iowrite32(dma_handle_3,mapped);
	printk(KERN_INFO"Image is loaded to RAM sucessfully, waiting for converting \n");		
	return len;
}


static my_release_2minor_startConvert(struct inode*inode,struct file*file)
{
	kfree(start_convert);
	printk(KERN_INFO"FILE 1 is closed...\n");
	return 0;
}

static ssize_t my_read_2minor_startConvert(struct file*filp, char __user*buf,size_t len,loff_t*off)
{	
	copy_to_user(buf,start_convert,4); // modify to device_read to get the data
	printk(KERN_INFO"Data read: DONE...\n");
	return mem_size;
}

/////////////////////////////////////
static int my_open_3minor_polling_finish(struct inode * inode, struct file * filp)
{	
	/*Creating Physical Memory*/
	if ((finish_convert = kmalloc(4,GFP_KERNEL)) == 0)
	{
		printk(KERN_INFO"Cannot allocate memory to the kernel\n");
		return -1;
	}
	return 0;
}

static ssize_t my_write_3minor_polling_finish(struct file*filp, const char __user*buf,size_t len, loff_t* off)
{	
	copy_from_user(finish_convert,buf,len);
	dma_handle_4 = dma_map_single(dev_struct,finish_convert,4,DMA_BIDIRECTIONAL);	
	mapped = ioremap(base_addr,4); //for 1 register
	iowrite32(dma_handle_4,mapped);
	printk(KERN_INFO"Write is done \n");		
	return len;
}

static ssize_t my_read_3minor_polling_finish(struct file*filp, char __user*buf,size_t len,loff_t*off)
{
	copy_to_user(buf,polling_finish,4); // modify to device_read to get the data
	printk(KERN_INFO"Data read: DONE...\n");
	return mem_size;
}

static int my_release_3minor_polling_finish(struct inode * inode, struct file * filp)
{
	kfree(polling_finish);
	printk(KERN_INFO"FILE 3 is closed...\n");
	return 0;	
}




////////////////////////////

static int my_open(struct inode*inode,struct file*file)
{
	/*Creating Physical Memory*/
	if ((kernel_buffer = kmalloc(mem_size,GFP_KERNEL)) == 0)
	{
		printk(KERN_INFO"Cannot allocate memory to the kernel\n");
		return -1;
	}
	if ((converted_img = kmalloc(mem_size,GFP_KERNEL)) == 0)
	{

		printk(KERN_INFO"Cannor allocate memory to the converted image\n");
	}
	printk(KERN_INFO"Device File opened...");
	return 0;
}
static my_release(struct inode*inode,struct file*file)
{
	kfree(kernel_buffer);
	printk(KERN_INFO"Device FILE closed...\n");
	return 0;
}

static ssize_t my_read(struct file*filp, char __user*buf,size_t len,)
{
	
	//mapped = ioport_map(iostart,ioextend);
	mapped = ioremap(base_addr,3);
	device_read = ioread32(mapped+4);
	printk(KERN_INFO"data is %d \n",device_read);
	printk(KERN_INFO"string length is %d \n",strlen(buf));

	copy_to_user(buf,&device_read,1); // modify to device_read to get the data
	printk(KERN_INFO"Data read: DONE...\n");
	return mem_size;
}
 
static ssize_t my_write(struct file*filp, const char __user*buf,size_t len, uint8_t write_option)
{
	switch(write_option){
		case 1:
			copy_from_user(kernel_buffer,buf,len);
			dma_handle = dma_map_single(dev_struct,kernel_buffer,mem_size,DMA_BIDIRECTIONAL);
			dma_handle_2 = dma_map_single(dev_struct,converted_img,mem_size,DMA_BIDIRECTIONAL);
			mapped = ioremap(base_addr,8); //for 2 register
			iowrite64(dma_handle,mapped);
			iowrite64(dma_handle_2,mapped);
			printk(KERN_INFO"Data is written sucessfully \n");		
			break;
		default:
			printk(KERN_INFO"nothing is written");
			break;
	}	

	//copy_from_user(kernel_buffer,buf,len);
	//mapped = ioport_map(iostart,ioextend);
	//mapped = ioremap(base_addr,3);	
	//iowrite32(11,mapped+4);
	//iowrite64(10,mapped+1);
	//printk(KERN_INFO"Data is written sucessfully...\n");
	return len;
}


static int __init chr_driver_init(void)
{


/*Check DMA capability*/
	if(dma_set_mask_and_coherent(dev_struct, DMA_BIT_MASK(64))){
		dev_warn(dev,"mydev: No suitable DMA availible");
	}

/*DMA mapping*/
	//dma_handle = dma_map_single(dev_struct,kernel_buffer,mem_size,DMA_BIDIRECTIONAL);
	
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
