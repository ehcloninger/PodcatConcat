#!/bin/bash
# 
# Written by Eric Cloninger (github @ehcloninger)
# Take a number of MP3 audio files from my favorite podcast and concatenate
# them into a single file, with header and trailer trimmed for brevity.

# sanitize command line
if [ $# -lt 2 ]
  then
    echo "Usage: $0 input_folder output_file [-ow]"
    exit 1
fi

# input folder exists
if [ ! -d "$1" ]; then
	echo "$1 does not exist"
    exit 1
fi

# should we overwrite output file
if [ -f $2 ]; then

   if [ $# -lt 3 ]; then
     echo "Output file exists: $2"
     echo "Usage: $0 input_folder output_file [-ow]"
     exit 1
   fi

   echo "Overwriting output file: $2."
   rm $2
fi

outfile=$2

# determine log file name from output mp3 file name. Delete if exists
logfile=$2".log"
if [ -f $2 ]; then
	rm "$logfile"
fi

# Add trailing slash to input folder if it doesn't exist
inputdir=$1
if [[ ! "$inputdir" =~ '/'$ ]]; then 
  inputdir=$1"/"
fi

# Create a temp dir for the intermediate mp3 files cut with ffmpeg
tmpdir="./tmpdir"
if [ ! -d $tmpdir ]; then
   mkdir $tmpdir
fi

#list of episodes. Each episode has 3 data points in this array. Content of this array are
# "episode file name in the folder it exists - local path name" "start time as hh:mm:ss"  "end time as hh:mm:ss"

episodes=( \
"1 - Pilot.mp3" "00:01:24" "00:34:15" \
"2 - Dave Kills a Man.mp3" "00:02:13" "00:33:16" 
)

# get length of episode
arraylength=${#episodes[@]}

# First loop to test that all input files exist and can be queried
for (( i=0,count=1; i<${arraylength}+1; i+=3,count++));
do

	# ignore empty lines in input
  if [ -z "${episodes[$i]}" ]; then
    continue
  fi 

  # construct input file name from input dir and file listing here
  inputfile=$inputdir${episodes[$i]}

  # echo "$count:${episodes[$i]}"

  # couple tests for existence. Just to make sure the file is accessible
  # and that this script actually works. stat function may be redundant
  if [ ! -f "$inputfile" ]; then
     echo "Input file does not exist: $inputfile"
     exit 1
  fi

  stat "$inputfile" 1>>$logfile
  status=$?
  if test $status -ne 0
  then
	echo "Failed stat test for input: $inputfile"
  fi
done

# build a temp file that will be used to contain the names of the temp files
# to process. This is input to the final ffmpeg command that puts all the 
# pieces together. Might be possible without the catfile using ffmpeg concat 
# with pipes, but I have enough disk space to keep the temp files around to
# save time of subsequent runs
catfile=$outfile".txt"
echo "# This is a comment" > $catfile

# Second loop to run ffmpeg on files
for (( i=0,count=1; i<${arraylength}+1; i+=3,count++));
do
  if [ -z "${episodes[$i]}" ]; then
    continue
  fi 

  # ignore empty start and end times
  if [ -z "${episodes[$i+1]}" ]; then
    continue
  fi 

  if [ -z "${episodes[$i+2]}" ]; then
    continue
  fi 

  # ignore an end time that is zero
  if [ "${episodes[$i+2]}" == "00:00:00" ]; then
  	# echo "Skipping ${episodes[$i]} due to zero length output"
  	continue;
  fi

  inputfile=$inputdir${episodes[$i]}
  tmpfile=$tmpdir"/"${episodes[$i]}

  echo "file '$tmpfile'" >> "$catfile"

  # skip tmp files that already exist to cut down time to process
  # This may cause problems if the tmpfiles from a broken run still
  # exist in the tmp dir. If that happens, delete the tmpfile or tmpdir
  if [ -f "$tmpfile" ]; then
     echo "Tmp file exists for ${episodes[$i]}. Skipping"
     continue
  fi

  echo "Taking input from $inputfile"
  ffmpeg -y -i "$inputfile" -ss ${episodes[$i+1]} -to ${episodes[$i+2]} -c copy "$tmpfile" 1>>"$logfile" 2>>"$logfile"
  status=$?
  if test $status -ne 0
  then
	echo "Failed ffmpeg for input: $inputfile see log file $logfile"
	exit 1
  fi
done

ffmpeg -f concat -safe 0 -i "$catfile" -c copy $outfile 1>>"$logfile" 2>>"$logfile"
status=$?
if test $status -ne 0
then
  echo "Failed ffmpeg for concat: $catfile see log file $logfile"
fi
