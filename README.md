# lio_axil2ahb
AXI4 Lite to AHB bridge for Leningrad IO subsystem.

# Размещение

Для работоспособности относительных путей ядро должно быть размещено по пути <proj_dir>/hw/ip.
Запуск команд должен производиться из корневой директории проекта. Рабочие папки будут созданы в папке <proj_dir>/build.

# Моделирование

## Cocotb + iverilog

fusesoc --cores-root=. run --target sim_cocotb --no-export lio_axil2ahb

pytest --log-file=./log.tx -k test_lio_axil2ahb


## Verilator + SystemC + DPI


## VCS + UVM + Synopsys VIP


# Lint

## Verilator
fusesoc --cores-root=. run --target lint --tool=verilator --no-export lio_axil2ahb

## Verible
fusesoc --cores-root=. run --target lint --tool=veriblelint --no-export lio_axil2ahb 


