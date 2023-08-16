#!/bin/bash

. ./color_output.sh

#scripts base
#aur_path_base=/var/xiange/aur
aur_path_base=/tmp/aur
aur_path_script=/var/xiange/aur

next_op=0

do_download_script()
{
	mkdir -p "$aur_path_base/$1"

	cd "$aur_path_base/$1"
	#curl -L -O https://aur.archlinux.org/cgit/aur.git/snapshot/{$1}.tar.gz
	git clone https://aur.archlinux.org/{$1}.git
}

do_update_list()
{
	local dats=$(date)

	cp pkg.tmp pkg_list
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
		diff -u pkg_list pkg.tmp > pkg.diff

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
}


#search packages
do_search()
{
	echo "in sync AUR PKGBUILD database.."
}

#install packages
do_install()
{
	echo "in sync AUR PKGBUILD database.."
}

#install packages
do_help()
{
	echo "in sync AUR PKGBUILD database.."
}

while getopts ":Ssiph" opt
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





