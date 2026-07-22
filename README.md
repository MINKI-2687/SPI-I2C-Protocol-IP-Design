# SPI/I2C 직렬 통신 프로토콜 IP 설계

SPI(Serial Peripheral Interface) 및 I2C(Inter-Integrated Circuit) 통신 프로토콜을 SystemVerilog로 설계한 프로젝트입니다.  
Master/Slave 구조의 양방향 통신 모듈을 구현하고, 테스트벤치를 통해 기능 검증을 수행했습니다.

## 🏗️ 시스템 구조

### SPI
```
SPI Master ──── SCLK/MOSI/MISO/SS ────> SPI Slave
     │                                       │
     └── FND Controller ◄── Data ────────────┘
```

### I2C
```
I2C Master ──── SCL/SDA (양방향) ────> I2C Slave
     │                                     │
     └── FND Controller ◄── Data ──────────┘
```

## 📁 디렉토리 구조
```
.
├── rtl/
│   ├── spi/                    # SPI 프로토콜 모듈
│   │   ├── spi_master.sv       # SPI Master (CPOL/CPHA 설정, 가변 클럭 분주)
│   │   ├── spi_slave.sv        # SPI Slave (수신 데이터 처리)
│   │   ├── spi_top.sv          # SPI Master-Slave 통합 Top
│   │   ├── system_top.sv       # FPGA 시스템 Top (버튼/FND 연동)
│   │   ├── slave_top.sv        # Slave 측 Top 모듈
│   │   ├── btn_debounce.sv     # 버튼 디바운싱
│   │   └── fnd_controller.sv   # 7-Segment FND 출력 제어
│   └── i2c/                    # I2C 프로토콜 모듈
│       ├── i2c_master.sv       # I2C Master (Start/Stop/ACK 제어)
│       ├── i2c_slave.sv        # I2C Slave (주소 매칭, 데이터 응답)
│       ├── i2c_top.sv          # I2C Master-Slave 통합 Top
│       ├── i2c_demo_top.sv     # I2C 데모 Top 모듈
│       ├── system_top.sv       # FPGA 시스템 Top
│       ├── btn_debounce.sv     # 버튼 디바운싱
│       └── fnd_controller.sv   # 7-Segment FND 출력 제어
└── tb/
    ├── spi/
    │   ├── tb_spi_master.sv    # SPI Master 단독 검증
    │   ├── tb_spi_slave.sv     # SPI Slave 단독 검증
    │   └── tb_spi_top.sv       # SPI 통합 시뮬레이션
    └── i2c/
        ├── tb_i2c_master.sv    # I2C Master 단독 검증
        └── tb_i2c_top.sv       # I2C 통합 시뮬레이션
```

## 🔧 기술 스택
| 항목 | 내용 |
|------|------|
| 설계 언어 | SystemVerilog |
| 시뮬레이션 | Xilinx Vivado Simulator |
| 타겟 FPGA | Basys3 (Xilinx Artix-7) |

## ⚙️ 주요 설계 내용

### SPI (Serial Peripheral Interface)
- **Full-Duplex** 동기식 직렬 통신 (MOSI/MISO 동시 전송)
- CPOL/CPHA 모드 설정 지원
- Slave Select(SS) 기반 다중 Slave 선택
- 가변 클럭 분주기를 통한 SCLK 주파수 제어

### I2C (Inter-Integrated Circuit)
- **Half-Duplex** 양방향 직렬 통신 (SDA 공유)
- 7-bit Slave 주소 지정 방식
- Start/Stop Condition 생성 및 ACK/NACK 핸드셰이킹
- Open-Drain 방식의 버스 중재