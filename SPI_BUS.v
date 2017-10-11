module spi_bus(clk,rst_n,d_out,spi_start,SI,SO,CS,SCLK,d_in,busy);
//clk spi 总线驱动时钟，根据外设特性设定时钟
//rst_n 复位信号
//d_out 需要通过spi总线输出的并行信号
//spi_start 总线启动信号，上升沿启动总线
//SI 总线输入信号
//SO 总线输出信号
//CS 片选信号
//SCLK 总线主时钟
//d_in SPI总线接收到的数据
//busy 总线忙碌状态标志，低电平表示空闲
parameter BUS_WIDTH = 16;
parameter CNT_SIZE = 4;		//require 2**CNT_SIZE >= BUS_WIDTH

input wire clk;
input wire rst_n;
input wire[BUS_WIDTH-1:0] d_out;
input wire spi_start;
input wire SI;			//从器件输出，主器件输入 
output reg SO;			//主器件输出，从器件输入 
output wire CS;
output wire SCLK;				//串行总线输出时钟
output reg[BUS_WIDTH-1:0] d_in;
output wire busy;		//工作状态位

reg [BUS_WIDTH-1:0] d_buf_in;
reg[BUS_WIDTH-1:0] d_buf_out;
reg[1:0] spi_start_rising;
reg[1:0] state;
reg[CNT_SIZE:0] send_cnt;			//发送数据计数器
reg chip_select;
//state machine
parameter wait_start = 2'd0,start = 2'd1,end_state = 2'd2;

wire bus_start = (~spi_start_rising[0])&spi_start_rising[1];	//spi_start产生上升沿时，bus_start = 1
assign CS = chip_select;
assign SCLK = (chip_select == 0)?clk:0;
assign busy = ~CS;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		spi_start_rising <= 2'b11;
	else begin
		if(clk == 1)begin
			spi_start_rising[0] <= spi_start_rising[1];
			spi_start_rising[1] <= spi_start;
		end
	end
end

always @(negedge clk or negedge rst_n) begin		//当clk为下降沿的时候将数据送给SO，同时接收总线上的SI数据，并移位，上升沿的时候数据更稳定
	if (!rst_n) begin
		SO <= 1;
		d_in <= 0;
	end
	else begin
		if(!clk)begin
			SO <= d_buf_out[BUS_WIDTH-1];			//高位优先
			if(state == start)begin
				d_buf_in[0] <= SI;
				d_buf_in[BUS_WIDTH-1:1] = d_buf_in[BUS_WIDTH-2:0];
			end
			else
				d_in <= d_buf_in;
		end
	end
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		chip_select <= 1;
		d_buf_out <= 0;
		state <= wait_start;
		send_cnt <= BUS_WIDTH-2;
	end
	else begin
		if(clk == 1) begin
			case(state)
				wait_start:begin
				if(bus_start == 1'b1) begin		//当spi_start信号产生上升沿时，传输开始。
						state <= start;				//总线开始传数据
						send_cnt <= BUS_WIDTH-1;	//初始化计数器
						chip_select = 0;				//拉低片选
					end
					else begin
						d_buf_out <= d_out;
						state <= wait_start;			//没有等到spi开始指令，继续等待
					end
				end
				start:begin								//开始状态
				d_buf_out[BUS_WIDTH-1:1] = d_buf_out[BUS_WIDTH-2:0];
					if (send_cnt > 0) begin		//如果计数器不等于0
							state <= start;
							send_cnt <= send_cnt-1;
					end
					else begin						//计数器等于0，发送和接收最后一个数据，同时进入end_state收尾状态
						state <= end_state;
					end
				end
				end_state:begin					//等待最后一个读数
					chip_select <= 1;				//拉高片选，通信结束
					state <= wait_start;			//进入等待总线指令状态
				end
			endcase
		end
	end
end
endmodule
