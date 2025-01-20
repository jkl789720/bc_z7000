//#include "xbram.h"
//#include "xparameters.h"
//#include "xil_printf.h"
//#include "xil_io.h"
//#include "sleep.h"
//
//#define XPAR_AXI_BRAM_CTRL_0_DEVICE_ID 0U
//#define XPAR_AXI_BRAM_CTRL_0_S_AXI_BASEADDR 0x81000000U
//
//#define XPAR_AXILITE_SLAVE_0_S00_AXI_BASEADDR 0x80000000
//
//#define BEAM_POS_NUM 16
//#define WRITE_REG_NUM BEAM_POS_NUM*4
//
//XBram bram;
//
//XBram_Config *cfg_ptr;
//
//void InitializeECC(XBram_Config *ConfigPtr, u32 EffectiveAddr);
//void bram_write_check();
//void bram_write_stim();
//void aux_information_write();
//
//
//void main()
//{
//	//initialize
//	XBram * bram_ptr = &bram;
//	cfg_ptr = XBram_LookupConfig(XPAR_AXI_BRAM_CTRL_0_DEVICE_ID);
//	XBram_CfgInitialize(bram_ptr,cfg_ptr ,
//			cfg_ptr -> CtrlBaseAddress);
//	InitializeECC(cfg_ptr, cfg_ptr->CtrlBaseAddress);
//
//		while(inbyte() == 1)
//		{
//			xil_printf("测试开始\n");
//			bram_write_stim();
//			bram_write_check();
//			aux_information_write();
//		}
//
//
//
//}
//
//void bram_write_stim()
//{
//	int i;
//	for(i = 0;i < WRITE_REG_NUM ; i = i + 1)
//	{
//			Xil_Out32(XPAR_AXI_BRAM_CTRL_0_S_AXI_BASEADDR+i*4, 0x55555555);
//	}
//	//ctrl_reg0
//	XBram_WriteReg(XPAR_AXI_BRAM_CTRL_0_S_AXI_BASEADDR, 488, 1);
//	//ctrl_reg1
//	XBram_WriteReg(XPAR_AXI_BRAM_CTRL_0_S_AXI_BASEADDR, 492, 2);
//}
//
//void bram_write_check()
//{
//	int i;
//	u32 read_value;
//	for(i = 0;i < WRITE_REG_NUM ; i = i + 1)
//	{
//		read_value = XBram_ReadReg(XPAR_AXI_BRAM_CTRL_0_S_AXI_BASEADDR, i*4);
//		if(read_value != 0x55555555)
//			xil_printf("测试错误，地址：%d,值：%d\n",i*4,read_value);
//		else
//			xil_printf("测试成功，地址：%d,值：%d\n",i*4,read_value);
//	}
//	//ctrl_reg0
//	read_value = XBram_ReadReg(XPAR_AXI_BRAM_CTRL_0_S_AXI_BASEADDR, 488);
//	if(read_value != 0x55555555)
//		xil_printf("测试错误，地址：%d,值：%d\n",488,read_value);
//	//ctrl_reg1
//	read_value = XBram_ReadReg(XPAR_AXI_BRAM_CTRL_0_S_AXI_BASEADDR, 492);
//	if(read_value != 0x55555555)
//		xil_printf("测试错误，地址：%d,值：%d\n",492,read_value);
//}
//
//void InitializeECC(XBram_Config *ConfigPtr, u32 EffectiveAddr)
//{
//	u32 Addr;
//	volatile u32 Data;
//
//	if (ConfigPtr->EccPresent &&
//	    ConfigPtr->EccOnOffRegister &&
//	    ConfigPtr->EccOnOffResetValue == 0 &&
//	    ConfigPtr->WriteAccess != 0) {
//		for (Addr = ConfigPtr->MemBaseAddress;
//		     Addr < ConfigPtr->MemHighAddress; Addr+=4) {
//			Data = XBram_In32(Addr);
//			XBram_Out32(Addr, Data);
//		}
//		XBram_WriteReg(EffectiveAddr, XBRAM_ECC_ON_OFF_OFFSET, 1);
//	}
//}
//
//void aux_information_write()
//{
//	Xil_Out32(XPAR_AXILITE_SLAVE_0_S00_AXI_BASEADDR+4,0);
//	usleep(1);
//	Xil_Out32(XPAR_AXILITE_SLAVE_0_S00_AXI_BASEADDR+4,1);
//	Xil_Out32(XPAR_AXILITE_SLAVE_0_S00_AXI_BASEADDR+8,BEAM_POS_NUM);
//
//}
//



