import processing.video.*;
import KinectPV2.*;
import com.sun.jna.*;
import java.lang.Math.*;
import java.util.Arrays;

boolean DEBUG = true;

// video to mask
Movie video;

// Kinect device
KinectPV2 kinect;
volatile int depthThreshold = 3000; // 1000 = 1m
int depthThresholdDelta = 100;
int[] kinectAdjustmentOffset = {0, 0};

// ratio of Kinect depth camera video size on bacgrkound video size.
// (> 1 = Kinect is smaller; < 1 = video is smaller)
float videoKinectScale;
float minimumVideoKinectScale;

void setup() {
  fullScreen();
  //size(1920, 1080);

  // setup Kinect
  kinect = new KinectPV2(this);
  kinect.enableDepthImg(true);
  kinect.enablePointCloud(true);
  kinect.setLowThresholdPC(0);
  kinect.setHighThresholdPC(depthThreshold);
  kinect.init();
  
  // setup video
  video = new Movie(this, "background.mp4");
  video.play();
  video.read();
  
  // calculating ratio between video and Kinect depth camera resolutions
  if(video.height - KinectPV2.HEIGHTDepth >= video.width - KinectPV2.WIDTHDepth) {
    videoKinectScale = (float) video.height / KinectPV2.HEIGHTDepth;
  } else {
    videoKinectScale = (float) video.width / KinectPV2.WIDTHDepth;
  }
  minimumVideoKinectScale = videoKinectScale;
  
  if(videoKinectScale < 1) {
    exit(
      "Background video size is smaller than Kinect camera one.",
      "Please provide a bigger resolution background video."
    );
  }
}

void draw() {
  if(video.available()) {
    video.read();
    
    // get Kinect depth image and flip it
    // HACK: image is copied because resizing the returned one does not work as should
    PImage depthImage = kinect.getPointCloudDepthImage().copy();
    PImage flippedDepthImage = createImage(depthImage.width, depthImage.height, RGB);
    for (int x = 0 ; x < flippedDepthImage.width; x++) {
      flippedDepthImage.set(flippedDepthImage.width-x-1,0, depthImage.get(x, 0, 1, depthImage.height));
    }
    depthImage = flippedDepthImage;
    //image(depthImage, 0, 0);
    
    // scale and crop it to fit video size without distorsions
    depthImage.resize(ceil(KinectPV2.WIDTHDepth * videoKinectScale), ceil(KinectPV2.HEIGHTDepth * videoKinectScale));
    depthImage = depthImage.get(kinectAdjustmentOffset[0], kinectAdjustmentOffset[1], video.width, video.height);
    //image(depthImage, 0, 0);
    
    // mask the video frame with Kinect depth data
    video.loadPixels();
    depthImage.loadPixels();
    for(int y = 0; y < video.height; y++) {
      for(int x = 0; x < video.width; x++) {
        var depth = depthImage.pixels[y * depthImage.width + x];
        if (depth == 0xFF000000) {
          video.pixels[y * video.width + x] = color(0);
        }
      }
    }
    video.updatePixels();
    //video.mask(depthImage);
    
    // displaying the masked video frame
    image(video, 0, 0);

    // HACK: since video.loop() in the destup code does not work lets manually loop it
    if(video.duration() - video.time() < 0.05) {
      video.jump(0);
    }
  }
  
  // Print debug info onscreen
  if (DEBUG) {
    textSize(16);
    stroke(0xFF4281A4);
    fill(0xFF4281A4);
    rect(0, 0, 330, 170);
    fill(255);
    text(
      "Video resolution: " + video.width + "x" + video.height + "\n" +
      "Kinect resolution: " + KinectPV2.WIDTHDepth + "x" + KinectPV2.HEIGHTDepth + "\n" +
      "Video/Kinect scale [s]: " + videoKinectScale + "\n" +
      "Depth threshold [d]: " + depthThreshold + "\n" +
      "Kinect adjustment offset [o]: " + Arrays.toString(kinectAdjustmentOffset) + "\n" +
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
    case 'o':
      configurationMode = ConfigurationMode.KINECT_ADJUSTMENT_OFFSET;
      break;
    case 's':
      configurationMode = ConfigurationMode.VIDEO_KINECT_SCALE;
      break;
  }
  
  if (configurationMode == ConfigurationMode.DEPTH_THRESHOLD) {
    if (keyCode == UP) {
      depthThreshold += depthThresholdDelta;
    } else if (keyCode == DOWN) {
      depthThreshold -= depthThresholdDelta;
    }
    kinect.setHighThresholdPC(depthThreshold);
  } else if (configurationMode == ConfigurationMode.VIDEO_KINECT_SCALE) {
    if ((keyCode == UP || keyCode == DOWN)) {
      var newVideoKinectScale = ceil((videoKinectScale + (keyCode == UP ? 0.1 : -0.1)) * 10) / 10.0f;
      if (minimumVideoKinectScale <= newVideoKinectScale) {
        videoKinectScale = newVideoKinectScale;
      }
    }
  } else if (configurationMode == ConfigurationMode.KINECT_ADJUSTMENT_OFFSET) {
    if ((keyCode == LEFT || keyCode == RIGHT)) {
      var newValue = kinectAdjustmentOffset[0] + (keyCode == LEFT ? 1 : -1);
      if(newValue >= 0 && video.width + newValue <= KinectPV2.WIDTHDepth * videoKinectScale) {
        kinectAdjustmentOffset[0] = newValue;
      }
    } else if ((keyCode == UP || keyCode == DOWN)) {
      var newValue = kinectAdjustmentOffset[1] + (keyCode == UP ? 1 : -1);
      if(newValue >= 0 && video.height + newValue <= KinectPV2.HEIGHTDepth * videoKinectScale) {
        kinectAdjustmentOffset[1] = newValue;
      }
    }
  }
}

void keyReleased() {
  if(key == 'd' || key == 'o' || key == 's') {
    configurationMode = null;
  }
}

void exit(final String errorMessage) {
  exit(errorMessage, "");
}

void exit(final String errorMessage, final String explanationMessage) {
  if(video.height < KinectPV2.HEIGHTDepth) {
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
