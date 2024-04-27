# Copyright AccurateRTL contributors.
# Licensed under the MIT License, see LICENSE for details.
# SPDX-License-Identifier: MIT

# test_my_design.py (extended)

import logging
import random
import math
import itertools
import cocotb

from cocotb.triggers import FallingEdge, RisingEdge, Timer
from cocotbext.ahb import AHBBus, AHBLiteMaster, AHBLiteSlaveRAM, AHBResp, AHBMonitor
from cocotbext.axi import AxiLiteBus, AxiLiteMaster
from cocotb.regression import TestFactory
from cocotb.clock import Clock


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.mem_size_kib = 1
        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())

        self.axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "axil"), dut.clk, dut.rst)
        self.ahb_lite_sram = AHBLiteSlaveRAM(
          AHBBus.from_entity(dut),
          dut.clk,
          dut.rst_n,
          def_val=0,
          bp=cycle_pause(),
          mem_size=self.mem_size_kib * 1024,
        )    

    def set_idle_generator(self, generator=None):
        if generator:
            self.axil_master.write_if.aw_channel.set_pause_generator(generator())
            self.axil_master.write_if.w_channel.set_pause_generator(generator())
            self.axil_master.read_if.ar_channel.set_pause_generator(generator())
        
    def set_backpressure_generator(self, generator=None):
        if generator:
            self.axil_master.write_if.b_channel.set_pause_generator(generator())
            self.axil_master.read_if.r_channel.set_pause_generator(generator())
        
    async def cycle_reset(self):
        self.dut.rst_n.setimmediatevalue(0)
        for i in range(10):
            await RisingEdge(self.dut.clk)
        
        self.dut.rst_n.value = 1
        for i in range(10):
            await RisingEdge(self.dut.clk)


async def read_write_test(dut, data_in=None, idle_inserter=None, backpressure_inserter=None):
    tb = TB(dut)
    print("Before reset")
    await tb.cycle_reset()

    print("After reset 1")
#    tb.set_idle_generator(idle_inserter)
#    tb.set_backpressure_generator(backpressure_inserter)
    await tb.axil_master.write_dword(0*4, 0)
    
    print("After reset 2")    
#    for n in range(10):
#        await tb.axil_master.write_dword(n*4, n)
#        print("After reset 3")
#        rd_data = await tb.axil_master.read_dword(n*4)
#        assert rd_data == n, "invalid data %x != %x!" % (rd_data, n) 
        
        

def cycle_pause():
    return itertools.cycle([1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 0])
    


if cocotb.SIM_NAME:
    for test in [read_write_test]:
        factory = TestFactory(test)
        factory.add_option("idle_inserter", [None, cycle_pause])
        factory.add_option("backpressure_inserter", [None, cycle_pause])
        factory.generate_tests()