#include "xbram.h"
#include "xparameters.h"
#include "xil_printf.h"
#include "xil_io.h"
#include "sleep.h"

#define XPAR_AXI_BRAM_CTRL_0_DEVICE_ID 0U
#define XPAR_AXI_BRAM_CTRL_0_S_AXI_BASEADDR 0x81000000U

#define XPAR_AXILITE_SLAVE_0_S00_AXI_BASEADDR 0x80000000

#define bram_bc_base    0x81000000

#define BEAM_POS_NUM 16
#define WRITE_REG_NUM BEAM_POS_NUM*4



XBram bram;

XBram_Config *cfg_ptr;

void InitializeECC(XBram_Config *ConfigPtr, u32 EffectiveAddr);
void bram_write_check();
void bram_write_stim();
void aux_information_write();


void main()
{
	//initialize
//	XBram * bram_ptr = &bram;
//	cfg_ptr = XBram_LookupConfig(XPAR_AXI_BRAM_CTRL_0_DEVICE_ID);
//	XBram_CfgInitialize(bram_ptr,cfg_ptr ,
//			cfg_ptr -> CtrlBaseAddress);
//	InitializeECC(cfg_ptr, cfg_ptr->CtrlBaseAddress);

		while(inbyte() == 1)
		{
//			xil_printf("测试开始\n");
			bram_write_stim();
//			bram_write_check();
//			aux_information_write();
			u32 data=XBram_ReadReg(bram_bc_base,0x1ec);//波位数量
			printf("the value is %u\r\n",data);
		}



}

void bram_write_stim()
{
    u32 testdata=0xFE0C0000;//0x01f40000
    XBram_WriteReg(bram_bc_base,0,testdata);//第一个波位
    testdata=0x05dc0000;
    XBram_WriteReg(bram_bc_base,4,0xff00ff00);//接收控制0x0000ffff
    XBram_WriteReg(bram_bc_base,8,0x00ff00ff);//发射控制
    XBram_WriteReg(bram_bc_base,12,0x000f);//发射使能

    testdata=0;
    XBram_WriteReg(bram_bc_base,16,testdata);//第二个波位
    XBram_WriteReg(bram_bc_base,20,0xff00ff00);
    XBram_WriteReg(bram_bc_base,24,0x00ff00ff);
    //XBram_WriteReg(bram_bc_base,28,0xffffffff);//发射使能
    XBram_WriteReg(bram_bc_base,28,0x0000000f);//发射使能

    testdata=0x01f40000;
    XBram_WriteReg(bram_bc_base,32,testdata);//第三个波位
    XBram_WriteReg(bram_bc_base,36,0xff00ff00);
    XBram_WriteReg(bram_bc_base,40,0x00ff00ff);
    XBram_WriteReg(bram_bc_base,44,0x0000000f);
//
    testdata=0x03e80000;
    XBram_WriteReg(bram_bc_base,48,testdata);//第四个波位
    XBram_WriteReg(bram_bc_base,52,0xff00ff00);
    XBram_WriteReg(bram_bc_base,56,0x00ff00ff);
    XBram_WriteReg(bram_bc_base,60,0x0000000f);

    testdata=0x03e80000;
    XBram_WriteReg(bram_bc_base,48,testdata);//第四个波位
    XBram_WriteReg(bram_bc_base,52,0xff00ff00);
    XBram_WriteReg(bram_bc_base,56,0x00ff00ff);
    XBram_WriteReg(bram_bc_base,60,0x0000000f);
    
    testdata=0x03e80000;
    XBram_WriteReg(bram_bc_base,48,testdata);//第四个波位
    XBram_WriteReg(bram_bc_base,52,0xff00ff00);
    XBram_WriteReg(bram_bc_base,56,0x00ff00ff);
    XBram_WriteReg(bram_bc_base,60,0x0000000f);
    
    testdata=0x03e80000;
    XBram_WriteReg(bram_bc_base,48,testdata);//第四个波位
    XBram_WriteReg(bram_bc_base,52,0xff00ff00);
    XBram_WriteReg(bram_bc_base,56,0x00ff00ff);
    XBram_WriteReg(bram_bc_base,60,0x0000000f);
    
    
    testdata=0x03e80000;
    XBram_WriteReg(bram_bc_base,48,testdata);//第四个波位
    XBram_WriteReg(bram_bc_base,52,0xff00ff00);
    XBram_WriteReg(bram_bc_base,56,0x00ff00ff);
    XBram_WriteReg(bram_bc_base,60,0x0000000f);
    
    
    
    
    
    
    
    
    
    Xil_Out32(bram_bc_base,0x200,testdata2);//开始波位

    XBram_WriteReg(bram_bc_base,0x1ec,BEAM_POS_NUM);//波位数量

    u32 testdata1=0x0000000b;
    XBram_WriteReg(bram_bc_base,0x1e8,testdata1);//寄存器配置


    XBram_WriteReg(0x80000000,4, 0); //vaild
    //GET_ADDR_DATA(memaddr, AXILITE_REG1,data_test); //vaild
    usleep(10);
    XBram_WriteReg(0x80000000,4,1);
    //GET_ADDR_DATA(memaddr, AXILITE_REG1,data_test);
    usleep(10);
    XBram_WriteReg(0x80000000,4,0);

    XBram_WriteReg(0x80000000,8,BEAM_POS_NUM);//波位数量 给fpga

//    xil_printf("数据发送完成\n");
}

