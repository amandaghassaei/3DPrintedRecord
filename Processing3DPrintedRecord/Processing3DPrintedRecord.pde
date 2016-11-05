//txt to stl conversion - 3d printable record
//by Amanda Ghassaei
//Dec 2012
//http://www.instructables.com/id/3D-Printed-Record/

/*
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
*/


import processing.opengl.*;
import unlekker.util.*;
import unlekker.modelbuilder.*;
import ec.util.*;

String filename = "finalEdit1Min.txt";

//record parameters
float recordHeight = 0.06;//height of top of record (inches)
int recordBottom = 0;//height of bottom of record
float innerHole = 0.286;//diameter of center hole in inches
int recordSize = 12;	// 12 inches? 7 inches? 5 inches?
			// This isn't the "real size", but the type of record you want to do

//audio parameters
float samplingRate = 44100;//(44.1khz audio initially)
float rpm = 33.3;//rev per min
float rateDivisor = 4;//how much we are downsampling by

float amplitude, bevel, grooveWidth, depth, dpi, micronsPerLayer, diameter, innerRad, outerRad;

String grooveAndPrinter = "amandaghassaei";

//global geometry storage
UVertexList recordPerimeterUpper,recordPerimeterLower,recordHoleUpper,recordHoleLower;//storage for perimeter and center hole of record
UVertexList grooveOuterUpper,grooveOuterLower,grooveInnerUpper,grooveInnerLower;//groove vertices
UVertexList lastEdge;//storage for conecting one groove to the next
UGeometry geo = new UGeometry();//place to store geometery of vertices

float secPerMin = 60;//seconds per minute
float thetaIter = (samplingRate*secPerMin)/(rateDivisor*rpm);//how many values of theta per cycle
float incrNum = TWO_PI/thetaIter;//calculcate angular incrementation amount
int samplenum = 0;//which audio sample we are currently on

void setup(){
  if (grooveAndPrinter == "CoLiDo2") {
    //groove parameters
    amplitude = 2;//amplitude of signal (in steps)
    bevel = 0.5;//bevelled groove edge
    grooveWidth = 2;//in pixels
    depth = 6;//measured in steps, depth of tops of wave in groove from uppermost surface of record

    //printer parameters
    dpi = 254;
    micronsPerLayer = 100; //microns per vertical print layer
  } else {
    if (grooveAndPrinter != "amandaghassaei") { // name should change to identify printer
      println("Groove and printer setting unknown, using 'amandaghassaei' instead.");
    }
    //groove parameters
    amplitude = 24;//amplitude of signal (in steps)
    bevel = 0.5;//bevelled groove edge
    grooveWidth = 2;//in pixels
    depth = 6;//measured in steps, depth of tops of wave in groove from uppermost surface of record

    //printer parameters
    dpi = 600;//objet printer prints at 600 dpi
    micronsPerLayer = 16;//microns per vertical print layer
  }

  if (recordSize == 5) {
    diameter = 5;
    innerRad = 1.9375;
    outerRad = 2.3125;
  } else {
    if (recordSize != 12) {
      println("We don't know the parameters for records of " +
        recordSize + "\" size, so generating a default 12\" record instead.");
    }
    diameter = 11.8;//diameter of record in inches
    innerRad = 2.35;//radius of innermost groove in inches
    outerRad = 5.75;//radius of outermost groove in inches
  }

  scaleVariables();//convert units, initialize etc
  setUpRecordShape();//draw basic shape of record
  drawGrooves(processAudioData());//draw in grooves
  
  //change extension of file name
  String name = filename;
  int dotPos = filename.lastIndexOf(".");
  if (dotPos > 0)
    name = filename.substring(0, dotPos);
  //write stl file from geomtery
  geo.writeSTL(this, name + ".stl");
  
  exit();
}

float[] processAudioData(){
  //get data out of txt file
  String rawData[] = loadStrings(filename);
  String rawDataString = rawData[0];
  float audioData[] = float(split(rawDataString,','));//separated by commas
  
  //normalize audio data to given bitdepth
  //first find max val
  float maxval = 0;
  for(int i=0;i<audioData.length;i++){
    if (abs(audioData[i])>maxval){
      maxval = abs(audioData[i]);
    }
  }
  //normalize amplitude to max val
  for(int i=0;i<audioData.length;i++){
    audioData[i]*=amplitude/maxval;
  }
  
  return audioData;
}

