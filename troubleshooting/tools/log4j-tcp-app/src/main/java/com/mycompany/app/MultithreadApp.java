package com.mycompany.app;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import java.util.concurrent.*;


public class MultithreadApp {
    private static final Logger logger = LogManager.getLogger(MultithreadApp.class);
    private static int LOGGER_THREADS = 20;
    private static long LOGGER_ITERATIONS = 1000000;
    private static int LOG_SIZE_BYTES = 1000;
    private static long LOGGER_SLEEP_MS = 1000;

	public static void main(String[] args) throws InterruptedException {
		CountDownLatch latch = new CountDownLatch(LOGGER_THREADS);
		Runnable app_instance;
		Thread thread;
		boolean infinite = false;
		
		System.out.println("log4j app multithread Mar-6-22");
		
		LOGGER_THREADS = Integer.parseInt(System.getenv("LOGGER_THREADS"));
		LOGGER_ITERATIONS = Integer.parseInt(System.getenv("LOGGER_ITERATIONS"));
		LOG_SIZE_BYTES = Integer.parseInt(System.getenv("LOG_SIZE_BYTES"));
		LOGGER_SLEEP_MS = Integer.parseInt(System.getenv("LOGGER_SLEEP_MS"));
		
		String is_infinite = System.getenv("INFINITE");
		if (is_infinite.startsWith("y") || is_infinite.startsWith("Y") || is_infinite.startsWith("T") ||  is_infinite.startsWith("t") ) {
			infinite = true;
		}
		
		for (int i=0; i < LOGGER_THREADS; i++) {
			app_instance = new LoggerApp(latch, i, LOGGER_ITERATIONS, LOG_SIZE_BYTES, LOGGER_SLEEP_MS, infinite);

			thread = new Thread(app_instance);
			thread.start();
		}
		
		latch.await();
	}

}

class LoggerApp implements Runnable {
	private static final Logger logger = LogManager.getLogger(LoggerApp.class);

	
	private CountDownLatch latch;
	private int ID;
	private long iterations;
	private int log_size;
	private long logger_sleep_ms;
	private boolean infinite;
	
	public LoggerApp(CountDownLatch latch, int ID, long iterations, int log_size, long logger_sleep_ms, boolean infinite) {
		this.latch = latch;
		this.ID = ID;
		this.iterations = iterations;
		this.log_size = log_size;
		this.logger_sleep_ms = logger_sleep_ms;
		this.infinite = infinite;
	}

    public void run(){
    	int count = 0;
    	System.out.println("running logger instance " + this.ID + "...");
    	String padding = createPadding(this.log_size);
    	boolean iterate = true;
    	
    	while (iterate) {
	        for (int i=0; i < this.iterations; i++) {
	            try {
	        		Thread.sleep(this.logger_sleep_ms);
	        	} catch (InterruptedException e) {
	        		// TODO Auto-generated catch block
	        		e.printStackTrace();
	        	}
	        	logger.debug("Thread " + this.ID + ": "+ i + " " + padding);
	            logger.info("Thread " + this.ID + ": "+ i + " " + padding);
	        }
	        count++;
	        System.out.println("logger instance " + this.ID + " completed set " + count + " of interations..");
	        iterate = this.infinite;
    	}
        latch.countDown();
       
    }
    
    private static String createPadding(int msgSize) {
  	  StringBuilder sb = new StringBuilder(msgSize);
  	  for (int i=0; i<msgSize; i++) {
  	    sb.append('x');
  	  }
  	  return sb.toString();
  	}
  }
