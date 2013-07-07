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

String filename = "your_file_name_here.txt";

UVertexList recordPerimeterUpper,recordPerimeterLower,recordHoleUpper,recordHoleLower;//storage for perimeter and center hole of record
UVertexList lastEdge;//storage for conecting one groove to the next
UGeometry geo;//storage for stl geometry

//parameters
float samplingRate = 44100;//(44.1khz audio initially)
float rpm = 33.3;//rev per min
float secPerMin = 60;//seconds per minute
float rateDivisor = 4;//how much we are downsampling by
float theta;//angle variable
float thetaIter = (samplingRate*secPerMin)/(rateDivisor*rpm);//how many values of theta per cycle
float radius;//variable to calculate radius of grooves
float diameter = 11.8;//diameter of record in inches
float innerHole = 0.286;//diameter of center hole in inches
float innerRad = 2.35;//radius of innermost groove in inches
float outerRad = 5.75;//radius of outermost groove in inches

//record parameters
float recordHeight = 0.04;//height of record in inches
int recordBottom = 0;//height of bottom of record

//variable parameters
float amplitude = 24;//amplitude of signal (in 16 micron steps)
float bevel = 0.5;//bevelled groove edge
float grooveWidth = 2;//in 600dpi pixels
float depth = 6;//measured in 16 microns steps, depth of tops of wave in groove from uppermost surface of record

float incrNum = TWO_PI/thetaIter;//calculcate angular incrementation amount

int grooveNum = 0;//variable for keeping track of how long this will take
int totalSampleNum;

