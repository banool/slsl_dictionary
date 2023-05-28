# Dev notes

## Video format
I made the following changes to the videos:
- iOS would not play the m4v videos so I converted them to MP4 H.264.
- To reduce the filesize of the mov videos I also converted them to a lower quality MP4 H.264.
- I removed the audio from all files. Generally most m4a files had audio whereas the mov ones didn't to begin with.

Regarding duplicates, using [this script](https://stackoverflow.com/a/16278407/3846032), I found a bunch of videos with duplicate filenames. In all cases but one (Railway Station 3) they were actually the exact same video. I renamed B4_Places_RailwayStation3 to add a _1 / _2 to the first / second respectively to avoid the collision.

TODO:
1. Write a script to report videos not attached to entries.
2. Write a script to report video URLs in entries that don't correspond to videos actually in the bucket.


todo, make sure these files are okay:
```
$ ./find_duplicates.sh
./NIE Book 4_Buildings-Places Video Signs/B4_Places_RailwayStation3.mov
./NIE Book 4_Places Video Signs/B4_Places_RailwayStation3.mov
./NIE Book 2_ Family Video Signs/SLSL_Voc_Family_BrotherInLaw.mov
./NIE Book 1_ Family Video Signs/SLSL_Voc_Family_BrotherInLaw.mov
./NIE Book 2_ Family Video Signs/SLSL_Voc_Family_FatherInLaw.mov
./NIE Book 1_ Family Video Signs/SLSL_Voc_Family_FatherInLaw.mov
./NIE Book 2_ Family Video Signs/SLSL_Voc_Family_Granddaughter.mov
./NIE Book 1_ Family Video Signs/SLSL_Voc_Family_Granddaughter.mov
./NIE Book 2_ Family Video Signs/SLSL_Voc_Family_Grandson.mov
./NIE Book 1_ Family Video Signs/SLSL_Voc_Family_Grandson.mov
./NIE Book 2_ Family Video Signs/SLSL_Voc_Family_MotherInLaw.mov
./NIE Book 1_ Family Video Signs/SLSL_Voc_Family_MotherInLaw.mov
./NIE Book 2_ Family Video Signs/SLSL_Voc_Family_SisterInLaw.mov
./NIE Book 1_ Family Video Signs/SLSL_Voc_Family_SisterInLaw.mov
```
