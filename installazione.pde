import processing.video.*;
import org.openkinect.freenect.*;
import org.openkinect.processing.*;
import com.sun.jna.*;

final boolean DEBUG = true;

Movie video;
Kinect kinect;
volatile int depthThreshold;
float videoKinectRatio;

void setup() {
  fullScreen();
  textSize(16);
  fill(255);
  
  // setup Kinect
  kinect = new Kinect(this);
  kinect.initDepth();
  kinect.enableColorDepth(true);
  depthThreshold = 110;
  
  // setup video
  video = new Movie(this, "background.mp4");
  video.loop();
  video.read();
  
  // calculating ratio between video and kinect
  if(video.height < kinect.height) {
    exit(
      "Background video resolution is smaller than Kinect camera one.",
      "Please provide a bigger resolution background video."
    );
  }
  if(video.height - kinect.height >= video.width - kinect.width) {
    videoKinectRatio = video.height / kinect.height;
  } else {
    videoKinectRatio = video.width / kinect.width;
  }
}

void draw() {
  if(video.available()) {
    video.read();
    
    // get Kinect depth image
    // HACK: copy() used in order to circumvent a Kinect library IndexOutOfBoundException
    PImage depthImage = kinect.getDepthImage().copy(); //<>//
    
    // scale and crop it to fit video size without distorsions
    depthImage.resize((int) (kinect.width * videoKinectRatio), (int) (kinect.height * videoKinectRatio));
    depthImage = depthImage.get(depthImage.width / 2 - video.width/2, depthImage.height / 2 - video.height/2, video.width, video.height);
    //if (video.width != depthImage.width || video.height != depthImage.height) {
      //exit();
    //}
    //image(depthImage, 0, 0);
    
    // Mask the video with Kinect depth data
    video.loadPixels();
    depthImage.loadPixels();
    for(int x = 0; x < depthImage.width; x++) {
      for(int y = 0; y < depthImage.height; y++) {
        int offset = x + y * depthImage.width;
        var depth = hue(depthImage.pixels[offset]);
        if (depth > depthThreshold) {
          video.pixels[offset] = color(0);
        }
      }
    }
    video.updatePixels();
    
    // displaying the masked video frame
    // HACK: scaling seems to lower framerate. ATM has been disabled.
    image(video, 0, 0);
  }
  
  // Print debug info onscreen
  if (DEBUG) {
    fill(0xFF4281A4);
    rect(0, height - 30, 600, height);
    fill(255);
    text(
      "Video/Kinect ratio: " + videoKinectRatio + " - Depth threshold: " + depthThreshold,
      10,
      height - 10
    );
  }
}

void keyPressed() {
  if (key == CODED) {
    if (keyCode == UP) {
      depthThreshold++;
    } else if (keyCode == DOWN) {
      depthThreshold--;
    }
  }
}

void exit(final String errorMessage) {
  exit(errorMessage, "");
}

void exit(final String errorMessage, final String explanationMessage) {
  if(video.height < kinect.height) {
    fill(color(0xFFC1666B));
    rect(0, 0, width, height);
    fill(255);
    textAlign(CENTER);
    textSize(48);
    text(errorMessage, width/2, height/2);
    textSize(16);
    text(explanationMessage, width/2, height/2 + 30);
    while(true) {
      delay(999999999);
    }
  }
}
