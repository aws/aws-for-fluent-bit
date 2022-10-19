# Tutorial: Fluent Bit Test with Valgrind for Memory Leak

## Introduction

Valgrind is a multipurpose code profiling and memory debugging software that runs on Linux. It mainly includes tools such as Memcheck, Callgrind, Cachegrind, etc.

Each tool can complete a task of debugging, detection or analysis. Can detect memory leaks, thread violations and Cache usage. Valgrind debugs programs based on emulation. It obtains control of the actual processor before the application, emulates a virtual processor on the basis of the actual processor, and makes the application run on the virtual processor, thereby Monitor the operation of the application. The application does not know whether the processor is virtual or real, and the application that has been compiled into binary code does not need to be recompiled. Valgrind directly interprets the binary code so that the application runs on it, so that it can check the possible occurrences of memory operations. mistake. So programs running under Valgrind run much slower and use much more memory - for example, programs under the Memcheck tool are more than twice as fast as normal. Therefore, it is best to use Valgrind on a machine with good performance.

Here is the official website for [Valgrind](https://valgrind.org/).

## How to Use Valgrind for Fluent-bit

### Preparation

If you install fluent-bit follows this [guidance](https://quip-amazon.com/tiE9AahyejAX/Debugging-Fluent-Bit-on-Amazon-Linux-2), then your fluent-bit is stored and run in aws ec2 linux 2 instance, that is, in a linux environment, which also meets the conditions for using valgrind.


### Step for Using Valgrind

Because both fluent-bit and Valgrind support a CLI interface with various flags matching up to the configuration options available. We can directly run fluent-bit with Valgrind like [this](https://github.com/fluent/fluent-bit/blob/master/DEVELOPER_GUIDE.md#valgrind:~:text=valgrind%20./bin/fluent%2Dbit%20%7Bargs%20for%20fluent%20bit%7D).

valgrind ./bin/fluent-bit {args for fluent bit}

Valgrind will generate a large number of output logs when it is running, so in order to browse all output logs conveniently, it is recommended to store them in a file instead of viewing them directly in the terminal, otherwise it is inconvenient and inconvenient to find, and at the same time It will also cause the loss of many output logs. Use CLI flag —log-file=“file-name” will save the output logs to a file named “file-name”.


### How to Understand Output

**At the beginning, the valgrind information "==62414==" indicates the process number:**

==62414== Command: ./valgrind_test
==62414== Memcheck, a memory error detector
==62414== Copyright (C) 2002-2017, and GNU GPL'd, by Julian Seward et al.
==62414== Using Valgrind-3.15.0 and LibVEX; rerun with -h for copyright info


**Program accesses memory at illegal address, invalid write:**

==62414== by 0x400566: main (valgrind_test.c:28)
==62414== Invalid write of size 4
==62414== at 0x40054B: fun (valgrind_test.c:21)
==62414== by 0x400566: main (valgrind_test.c:28)
==62414== Address 0x5201068 is 0 bytes after a block of size 40 alloc'd
==62414== at 0x4C2AEC3: malloc (vg_replace_malloc.c:309)
==62414== by 0x40053E: fun (valgrind_test.c:20)


**Heap area condition:**

==62414== total heap usage: 1 allocs, 0 frees, 40 bytes allocated
==62414== HEAP SUMMARY:
==62414== in use at exit: 40 bytes in 1 blocks

**The memory leak message looks like this:**

==62414== 40 bytes in 1 blocks are definitely lost in loss record 1 of 1
==62414== at 0x4C2AEC3: malloc (vg_replace_malloc.c:309)
==62414== by 0x40053E: fun (valgrind_test.c:20)
==62414== by 0x400566: main (valgrind_test.c:28)

**There are several kinds of leaks; the two most important categories are, definitely lost, possibly lost:**

==62414== LEAK SUMMARY:
==62414== definitely lost: 40 bytes in 1 blocks
==62414== indirectly lost: 0 bytes in 0 blocks
==62414== possibly lost: 0 bytes in 0 blocks
==62414== still reachable: 0 bytes in 0 blocks
==62414== suppressed: 0 bytes in 0 blocks
==62414==
==62414== For lists of detected and suppressed errors, rerun with: -s
==62414== ERROR SUMMARY: 2 errors from 2 contexts (suppressed: 0 from 0)