void scaleVariables(){
  //convert everything to inches
  float micronsPerInch = 25400;//scalingfactor
  amplitude = amplitude*micronsPerLayer/micronsPerInch;
  depth = depth*micronsPerLayer/micronsPerInch;
  if ((recordHeight - depth) <= recordBottom) {
    println("Error: your printer doesn't allow such a huge depth!");
  }
  grooveWidth /= dpi;
}

void setUpRecordShape(){
  //set up storage
  recordPerimeterUpper = new UVertexList();
  recordPerimeterLower = new UVertexList();
  recordHoleUpper = new UVertexList();
  recordHoleLower = new UVertexList();
  
  //get vertices
  for(float theta=0;theta<TWO_PI;theta+=incrNum){
    //outer edge of record
    float perimeterX = diameter/2+diameter/2*cos(theta);
    float perimeterY = diameter/2+diameter/2*sin(theta);
    recordPerimeterUpper.add(perimeterX,perimeterY,recordHeight);
    recordPerimeterLower.add(perimeterX,perimeterY,recordBottom);
    //center hole
    float centerHoleX = diameter/2+innerHole/2*cos(theta);
    float centerHoleY = diameter/2+innerHole/2*sin(theta);
    recordHoleUpper.add(centerHoleX,centerHoleY,recordHeight);
    recordHoleLower.add(centerHoleX,centerHoleY,recordBottom);
  }
  
  //close vertex lists (closed loops)
  recordPerimeterUpper.close();
  recordPerimeterLower.close();
  recordHoleUpper.close();
  recordHoleLower.close();
  
  //connect vertices
  geo.quadStrip(recordHoleUpper,recordHoleLower);
  geo.quadStrip(recordHoleLower,recordPerimeterLower);
  geo.quadStrip(recordPerimeterLower,recordPerimeterUpper);
  
  //to start, outer edge of record is the last egde we need to connect to with the outmost groove
  lastEdge = new UVertexList();
  lastEdge.add(recordPerimeterUpper);
  
  println("record drawn, starting grooves");
}

void drawGrooves(float[] audioData){
  
  int grooveNum = 0;//which groove we are currently drawing
  
  //set up storage
  grooveOuterUpper = new UVertexList();
  grooveOuterLower = new UVertexList();
  grooveInnerUpper = new UVertexList();
  grooveInnerLower = new UVertexList();
  
  //DRAW GROOVES
  float radius = outerRad;//outermost radius (at 5.75") to start
  float radIncr = (grooveWidth+2*bevel*amplitude)/thetaIter;//calculate radial incrementation amount
  int totalgroovenum = int(audioData.length/(rateDivisor*thetaIter));
  
  //first draw starting cap
  UVertexList stop1 = beginStartCap(radius, audioData[0]);
  
  //then spiral groove
  while (rateDivisor*samplenum<(audioData.length-rateDivisor*thetaIter+1) && (radius>innerRad)){//while we still have audio to write and we have not reached the innermost groove  //radius>innerRad &&
    
    clearGrooveStorage();
    for(float theta=0;theta<TWO_PI;theta+=incrNum){//for theta between 0 and 2pi
      radius = iter(theta, radius, grooveNum, audioData, radIncr);
    }
    completeGrooveRev(grooveNum, radius, audioData);
    connectVertices(grooveNum);

    if (grooveNum==0){//complete beginning cap if neccesary
      finishStartCap(radius, stop1);
    }
    
    //tell me how much longer
    grooveNum++;
    print(grooveNum);
    print(" of ");
    print(totalgroovenum);
    println(" grooves drawn");
  }

  if (radius < innerRad) {
    println("We stopped before the end of the track, since we reached the inner radius");
  }
  
  //the locked groove is made out of two intersecting grooves, one that spirals in, and one that creates a perfect circle.
  //the ridge between these grooves gets lower and lower until it disappears and the two grooves become one wide groove.
  radius = drawPenultGroove(radius, grooveNum, audioData, radIncr);//second to last groove
  clearGrooveStorage();
  for(float theta=0;theta<TWO_PI;theta+=incrNum){//draw last groove (circular locked groove)
    iter(theta, radius, grooveNum, null, radIncr);
  }
  completeGrooveRev(grooveNum, radius, null);
  connectVertices(grooveNum);

  geo.quadStrip(lastEdge,recordHoleUpper);//close remaining space between last groove and center hole
}
