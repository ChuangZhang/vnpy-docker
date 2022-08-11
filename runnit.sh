dmidecode_info=$(whereis -b dmidecode)
dmidecode_path=`echo ${dmidecode_info#*:}`
echo $dmidecode_path
sudo docker run --name data --privileged \
-v ${dmidecode_path}:${dmidecode_path} -v /opt/data/vnpy:/var/vnpy -v /dev/mem:/dev/mem \
-p 222:222 -p 18124:18124 -p 18123:18123 -t -d -i zchuang:vnpy \
/bin/bash /root/.profile
