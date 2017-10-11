module spi_bus(clk,rst_n,d_out,spi_start,SI,SO,CS,SCLK,d_in,busy);

parameter BUS_WIDTH = 8;

input wire clk;
input wire rst_n;
input wire[BUS_WIDTH-1:0] d_out;
input wire spi_start;
input wire SI;			//从器件输出，主器件输入 
output reg SO;			//主器件输出，从器件输入 
output wire CS;
output wire SCLK;				//串行总线输出时钟
output reg[BUS_WIDTH-1:0] d_in;
output reg busy;		//工作状态位

reg [BUS_WIDTH-1:0] d_buf_in;
reg[BUS_WIDTH-1:0] d_buf_out;

reg[1:0] state;
reg[3:0] send_cnt;			//发送数据计数器
reg chip_select;
//state machine
parameter wait_start = 2'd0,start = 2'd1,end_state = 2'd2,end_state1 = 2'd3;
assign CS = chip_select;
assign SCLK = (chip_select == 0)?clk:0;

always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		chip_select <= 1;
		SO <= 1;
		d_in <= 0;
		busy <= 0;
		state <= wait_start;
		send_cnt <= BUS_WIDTH-2;
		d_buf_out <= 0;
	end
	else begin
		if(clk == 1) begin
			case(state)
				wait_start:begin
					if(spi_start == 1'b1) begin
						state <= start;				//总线开始传数据
						send_cnt <= BUS_WIDTH-2;	//初始化计数器
						d_buf_out <= d_out;			//上缓存
						busy <= 1;						//总线进入忙碌状态
						chip_select = 0;				//拉低片选
						SO <= d_out[BUS_WIDTH-1];	//先传输MSB
					end
					else begin
						state <= wait_start;			//没有等到spi开始指令，继续等待
					end
				end
				start:begin								//开始状态
					if (send_cnt > 0) begin		//如果计数器不等于0
							state <= start;
							d_buf_in[send_cnt+1] <= SI;
							SO <= d_buf_out[send_cnt];
							send_cnt <= send_cnt-1;
					end
					else begin						//计数器等于0，发送最后一个数据，同时进入end_state收尾状态
						d_buf_in[send_cnt+1] <= SI;
						SO <= d_buf_out[send_cnt];//发送data[0]数据
						state <= end_state;
					end
				end
				end_state:begin
					d_buf_in[0] <= SI;			//接受data[0]数据
					state <= end_state1;			//进入最后一个状态
				end
				end_state1:begin
					chip_select <= 1;				//拉高片选，通信结束
					busy <= 0;						//模块退出忙碌状态
					d_in <= d_buf_in;				//将接收到的数据通过并行总线输出
					state <= wait_start;			//进入等待总线指令状态
				end
			endcase
		end
	end
end
endmodule
