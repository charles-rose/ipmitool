#!/bin/bash
#
#  Copyright (c) 2003 Fredrik Ohrn.  All Rights Reserved.
#
#  See the included COPYING file for license details.
#

# Edit the variables

hostname=$HOSTNAME

ipmi_cmd="/usr/local/bin/ipmitool -I open"
rrd_dir="/some/dir/rrd"

# Full path to the rrdcgi executable.
rrdcgi=/usr/local/bin/rrdcgi

# Where should rrdcgi store the graphs? This path must be within the
# document root and writable by the webserver user.
img_dir=/usr/local/apache2/htdocs/images/graphs

# Where will the graphs show up on the webserver?
web_dir=/images/graphs

# No need to edit below this point.

color[0]="0000FF"
color[1]="00FF00"
color[2]="FF0000"
color[3]="FFFF00"
color[4]="FF00FF"
color[5]="00FFFF"
color[6]="4444AA"
color[7]="44AA44"
color[8]="AA4444"
color[9]="AAAA44"
color[10]="AA44AA"
color[11]="44AAAA"

cat << EOF
#!$rrdcgi
<html>
<head>
<title>$hostname</title>
<RRD::GOODFOR 300>
<body>
<h2>$hostname</h2>
EOF


IFS="
"

i=0
groups=

for line in `eval $ipmi_cmd -c -v sdr list full` ; do

	IFS=,

	split=($line)

	file="$rrd_dir/$hostname-${split[0]}.rrd"
	group=`echo "${split[2]} ${split[*]:10:6}" | tr ' .-' ___`

	group_color=${group}_color

	if [ -z "${!group}" ] ; then
		groups="$groups $group"

		declare $group_color=0

		group_unit=${group}_unit
		declare $group_unit="${split[2]}"

		group_title=${group}_title
		declare $group_title="${split[5]} / ${split[6]}"

		group_thres=${group}_thres
		declare $group_thres="${split[10]},${split[11]},${split[12]},${split[13]},${split[14]},${split[15]}"
	fi

	declare $group="${!group}
  DEF:var$i=\"$file\":var:AVERAGE LINE1:var$i#${color[${!group_color}]}:\"${split[0]}\""

	declare $group_color=$[ ${!group_color} + 1 ]

	c=$[ c + 1 ]
	i=$[ i + 1 ]
done

IFS=" "

for group in $groups ; do

	group_unit=${group}_unit
	group_title=${group}_title
	group_thres=${group}_thres

	IFS=,

	split=(${!group_thres})

	thres=

	if [ -n "${split[0]}" ] ; then
		if [ -n "${split[3]}" ] ; then
			thres="
  HRULE:${split[0]}#000000
  HRULE:${split[3]}#000000:\"Upper & lower non-recoverable thresholds\""
		else
			thres="
  HRULE:${split[0]}#000000:\"Upper non-recoverable threshold\""
		fi
	else
		if [ -n "${split[3]}" ] ; then
			thres="
  HRULE:${split[3]}#000000:\"Lower non-recoverable threshold\""
		fi
	fi

	if [ -n "${split[1]}" ] ; then
		if [ -n "${split[4]}" ] ; then
			thres="$thres
  HRULE:${split[1]}#FF0000
  HRULE:${split[4]}#FF0000:\"Upper & lower critical thresholds\""
		else
			thres="$thres
  HRULE:${split[1]}#FF0000:\"Upper critical threshold\""
		fi
	else
		if [ -n "${split[4]}" ] ; then
			thres="$thres
  HRULE:${split[4]}#FF0000:\"Lower critical threshold\""
		fi
	fi

	if [ -n "${split[2]}" ] ; then
		if [ -n "${split[5]}" ] ; then
			thres="$thres
  HRULE:${split[2]}#FFCC00
  HRULE:${split[5]}#FFCC00:\"Upper & lower warning thresholds\""
		else
			thres="$thres
  HRULE:${split[2]}#FFCC00:\"Upper warning threshold\""
		fi
	else
		if [ -n "${split[5]}" ] ; then
			thres="$thres
  HRULE:${split[5]}#FFCC00:\"Lower warning threshold\""
		fi
	fi


	cat << EOF
<h3>${!group_title}</h3>
<RRD::GRAPH "$img_dir/$hostname-$group-daily.gif"
  --imginfo "<img src="$web_dir/%s" width="%lu" height="%lu">"
  --lazy
  --height 200
  --vertical-label "${!group_unit}"
  --title "Daily graph"
  --width 576 ${!group} $thres
>
<RRD::GRAPH "$img_dir/$hostname-$group-weekly.gif"
  --imginfo "<img src="$web_dir/%s" width="%lu" height="%lu">"
  --lazy
  --start -7d
  --height 200
  --vertical-label "${!group_unit}"
  --title "Weelky graph"
  --width 672 ${!group} $thres
>
EOF
#<RRD::GRAPH "$img_dir/$hostname-$group-monthly.gif"
#  --imginfo "<img src="$web_dir/%s" width="%lu" height="%lu">"
#  --lazy
#  --start -30d
#  --height 200
#  --vertical-label "${!group_unit}"
#  --title "Monthly graph"
#  --width 720 ${!group} $thres
#>
#EOF

done

cat << EOF
</body>
</html>
EOF
