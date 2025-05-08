#!/bin/bash
# this program reads an input file and uses Tesseroid software to generate components of gravity fields
# 1 - path where the input file is located and the results should be stored

inputfile="$1/gravtestinput.dat"
path="/home/fomin/CODES/othersoft/tesseroids-master/bin/"

echo "Path to tesseroid is $path"
echo "Reading file $inputfile"
[ ! -f $inputfile ] && echo -e "INPUT FILE DOES NOT EXIST!" && exit

line=$(head -n 1 $inputfile)
read xb1 xb2 <<< ${line%$'\r'}
line=$(head -n 2 $inputfile | tail -n 1)
read yb1 yb2 <<< ${line%$'\r'}
line=$(head -n 3 $inputfile | tail -n 1)
read min_lon max_lon min_lat max_lat <<< ${line%$'\r'}
line=$(head -n 4 $inputfile | tail -n 1)
read thick N_z d_x E Z_Usec rho <<< ${line%$'\r'}
d_y=$d_x

echo "Longitude from $min_lon to $max_lon with step $d_x"
echo "Latitude from $min_lat to $max_lat with step $d_y"

echo "X prism size is from $xb1 to $xb2"
echo "Y prism size is from $yb1 to $yb2"
echo "Prism thickness is $thick"
echo "Number of prisms is $N_z"

echo "Z_Usec is $Z_Usec"
echo "Rock density is $rho"
echo "Elevation is $E"

lon=($(seq $min_lon $d_x $max_lon))
N_x=${#lon[@]}
lat=($(seq $min_lat $d_y $max_lat))
N_y=${#lat[@]}

((zb1=-$N_z*$thick))

filesph="$1/grav_tesse_sph.txt"
fileglq="$1/grav_tesse_glq.txt"
rm $filesph $fileglq &> /dev/null
echo "Writing results of computation in spherical coordinates to $filesph"
echo "Writing results of Gauss-Legendre Quadrature computation to $fileglq"

for ((k=1;k<=$N_z;k++))
do
   zb2=$zb1
   ((zb1=$zb2+$thick))
   ((depth=-($zb2+$zb1)/2))
   for ((i=0;i<$N_x;i++))
   do
      xp=${lon[$i]}
      for ((j=0;j<$N_y;j++))
      do
         yp=${lat[$j]}

         # Free Air and Geoid
         echo "$xb1 $xb2 $yb1 $yb2 $zb1 $zb2 $rho" > tess-model.txt
         $path/tess2prism < tess-model.txt > prism-model.txt
         echo "$xp $yp $E" > point.txt
         #Free Air - Spherical
         FAS=$($path/prismgs prism-model.txt < point.txt | awk 'NR==4 {print $6}')
         #Free Air - Gauss-Legendre Quadrature
         FAT=$($path/tessgz tess-model.txt < point.txt | awk 'NR==7 {print $4}')
         #Geoid - Spherical
         GES=$($path/prismpots prism-model.txt < point.txt | awk 'NR==4 {print $4}')
         GES=$(echo "$GES/9.81" | bc -l)
         #Geoid - Gauss-Legendre Quadrature
         GET=$($path/tesspot tess-model.txt < point.txt | awk 'NR==7 {print $4}')
         GET=$(echo "$GET/9.81" | bc -l)

         #Gradients
         echo "$xp $yp $Z_Usec" > point.txt
         #Gradients - Spherical
         line=$($path/prismggts prism-model.txt < point.txt | awk 'NR==4 {print $4" "$5" "$6" "$7" "$8" "$9}')
         read UxxS U_sec2S U_sec3S UyyS U_sec5S UzzS <<< ${line%$'\r'}
         #Gradients - Gauss-Legendre Quadrature
         UzzT=$($path/tessgzz tess-model.txt < point.txt | awk 'NR==7 {print $4}')
         UxxT=$($path/tessgxx tess-model.txt < point.txt | awk 'NR==7 {print $4}')
         UyyT=$($path/tessgyy tess-model.txt < point.txt | awk 'NR==7 {print $4}')

         #output the results
         echo "$xp $yp $depth $FAS $GES $UxxS $UyyS $UzzS" >> $filesph
         echo "$xp $yp $depth $FAT $GET $UxxT $UyyT $UzzT" >> $fileglq
      done
   done
   curper=$(echo "100*$k/$N_z" | bc)
   echo -en "\r$curper % completed ..."
done
echo -en "\rComputation finished!\n"
