// Copyright AccurateRTL contributors.
// Licensed under the MIT License, see LICENSE for details.
// SPDX-License-Identifier: MIT

`timescale 1ps / 1ps

module lio_axil2ahb #( 
  parameter AWIDTH = 16, 
  parameter DWIDTH = 32,
  parameter SIZE_SEL_ADDR_BITS = 0   // 0 - чтение только по 4 байта  2 - использование окон для выбора размера чтения
)
(
  input   clk,
  input   rst_n,
  output  rst,
  
  input        [AWIDTH+SIZE_SEL_ADDR_BITS-1:0]   axil_awaddr,
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
  input        [AWIDTH+SIZE_SEL_ADDR_BITS-1:0]   axil_araddr,
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
    hsize        <= 3'b010;
  end
  else begin
    case (stt)
      WAITING_AXIL_TRANS: begin
        if (axil_awvalid) begin
          stt          <= WAITING_AXIL_WDATA;
          axil_wready  <= 1'b1;
          haddr        <= axil_awaddr;
          hwrite       <= 1'b0;
          hsel         <= 1'b0;
        end
        else begin
          if (axil_arvalid) begin
            stt          <= REQUESTING_AHB_READ;
            haddr        <= axil_araddr;
            hwrite       <= 1'b0;
            hsel         <= 1'b1;
            if (SIZE_SEL_ADDR_BITS==2) 
              if (axil_araddr[AWIDTH+SIZE_SEL_ADDR_BITS-1:AWIDTH]<3)
                hsize        <= axil_araddr[AWIDTH+SIZE_SEL_ADDR_BITS-1:AWIDTH];
              else
                hsize        <= 3'b010;
            else
              hsize        <= 3'b010;
          end
        end  
      end
      
      WAITING_AXIL_WDATA: begin
        if (axil_wvalid) begin
          hwdata       <= axil_wdata;
          axil_wready  <= 1'b0;
          hsel         <= 1'b1;
          hwrite       <= 1'b1;
          if (axil_wstrb==4'hf)
            hsize   <= 3'b010;
          else
            if ((axil_wstrb==4'h3) || (axil_wstrb==4'hC))
              hsize   <= 3'b001;
            else
              if ((axil_wstrb==4'h1) || (axil_wstrb==4'h2) || (axil_wstrb==4'h4) || (axil_wstrb==4'h8))
                hsize   <= 3'b000;
              else
                hsize   <= 3'b010;
                
          stt <= REQUESTING_AHB_WRITE;
        end
      end
            
      REQUESTING_AHB_WRITE: begin
        if (hready) begin
          hwrite       <= 1'b0;
          hsel         <= 1'b0;
          stt <= WRITING_AHB_DATA;
        end
      end
      
      REQUESTING_AHB_READ: begin
        if (hready) begin
          hwrite       <= 1'b0;
          hsel         <= 1'b0;
          stt <= READING_AHB_DATA;
        end  
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


assign htrans  = 2'b10;   //NONSEQ

assign axil_bresp    = '0;
assign axil_rresp    = '0;

assign rst = ~rst_n;

endmodule


