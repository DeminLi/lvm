使用说明

1. 运行环境: 理论上支持所有的linux 2.6内核以上系统(linux c编的嘛), 目前只在Ubuntu, Redhat上测试过

2. 使用方法: 
 2.1. 编译wr.c 和 args.c. args.c编译后的文件务必命名为vm.out, wr.c的随意. 然后将两者编译后的文件放在同一目录下
 2.2. 运行后出现">>>"的等待输入提示符时, 表明已经默认建好了两个虚拟机vm1和vm2
 2.3. 若想操作某台虚拟机, 命令格式为vm<number> <your command>. 例如, 我希望查看vm1的所有网口信息, 则需要输入: vm1 ifconfig -a
 2.4. 与KVM类似, 在主机中创建了两个虚拟网口vm1和vm2(类似于vnet0 vnet1). 他们的操作和vnet0和vnet1相同. 例如要将他们放入br0中, 直接在主机的终端中(不是">>>"了)输入命令: ovs-vsctl add-port br0 vm1 即可.

3. 目前尚未修复的漏洞:
 3.1. 无法停止无限输出结果的命令, 例如ping <ip>. 解决该问题方法有两个, 一是手动杀掉该命令所触发的进程, 二是尽量避免输入有无限输出结果的命令, 例如改用ping -w 4 <ip>

4. 可能遇到的问题:
 5.1. 某些莫名其妙的问题可能来自于wr.out的权限不够. 解决方式就是更改其权限: chmod 777 wr.out
 5.2. 错误提示:RTNETLINK answers: File exists. 解决方法是在主机终端: ip link delete vm1 type veth; ip link delete vm2 type veth

5. 下一版改进计划:
 5.1. 修复3.1的漏洞
 5.2. 精简算法

6. 下下一版改进计划:
 6.1. 使用makefile编译程序
 6.2. 可启动任意数量的虚拟机

7. 如果遇到其他问题或者有改进的想法, 请骚扰!

Any question, feel free to contact me.