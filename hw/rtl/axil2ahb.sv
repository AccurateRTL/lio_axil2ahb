/*
Copyright (c) 2024 AccurateRTL contributors

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

SPDX-License-Identifier: MIT
*/

module axil2ahb #( parameter AWIDTH = 16, DWIDTH = 32)
(
  input   clk,
  input   rst_n,
  output  rst,
  
  input        [AWIDTH-1:0]     axil_awaddr,
  input        [2:0]            axil_awprot,
  input                         axil_awvalid,
  output logic                  axil_awready,
  input        [DWIDTH-1:0]     axil_wdata,
  input        [DWIDTH/8-1:0]   axil_wstrb,
  input                         axil_wvalid,
  output logic                  axil_wready,
  output logic [1:0]            axil_bresp,
  output logic                  axil_bvalid,
  input                         axil_bready,
  input        [AWIDTH-1:0]     axil_araddr,
  input [2:0]                   axil_arprot,
  input                         axil_arvalid,
  output logic                  axil_arready,
  output logic [DWIDTH-1:0]     axil_rdata,
  output logic [1:0]            axil_rresp,
  output logic                  axil_rvalid,
  input                         axil_rready,
                    
  output logic [AWIDTH-1:0]     haddr,    
  output logic [DWIDTH-1:0]     hwdata,   
  output logic                  hsel,     
  output logic                  hwrite,   
  output logic  [1:0]           htrans,   
  output logic  [2:0]           hsize,    
  input                         hready,   
                        
  input       [DWIDTH-1:0]      hrdata,  
  input        [1:0]            hresp    
);

typedef enum {
    WAITING_AXIL_TRANS,
    WAITING_AXIL_WDATA,
    WAITING_AXIL_WDATA_ACK,
    WAITING_AXIL_RDATA_ACK,
    REQUESTING_AHB_WRITE,
    REQUESTING_AHB_READ,
    WRITING_AHB_DATA,
    READING_AHB_DATA
} axil2ahb_sm_states;

axil2ahb_sm_states stt;

always_comb begin
  if (stt==WAITING_AXIL_TRANS) begin
    if (axil_awvalid) begin
      axil_awready = 1'b1; 
      axil_arready = 1'b0;
    end
    else begin
      if (axil_arvalid) begin
        axil_awready = 1'b0; 
        axil_arready = 1'b1;
      end
      else begin
        axil_awready = 1'b0; 
        axil_arready = 1'b0;
      end
    end
  end
  else begin      
    axil_awready = 1'b0; 
    axil_arready = 1'b0;  
  end
end

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    stt          <= WAITING_AXIL_TRANS;
    haddr        <= '0;
    hwrite       <= 1'b0;
    hsel         <= 1'b0;
    axil_wready  <= 1'b0;
    axil_bvalid  <= 1'b0;
    axil_rvalid  <= 1'b0;
  end
  else begin
    case (stt)
      WAITING_AXIL_TRANS: begin
        if (axil_awvalid) begin
          stt          <= WAITING_AXIL_WDATA;
          axil_wready  <= 1'b1;
          haddr        <= axil_awaddr;
          hwrite       <= 1'b1;
          hsel         <= 1'b0;
        end
        else begin
          if (axil_arvalid) begin
            stt          <= REQUESTING_AHB_READ;
            haddr        <= axil_araddr;
            hwrite       <= 1'b0;
            hsel         <= 1'b1;
          end
        end  
      end
      
      WAITING_AXIL_WDATA: begin
        if (axil_wvalid) begin
          hwdata       <= axil_wdata;
          axil_wready  <= 1'b0;
          hsel         <= 1'b1;
          stt     <= REQUESTING_AHB_WRITE;
        end
      end
            
      REQUESTING_AHB_WRITE: begin
        if (hready)
          stt <= WRITING_AHB_DATA;
      end
      
      REQUESTING_AHB_READ: begin
        if (hready)
          stt <= READING_AHB_DATA;
      end

      WRITING_AHB_DATA: begin
        if (hready) begin
          stt         <= WAITING_AXIL_WDATA_ACK;
          hsel        <= 1'b0;
          axil_bvalid <= 1'b1;
        end
      end
      
      WAITING_AXIL_WDATA_ACK: begin
        if (axil_bready) begin
          stt         <= WAITING_AXIL_TRANS;
          axil_bvalid <= 1'b0;
        end
      end
      
      READING_AHB_DATA: begin
        if (hready) begin
          stt         <= WAITING_AXIL_RDATA_ACK;
          hsel        <= 1'b0;
          axil_rdata  <= hrdata;
          axil_rvalid <= 1'b1;
        end
      end
      
      WAITING_AXIL_RDATA_ACK: begin
        if (axil_rready) begin
          stt         <= WAITING_AXIL_TRANS;
          axil_rvalid <= 1'b0;
        end
      end
      

      default: begin
        stt <= WAITING_AXIL_TRANS;
      end
    endcase  
  end    
end


// assign haddr   = '0;

// assign hsel    = '0;
// assign hwrite  = '0;
assign htrans  = 2'b10;   //NONSEQ
assign hsize   = 3'b010;  //32b

assign axil_bresp    = '0;
//assign axil_bvalid   = stt==WRITING_AHB_DATA;

// assign axil_rdata    = '0;
assign axil_rresp    = '0;
// assign axil_rvalid   = '0;

assign rst = ~rst_n;
endmodule


