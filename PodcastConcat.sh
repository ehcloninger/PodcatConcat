#!/bin/bash
# 
# Written by Eric Cloninger (github @ehcloninger)
# Take a number of MP3 audio files from my favorite podcast and concatenate
# them into a single file, with header and trailer trimmed for brevity.
#
# Licensed under the MIT License. 

convertsecs() {
 ((h=${1}/3600))
 ((m=(${1}%3600)/60))
 ((s=${1}%60))
 printf "%02d:%02d:%02d\n" $h $m $s
}

converttimestamp() {
  hh="$(cut -d':' -f1 <<<"${1}")"
  mm="$(cut -d':' -f2 <<<"${1}")"
  ss="$(cut -d':' -f3 <<<"${1}")"
  printf $((10#${hh}*3600+10#${mm}*60+10#${ss}))
}

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
# These are completely bogus file titles. Replace with those from some other location
# "1 - Pilot.mp3" "00:01:24" "00:34:15" \
# "2 - Dave Kills a Man.mp3" "00:02:13" "00:33:16" 
"1 - Pilot.mp3"                                                           "00:02:35" "04:00:00" \
"2 - Glow Cloud.mp3"                                                      "00:01:55" "04:00:00" \
"3 - Station Management.mp3"                                              "00:00:24" "04:00:00" \
"4 - PTA Meeting.mp3"                                                     "00:01:11" "04:00:00" \
"5 - The Shape in Grove Park.mp3"                                         "00:02:02" "04:00:00" \
"6 - The Drawbridge.mp3"                                                  "00:01:56" "04:00:00" \
"7 - History Week.mp3"                                                    "00:02:09" "04:00:00" \
"8 - The Lights in Radon Canyon.mp3"                                      "00:01:09" "04:00:00" \
"9 - _PYRAMID_.mp3"                                                       "00:01:32" "04:00:00" \

"10 - Feral Dogs.mp3"                                                     "00:02:23" "04:00:00" \
"11 - Wheat & Wheat By-Products.mp3"                                      "00:00:23" "04:00:00" \
"12 - The Candidate.mp3"                                                  "00:00:23" "04:00:00" \
"13 - A Story About You..mp3"                                             "00:01:32" "04:00:00" \
"14 - The Man in the Tan Jacket.mp3"                                      "00:01:09" "04:00:00" \
"15 - Street Cleaning Day.mp3"                                            "00:01:57" "04:00:00" \
"16 - The Phone Call.mp3"                                                 "00:01:56" "04:00:00" \
"17 - Valentine.mp3"                                                      "00:01:32" "04:00:00" \
"18 - The Traveler.mp3"                                                   "00:01:32" "04:00:00" \
"19A - The Sandstorm.mp3"                                                 "00:00:23" "04:00:00" \
"19B - The Sandstorm.mp3"                                                 "00:02:02" "04:00:00" \

"20 - Poetry Week.mp3"                                                    "00:00:51" "04:00:00" \
"21 - A Memory of Europe.mp3"                                             "00:00:23" "04:00:00" \
"22 - The Whispering Forest.mp3"                                          "00:01:03" "04:00:00" \
"23 - Eternal Scouts.mp3"                                                 "00:01:46" "04:00:00" \
"24 - The Mayor.mp3"                                                      "00:01:33" "04:00:00" \
"25 - One Year Later.mp3"                                                 "00:00:25" "04:00:00" \
"26 - Faceless Old Woman.mp3"                                             "00:00:23" "04:00:00" \
"27 - First Date.mp3"                                                     "00:01:32" "04:00:00" \
"28 - Summer Reading Program.mp3"                                         "00:01:06" "04:00:00" \
"29 - Subway.mp3"                                                         "00:00:23" "04:00:00" \

"30 - Dana.mp3"                                                           "00:00:54" "04:00:00" \
"31 - A Blinking Light up on the Mountain.mp3"                            "00:01:03" "04:00:00" \
"32 - Yellow Helicopters.mp3"                                             "00:00:23" "04:00:00" \
"33 - Cassette.mp3"                                                       "00:01:32" "04:00:00" \
"34 - A Beautiful Dream.mp3"                                              "00:01:37" "04:00:00" \
"35 - Lazy Day.mp3"                                                       "00:02:03" "04:00:00" \
"36 - Missing.mp3"                                                        "00:01:56" "04:00:00" \
"37 - The Auction.mp3"                                                    "00:01:32" "04:00:00" \
"38 - Orange Grove.mp3"                                                   "00:01:09" "04:00:00" \
"39 - The Woman from Italy.mp3"                                           "00:00:23" "04:00:00" \

"40 - The Deft Bowman.mp3"                                                "00:01:33" "04:00:00" \
"41 - WALK.mp3"                                                           "00:00:23" "04:00:00" \
"42 - Numbers.mp3"                                                        "00:00:23" "04:00:00" \
"43 - Visitor.mp3"                                                        "00:02:13" "04:00:00" \
"44 - Cookies.mp3"                                                        "00:01:07" "04:00:00" \
"45 - A Story About Them.mp3"                                             "00:02:00" "04:00:00" \
"46 - Parade Day.mp3"                                                     "00:02:36" "04:00:00" \
"47 - Company Picnic.mp3"                                                 "00:02:13" "04:00:00" \
"48 - Renovations.mp3"                                                    "00:02:01" "04:00:00" \
"49 - Old Oak Doors Part A.mp3"                                           "00:02:36" "04:00:00" \
"49 - Old Oak Doors Part B.mp3"                                           "00:02:57" "04:00:00" \

"50 - Capital Campaign.mp3"                                               "00:00:50" "04:00:00" \
"51 - Rumbling.mp3"                                                       "00:00:23" "04:00:00" \
"52 - The Retirement of Pamela Winchell.mp3"                              "00:00:59" "04:00:00" \
"53 - The September Monologues.mp3"                                       "00:01:45" "04:00:00" \
"54 - A Carnival Comes to Town.mp3"                                       "00:01:50" "04:00:00" \
"55 - The University of What It Is.mp3"                                   "00:02:43" "04:00:00" \
"56 - Homecoming.mp3"                                                     "00:02:40" "04:00:00" \
"57 - The List.mp3"                                                       "00:01:54" "04:00:00" \
"58 - Monolith.mp3"                                                       "00:01:49" "04:00:00" \
"59 - Antiques.mp3"                                                       "00:01:29" "04:00:00" \

"60 - Water Failure.mp3"                                                  "00:02:11" "04:00:00" \
"61 - BRINY DEPTHS.mp3"                                                   "00:02:14" "04:00:00" \
"62 - Hatchets.mp3"                                                       "00:02:38" "04:00:00" \
"63 - There Is No Part 1_ Part 2.mp3"                                     "00:01:45" "04:00:00" \
"64 - WE MUST GIVE PRAISE.mp3"                                            "00:02:47" "04:00:00" \
"65 - Voicemail.mp3"                                                      "00:02:33" "04:00:00" \
"66 - worms....mp3"                                                       "00:02:32" "04:00:00" \
"67 - [Best Of_].mp3"                                                     "00:02:34" "04:00:00" \
"68 - Faceless Old Women.mp3"                                             "00:02:35" "04:00:00" \
"69 - Fashion Week.mp3"                                                   "00:02:14" "04:00:00" \

"70A - Taking Off.mp3"                                                    "00:01:50" "04:00:00" \
"70B - Review.mp3"                                                        "00:01:30" "04:00:00" \
"71 - The Registry of Middle School Crushes.mp3"                          "00:02:58" "04:00:00" \
"72 - Well of Night.mp3"                                                  "00:00:23" "04:00:00" \
"73 - Triptych.mp3"                                                       "00:02:24" "04:00:00" \
"74 - Civic Changes.mp3"                                                  "00:00:23" "04:00:00" \
"75 - Through the Narrow Place.mp3"                                       "00:01:57" "04:00:00" \
"76 - An Epilogue.mp3"                                                    "00:01:05" "04:00:00" \
"77 - A Stranger.mp3"                                                     "00:01:32" "04:00:00" \
"78 - Cooking Stuff_ Thanksgiving Special.mp3"                            "00:02:09" "04:00:00" \
"79 - Lost in the Mail.mp3"                                               "00:02:11" "04:00:00" \

"80 - A New Sheriff in Town.mp3"                                          "00:02:25" "04:00:00" \
"81 - After 3327.mp3"                                                     "00:01:52" "04:00:00" \
"82 - Skating Rink.mp3"                                                   "00:02:10" "04:00:00" \
"83 - One Normal Town.mp3"                                                "00:01:10" "04:00:00" \
"84 - Past Time.mp3"                                                      "00:01:33" "04:00:00" \
"85 - The April Monologues.mp3"                                           "00:01:30" "04:00:00" \
"86 - Standing and Breathing.mp3"                                         "00:00:23" "04:00:00" \
"87 - The Trial of Hiram McDaniels.mp3"                                   "00:01:32" "04:00:00" \
"88 - Things Fall Apart.mp3"                                              "00:01:00" "04:00:00" \
"89 - Who's a Good Boy_ Part 1.mp3"                                       "00:00:23" "04:00:00" \

"90 - Who's a Good Boy_ Part 2.mp3"                                       "00:00:48" "04:00:00" \
"91 - The 12_37.mp3"                                                      "00:01:58" "04:00:00" \
"92 - If He Had Lived.mp3"                                                "00:01:52" "04:00:00" \
"93 - Big Sister.mp3"                                                     "00:01:48" "04:00:00" \
"94 - All Right.mp3"                                                      "00:01:38" "04:00:00" \
"95 - Zookeeper.mp3"                                                      "00:01:32" "04:00:00" \
"96 - Negotiations.mp3"                                                   "00:02:47" "04:00:00" \
"97 - Josefina.mp3"                                                       "00:01:55" "04:00:00" \
"98 - Flight.mp3"                                                         "00:01:57" "04:00:00" \
"99 - Michigan.mp3"                                                       "00:01:22" "04:00:00" \

"100 - Toast.mp3"                                                         "00:01:43" "04:00:00" \
"101 - Guidelines for Disposal.mp3"                                       "00:01:43" "04:00:00" \
"102 - Love Is a Shambling Thing.mp3"                                     "00:01:20" "04:00:00" \
"103 - Ash Beach.mp3"                                                     "00:01:57" "04:00:00" \
"104 - The Hierarchy of Angels.mp3"                                       "00:01:57" "04:00:00" \
"105 - What Happened at the Smithwick House.mp3"                          "00:01:49" "04:00:00" \
"106 - Filings.mp3"                                                       "00:01:56" "04:00:00" \
"107 - The Missing Sky.mp3"                                               "00:02:41" "04:00:00" \
"108 - Cal.mp3"                                                           "00:02:12" "04:00:00" \
"109 - A Story About Huntokar.mp3"                                        "00:01:57" "04:00:00" \

"110 - Matryoshka.mp3"                                                    "00:02:44" "04:00:00" \
"111 - Summer 2017, Night Vale, USA.mp3"                                  "00:01:32" "04:00:00" \
"112 - Citizen Spotlight.mp3"                                             "00:01:59" "04:00:00" \
"113 - Niecelet.mp3"                                                      "00:02:07" "04:00:00" \
"114 - Council Member Flynn, Part 1.mp3"                                  "00:02:07" "04:00:00" \
"115 - Council Member Flynn, Part 2.mp3"                                  "00:01:52" "04:00:00" \
"116 - Council Member Flynn, Part 3.mp3"                                  "00:01:44" "04:00:00" \
"117 - eGemony, Part 1_ _Canadian Club_.mp3"                              "00:02:16" "04:00:00" \
"118 - eGemony, Part 2_ _The Cavelands_.mp3"                              "00:02:02" "04:00:00" \
"119 - eGemony, Part 3_ _Love, Among Other Things, Is All You Need_.mp3"  "00:01:54" "04:00:00" \

"120 - All Smiles' Eve.mp3"                                               "00:001:40" "04:00:00" \
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

# Build a chapter file for mp3chaps that is the output mp3 file name minus the
# .mp3 and with .chapter.txt. This is a simple substitution regex, so it may fail
# on complex path or output file names.
totaltime=0
chapterfile="${outfile%.*}"".chapters.txt"
if [ -f $chapterfile ]; then
	rm "$chapterfile"
fi

# Second loop to run ffmpeg on files and create chapter markers
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

  start=$(converttimestamp ${episodes[$i+1]})
  end=$(converttimestamp ${episodes[$i+2]})
  thiseplen=$((end-start))

  totaltimestr=$(convertsecs $totaltime)
  echo "$totaltimestr ${episodes[$i]}" >> "$chapterfile"

  totaltime=$((totaltime+thiseplen))

  # skip tmp files that already exist to cut down time to process
  # This may cause problems if the tmpfiles from a broken run still
  # exist in the tmp dir. If that happens, delete the tmpfile or tmpdir
  if [ -f "$tmpfile" ]; then
     echo "Tmp file exists for ${episodes[$i]}. Skipping"
     continue
  fi

  # If you want to have the trailer left intact change the value of -to to something large like 04:00:00
  echo "Taking input from $inputfile"
  echo "------------- CUTTING : $inputfile -------------" >> "$logfile"
  ffmpeg -y -i "$inputfile" -ss ${episodes[$i+1]} -to ${episodes[$i+2]} -c copy "$tmpfile" 1>>"$logfile" 2>>"$logfile"
  status=$?
  if test $status -ne 0
  then
	echo "Failed ffmpeg for input: $inputfile see log file $logfile"
	exit 1
  fi

done

echo "------------- CONCATENATE -------------" >> "$logfile"

ffmpeg -f concat -safe 0 -i "$catfile" -c copy $outfile 1>>"$logfile" 2>>"$logfile"
status=$?
if test $status -ne 0
then
  echo "Failed ffmpeg for concat: $catfile see log file $logfile"
fi

# Add chapters to output file. This part is ongoing research. There appears to be a lax
# standard for chapter marks in MP3 files. The eyeD3 python tool and library has support
# for adding the marks and there is a python script that does the hard work.
#     pip install eyeD3
#     pip install mp3chaps

echo "------------- CHAPTERS -------------" >> "$logfile"

# If you get an error on mp3chaps at or near line 44 about the TLEN tag, then you'll need to
# Modify the python source using the diffs in this github PR.
# https://github.com/dskrad/mp3chaps/pull/1/commits/f085024cd5bd367b4d2ec692701fffebf296de24
mp3chaps -i "$outfile" 1>>"$logfile" 2>>"$logfile"
status=$?
if test $status -ne 0
then
  echo "Failed mp3chaps: $catfile see log file $logfile"
fi

# rm $catfile
# rm $chapterfile