#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/time.h>
#include <errno.h>    
#include <unistd.h>
#include <string.h>
#include <math.h>

// Large text of exactly 1000 bytes
#define ONE_KB_TEXT "GRHGCNRDCTLUWQCBFBKFGZHTRUDQEWDDKBVMHPYVOAHGADVQGRHGCNRDCTLUWQCBFBKFGZHTGEUKFXWNCKXPRWBSVJGHEARMDQGVVRFPVCIBYEORHYPUTQJKUMNZJXIYLDCJUHABJIXFPUNJQDORGPKWFLQZXIGVGCWTZCVWGBFSGVXGEITYKNTWCYZDOAZFOTXDOFRPECXBSCSORSUUNUJZEJZPTODHBXVMOETBRFGNWNZHGINVNYZPKKSFLZHLSSDHFGLTHZEKICPGNYSCTAIHARDDYIJHKLMAOIDLEKRXMFNVJOJVDFYKNVIQKCIGTRFWKJRHQSFDWWKTJNMNKFBOMBMZMRCOHPUFZEPTQTZBLBDBZPJJXRYDFSOWKDVZLZYWSJYFTCKQJFPQOMCWQHKLNHUGWWVBGTRLLVUHTPHTKNBSRUNNOIFGIJPBHPCKYXNGDCQYJEWFFKRRTHJDUBEZPJIXMAOLZQDZQAYEUZFRLTLTXNGAVAGZZDUERZWTJVDTXPKOIRTCKTFOFJAXVFLNKPBYOIYVPHUYBRZZORCEMMAUTZIAUSXVDTKHSUIRTSYWQMYZBMUGSATXPNESEVQMUKHYZFWSLHJDNYUQWOKDUTUKPRXBLIYGSCFGBGXATINMMCWNWBGJTLZTPKGBTPWTHQPUHDJITWPCJLGZFNZTCIEWWVTREFCTPVOUADQCRQCBRHNHDKGQIXHIWGGDGAAFYZRODKFTKQATAUDOMZTSQUYZHGNJOBSUJDHESPBOIJCGXPEZMMQJNFTYBJEYXPZAZICZJKEZKCZEUMZTTSQEHADOVMCDMDEBUJAPKIAEYQEWIYZSAYAWAGFSTBJYCUFZHMJMLCTVTZWGCPDAURQYSXVICLVWKPAOMVTQTESYFPTMNMSNZPUXMDJRDKHDRAIRYELEXRJUAMOLZVWNHGNVFETVUDZEIDJRPSHMXAZDZXDCXMUJTPDTDUHBAZGPIQOUNUHMVLCZCSUUHGTE"

long long timeInMilliseconds(void) {
    struct timeval tv;

    gettimeofday(&tv,NULL);
    return (((long long)tv.tv_sec)*1000)+(tv.tv_usec/1000);
}

/* msleep(): Sleep for the requested number of milliseconds. */
void msleep(long msec)
{
    struct timespec ts;
    int res;

    if (msec < 0)
    {
        errno = EINVAL;
    }

    ts.tv_sec = msec / 1000;
    ts.tv_nsec = (msec % 1000) * 1000000;

    do {
        res = nanosleep(&ts, &ts);
    } while (res && errno == EINTR);
}

