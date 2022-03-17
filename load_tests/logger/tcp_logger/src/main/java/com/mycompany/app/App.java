package com.mycompany.app;

import org.apache.logging.log4j.LogManager;
import java.util.concurrent.TimeUnit;
import org.apache.logging.log4j.Logger;

public class App
{
    private static final Logger logger;
    private static int TIME;
    private static int ITERATION;
    private static String ONE_KB_TEXT;
    
    public static void main(final String[] args) throws InterruptedException {

        String tmp = System.getenv("TIME");
        if (tmp != null) {
            try {
                App.TIME = Integer.parseInt(tmp);
            }
            catch (NumberFormatException e) {
                e.printStackTrace();
            }
        }
        tmp = System.getenv("ITERATION");
        if (tmp != null) {
            try {
                App.ITERATION = Integer.parseInt(tmp.replace("m", "")) * 1000;
            }
            catch (NumberFormatException e) {
                e.printStackTrace();
            }
        }

        if (System.getenv("DEBUG_TCP_LOGGER") != null && System.getenv("DEBUG_TCP_LOGGER").equals("true")) {
            System.out.println("Starting Load Test. Iteration " + App.ITERATION + ". On port: " + System.getenv("LOGGER_PORT") + ". Time: " + App.TIME);
        }

        final ClassLoader loader = App.class.getClassLoader();
        final long testStartTime = System.currentTimeMillis();
        long testExpectedTime = System.currentTimeMillis();
        for (int i = 0; i < App.TIME; ++i) {
            final long batchStartTime = System.currentTimeMillis();
            for (int k = 0; k < App.ITERATION; ++k) {
                App.logger.info("" + (10000000 + i*App.ITERATION + k) + "_" + batchStartTime + "_" + App.ONE_KB_TEXT);
            }
            testExpectedTime += 1000L;
            final long deltaTime = testExpectedTime - System.currentTimeMillis();
            TimeUnit.MILLISECONDS.sleep(deltaTime);
        }
    }
    
    static {
        logger = LogManager.getLogger((Class)App.class);
        App.TIME = 10;
        App.ITERATION = 1;
        App.ONE_KB_TEXT = "RUDQEWDDKBVMHPYVOAHGADVQGRHGCNRDCTLUWQCBFBKFGZHTGEUKFXWNCKXPRWBSVJGHEARMDQGVVRFPVCIBYEORHYPUTQJKUMNZJXIYLDCJUHABJIXFPUNJQDORGPKWFLQZXIGVGCWTZCVWGBFSGVXGEITYKNTWCYZDOAZFOTXDOFRPECXBSCSORSUUNUJZEJZPTODHBXVMOETBRFGNWNZHGINVNYZPKKSFLZHLSSDHFGLTHZEKICPGNYSCTAIHARDDYIJHKLMAOIDLEKRXMFNVJOJVDFYKNVIQKCIGTRFWKJRHQSFDWWKTJNMNKFBOMBMZMRCOHPUFZEPTQTZBLBDBZPJJXRYDFSOWKDVZLZYWSJYFTCKQJFPQOMCWQHKLNHUGWWVBGTRLLVUHTPHTKNBSRUNNOIFGIJPBHPCKYXNGDCQYJEWFFKRRTHJDUBEZPJIXMAOLZQDZQAYEUZFRLTLTXNGAVAGZZDUERZWTJVDTXPKOIRTCKTFOFJAXVFLNKPBYOIYVPHUYBRZZORCEMMAUTZIAUSXVDTKHSUIRTSYWQMYZBMUGSATXPNESEVQMUKHYZFWSLHJDNYUQWOKDUTUKPRXBLIYGSCFGBGXATINMMCWNWBGJTLZTPKGBTPWTHQPUHDJITWPCJLGZFNZTCIEWWVTREFCTPVOUADQCRQCBRHNHDKGQIXHIWGGDGAAFYZRODKFTKQATAUDOMZTSQUYZHGNJOBSUJDHESPBOIJCGXPEZMMQJNFTYBJEYXPZAZICZJKEZKCZEUMZTTSQEHADOVMCDMDEBUJAPKIAEYQEWIYZSAYAWAGFSTBJYCUFZHMJMLCTVTZWGCPDAURQYSXVICLVWKPAOMVTQTESYFPTMNMSNZPUXMDJRDKHDRAIRYELEXRJUAMOLZVWNHGNVFETVUDZEIDJRPSHMXAZDZXDCXMUJTPDTDUHBAZGPIQOUNUHMVLCZCSUUHGTE";
    }
}
