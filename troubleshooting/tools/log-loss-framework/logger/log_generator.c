#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/time.h>
#include <errno.h>    
#include <unistd.h>
#include <string.h>
#include <math.h>

// Large text around 1Kb
#define ONE_KB_TEXT "RUDQEWDDKBVMHPYVOAHGADVQGRHGCNRDCTLUWQCBFBKFGZHTGEUKFXWNCKXPRWBSVJGHEARMDQGVVRFPVCIBYEORHYPUTQJKUMNZJXIYLDCJUHABJIXFPUNJQDORGPKWFLQZXIGVGCWTZCVWGBFSGVXGEITYKNTWCYZDOAZFOTXDOFRPECXBSCSORSUUNUJZEJZPTODHBXVMOETBRFGNWNZHGINVNYZPKKSFLZHLSSDHFGLTHZEKICPGNYSCTAIHARDDYIJHKLMAOIDLEKRXMFNVJOJVDFYKNVIQKCIGTRFWKJRHQSFDWWKTJNMNKFBOMBMZMRCOHPUFZEPTQTZBLBDBZPJJXRYDFSOWKDVZLZYWSJYFTCKQJFPQOMCWQHKLNHUGWWVBGTRLLVUHTPHTKNBSRUNNOIFGIJPBHPCKYXNGDCQYJEWFFKRRTHJDUBEZPJIXMAOLZQDZQAYEUZFRLTLTXNGAVAGZZDUERZWTJVDTXPKOIRTCKTFOFJAXVFLNKPBYOIYVPHUYBRZZORCEMMAUTZIAUSXVDTKHSUIRTSYWQMYZBMUGSATXPNESEVQMUKHYZFWSLHJDNYUQWOKDUTUKPRXBLIYGSCFGBGXATINMMCWNWBGJTLZTPKGBTPWTHQPUHDJITWPCJLGZFNZTCIEWWVTREFCTPVOUADQCRQCBRHNHDKGQIXHIWGGDGAAFYZRODKFTKQATAUDOMZTSQUYZHGNJOBSUJDHESPBOIJCGXPEZMMQJNFTYBJEYXPZAZICZJKEZKCZEUMZTTSQEHADOVMCDMDEBUJAPKIAEYQEWIYZSAYAWAGFSTBJYCUFZHMJMLCTVTZWGCPDAURQYSXVICLVWKPAOMVTQTESYFPTMNMSNZPUXMDJRDKHDRAIRYELEXRJUAMOLZVWNHGNVFETVUDZEIDJRPSHMXAZDZXDCXMUJTPDTDUHBAZGPIQOUNUHMVLCZCSUUHGTEIQOUNUHMVLCZCSUUHGTEIQOU"

#define MAX(x, y) (((x) > (y)) ? (x) : (y))
#define MIN(x, y) (((x) < (y)) ? (x) : (y))

int getMessagesPerCycle(float throughput, float size)
{
    return ceil(throughput / size);
}

int getMessagesPerMinute(float throughput, float size)
{
    return (throughput * 60) / size;
}

int getTimeBetweenCycle(float messagesPerMinute)
{
    // need to treat messages per minute as a max of 60 opportunities to send messages
    return 60 / MIN(messagesPerMinute, 60) * 1000;
}

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
    int totalSizeInKb = atoi(getenv("TOTAL_SIZE_IN_MB")) * 1024;
    int throughputInKb = atoi(getenv("THROUGHPUT_IN_KB"));
    int shouldBurst = atoi(getenv("SHOULD_BURST"));

    int idCounter = 10000000;
    char* data = malloc(strlen(ONE_KB_TEXT) * sizeInKb + 1);

    int totalMessages = totalSizeInKb / sizeInKb;
    int messagesSent = 0;
    int messagesPerMinute = getMessagesPerMinute(throughputInKb, sizeInKb);
    int timeBetweenCycleInMs = getTimeBetweenCycle(messagesPerMinute);
    int messagesPerCycle = getMessagesPerCycle(throughputInKb, sizeInKb);

    // build log message size
    for (int i = 0; i < sizeInKb; i++)
    {
        snprintf(&data[strlen(data)], strlen(ONE_KB_TEXT) + 1, "%s", ONE_KB_TEXT);
    }

    printf("sizeInKb: %d\n", sizeInKb);
    printf("totalSizeInKb: %d\n", totalSizeInKb);
    printf("throughputInKb: %d\n", throughputInKb);
    printf("shouldBurst: %d\n", shouldBurst);
    printf("messagesPerMinute: %d\n", messagesPerMinute);
    printf("timeBetweenCycleInMs: %d\n", timeBetweenCycleInMs);
    printf("messagesPerCycle: %d\n", messagesPerCycle);
    printf("totalMessages: %d\n", totalMessages);

    // send messages until total count reached
    while (messagesSent < totalMessages)
    {
        int j = 0;
        long long startSeconds;
        long long endSeconds;
        startSeconds = timeInMilliseconds();
        int messagesToSend = shouldBurst ? messagesPerMinute : messagesPerCycle;

        while (j < messagesToSend && messagesSent < totalMessages)
        {
            printf("%d_%lld_%s\n", idCounter, startSeconds, data);
            idCounter++;
            j++;
            messagesSent++;
        }

        // flush after writes
        fflush(stdout);

        endSeconds = timeInMilliseconds();
        int timeToWait = shouldBurst ? 60000 : timeBetweenCycleInMs;

        if (messagesSent < totalMessages)
        {
            msleep(timeToWait + startSeconds - endSeconds);
        }
    }

    return 0;
}