int main()
{
    int sizeInKb = atoi(getenv("SIZE_IN_KB"));
    int totalSizeInKb = atoi(getenv("TOTAL_SIZE_IN_MB")) * 1000;
    int throughputInKb = atoi(getenv("THROUGHPUT_IN_KB"));
    int cycleTimeInS = atoi(getenv("CYCLE_TIME_IN_SECONDS"));
    int cycleTimeInMs = cycleTimeInS * 1000;
    int j = 0;
    long long startSeconds;
    long long endSeconds;
    long long timeDiff;
    long long loggingStart;
    long long loggingEnd;
    long long actualTimeElapsed = 0;
    long long expectedTimeElapsed = 0;

    char *noSleep = getenv("NO_SLEEP");

    int idCounter = 10000000;
    char* data = malloc(strlen(ONE_KB_TEXT) * sizeInKb + 1);
    if (!data) {
        printf("malloc failure");
        return 1;
    }

    int totalMessages = totalSizeInKb / sizeInKb;
    int messagesSent = 0;
    int messagesPerCycle = (throughputInKb * cycleTimeInS) / sizeInKb;
    int messagesThisCycle = 0;

    char *burst_enabled = getenv("BURST_SIZE_IN_MB");
    int burstSizeInMB = 0;
    int burstThroughputInKb = 0;
    int burstMessagesPerCycle = 0;
    int totalBurstMessages = 0;
    int burstDelayInMB = 0;
    int burstDelayMessages = 0;
    if (burst_enabled != NULL) {
        burstSizeInMB = atoi(burst_enabled);
        burstThroughputInKb = atoi(getenv("BURST_THROUGHPUT_IN_KB"));
        if ((burstSizeInMB * 2 * 1000) > totalSizeInKb) {
            printf("ERROR: BURST_SIZE_IN_MB must be less than half of TOTAL_SIZE_IN_MB");
            return 1;
        }
        totalBurstMessages = (burstSizeInMB * 1000) / sizeInKb;
        burstDelayInMB = atoi(getenv("BURST_DELAY_IN_MB")); /* how far into the full output should burst start */
        if ((burstDelayInMB + burstSizeInMB) >= (totalSizeInKb / 1000)) {
            printf("ERROR: BURST_DELAY_IN_MB + BURST_SIZE_IN_MB >= TOTAL_SIZE_IN_MB");
            return 1;
        }
        burstDelayMessages = (burstDelayInMB * 1000) / sizeInKb;
        burstMessagesPerCycle = (burstThroughputInKb * cycleTimeInS) / sizeInKb;
    }

    // build log message size
    for (int i = 0; i < sizeInKb; i++)
    {
        snprintf(&data[strlen(data)], strlen(ONE_KB_TEXT) + 1, "%s", ONE_KB_TEXT);
    }

    printf("sizeInKb: %d\n", sizeInKb);
    printf("totalSizeInKb: %d\n", totalSizeInKb);
    printf("throughputInKb: %d\n", throughputInKb);
    printf("cycleTimeInS: %d\n", cycleTimeInS);
    printf("cycleTimeInMs: %d\n", cycleTimeInMs);
    printf("messagesPerCycle: %d\n", messagesPerCycle);
    printf("totalMessages: %d\n", totalMessages);

    loggingStart = timeInMilliseconds();

    // send messages until total count reached
    while (messagesSent < totalMessages)
    {
        j = 0;
        startSeconds = timeInMilliseconds();


        if (messagesSent >= burstDelayMessages && messagesSent < (burstDelayMessages + totalBurstMessages)) {
            messagesThisCycle = burstMessagesPerCycle;
        } else {
            messagesThisCycle = messagesPerCycle;
        }

        /* 
         * from research, log4j and probably other logs do buffered flushing to files/stdout
         * so we write all messages per cycle, then fflush(stdout)
         */
        while (j < messagesThisCycle && messagesSent < totalMessages) {
            printf("%d_%lld_%s\n", idCounter, startSeconds, data);
            idCounter++;
            j++;
            messagesSent++;
        }
        fflush(stdout);

        endSeconds = timeInMilliseconds();
        timeDiff = startSeconds - endSeconds;
        expectedTimeElapsed += cycleTimeInMs;
        actualTimeElapsed = endSeconds - loggingStart;

        if (actualTimeElapsed < expectedTimeElapsed)
        {   
            if (noSleep == NULL) {
                msleep((expectedTimeElapsed - actualTimeElapsed));
            }
        }
    }

    loggingEnd = timeInMilliseconds();
    timeDiff = loggingEnd - loggingStart;
    double timeDiffD = (double) timeDiff;
    double sizeSent = (double) messagesSent * sizeInKb;
    double realThroughput = sizeSent / (timeDiff / 1000);
    printf("real runtime: %lldms\n", timeDiff);
    printf("emitted: %dkb\n", messagesSent * sizeInKb);
    printf("real throughput: %fKB/s\n", realThroughput);

    /* write to file to save results when writing to remove log driver */
    FILE *f = fopen("/results/throughput.txt", "w");
    if (f == NULL)
    {
        printf("Error opening file!\n");
        /* 
         * if a volume isn't configured for this path it might fail 
         * so just exit with success. When we run in ECS validator has a SUCCESS
         * dependency on logger. 
         */
        return 0;
    }
    fprintf(f, "real runtime: %lldms\n", timeDiff);
    fprintf(f, "emitted: %dkb\n", messagesSent * sizeInKb);
    fprintf(f, "real throughput: %fKB/s\n", realThroughput);
    fclose(f);

    return 0;
}