void setup(){
  
  geo = new UGeometry();//place to store geometery of verticies
  
  setUpVariables();//convert units, initialize etc
  setUpRecordShape();//draw basic shape of record
  drawGrooves(processAudioData());//draw in grooves
  
  //change extension of file name
  String name = filename;
  int dotPos = filename.lastIndexOf(".");
  if (dotPos > 0)
    name = filename.substring(0, dotPos);
  geo.writeSTL(this, name + ".stl");//write stl file from geomtery
  
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

void setUpVariables(){
  
  //convert everything to inches
  float micronsPerInch = 25400;//scalingfactor
  float dpi = 600;//objet printer prints at 600 dpi
  byte micronsPerLayer = 16;//microns per vertical print layer
  
  amplitude = amplitude*micronsPerLayer/micronsPerInch;
  depth = depth*micronsPerLayer/micronsPerInch;
  grooveWidth /= dpi;
  
}

void setUpRecordShape(){
  
  //set up storage
  recordPerimeterUpper = new UVertexList();
  recordPerimeterLower = new UVertexList();
  recordHoleUpper = new UVertexList();
  recordHoleLower = new UVertexList();
  
  //get verticies
  for(theta=0;theta<TWO_PI;theta+=incrNum){
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
  
  //connect verticies
  geo.quadStrip(recordHoleUpper,recordHoleLower);
  geo.quadStrip(recordHoleLower,recordPerimeterLower);
  geo.quadStrip(recordPerimeterLower,recordPerimeterUpper);
  
  //to start, outer edge of record is the last egde we need to connect to with the outmost groove
  lastEdge = new UVertexList();
  lastEdge.add(recordPerimeterUpper);
  
  println("record drawn, starting grooves");
  grooveNum = 0;//variable for keeping track of how much longer this will take
  
}

void drawGrooves(float[] audioData){
  
  UVertexList grooveOuterUpper,grooveOuterLower,grooveInnerUpper,grooveInnerLower;//groove verticies
  UVertexList stop1,stop2;//storage for very beginning and end of sprial groove
  
  //set up storage
  grooveOuterUpper = new UVertexList();
  grooveOuterLower = new UVertexList();
  grooveInnerUpper = new UVertexList();
  grooveInnerLower = new UVertexList();
  stop1 = new UVertexList();
  stop2 = new UVertexList();
  
  //DRAW GROOVES
  radius = outerRad;//outermost radius (at 5.75") to start
  float radIncr = (grooveWidth+2*bevel*amplitude)/thetaIter;//calculate radial incrementation amount
  int samplenum = 0;
  int totalgroovenum = int(audioData.length/(rateDivisor*thetaIter));
  
  //first draw starting cap
  theta = 0;
  float sineTheta = sin(theta);
  float cosineTheta = cos(theta);
  //calculate height of groove
  float grooveHeight = recordHeight-depth-amplitude+audioData[int(rateDivisor*samplenum)];
  stop1.add((diameter/2+(radius+amplitude*bevel)*cosineTheta),(diameter/2+(radius+amplitude*bevel)*sineTheta),recordHeight);//outerupper
  stop2.add((diameter/2+radius*cosineTheta),(diameter/2+radius*sineTheta),grooveHeight);//outerlower
  stop2.add((diameter/2+(radius-grooveWidth)*cosineTheta),(diameter/2+(radius-grooveWidth)*sineTheta),grooveHeight);//innerlower
  stop1.add((diameter/2+(radius-grooveWidth-amplitude*bevel)*cosineTheta),(diameter/2+(radius-grooveWidth-amplitude*bevel)*sineTheta),recordHeight);//innerupper
  //draw triangles
  geo.quadStrip(stop1,stop2);
  
  //then spiral groove
  while (rateDivisor*samplenum<(audioData.length-rateDivisor*thetaIter+1)){//while we still have audio to write and we have not reached the innermost groove  //radius>innerRad &&
  
    //clear lists
    grooveOuterUpper.reset();
    grooveOuterLower.reset();
    grooveInnerUpper.reset();
    grooveInnerLower.reset();

    for(theta=0;theta<TWO_PI;theta+=incrNum){//for theta between 0 and 2pi
      
      sineTheta = sin(theta);
      cosineTheta = cos(theta);

      //calculate height of groove
      grooveHeight = recordHeight-depth-amplitude+audioData[int(rateDivisor*samplenum)];
      samplenum++;//increment sample num
      
      if (grooveNum==0){
        grooveOuterUpper.add((diameter/2+(radius+amplitude*bevel)*cosineTheta),(diameter/2+(radius+amplitude*bevel)*sineTheta),recordHeight);
      }
      grooveOuterLower.add((diameter/2+radius*cosineTheta),(diameter/2+radius*sineTheta),grooveHeight);
      grooveInnerLower.add((diameter/2+(radius-grooveWidth)*cosineTheta),(diameter/2+(radius-grooveWidth)*sineTheta),grooveHeight);
      grooveInnerUpper.add((diameter/2+(radius-grooveWidth-amplitude*bevel)*cosineTheta),(diameter/2+(radius-grooveWidth-amplitude*bevel)*sineTheta),recordHeight);
      
      radius -= radIncr;
      
    }
    
    //add last value to grooves to complete one full rev
    theta = 0;
    sineTheta = sin(theta);
    cosineTheta = cos(theta);

    //calculate height of groove
    grooveHeight = recordHeight-depth-amplitude+audioData[int(rateDivisor*samplenum)];
    
    if (grooveNum==0){
      grooveOuterUpper.add(grooveInnerUpper.first());//grooveOuterUpper.add((diameter/2+(radius+amplitude*bevel)*cosineTheta),(diameter/2+(radius+amplitude*bevel)*sineTheta),recordHeight);
    }
    grooveOuterLower.add((diameter/2+radius*cosineTheta),(diameter/2+radius*sineTheta),grooveHeight);
    grooveInnerLower.add((diameter/2+(radius-grooveWidth)*cosineTheta),(diameter/2+(radius-grooveWidth)*sineTheta),grooveHeight);
    grooveInnerUpper.add((diameter/2+(radius-grooveWidth-amplitude*bevel)*cosineTheta),(diameter/2+(radius-grooveWidth-amplitude*bevel)*sineTheta),recordHeight);

    //connect verticies
    if (grooveNum==0){//if joining a roove to the edge of the record
      geo.quadStrip(lastEdge,grooveOuterUpper);
      geo.quadStrip(grooveOuterUpper,grooveOuterLower);
    }
    else{//if joining a groove to another groove
      geo.quadStrip(lastEdge,grooveOuterLower);
    }
    geo.quadStrip(grooveOuterLower,grooveInnerLower);
    geo.quadStrip(grooveInnerLower,grooveInnerUpper);
    
    //set new last edge
    lastEdge.reset();//clear old data
    lastEdge.add(grooveInnerUpper);
    
    //complete beginning cap if necessary
    if (grooveNum==0){
      //clear stop2
      stop2.reset();
      stop2.add(diameter/2+diameter/2*cosineTheta,diameter/2+diameter/2*sineTheta,recordHeight);//outer perimeter[0]
      stop2.add((diameter/2+(radius+amplitude*bevel)*cosineTheta),(diameter/2+(radius+amplitude*bevel)*sineTheta),recordHeight);//outer groove edge [2pi]
      //draw triangles
      geo.quadStrip(stop1,stop2);
    }
    
    //tell me how much longer
    grooveNum++;
    print(grooveNum);
    print(" of ");
    print(totalgroovenum);
    println(" grooves drawn");
  }
  
  //draw end cap of spiral groove
  stop1.reset();
  stop2.reset();
  stop1.add((diameter/2+(radius+amplitude*bevel)*cosineTheta),(diameter/2+(radius+amplitude*bevel)*sineTheta),recordHeight);//outeruppter
  stop2.add((diameter/2+radius*cosineTheta),(diameter/2+radius*sineTheta),grooveHeight);//outerlower
  stop2.add((diameter/2+(radius-grooveWidth)*cosineTheta),(diameter/2+(radius-grooveWidth)*sineTheta),grooveHeight);//innerlower
  stop1.add((diameter/2+(radius-grooveWidth-amplitude*bevel)*cosineTheta),(diameter/2+(radius-grooveWidth-amplitude*bevel)*sineTheta),recordHeight);//innerupper
  //draw triangles
  geo.quadStrip(stop1,stop2);
  stop2.reset();
  stop2.add(lastEdge.last());//innerupper[0]
  stop2.add(diameter/2+innerHole/2*cosineTheta,diameter/2+innerHole/2*sineTheta,recordHeight);//innerhole[0]
  //draw triangles
  geo.quadStrip(stop1,stop2);
  
  geo.quadStrip(lastEdge,recordHoleUpper);//close remaining space between last groove and center hole
  
}

