float getNextSampleElseZero(float[] audioData){
  float aud;
  if (rateDivisor*samplenum>(audioData.length-1)){
    aud = 0;
  } else  {
    aud = audioData[int(rateDivisor*samplenum)];
  }
  samplenum++;//increment sample num
  return aud;
}

float iter(float theta, float radius, int grooveNum, float[] audioData, float radIncr){
  float sineTheta = sin(theta);
  float cosineTheta = cos(theta);

  //calculate height of groove
  float grooveHeight = recordHeight-depth-amplitude;
  if (audioData!=null) grooveHeight += getNextSampleElseZero(audioData);
  
  
  if (grooveNum==0){
    grooveOuterUpper.add((diameter/2+(radius+amplitude*bevel)*cosineTheta),(diameter/2+(radius+amplitude*bevel)*sineTheta),recordHeight);
  }
  grooveOuterLower.add((diameter/2+radius*cosineTheta),(diameter/2+radius*sineTheta),grooveHeight);
  grooveInnerLower.add((diameter/2+(radius-grooveWidth)*cosineTheta),(diameter/2+(radius-grooveWidth)*sineTheta),grooveHeight);
  grooveInnerUpper.add((diameter/2+(radius-grooveWidth-amplitude*bevel)*cosineTheta),(diameter/2+(radius-grooveWidth-amplitude*bevel)*sineTheta),recordHeight);
  
  return radius - radIncr; 
}

void completeGrooveRev(int grooveNum, float radius, float[] audioData){
  //add last value to grooves to complete one full rev (theta=0)
  float grooveHeight = recordHeight-depth-amplitude;
  if (audioData!=null) grooveHeight += audioData[int(rateDivisor*samplenum)];
  if (grooveNum==0){//if joining a groove to the edge of the record
    grooveOuterUpper.add(grooveInnerUpper.first());
  }
  grooveOuterLower.add(diameter/2+radius,diameter/2,grooveHeight);
  grooveInnerLower.add(diameter/2+(radius-grooveWidth),diameter/2,grooveHeight);
  grooveInnerUpper.add(diameter/2+radius-grooveWidth-amplitude*bevel,diameter/2,recordHeight);
}

void connectVertices(int grooveNum){
  //connect vertices
  if (grooveNum==0){//if joining a groove to the edge of the record
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
}

UVertexList beginStartCap(float radius, float firstSample){//this is a tiny piece of geometry that closes off the front end of the groove
  UVertexList stop1 = new UVertexList();
  UVertexList stop2 = new UVertexList();
  float grooveHeight = recordHeight-depth-amplitude+firstSample;
  stop1.add((diameter/2+(radius+amplitude*bevel)),(diameter/2),recordHeight);//outerupper
  stop2.add(diameter/2+radius,diameter/2,grooveHeight);//outerlower
  stop2.add(diameter/2+(radius-grooveWidth),diameter/2,grooveHeight);//innerlower
  stop1.add((diameter/2+(radius-grooveWidth-amplitude*bevel)),diameter/2,recordHeight);//innerupper
  geo.quadStrip(stop1,stop2);//draw triangles
  return stop1;
}

void finishStartCap(float radius, UVertexList stop1){
  UVertexList stop2 = new UVertexList();
  stop2.add(diameter,diameter/2,recordHeight);//outer perimeter[0]
  stop2.add((diameter/2+radius+amplitude*bevel),(diameter/2),recordHeight);//outer groove edge [2pi]
  //draw triangles
  geo.quadStrip(stop1,stop2);
}

void clearGrooveStorage(){
  grooveOuterUpper.reset();
  grooveOuterLower.reset();
  grooveInnerUpper.reset();
  grooveInnerLower.reset();
}

float drawPenultGroove(float radius,int grooveNum, float[] audioData, float radIncr){
  //the locked groove is made out of two intersecting grooves, one that spirals in, and one that creates a perfect circle.
  //the ridge between these grooves gets lower and lower until it disappears and the two grooves become on wide groove.
  float changeTheta = TWO_PI*(0.5*amplitude)/(amplitude+grooveWidth);//what value of theta to merge two last grooves
  float ridgeDecrNum = TWO_PI*amplitude/(changeTheta*thetaIter);//how fast the ridge height is decreasing
  float ridgeHeight = recordHeight;//center ridge starts at same height as record
  clearGrooveStorage();
  
  UVertexList ridge = new UVertexList();
  float theta;
  for(theta=0;theta<TWO_PI;theta+=incrNum){//draw part of spiral groove, until theta = changeTheta
    if (theta<=changeTheta){
      float sineTheta = sin(theta);
      float cosineTheta = cos(theta);
      ridge.add((diameter/2+(radius-grooveWidth-amplitude*bevel)*cosineTheta),(diameter/2+(radius-grooveWidth-amplitude*bevel)*sineTheta),ridgeHeight);
      radius = iter(theta, radius, grooveNum, audioData, radIncr);
      ridgeHeight -= ridgeDecrNum;
      } else {
        break;//get out of this for loop is theat > changeTheta
      }
  }
  
  //complete rev w/o audio data 
  float grooveHeight = recordHeight-depth-amplitude;//zero point for the groove
  
  float sineTheta = sin(theta);//using theta from where we left off
  float cosineTheta = cos(theta);
  grooveOuterLower.add((diameter/2+radius*cosineTheta),(diameter/2+radius*sineTheta),grooveHeight);
  grooveInnerLower.add((diameter/2+(radius-grooveWidth)*cosineTheta),(diameter/2+(radius-grooveWidth)*sineTheta),grooveHeight);
  ridge.add((diameter/2+(radius-grooveWidth-amplitude*bevel)*cosineTheta),(diameter/2+(radius-grooveWidth-amplitude*bevel)*sineTheta),grooveHeight);
  geo.quadStrip(grooveOuterLower,grooveInnerLower);
  geo.quadStrip(grooveInnerLower,ridge);
  
  for(theta=theta;theta<TWO_PI;theta+=incrNum){//for theta between current position and 2pi
    sineTheta = sin(theta);
    cosineTheta = cos(theta);
    grooveOuterLower.add((diameter/2+radius*cosineTheta),(diameter/2+radius*sineTheta),grooveHeight);    
    ridge.add((diameter/2+radius*cosineTheta),(diameter/2+radius*sineTheta),grooveHeight);    
    radius -= radIncr; 
  } 
  //connect vertices
  geo.quadStrip(lastEdge,grooveOuterLower);
  
  //set new last edge
  lastEdge.reset();//clear old data
  lastEdge.add(ridge);
  
  return radius;
}