void bram_write_check()
{
	int i;
	u32 read_value;
	for(i = 0;i < WRITE_REG_NUM ; i = i + 1)
	{
		read_value = XBram_ReadReg(XPAR_AXI_BRAM_CTRL_0_S_AXI_BASEADDR, i*4);
		if(read_value != 0x55555555)
			xil_printf("测试错误，地址：%d,值：%d\n",i*4,read_value);
		else
			xil_printf("测试成功，地址：%d,值：%d\n",i*4,read_value);
	}
	//ctrl_reg0
	read_value = XBram_ReadReg(XPAR_AXI_BRAM_CTRL_0_S_AXI_BASEADDR, 488);
	if(read_value != 0x55555555)
		xil_printf("测试错误，地址：%d,值：%d\n",488,read_value);
	//ctrl_reg1
	read_value = XBram_ReadReg(XPAR_AXI_BRAM_CTRL_0_S_AXI_BASEADDR, 492);
	if(read_value != 0x55555555)
		xil_printf("测试错误，地址：%d,值：%d\n",492,read_value);
}

void InitializeECC(XBram_Config *ConfigPtr, u32 EffectiveAddr)
{
	u32 Addr;
	volatile u32 Data;

	if (ConfigPtr->EccPresent &&
	    ConfigPtr->EccOnOffRegister &&
	    ConfigPtr->EccOnOffResetValue == 0 &&
	    ConfigPtr->WriteAccess != 0) {
		for (Addr = ConfigPtr->MemBaseAddress;
		     Addr < ConfigPtr->MemHighAddress; Addr+=4) {
			Data = XBram_In32(Addr);
			XBram_Out32(Addr, Data);
		}
		XBram_WriteReg(EffectiveAddr, XBRAM_ECC_ON_OFF_OFFSET, 1);
	}
}

void aux_information_write()
{
	Xil_Out32(XPAR_AXILITE_SLAVE_0_S00_AXI_BASEADDR+4,0);
	usleep(1);
	Xil_Out32(XPAR_AXILITE_SLAVE_0_S00_AXI_BASEADDR+4,1);
	Xil_Out32(XPAR_AXILITE_SLAVE_0_S00_AXI_BASEADDR+8,BEAM_POS_NUM);

}

