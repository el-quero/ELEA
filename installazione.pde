import processing.video.*;
import org.openkinect.freenect.*;
import org.openkinect.processing.*;
import com.sun.jna.*;
import java.lang.Math.*;
import java.util.Arrays;

boolean DEBUG = true;
int[] kinectAdjustmentOffset = {0, -350};

// video to mask
Movie video;

// Kinect device
Kinect kinect;

volatile int depthThreshold;

// ratio of Kinect depth camera video size on bacgrkound video size.
// (> 1 = Kinect is smaller; < 1 = video is smaller)
float videoKinectScale;
float minimuVideoKinectScale;

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
  
  // calculating ratio between video resolution and Kinect depth camera resolution
  if(video.height - kinect.height >= video.width - kinect.width) {
    videoKinectScale = video.height / kinect.height;
  } else {
    videoKinectScale = video.width / kinect.width;
  }
  minimuVideoKinectScale = videoKinectScale;
  
  if(videoKinectScale < 1) {
    exit(
      "Background video size is smaller than Kinect camera one.",
      "Please provide a bigger resolution background video."
    );
  }
  
  // TODO: calculate initial kinectAdjustmentOffset in order to center Kinect depth camera frame
}

void draw() {
  if(video.available()) {
    video.read();
    
    // get Kinect depth image
    // HACK: copy() used in order to circumvent a Kinect library IndexOutOfBoundException
    PImage depthImage = kinect.getDepthImage().copy(); //<>//
    
    // scale and crop it to fit video size without distorsions
    depthImage.resize(ceil(kinect.width * videoKinectScale), ceil(kinect.height * videoKinectScale));
    
    // Mask the video with Kinect depth data
    video.loadPixels();
    depthImage.loadPixels();
    var currentKinectAdjustmentOffset = Arrays.copyOf(kinectAdjustmentOffset, kinectAdjustmentOffset.length);
    for(int y = 0; y < video.height; y++) {
      for(int x = 0; x < video.width; x++) {
        var depth = hue(depthImage.pixels[(y - currentKinectAdjustmentOffset[1]) * depthImage.width + (x - currentKinectAdjustmentOffset[0])]);
        if (depth > depthThreshold) {
          video.pixels[y * video.width + x] = color(0);
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
    stroke(0xFF4281A4);
    fill(0xFF4281A4);
    rect(0, 0, 330, 170);
    fill(255);
    text(
      "Video resolution: " + video.width + "x" + video.height + "\n" +
      "Video resolution: " + kinect.width + "x" + kinect.height + "\n" +
      "Video/Kinect scale [s]: " + videoKinectScale + "\n" +
      "Depth threshold [d]: " + depthThreshold + "\n" +
      "Kinect adjustment offset [k]: " + Arrays.toString(kinectAdjustmentOffset) + "\n" +
      "This informations panel can be toggled with [i].",
      10,
      20
    );
  }
}

enum ConfigurationMode {
  DEPTH_THRESHOLD,
  KINECT_ADJUSTMENT_OFFSET,
  VIDEO_KINECT_SCALE
}
ConfigurationMode configurationMode = null;

void keyPressed() {
  switch (key) {
    case 'i':
      DEBUG = !DEBUG;
      break;
    case 'd':
      configurationMode = ConfigurationMode.DEPTH_THRESHOLD;
      break;
    case 'k':
      configurationMode = ConfigurationMode.KINECT_ADJUSTMENT_OFFSET;
      break;
    case 's':
      configurationMode = ConfigurationMode.VIDEO_KINECT_SCALE;
      break;
  }
  
  if (configurationMode == ConfigurationMode.DEPTH_THRESHOLD) {
    if (keyCode == UP) {
      depthThreshold++;
    } else if (keyCode == DOWN) {
      depthThreshold--;
    }
  } else if (configurationMode == ConfigurationMode.VIDEO_KINECT_SCALE) {
    if ((keyCode == UP || keyCode == DOWN)) {
      var newVideoKinectScale = ceil((videoKinectScale + (keyCode == UP ? 0.1 : -0.1)) * 10) / 10.0f;
      if (minimuVideoKinectScale <= newVideoKinectScale) {
        videoKinectScale = newVideoKinectScale;
      }
    }
  } else if (configurationMode == ConfigurationMode.KINECT_ADJUSTMENT_OFFSET) {
    if ((keyCode == LEFT || keyCode == RIGHT)) {
      var newValue = kinectAdjustmentOffset[0] + (keyCode == LEFT ? -1 : 1);
      if(newValue <= 0 && video.width - kinect.width * videoKinectScale + newValue > 0) {
        kinectAdjustmentOffset[0] = newValue;
      }
    } else if ((keyCode == UP || keyCode == DOWN)) {
      var newValue = kinectAdjustmentOffset[1] + (keyCode == UP ? -1 : 1);
      if(newValue <= 0 && video.height - kinect.height * videoKinectScale + newValue > 0) {
        kinectAdjustmentOffset[1] = newValue;
      }
    }
  }
}

void keyReleased() {
  if(key == 'd' || key == 'k' || key == 's') {
    configurationMode = null;
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
