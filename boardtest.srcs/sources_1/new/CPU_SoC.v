`timescale 1ns / 1ps

module CPU_SoC(     //这段代码是在cpu.v 的基础上加入了soc接口
    input clk,
    input rst,

    // 指令接口 改用Harvard架构 ，使用独立的指令总线
    output [31:0] inst_addr,      // 指令地址
    input [31:0] inst_data,       // 指令数据

    // 数据接口 (独立的数据总线)
    output [31:0] data_addr,      // 数据地址
    output [31:0] data_writeData, // 写入数据
    output data_we,               // 数据写使能
    output data_re,               // 数据读使能
    input [31:0] data_readData,   // 读取数据

    output [31:0] pc_out
);
//也是就是说一个存储器存放指令的地址 一个存放指令的内容
    reg [31:0] pc;    //pc寄存器

    wire stall, flush_IFID, flush_IDEX;  //各个流水线的控制信号
    wire flush_on_jump;             // 跳转时flush流水线
    wire [1:0] forwardA, forwardB;

    wire [31:0] pc_IFID, instruction_IFID;
    wire [6:0] opcode_ID = instruction_IFID[6:0]; //操作符号信号
    wire [4:0] rd_ID = instruction_IFID[11:7];  //目标寄存器
    wire [2:0] funct3_ID = instruction_IFID[14:12];  //三位功能
    wire [4:0] rs1_ID = instruction_IFID[19:15];
    wire [4:0] rs2_ID = instruction_IFID[24:20]; //两个寄存器
    wire [6:0] funct7_ID = instruction_IFID[31:25];  //7位功能码

    wire [31:0] pc_IDEX, readData1_IDEX, readData2_IDEX, imm_IDEX;
    wire [4:0] rs1_IDEX, rs2_IDEX, rd_IDEX;                    //解码到执行阶段
    wire [3:0] aluOp_IDEX;
    wire regWe_IDEX, memWe_IDEX, isFromMem_IDEX, isFromPC4_IDEX, bIsImm_IDEX, bIs20bImm_IDEX;
    wire [1:0] pcSource_IDEX;
    wire [2:0] funct3_IDEX;      // 这里还需要添加一个EX阶段的funct3用于分支条件判断
    wire isBranch_IDEX;          // 这里需要添加一个标识符信号标记是否为分支指令

    wire [31:0] pc_EXMEM, aluResult_EXMEM, readData2_EXMEM, imm_EXMEM;  // 添加imm_EXMEM  用于处理立即数
    wire [4:0] rd_EXMEM;
    wire regWe_EXMEM, memWe_EXMEM, isFromMem_EXMEM, isFromPC4_EXMEM;   //执行到访存阶段
    wire [1:0] pcSource_EXMEM;

    wire [31:0] pc_MEMWB, aluResult_MEMWB, memReadData_MEMWB; //访存到写入阶段
    wire [4:0] rd_MEMWB;
    wire regWe_MEMWB, isFromMem_MEMWB, isFromPC4_MEMWB;
    //全部修改成了显示声明
    wire [31:0] imm_I_ID, imm_S_ID, imm_B_ID, imm_U_ID, imm_J_ID;
    reg [31:0] imm_ID;

    assign imm_I_ID = {{20{instruction_IFID[31]}}, instruction_IFID[31:20]};
    assign imm_S_ID = {{20{instruction_IFID[31]}}, instruction_IFID[31:25], instruction_IFID[11:7]};
    assign imm_B_ID = {{19{instruction_IFID[31]}}, instruction_IFID[31], instruction_IFID[7], instruction_IFID[30:25], instruction_IFID[11:8], 1'b0};
    assign imm_U_ID = {instruction_IFID[31:12], 12'b0};
    assign imm_J_ID = {{11{instruction_IFID[31]}}, instruction_IFID[19:12], instruction_IFID[20], instruction_IFID[30:21], 1'b0};

   //寄存器写入信号 内存写入   对ALU写入信号的立即数判断信号            数据写回信号
    reg regWe_ID, memWe_ID,         bIsImm_ID, bIs20bImm_ID,                 isFromMem_ID, isFromPC4_ID;
    reg [1:0] pcSource_ID;
    reg [3:0] aluOp_ID;
    reg isBranch_ID;                 

    wire [31:0] readData1_ID, readData2_ID;
    reg [31:0] writeData_WB;

    reg [31:0] aluA_EX, aluB_EX;
    wire [31:0] aluResult_EX;
    wire aluCon_EX;

    reg [31:0] forwardedA, forwardedB;


    // 指令接口 始终输出PC地址，获取指令
    assign inst_addr = pc;
    assign pc_out = pc;

    // 数据接口 用于load/store操作
    assign data_addr = aluResult_EXMEM;
    assign data_writeData = readData2_EXMEM;
    assign data_we = memWe_EXMEM;
    assign data_re = isFromMem_EXMEM;

    IF_ID if_id_reg (
        .clk(clk),
        .rst(rst),
        .stall(stall),
        .flush(flush_IFID | flush_on_jump),  // 这里跳转指令有问题跳转时也需要flush
        .pc_in(pc),
        .instruction_in(inst_data),  
        .pc_out(pc_IFID),
        .instruction_out(instruction_IFID)
    );

    RegFile myrf (      //各个模块的实例化
        .clk(clk),
        .rst(rst),
        .regWe(regWe_MEMWB),
        .readReg1(rs1_ID),
        .readReg2(rs2_ID),
        .writeReg(rd_MEMWB),
        .writeData(writeData_WB),
        .readData1(readData1_ID),
        .readData2(readData2_ID)
    );

    ID_EX id_ex_reg (
        .clk(clk),
        .rst(rst),
        .flush(flush_IDEX | flush_on_jump),  // 修复：跳转时也需要flush ID/EX阶段
        .stall(stall),              // 添加stall信号连接
        .pc_in(pc_IFID),
        .readData1_in(readData1_ID),
        .readData2_in(readData2_ID),
        .imm_in(imm_ID),
        .rs1_in(rs1_ID),
        .rs2_in(rs2_ID),
        .rd_in(rd_ID),
        .aluOp_in(aluOp_ID),
        .regWe_in(regWe_ID),
        .memWe_in(memWe_ID),
        .isFromMem_in(isFromMem_ID),
        .isFromPC4_in(isFromPC4_ID),
        .bIsImm_in(bIsImm_ID),
        .bIs20bImm_in(bIs20bImm_ID),
        .pcSource_in(pcSource_ID),
        .funct3_in(funct3_ID),       // 添加funct3到EX阶段
        .isBranch_in(isBranch_ID),   
        .pc_out(pc_IDEX),
        .readData1_out(readData1_IDEX),
        .readData2_out(readData2_IDEX),
        .imm_out(imm_IDEX),
        .rs1_out(rs1_IDEX),
        .rs2_out(rs2_IDEX),
        .rd_out(rd_IDEX),
        .aluOp_out(aluOp_IDEX),
        .regWe_out(regWe_IDEX),
        .memWe_out(memWe_IDEX),
        .isFromMem_out(isFromMem_IDEX),
        .isFromPC4_out(isFromPC4_IDEX),
        .bIsImm_out(bIsImm_IDEX),
        .bIs20bImm_out(bIs20bImm_IDEX),
        .pcSource_out(pcSource_IDEX),
        .funct3_out(funct3_IDEX),    
        .isBranch_out(isBranch_IDEX) 
    );

    ALU alu_inst (
        .dataA(aluA_EX),
        .dataB(aluB_EX),
        .opcode(aluOp_IDEX),
        .result(aluResult_EX),
        .con(aluCon_EX)
    );

    EX_MEM ex_mem_reg (
        .clk(clk),
        .rst(rst),
        .flush(flush_on_jump),
        .pc_in(pc_IDEX),
        .aluResult_in(aluResult_EX),
        .readData2_in(forwardedB),
        .imm_in(imm_IDEX),           
        .rd_in(rd_IDEX),
        .regWe_in(regWe_IDEX),
        .memWe_in(memWe_IDEX),
        .isFromMem_in(isFromMem_IDEX),
        .isFromPC4_in(isFromPC4_IDEX),
        .pcSource_in(pcSource_EX_corrected),  
        .pc_out(pc_EXMEM),
        .aluResult_out(aluResult_EXMEM),
        .readData2_out(readData2_EXMEM),
        .imm_out(imm_EXMEM),         
        .rd_out(rd_EXMEM),
        .regWe_out(regWe_EXMEM),
        .memWe_out(memWe_EXMEM),
        .isFromMem_out(isFromMem_EXMEM),
        .isFromPC4_out(isFromPC4_EXMEM),
        .pcSource_out(pcSource_EXMEM)
    );

    MEM_WB mem_wb_reg (
        .clk(clk),
        .rst(rst),
        .pc_in(pc_EXMEM),
        .aluResult_in(aluResult_EXMEM),
        .memReadData_in(data_readData),  // 使用独立的数据读取接口
        .rd_in(rd_EXMEM),
        .regWe_in(regWe_EXMEM),
        .isFromMem_in(isFromMem_EXMEM),
        .isFromPC4_in(isFromPC4_EXMEM),
        .pc_out(pc_MEMWB),
        .aluResult_out(aluResult_MEMWB),
        .memReadData_out(memReadData_MEMWB),
        .rd_out(rd_MEMWB),
        .regWe_out(regWe_MEMWB),
        .isFromMem_out(isFromMem_MEMWB),
        .isFromPC4_out(isFromPC4_MEMWB)
    );

    HazardDetection hazard_unit (
        .rs1_ID(rs1_ID),
        .rs2_ID(rs2_ID),
        .rd_EX(rd_IDEX),
        .isFromMem_EX(isFromMem_IDEX),
        .opcode_ID(opcode_ID),
        .stall(stall),
        .flush_IFID(flush_IFID),
        .flush_IDEX(flush_IDEX)
    );

    ForwardingUnit forwarding_unit (
        .rs1_EX(rs1_IDEX),
        .rs2_EX(rs2_IDEX),
        .rd_MEM(rd_EXMEM),
        .rd_WB(rd_MEMWB),
        .regWe_MEM(regWe_EXMEM),
        .regWe_WB(regWe_MEMWB),
        .forwardA(forwardA),
        .forwardB(forwardB)
    );

    always @(*) begin
        case (forwardA)                       //数据转发的相应编码
            2'b00: forwardedA = readData1_IDEX;  //没有转发
            2'b01: forwardedA = writeData_WB;   //wb转发
            2'b10: forwardedA = aluResult_EXMEM;     //MEM转发
            default: forwardedA = readData1_IDEX;
        endcase

        case (forwardB)
            2'b00: forwardedB = readData2_IDEX;
            2'b01: forwardedB = writeData_WB;
            2'b10: forwardedB = aluResult_EXMEM;
            default: forwardedB = readData2_IDEX;
        endcase
    end

    always @(*) begin
        aluA_EX = forwardedA;      //这段是ALU的输入的多路选择器
        if (bIs20bImm_IDEX || bIsImm_IDEX)
            aluB_EX = imm_IDEX;
        else
            aluB_EX = forwardedB;
    end

    always @(*) begin
        if (isFromPC4_MEMWB)
            writeData_WB = pc_MEMWB + 4;
        else if (isFromMem_MEMWB)
            writeData_WB = memReadData_MEMWB;   //这段是写回的多路选择器
        else
            writeData_WB = aluResult_MEMWB;
    end

    always @(*) begin
        if (bIs20bImm_ID) begin    //20位立即数
            // 区分 LUI U型和 J型 的立即数格式
            if (opcode_ID == 7'b1101111)  // JAL指令
                imm_ID = imm_J_ID;  // 使用J型立即数
            else  // LUI指令 (0110111)
                imm_ID = imm_U_ID;  // 使用U型立即数
        end
        else if (opcode_ID == 7'b1100011)  // 修改分支指令使用B型立即数
            imm_ID = imm_B_ID;
        else if (bIsImm_ID)      //s型立即数 还是I型立即数
            imm_ID = (opcode_ID == 7'b0100011) ? imm_S_ID : imm_I_ID;
        else           //没有立即数
            imm_ID = 32'h0;
    end

    always @(*) begin
        regWe_ID = 1'b0;
        memWe_ID = 1'b0;
        bIsImm_ID = 1'b0;      //初始化所有控制信号为0
        bIs20bImm_ID = 1'b0;
        isFromMem_ID = 1'b0;
        isFromPC4_ID = 1'b0;
        pcSource_ID = 2'b00;
        aluOp_ID = 4'b0000;
        isBranch_ID = 1'b0;    

        case (opcode_ID)
            7'b0110011: begin
                regWe_ID = 1'b1;    //允许写寄存器的指令
                case ({funct7_ID, funct3_ID})
                    10'b0000000000: aluOp_ID = 4'b0000; // ADD
                    10'b0100000000: aluOp_ID = 4'b1000; // SUB
                    10'b0000000111: aluOp_ID = 4'b0111; // AND
                    10'b0000000110: aluOp_ID = 4'b0110; // OR
                    10'b0000000100: aluOp_ID = 4'b0100; // XOR
                    10'b0000000001: aluOp_ID = 4'b0001; // SLL
                    10'b0000000101: aluOp_ID = 4'b0101; // SRL
                    10'b0100000101: aluOp_ID = 4'b1101; // SRA
                    default: aluOp_ID = 4'b0000;
                endcase
            end

            7'b0010011: begin
                regWe_ID = 1'b1;   // 允许写寄存器的指令
                bIsImm_ID = 1'b1;  //并且使用立即数的指令
                case (funct3_ID)
                    3'b000: aluOp_ID = 4'b0000; // ADDI
                    3'b111: aluOp_ID = 4'b0111; // ANDI
                    3'b110: aluOp_ID = 4'b0110; // ORI
                    3'b100: aluOp_ID = 4'b0100; // XORI
                    3'b001: aluOp_ID = 4'b0001; // SLLI
                    3'b101: aluOp_ID = (funct7_ID[5]) ? 4'b1101 : 4'b0101; // SRAI/SRLI
                    default: aluOp_ID = 4'b0000;
                endcase
            end

            7'b0000011: begin
                regWe_ID = 1'b1;
                bIsImm_ID = 1'b1;    //内存的加载
                isFromMem_ID = 1'b1;
                aluOp_ID = 4'b0000;
            end

            7'b0100011: begin
                bIsImm_ID = 1'b1;
                memWe_ID = 1'b1;    //内存的存入
                aluOp_ID = 4'b0000;
            end

            7'b1100011: begin    //分支指令 ID阶段只标记，EX阶段判断
                regWe_ID = 1'b0;   //不写寄存器
                isBranch_ID = 1'b1; // 标记为分支指令
                pcSource_ID = 2'b01; // 暂时假设跳转，EX阶段会根据条件修正
                
            end    //条件跳转指令

            7'b0110111: begin
                regWe_ID = 1'b1;
                bIs20bImm_ID = 1'b1;
                aluOp_ID = 4'b1111;   //加载高位立即数
            end

            7'b1101111: begin
                regWe_ID = 1'b1;
                bIs20bImm_ID = 1'b1;
                isFromPC4_ID = 1'b1;
                pcSource_ID = 2'b10;   //JAL指令
            end

            7'b1100111: begin
                regWe_ID = 1'b1;
                bIsImm_ID = 1'b1;
                isFromPC4_ID = 1'b1;
                pcSource_ID = 2'b11;   //JALR指令
                aluOp_ID = 4'b0000;   
            end

            default: begin
            end
        endcase
    end

   
    reg branchTaken_EX;  // EX阶段判断分支是否成立
    always @(*) begin
        branchTaken_EX = 1'b0;  // 默认不跳转
        if (isBranch_IDEX) begin
            case (funct3_IDEX)
                3'b000: branchTaken_EX = (forwardedA == forwardedB);  // BEQ
                3'b001: branchTaken_EX = (forwardedA != forwardedB);  // BNE
                3'b100: branchTaken_EX = ($signed(forwardedA) < $signed(forwardedB));  // BLT
                3'b101: branchTaken_EX = ($signed(forwardedA) >= $signed(forwardedB)); // BGE
                3'b110: branchTaken_EX = (forwardedA < forwardedB);   // BLTU
                3'b111: branchTaken_EX = (forwardedA >= forwardedB);  // BGEU
                default: branchTaken_EX = 1'b0;
            endcase
        end
    end

    // 如果是分支指令且条件不成立，改为顺序执行
    reg [1:0] pcSource_EX_corrected;
    always @(*) begin
        if (isBranch_IDEX && !branchTaken_EX) begin
            pcSource_EX_corrected = 2'b00;  // 分支不成立，顺序执行
        end else begin
            pcSource_EX_corrected = pcSource_IDEX;  // 保持原有pcSource
        end
    end

    reg [31:0] pc_next; 
    reg prev_jump;  // 记录上个周期是否发生了跳转

    always @(*) begin
       
        pc_next = pc + 32'd4;

     
        // 如果上个周期已经跳转,本周期忽略pcSource信号(防止重复跳转)
        if (!prev_jump) begin
            case (pcSource_EXMEM)
                2'b00: pc_next = pc + 32'd4;  // 正常顺序执行
                2'b01: pc_next = pc_EXMEM + imm_EXMEM;  //使用MEM阶段的立即数
                2'b10: pc_next = pc_EXMEM + imm_EXMEM;  
                2'b11: pc_next = aluResult_EXMEM & 32'hFFFFFFFE;  // 使用ALU计算的结果
                default: pc_next = pc + 32'd4;
            endcase
        end
    end

    // PC寄存器更新
    always @(posedge clk) begin
        if (rst) begin
            pc <= 32'h00004000;   // 复位到程序起始地址
            prev_jump <= 1'b0;
        end else begin
            if (!stall) begin
                pc <= pc_next;
                prev_jump <= (pcSource_EXMEM != 2'b00);  // 记录本周期是否跳转
            end else begin
                prev_jump <= 1'b0;  // stall时清除prev_jump,避免永久阻塞
            end
        end
    end

    // 跳转flush逻辑：当发生跳转时需要flush流水线
    assign flush_on_jump = (pcSource_EXMEM != 2'b00);

endmodule