##//txt to stl conversion - 3d printable record
##//by Amanda Ghassaei
##//Dec 2012
##//http://www.instructables.com/id/3D-Printed-Record/
##
##/*
## * This program is free software; you can redistribute it and/or modify
## * it under the terms of the GNU General Public License as published by
## * the Free Software Foundation; either version 3 of the License, or
## * (at your option) any later version.
##*/


import wave
import math
import struct

bitDepth = 8#target bitDepth
frate = 44100#target frame rate

fileName = "your_file_name_here.wav"#file to be imported (change this)

#read file and get data
w = wave.open(fileName, 'r')
numframes = w.getnframes()

frame = w.readframes(numframes)#w.getnframes()

frameInt = map(ord, list(frame))#turn into array

#separate left and right channels and merge bytes
frameOneChannel = [0]*numframes#initialize list of one channel of wave
for i in range(numframes):
    frameOneChannel[i] = frameInt[4*i+1]*2**8+frameInt[4*i]#separate channels and store one channel in new list
    if frameOneChannel[i] > 2**15:
        frameOneChannel[i] = (frameOneChannel[i]-2**16)
    elif frameOneChannel[i] == 2**15:
        frameOneChannel[i] = 0
    else:
        frameOneChannel[i] = frameOneChannel[i]

#convert to string
audioStr = ''
for i in range(numframes):
    audioStr += str(frameOneChannel[i])
    audioStr += ","#separate elements with comma

fileName = fileName[:-3]#remove .wav extension
text_file = open(fileName+"txt", "w")
text_file.write("%s"%audioStr)
text_file.close()



