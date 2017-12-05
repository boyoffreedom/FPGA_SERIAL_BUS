module txd_send(clk,rst_n,data_in,txd_start,txd_ready,txd);	//

//BAUD = 50M/baudrate
parameter BAUD = 434;		//baud rate clock division coefficiency，需要发送数据定义

input wire clk,rst_n,txd_start;
input wire [31:0] data_in;
output reg txd_ready,txd;

parameter WAIT_START = 0,SEND_BYTE = 1,EOS = 2;

integer fdiv_cnt;
reg clk_b;			//baud rate clk
reg[7:0] send_byte_cnt;	//最多可发送255个字节
reg[31:0] di_buf;		//data input buffer
reg[7:0] txd_buf;		//txd bit send buf
reg[5:0] state;
reg[3:0] send_bit_cnt;	//bit state
integer cnt;

//波特率分频
always@(posedge clk or negedge rst_n) begin			//baud rate clock division
	if(!rst_n) begin
		clk_b <= 0;
		fdiv_cnt <= 0;
	end
	else begin
		if(fdiv_cnt <= BAUD) begin
			fdiv_cnt <= fdiv_cnt + 1;
			clk_b <= 0;
		end
		else begin
			fdiv_cnt <= 0;
			clk_b <= 1;			//clk_b为脉冲型时钟
		end
	end
end

//serial communication byte level
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		state <= WAIT_START;
		txd_ready <= 1;
		txd_buf <= 0;
		send_byte_cnt <= 0;
		send_bit_cnt <= 0;
	end
	else begin
	case(state)
		WAIT_START:begin					//等待信号发生
			if(txd_start == 1) begin
				txd_ready <= 0;			//进入忙碌状态
				di_buf <= data_in;		//数据缓存
				state <= SEND_BYTE;
			end
			else begin
				txd_ready <= 1;
				state <= WAIT_START;
			end
		end
		SEND_BYTE:begin
			if(clk_b) begin			//rising edge of baud rate clock;时钟沿同步
				state <= SEND_BYTE;
				case(send_byte_cnt)			//选择发送数据字节
					0: txd_buf <= di_buf[31:24];
					1: txd_buf <= di_buf[23:16];
					2: txd_buf <= di_buf[15: 8];
					3: txd_buf <= di_buf[ 7: 0];
					4: state <= EOS;
					default: state <= EOS;
				endcase
				
				if(send_bit_cnt < 14) begin
					send_bit_cnt <= send_bit_cnt + 1'b1;
				end
				else begin
					send_bit_cnt <= 0;							//重置发送位计数器
					send_byte_cnt <= send_byte_cnt + 1'b1;			//发送下一个字节数据
				end
				
			end
			else begin
				state <= SEND_BYTE;
			end
		end
		EOS:begin		//end of send;
			send_bit_cnt <= 0;
			send_byte_cnt <= 0;
			txd_ready <= 1;
			state <= WAIT_START;
		end
		endcase
	end
end

//serial communication bit level
always @(posedge clk or negedge rst_n)begin
	if(!rst_n) begin
		txd <= 1;
	end
	case(send_bit_cnt)
		4'd0 : txd <= 1'b1;			//start_bit_pre
		4'd1 : txd <= 1'b1;			//start_bit_pre
		4'd2 : txd <= 1'b0;			//start_bit
		4'd3 : txd <= txd_buf[0];	//data_bit
		4'd4 : txd <= txd_buf[1];
		4'd5 : txd <= txd_buf[2];
		4'd6 : txd <= txd_buf[3];
		4'd7 : txd <= txd_buf[4];
		4'd8 : txd <= txd_buf[5];
		4'd9 : txd <= txd_buf[6];
		4'd10: txd <= txd_buf[7];
		4'd11: txd <= 1'b1; 			//end_bit
		4'd12: txd <= 1'b1; 			//end_bit
		4'd13: txd <= 1'b1; 			//end_bit
		4'd14: txd <= 1'b1; 			//end_bit
		default:txd<= 1'b1;			//default
	endcase
end
endmodule

