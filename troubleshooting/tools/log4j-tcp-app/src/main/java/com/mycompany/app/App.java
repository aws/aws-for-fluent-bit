package com.mycompany.app;

//import org.apache.log4j.Logger;
//
//import org.slf4j.Logger;
//import org.slf4j.LoggerFactory;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import java.util.*;

/**
 * Hello world!
 *
 */
public class App 
{
    private static final Logger logger = LogManager.getLogger(App.class);
    private static int LOOP_ITERATIONS = 40;
    private static int INNER_LOOP_ITERATIONS = 12500;
    private static int LOG_PADDING = 20000;

//	static org.apache.log4j.Logger log = org.apache.log4j.Logger.getLogger(App.class.getName());
    public static void main( String[] args ) throws InterruptedException
    {
    	String tmp;
        System.out.println( "Hello World! v5: 2 second sleep, 1 mil logs" );
        //System.out.println(Thread.currentThread().getContextClassLoader().getResource("log4j.properties"));
        ClassLoader loader = App.class.getClassLoader();
        // System.out.println(loader.getResource("App.class"));
        
        tmp = System.getenv("LOOP_ITERATIONS");
        if (tmp != null) {
        	try {
        		LOOP_ITERATIONS = Integer.parseInt(tmp);
        	}
        	catch (NumberFormatException e) {
        		e.printStackTrace();
        	}
        }
        
        tmp = System.getenv("LOG_PADDING");
        if (tmp != null) {
        	try {
        		LOG_PADDING = Integer.parseInt(tmp);
        	}
        	catch (NumberFormatException e) {
        		e.printStackTrace();
        	}
        }
        
        String padding = createPadding(LOG_PADDING);
        
        logger.debug("Hello this is a debug message");
        logger.info("Hello this is an info message");
        
        double[] metrics = new double[LOOP_ITERATIONS];
        double total = 0;
        long total_ms = 0;
        
        
        for (int i=0; i < LOOP_ITERATIONS; i++) {
        
	        long startTime = System.currentTimeMillis();
	
	        
	        for (int k=0; k < INNER_LOOP_ITERATIONS; k++) {
	        	logger.debug("Hello " + i + " " + padding);
	            logger.info("Hello " + i + " " + padding);
	        }
	        
	        long endTime = System.currentTimeMillis();
	        
	        long elapsedms = (endTime - startTime);
	        total_ms += elapsedms;
	        
	        
	        long seconds = (endTime - startTime)/1000;
	        long milli = (endTime - startTime) % 1000;
	        double logspermillisecond = (INNER_LOOP_ITERATIONS * 2)/elapsedms;
	        total += logspermillisecond;
	        metrics[i] = logspermillisecond;
	        
	        System.out.println("Iteration: " + i);
	        System.out.println("Sent: " + (INNER_LOOP_ITERATIONS * 2) + " logs");
	        System.out.println("Log size: " + LOG_PADDING + " bytes");
	        System.out.println("Runtime: " + seconds + "." + milli + "s\nRate: " + logspermillisecond + " logs/ms");
	        System.out.println("Total execution time: " + (endTime - startTime)  + "ms");
	        System.out.println("_____________");
	        java.util.concurrent.TimeUnit.SECONDS.sleep(2);
        }
        System.out.println("AVERAGE RATE: " + (total / LOOP_ITERATIONS) + " logs/ms");
        System.out.println("AVERAGE RATE good math: " + ((LOOP_ITERATIONS * INNER_LOOP_ITERATIONS * 2)/ total_ms) + " logs/ms");
       
        double stdev = calculateStandardDeviation(metrics);
        System.out.println("STDEV: " + stdev + " logs/ms");
        
    }
    
    private static String createPadding(int msgSize) {
    	  StringBuilder sb = new StringBuilder(msgSize);
    	  for (int i=0; i<msgSize; i++) {
    	    sb.append('x');
    	  }
    	  return sb.toString();
    }
    
	private static double calculateStandardDeviation(double[] array) {

		// finding the sum of array values
		double sum = 0.0;

		for (int i = 0; i < array.length; i++) {
			sum += array[i];
		}

		// getting the mean of array.
		double mean = sum / array.length;

		// calculating the standard deviation
		double standardDeviation = 0.0;
		for (int i = 0; i < array.length; i++) {
			standardDeviation += Math.pow(array[i] - mean, 2);

		}

		return Math.sqrt(standardDeviation/array.length);
	}
}
