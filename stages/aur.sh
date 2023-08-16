#!/bin/bash

. ./color_output.sh

#scripts base
#aur_path_base=/var/xiange/aur
aur_path_base=/tmp/aur
aur_path_script=/var/xiange/aur

next_op=0



#$1 is package name
do_download_script()
{


	if [ ! -d "$aur_path_base/$1" ]; then
		#first time
		cd "$aur_path_base"
		err_check "cd $aur_path_base failed"

		#first, clone it from gitlab
		git clone https://gitlab.archlinux.org/archlinux/packaging/packages/${1}.git
		if [ ! -f $aur_path_base/$1/PKGBUILD ]; then
			rm -rf $aur_path_base/$1 2>&1 > /dev/null 
			git clone https://aur.archlinux.org/${1}.git
			if [ ! -f $aur_path_base/$1/PKGBUILD ]; then
				showFailed "clone failed: PKGBUILD not found"
				exit 1
			fi
		fi

	else
		cd "$aur_path_base/$1"
		err_check "enter $1 failed"
		git pull 
		if [ "$?" != "0" ]; then
			showFailed "pull $1 falied"
		fi
	fi
}


gpkg_read()
{
	local line
	local count
	local -a value
	local rest="0"
	local nl=0

	while IFS=, read -r -a value
	do
		nl=$((${nl} + 1))
		count=${#value[*]}
		[ $count == 0 ] && continue

		showinfo "($nl) Sync package ${value[0]}.."
		do_download_script "${value[0]}"

		unset value
	done
}


#read from a file, $1 is file name, $2 is operation
gpkg_readfile()
{
	XG_CSV_OP=$2
	gpkg_read < $1
}




do_update_list()
{
	local dats=$(date)

	mv pkg.tmp pkg_list
	err_check "copy failed"
	git add pkg_list
	err_check "add pkg_list failed"
	git commit -m "$dats"
	err_check "commit pkg_list failed"
}

do_sync()
{
	showinfo "syncing AUR PKGBUILD database.."
	if [ ! -d $aur_path_base ]; then
		showinfo "create dir: $aur_path_base"

		mkdir -p $aur_path_base
		err_check "create $aur_path_base failed"

		cd $aur_path_base
		err_check "cd $aur_path_base failed"

		git init
		err_check "git init in $aur_path_base failed"
	else
		cd $aur_path_base
		err_check "cd $aur_path_base failed"
	fi


	#get all aur files
	showinfo "get packages infomation from server.."
	curl https://aur.archlinux.org/packages.gz -o pkg.tmp.gz
	err_check "retrive https://aur.archlinux.org/packages.gz failed"

	#unzip
	gunzip -f pkg.tmp.gz
	err_check "gunzip pkg.tmp.gz failed"

	if [ -f $aur_path_base/pkg_list ]; then
		showinfo "comparing with pkg_list .."
		diff -u pkg_list pkg.tmp > /tmp/pkg.diff

		if [ "$?" == "0" ]; then
			#no change.
			showinfo "No change found"
		else
			showinfo "changes found, added to git.."
			do_update_list
		fi
	else
		showinfo "pkg_list not found, update first time.."
		do_update_list
	fi

	#sync all packages..
	#gpkg_readfile pkg_list
}


#search packages
do_search()
{
	local pname="$1"
	if [ ! -f $aur_path_base/pkg_list ]; then
		#not init
		do_sync
	fi

	#search $pname 
	cat /tmp/aur/pkg_list | grep "$pname" | nl
}

#install packages
do_install()
{
	echo "in sync AUR PKGBUILD database.."
}

#$1 is package name
do_show_pkgbuild()
{
	showinfo "syncing scripts with server.."
	do_download_script "$1"

	cd $aur_path_base/$1
	err_check "enter $aur_path_base/$1 failed"

	showinfo "all files:"
	ls -lh $aur_path_base/$1

	showinfo "showing PKGBUILD..."
	cat PKGBUILD
}

#install packages
do_mode()
{
	if [ -z "$1" ]; then
		showFailed "No package name specified."
		showinfo "Usage: -m info package_name"
		exit 1
	fi

	showinfo "Mode: $op_args, package=$1"

	if [ "$op_args" == "info" ]; then
		do_show_pkgbuild "$1"
	fi
}


#install packages
do_help()
{
	echo "in sync AUR PKGBUILD database.."
}

while getopts ":Ssipm:h" opt
do
	case $opt in
		S)
			next_op=do_sync
			;;

		s)
			next_op=do_search
			;;

		i)
			next_op=do_install
			;;

		m)
			op_args=$OPTARG
			next_op=do_mode
			;;

		p)
			echo "show dependent"
			;;

		d)
			echo "no dependent"
			;;

		?)
			next_op=do_help
			;;
	esac
done

shift $(($OPTIND-1))

p1=$1
#echo "p1=$1"

$next_op $1





