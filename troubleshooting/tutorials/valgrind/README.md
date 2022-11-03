# Tutorial: Testing for Memory Leaks in Fluent Bit

## Purpose

Valgrind is a multipurpose code profiling and memory debugging software that runs on Linux. It mainly includes tools such as Memcheck, Callgrind, Cachegrind, etc.

Each tool can complete a task of debugging, detection or analysis. Can detect memory leaks, thread violations and Cache usage. Valgrind debugs programs based on emulation. It obtains control of the actual processor before the application, emulates a virtual processor on the basis of the actual processor, and makes the application run on the virtual processor, thereby Monitor the operation of the application. The application does not know whether the processor is virtual or real, and the application that has been compiled into binary code does not need to be recompiled. Valgrind directly interprets the binary code so that the application runs on it, so that it can check the possible occurrences of memory operations. mistake. So programs running under Valgrind run much slower and use much more memory - for example, programs under the Memcheck tool are more than twice as fast as normal. Therefore, it is best to use Valgrind on a machine with good performance.

Here is the official website for [Valgrind](https://valgrind.org/).

## How to Use Valgrind for Fluent-bit

### Preparation

Install Fluent-bit according to the [guidance](https://docs.fluentbit.io/manual/installation/getting-started-with-fluent-bit).

Note: Fluent-bit supports for valgrind that makes it easier for Valgrind to track the stack when Fluent bit switches from one coroutine to another. You must compile it with `cmake -DFLB_VALGRIND=On` to get this support.

### Step for Using Valgrind

Because both fluent-bit and Valgrind support a CLI interface with various flags matching up to the configuration options available. We can directly run fluent-bit with Valgrind like [this](https://github.com/fluent/fluent-bit/blob/master/DEVELOPER_GUIDE.md#valgrind:~:text=valgrind%20./bin/fluent%2Dbit%20%7Bargs%20for%20fluent%20bit%7D).

```
valgrind ./bin/fluent-bit {args for fluent bit}
```

Valgrind will generate a large number of output logs when it is running, so in order to browse all output logs conveniently, it is recommended to store them in a file instead of viewing them directly in the terminal, otherwise it is inconvenient and inconvenient to find, and at the same time It will also cause the loss of many output logs. Use CLI `flag —log-file=“file-name”` will save the output logs to a file named “file-name”. 

Also, add `--leak-check=full` to get more information and `--error-limit=no` which can make Valgrind always shows errors, regardless of how many there are.

## How to Understand Valgrind Output

**At the beginning, the valgrind information "==62414==" indicates the process number:**
```
==62414== Command: ./valgrind_test
==62414== Memcheck, a memory error detector
==62414== Copyright (C) 2002-2017, and GNU GPL'd, by Julian Seward et al.
==62414== Using Valgrind-3.15.0 and LibVEX; rerun with -h for copyright info
```

**Program accesses memory at illegal address, invalid write:**
```
==62414== by 0x400566: main (valgrind_test.c:28)
==62414== Invalid write of size 4
==62414== at 0x40054B: fun (valgrind_test.c:21)
==62414== by 0x400566: main (valgrind_test.c:28)
==62414== Address 0x5201068 is 0 bytes after a block of size 40 alloc'd
==62414== at 0x4C2AEC3: malloc (vg_replace_malloc.c:309)
==62414== by 0x40053E: fun (valgrind_test.c:20)
```

**Heap area condition:**
```
==62414== total heap usage: 1 allocs, 0 frees, 40 bytes allocated
==62414== HEAP SUMMARY:
==62414== in use at exit: 40 bytes in 1 blocks
```

**The memory leak message looks like this:**
```
==62414== 40 bytes in 1 blocks are definitely lost in loss record 1 of 1
==62414== at 0x4C2AEC3: malloc (vg_replace_malloc.c:309)
==62414== by 0x40053E: fun (valgrind_test.c:20)
==62414== by 0x400566: main (valgrind_test.c:28)
```

**There are several kinds of leaks; the two most important categories are, definitely lost, possibly lost:**
```
==62414== LEAK SUMMARY:
==62414== definitely lost: 40 bytes in 1 blocks
==62414== indirectly lost: 0 bytes in 0 blocks
==62414== possibly lost: 0 bytes in 0 blocks
==62414== still reachable: 0 bytes in 0 blocks
==62414== suppressed: 0 bytes in 0 blocks
==62414==
==62414== For lists of detected and suppressed errors, rerun with: -s
==62414== ERROR SUMMARY: 2 errors from 2 contexts (suppressed: 0 from 0)
```

* “definitely lost” means your program is leaking memory – fix those leaks!
* “indirectly lost” means your program is leaking memory in a pointer-based structure. (E.g. if the root node of a binary tree is “definitely lost”, all the children will be “indirectly lost”.) If you fix the “definitely lost” leaks, the “indirectly lost” leaks should go away.
* “possibly lost” means your program is leaking memory, unless you’re doing unusual things with pointers that could cause them to point into the middle of an allocated block; see the user manual for some possible causes. Use —show-possibly-lost=no if you don’t want to see these reports.
* “still reachable” means your program is probably ok – it didn’t free some memory it could have. This is quite common and often reasonable. Don’t use —show-reachable=yes if you don’t want to see these reports.
* “suppressed” means that a leak error has been suppressed. There are some suppressions in the default suppression files. You can ignore suppressed errors.

## How to Stop Valgrind and Get Summary

After beginning valgrind, it will take really long time to get the summary, here is the way to stop it and get leak summary.
For example,  if we start valgrind on a sleep command:
```
[ec2-user@ip-172-31-82-92 ~]$ valgrind sleep 240
==240977== Memcheck, a memory error detector
==240977== Copyright (C) 2002-2022, and GNU GPL'd, by Julian Seward et al.
==240977== Using Valgrind-3.19.0 and LibVEX; rerun with -h for copyright info
==240977== Command: sleep 240
==240977== 
```

then kill that command:
```
[ec2-user@ip-172-31-82-92 ~]$ kill -TERM 240977
```

We will get the leak summary
```
==240977== LEAK SUMMARY:
==240977==    definitely lost: 0 bytes in 0 blocks
==240977==    indirectly lost: 0 bytes in 0 blocks
==240977==      possibly lost: 0 bytes in 0 blocks
==240977==    still reachable: 3,676 bytes in 29 blocks
==240977==         suppressed: 0 bytes in 0 blocks
==240977== Rerun with --leak-check=full to see details of leaked memory
==240977== 
==240977== For lists of detected and suppressed errors, rerun with: -s
==240977== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
Terminated
```

Also, we can use command `kill -SIGUSR1 $pid` or `SIGUSR2` to stop valgrind and get leak summary.



