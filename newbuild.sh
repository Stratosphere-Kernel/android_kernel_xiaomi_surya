#!/bin/bash
# 
# Odds and Ends for Android Kernel Building 
# Copyright 2022 Karthik Sreedevan <taalojarvi@github.com>
# Portions Copyright Aayush Gupta <TheImpulson@github.com>
# Based on @TheImpulson's FireKernel Buildscript with a few additions and fixes of my own
#
# If you modify this script to suit  your needs, add your authorship info in the following format
# Portions Copyight <YEAR> <NAME> <EMAIL>
#
export SECONDS=0
export TZ=Etc/UTC
BUILD_START=$(date +"%s")


# Colours and Graphics
blue='\033[0;34m'
cyan='\033[0;36m'
yellow='\033[0;33m'
red='\033[0;31m'
nocol='\033[0m'
green='\e[32m'
DIVIDER="$blue***********************************************$nocol"


# Kernel details
KERNEL_NAME="Stratosphere"
VERSION="Kernel"
RELEASE_MSG="Stratosphere Kernel: Personal Machine Build"
DEFCONFIG=vendor/surya-perf_defconfig
# Need not edit these.
DATE=$(date +"%d-%m-%Y-%I-%M")
SHORTDATE=$(date +"%d-%m-%Y")
TIMESTAMP=$(date)
LOG="Build"-$SHORTDATE
FINAL_ZIP=$KERNEL_NAME-$VERSION-$DATE.zip
RELEASE_TAG=earlyaccess-$DATE


# Dirs and Files
BASE_DIR=$HOME
KERNEL_DIR=$(pwd)
ANYKERNEL_DIR=$BASE_DIR/AnyKernel3
UPLOAD_DIR=$BASE_DIR/Stratosphere-Canaries
TC_DIR=$BASE_DIR/azure-clang
LOG_DIR=$BASE_DIR/logs
CONFIG_DIR=$BASE_DIR/configs

# Need not be edited
RELEASE_NOTES=$UPLOAD_DIR/releasenotes.md
OUTPUT=$BASE_DIR/output
KERNEL_IMG=$OUTPUT/arch/arm64/boot/Image
KERNEL_DTBO=$OUTPUT/arch/arm64/boot/dtbo.img
KERNEL_DTB=$OUTPUT/arch/arm64/boot/dts/qcom/sdmmagpie.dtb



# Export Environment Variables. 
export PATH="$TC_DIR/bin:$PATH"
# export PATH="$TC_DIR/bin:$HOME/gcc-arm/bin${PATH}"
export CLANG_TRIPLE=aarch64-linux-gnu-
export ARCH=arm64
# export CROSS_COMPILE=~/gcc-arm64/bin/aarch64-elf-
# export CROSS_COMPILE_ARM32=~/gcc-arm/bin/arm-eabi-
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
export LD_LIBRARY_PATH=$TC_DIR/lib
# Need not be edited.
export KBUILD_BUILD_USER=$USER
export KBUILD_BUILD_HOST=$(hostname)
export USE_HOST_LEX=yes
export USE_CCACHE=1
export CCACHE_EXEC=$(command -v ccache)
if [ "$(cat /sys/devices/system/cpu/smt/active)" = "1" ]; then
		export THREADS=$(expr $(nproc --all) \* 2)
	else
		export THREADS=$(nproc --all)
	fi
	
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !BE CAREFUL EDITING PAST THIS POINT!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Create default preferences
function create_prefs() {
	printf "\n$cyan Writing default preferences! $nocol\n"
	mkdir "$CONFIG_DIR"/
	touch "$CONFIG_DIR"/kscript.prefs.enabled
	echo 105 >> "$CONFIG_DIR"/kscript.prefs.enabled
	touch "$CONFIG_DIR"/pref.packaging
	echo false >> "$CONFIG_DIR"/pref.packaging
	touch "$CONFIG_DIR"/pref.ramdisk
	echo false >> "$CONFIG_DIR"/pref.ramdisk
	touch "$CONFIG_DIR"/pref.kuser
	echo "$KBUILD_BUILD_USER" >> "$CONFIG_DIR"/pref.kuser
	touch "$CONFIG_DIR"/pref.hostname
	echo "$KBUILD_BUILD_HOST" >> "$CONFIG_DIR"/pref.hostname
	touch "$CONFIG_DIR"/pref.buildtype
	echo clean >> "$CONFIG_DIR"/pref.buildtype
	touch "$CONFIG_DIR"/pref.release
	echo false >> "$CONFIG_DIR"/pref.release
	touch "$CONFIG_DIR"/pref.updaterepo
	echo false >> "$CONFIG_DIR"/pref.updaterepo
	load_prefs
}

# Load Preferences from prop files
function load_prefs() {
	
	printf "\n$cyan Loading Preferences $nocol"
	if [ -f "$CONFIG_DIR"/kscript.prefs.enabled ]; then
			if [ "$(cat "$CONFIG_DIR"/kscript.prefs.enabled)" = "105" ];then
				printf "$cyan <$green SUCCESS! $cyan>$nocol\n" 
				export PREFS_PACKAGING=$(cat "$CONFIG_DIR"/pref.packaging)
				export PREFS_RAMDISK=$(cat "$CONFIG_DIR"/pref.ramdisk)
				export KBUILD_BUILD_USER=$(cat "$CONFIG_DIR"/pref.kuser)
				export KBUILD_BUILD_HOST=$(cat "$CONFIG_DIR"/pref.hostname)
				export PREFS_BUILDTYPE=$(cat "$CONFIG_DIR"/pref.buildtype)
				export PREFS_RELEASE=$(cat "$CONFIG_DIR"/pref.release)
				export PREFS_UPDATEREPO=$(cat "$CONFIG_DIR"/pref.updaterepo)
			else 
				printf "$cyan <$red FAILED! $cyan>$nocol\n" 
				printf "\n$red Preferences are outdated! Regenerating!"
				rm -rf "$CONFIG_DIR"/
				create_prefs
			fi
		
	else
		printf "$cyan <$red FAILED! $cyan>$nocol\n" 
		create_prefs
	fi

}

# Toggle Preferences and store them on disk
function toggle_prefs {
	clear
	printf "\n$yellow Listing Preferences: "
	printf "\n"
	
	printf "\n$yellow 1. Create Package After Compilation "
	if [ "$PREFS_PACKAGING" = true ]; then
		printf "$cyan <$green ENABLED $cyan>$nocol\n" 
	else
		printf "$cyan <$red DISABLED $cyan>$nocol\n" 
	fi
	
	printf "\n$yellow 2. Use RAMDISK to speedup compilation "
	if [ "$PREFS_RAMDISK" = true ]; then
		printf "$cyan <$green ENABLED $cyan>$nocol\n" 
	else
		printf "$cyan <$red DISABLED $cyan>$nocol\n" 
	fi
	
	printf "\n$yellow 3. Update AK and TC Repos before Compilation"
	if [ "$PREFS_UPDATEREPO" = true ]; then
		printf "$cyan <$green ENABLED $cyan>$nocol\n" 
	else
		printf "$cyan <$red DISABLED $cyan>$nocol\n" 
	fi
	
	printf "\n$yellow 4. Release Package to Github "
	if [ "$PREFS_RELEASE" = true ]; then
		printf "$cyan <$green ENABLED $cyan>$nocol\n" 
	else
		printf "$cyan <$red DISABLED $cyan>$nocol\n" 
	fi
	
	
	
	printf "\n$yellow 5. Toggle Build Type "
	if [ "$PREFS_BUILDTYPE" = clean ]; then
		printf "$cyan <$green CLEAN $cyan>$nocol\n" 
	else
		printf "$cyan <$red DIRTY $cyan>$nocol\n" 
	fi
	
	printf "\n$yellow 6. Set Custom Build Username "
	printf "$cyan <$green $KBUILD_BUILD_USER $cyan>$nocol\n"
	printf "\n$yellow 7. Set Custom Build Hostname "
	printf "$cyan <$green $KBUILD_BUILD_HOST $cyan>$nocol\n"  
	
	printf "\n"
	printf "\n$yellow 8. Exit to Main Menu"
	printf "\n"
	printf "\n$yellow Awaiting User Input: $red"
	read toggle
	case $toggle in
		1) if [ $PREFS_PACKAGING = true ]; then
			sed -i "s/true/false/" "$CONFIG_DIR"/pref.packaging
			export PREFS_PACKAGING=$(cat "$CONFIG_DIR"/pref.packaging)
			sed -i "s/true/false/" "$CONFIG_DIR"/pref.release
			export PREFS_RELEASE=$(cat "$CONFIG_DIR"/pref.release)
		   else
		   	sed -i "s/false/true/" "$CONFIG_DIR"/pref.packaging
		   	export PREFS_PACKAGING=$(cat "$CONFIG_DIR"/pref.packaging)
		   fi
		   toggle_prefs
		   ;;
		2) if [ $PREFS_RAMDISK = true ]; then
			sed -i "s/true/false/" "$CONFIG_DIR"/pref.ramdisk
			export PREFS_RAMDISK=$(cat "$CONFIG_DIR"/pref.ramdisk)
		   else
		   	sed -i "s/false/true/" "$CONFIG_DIR"/pref.ramdisk
		   	export PREFS_RAMDISK=$(cat "$CONFIG_DIR"/pref.ramdisk)
		   fi
		   toggle_prefs
		   ;;
		3) if [ $PREFS_UPDATEREPO = true ]; then
			sed -i "s/true/false/" "$CONFIG_DIR"/pref.updaterepo
			export PREFS_UPDATEREPO=$(cat "$CONFIG_DIR"/pref.updaterepo)
		   else
		   	sed -i "s/false/true/" "$CONFIG_DIR"/pref.updaterepo
		   	export PREFS_UPDATEREPO=$(cat "$CONFIG_DIR"/pref.updaterepo)
		   fi
		   toggle_prefs
		   ;;
		4) if [ $PREFS_RELEASE = true ]; then
			sed -i "s/true/false/" "$CONFIG_DIR"/pref.release
			export PREFS_RELEASE=$(cat "$CONFIG_DIR"/pref.release)
		   else
		   	sed -i "s/false/true/" "$CONFIG_DIR"/pref.release
		   	sed -i "s/false/true/" "$CONFIG_DIR"/pref.packaging
		   	export PREFS_RELEASE=$(cat "$CONFIG_DIR"/pref.release)
		   	export PREFS_PACKAGING=$(cat "$CONFIG_DIR"/pref.packaging)
		   	
		   fi
		   toggle_prefs
		   ;;
		5) if [ $PREFS_BUILDTYPE = clean ]; then
			sed -i "s/clean/dirty/" "$CONFIG_DIR"/pref.buildtype
			export PREFS_BUILDTYPE=$(cat "$CONFIG_DIR"/pref.buildtype)
		   else
		   	sed -i "s/dirty/clean/" "$CONFIG_DIR"/pref.buildtype
		   	export PREFS_BUILDTYPE=$(cat "$CONFIG_DIR"/pref.buildtype)
		   fi
		   toggle_prefs
		   ;;
		6) printf "\n"
		   printf "\n$yellow Enter new username: $red"
		   read newuser
		   printf "\n"
		   if [ "$newuser" = "" ]; then
		   	printf "\n$red Username cannot be empty!\n"
		   	toggle_prefs
		   else
		   	sed -i "s/$KBUILD_BUILD_USER/$newuser/" "$CONFIG_DIR"/pref.kuser
		   	export KBUILD_BUILD_USER=$(cat "$CONFIG_DIR"/pref.kuser)
		   	toggle_prefs 
		   fi
		   ;;
		7) printf "\n"
		   printf "\n$yellow Enter new hostname: $red"
		   read newhost
		   printf "\n"
		   if [ "$newhost" = "" ]; then
		   	printf "\n$red Hostname cannot be empty!\n"
		   	toggle_prefs
		   else
		   	sed -i "s/$KBUILD_BUILD_HOST/$newhost/" "$CONFIG_DIR"/pref.hostname
		   	export KBUILD_BUILD_HOST=$(cat "$CONFIG_DIR"/pref.hostname)
		   	toggle_prefs 
		   fi
		   ;;
		8) menu
		   ;;
		*) menu
		   ;;
	esac
}

# Check if script is unmodified since last run to reduce Disk I/O with preflight checks
function check_hash() {
	if [ ! -f "$CONFIG_DIR"/kscript.hash ]; then
		printf "\n$cyan Checksum file not found. Creating!$nocol\n"
		touch "$CONFIG_DIR"/kscript.hash
	else
		printf "$cyan Previous checksum found!$nocol\n"
	fi
	printf "$cyan Checking if script has been modified "
	export CHECKSUM_CURRENT=$(md5sum $(pwd)/"$0")
	export CHECKSUM_FILE=$(cat "$CONFIG_DIR"/kscript.hash)
	if [ "$CHECKSUM_CURRENT" = "$CHECKSUM_FILE" ]; then
		printf "$cyan <$green SUCCESS! $cyan>$nocol\n" 
	else
		printf "$cyan <$red FAILED! $cyan>$nocol\n" 
		preflight
	fi
}

# Pre-Flight Checks
function preflight() {
	printf "\n"
	printf "$DIVIDER\n"
	printf "$cyan Checking if Directories are valid\n$nocol"
	printf "$DIVIDER\n"
	printf "\n"
	
	printf "$cyan Checking Anykernel directory "
	if [ -d "$ANYKERNEL_DIR" ]; then
		printf "<$green SUCCESS $cyan> \n"
	else
		printf "<$red FAILED $cyan> \n"
		printf "$red Please edit script with correct directory! $nocol \n"
		exit 1 
	fi
	
	printf "$cyan Checking Release Package directory "
	if [ -d "$UPLOAD_DIR" ]; then
		printf "<$green SUCCESS $cyan> \n"
	else
		printf "<$red FAILED $cyan> \n"
		mkdir "$UPLOAD_DIR" 
	fi
	
	printf "$cyan Checking Logs Directory "
	if [ -d "$UPLOAD_DIR" ]; then
		printf "<$green SUCCESS $cyan> \n"
	else
		printf "<$red FAILED $cyan> \n"
		mkdir "$LOG_DIR" 
	fi
	
	printf "$cyan Checking Toolchain directory "
	if [ -d "$TC_DIR" ]; then
		printf "<$green SUCCESS $cyan> \n"
	else
		printf "<$red FAILED $cyan> \n"
		printf "$red Please edit script with correct directory $nocol \n" 
		exit 1
	fi
	
	printf "\n"
	
	printf "$cyan Generating Hash for Buildscript $nocol\n"
	rm "$CONFIG_DIR"/kscript.hash
	touch "$CONFIG_DIR"/kscript.hash
	md5sum $(pwd)/"$0" >> "$CONFIG_DIR"/kscript.hash
}
# Create Release Notes
function make_releasenotes()  {
	touch releasenotes.md
	echo -e "#earlyaccess" > releasenotes.md
	echo -e >> releasenotes.md
	echo -e "This is an Early Access Build of "$KERNEL_NAME" Kernel. Flash at your own risk!" >> releasenotes.md
	COMPILE_END=$(("$SECONDS"%3600/60))
#	CDIFF=$(($COMPILE_END - $COMPILE_START))
#	export COMPILE_END=$( "$(SECONDS)" % 3600)/60
#	printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)) >> releasenotes.md
	BUILD_END=$(date +"%s")
	DIFF=$(($BUILD_END - $BUILD_START))
	echo -e "Build completed after $((DIFF/60)) minute(s)" >> releasenotes.md
# 	echo -e "Build completed after ""$COMPILE_END"" minutes on "$KBUILD_BUILD_HOST"" >>releasenotes.md
	echo -e "Build Date: ""$TIMESTAMP" >> releasenotes.md
	echo -e >> releasenotes.md
	echo -e "Last 5 Commits before Build:-" >> releasenotes.md
	git log --decorate=auto --pretty=format:'%C(yellow)%d%Creset %s %C(bold blue)<%an>%Creset %n' --graph -n 10 >> releasenotes.md
	cp releasenotes.md "$RELEASE_NOTES"
}

# Make defconfig
function make_defconfig()  {
	echo -e " "
#	make $DEFCONFIG LD=aarch64-elf-ld.lld O=$OUTPUT 2>&1 | tee -a "$LOG_DIR"/"$LOG"
	make $DEFCONFIG CC='ccache clang -Qunused-arguments -fcolor-diagnostics' LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip O="$OUTPUT"
}

# Make Kernel
function make_kernel  {
	echo -e " "
	COMPILE_START=$(date +"%s")
#	make -j$THREADS LD=ld.lld O=$OUTPUT 2>&1 | tee -a "$LOG_DIR"/"$LOG"
	make -j"$THREADS" CC='ccache clang -Qunused-arguments -fcolor-diagnostics' LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip O="$OUTPUT" 2>&1 | tee -a "$LOG_DIR"/"$LOG"
# Check if Image.gz-dtb exists. If not, stop executing.
	if ! [ -a "$KERNEL_IMG" ];
 		then
    		echo -e "$red An error has occured during compilation. Please check your code. $cyan"
    		exit 1
    	else
    		printf "\n$green Kernel built succesfully! \n$cyan"
  	fi 
}

# Make Flashable Zip
function make_package()  {
	printf "\n"
	printf "\n$green Packaging Kernel! \n"
	cp "$KERNEL_IMG" "$ANYKERNEL_DIR"
	cp "$KERNEL_DTB" "$ANYKERNEL_DIR"/dtb
	cp "$KERNEL_DTBO" "$ANYKERNEL_DIR"
	cd "$ANYKERNEL_DIR"
	zip -r9 UPDATE-AnyKernel2.zip * -x README.md LICENSE UPDATE-AnyKernel2.zip zipsigner.jar
	java -jar zipsigner.jar UPDATE-AnyKernel2.zip UPDATE-AnyKernel2-signed.zip
	mv UPDATE-AnyKernel2-signed.zip "$FINAL_ZIP"
	cp "$FINAL_ZIP" "$UPLOAD_DIR"
	cd "$KERNEL_DIR"
}

# Upload Flashable Zip to GitHub Releases <3
function release()  {
	printf "\n"
	printf "\n$red Releasing Kernel Package to Github! \n"
	cd "$UPLOAD_DIR"
	gh release create "$RELEASE_TAG" "$FINAL_ZIP" -F releasenotes.md -p -t "$RELEASE_MSG"
	cd "$KERNEL_DIR"
}

# Make Clean
function make_cleanup()  {
	echo -e "$DIVIDER"
	echo -e "$cyan    Cleaning out build artifacts. Please wait       "
	echo -e "$DIVIDER"
	echo -e " "
#	make clean LD=ld.lld O=$OUTPUT 2>&1 | tee -a "$LOG_DIR"/"$LOG"
#	make mrproper LD=ld.lld O=$OUTPUT 2>&1 | tee -a "$LOG_DIR"/"$LOG"
	make clean -j$THREADS CC='ccache clang -Qunused-arguments -fcolor-diagnostics' LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip O="$OUTPUT" 
	make mrproper -j$THREADS CC='ccache clang -Qunused-arguments -fcolor-diagnostics' LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip O="$OUTPUT"
}

# Check for Script Artifacts from previous builds
function artifact_check()  {
	echo -e " "
	echo -e "$red Deleting dtbo.img if found $cyan" 
	find "$ANYKERNEL_DIR" -name dtbo.img -delete 
	echo -e "$red Deleting releasenotes.md if found $cyan" 
	find "$ANYKERNEL_DIR" -name releasenotes.md -delete 
	echo -e "$red Deleting Image.gz-dtb if found $cyan"
	find "$ANYKERNEL_DIR" -name Image.gz-dtb -delete 
	echo -e "$red Deleting Image.gz-dtb if found $cyan" 
	find "$ANYKERNEL_DIR" -name Image.gz -delete 
	echo -e "$red Deleting sdmmagpie.dtb if found $cyan" 
	find "$ANYKERNEL_DIR" -name sdmmagpie.dtb -delete 
	find "$ANYKERNEL_DIR" -name dtb -delete 
	echo -e "$red Deleting releasenotes.md if found $cyan" 
	find "$KERNEL_DIR" -name releasenotes.md -delete 
	echo -e "$red Deleting zipped packages if found $cyan" 
	find "$ANYKERNEL_DIR" -name \*.zip -delete 
	echo -e "$red Deleting zipped packages if found $cyan" 
	find "$UPLOAD_DIR" -name \*.zip -delete 
}

# Update Toolchain Repository
function update_repo()  {
	echo -e " "
	cd "$TC_DIR"
	git pull origin --ff-only
	cd "$ANYKERNEL_DIR"
	git pull https://github.com/osm0sis/AnyKernel3 master
	git push
	cd "$KERNEL_DIR"
}

# Open Menuconfig
function make_menuconfig()  {
	echo -e " "
	make nconfig CC='ccache clang -Qunused-arguments -fcolor-diagnostics' LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip O="$OUTPUT"
	# make menuconfig LD=ld.lld O=$OUTPUT 2>&1 | tee -a "$LOG_DIR"/"$LOG"
}

# Clear CCACHE
function clear_ccache  {
	echo -e " "
	ccache -Cz
}

# Regenerate Defconfig
function regen_defconfig()  {
	echo -e " "
	cp "$OUTPUT"/.config "$KERNEL_DIR"/arch/arm64/configs/"$DEFCONFIG"
	# git commit arch/arm64/configs/$DEFCONFIG
}
	
# Menu
function menu()  {
	clear
	echo -e "$yellow What do you want to do?"
	echo -e ""
	echo -e "1: Build Kernel"
	echo -e "2: Open Menuconfig"
	echo -e "3: Cleanup script artifacts"
	echo -e "4: Clear ccache and reset stats"
	echo -e "5: Regenerate defconfig"
	echo -e "6: Toggle Preferences"
	echo -e "7: Exit to Shell"
	echo -e ""
	echo -e "Awaiting User Input: $red"
	read choice
	
	case $choice in
		1) echo -e "$DIVIDER"
		   echo -e "$cyan        Building "$KERNEL_NAME "Kernel         "
		   echo -e "$DIVIDER"
		   if [ "$PREFS_UPDATEREPO" = "true" ]; then
		   	update_repo
		   else
		   	printf "\n$red Skipping Repo Updation\n$cyan"
		   fi
		   if [ "$PREFS_BUILDTYPE" = "clean" ]; then
		   	make_cleanup
		   else
		   	printf "\n$red Skipping Cleanup$cyan"
		   fi
		   artifact_check
		   make_defconfig
	 	   make_kernel
	 	   if [ "$PREFS_RELEASE" = "true" ]; then
		   	make_releasenotes 
		   else
		   	printf "\n$red Skipping Changelog Generation$cyan"
		   fi 
	 	   if [ "$PREFS_PACKAGING" = "true" ]; then
		   	make_package
		   else
		   	printf "\n$red Skipping Packaging$cyan"
		   fi
	 	   if [ "$PREFS_RELEASE" = "true" ]; then
		   	release
		   else
		   	printf "\n$red Skipping Release$cyan"
		   fi
	 	   ;;
	 	2) echo -e "$DIVIDER"
		   echo -e "$cyan        Opening Menuconfig                          "
		   echo -e "$DIVIDER"
	 	   make_defconfig
	 	   make_menuconfig
	 	   menu
	 	   ;;
	 	3) make_cleanup
	 	   artifact_check
	 	   menu
	 	   ;;
	 	4) echo -e "$DIVIDER"
		   echo -e "$cyan    Clearing CCACHE                            "
		   echo -e "$DIVIDER"
	 	   clear_ccache
	 	   menu
	 	   ;;
	 	5) echo -e "$DIVIDER"
		   echo -e "$cyan    Regenerating defconfig. Please wait        "
		   echo -e "$DIVIDER"
	 	   make_defconfig
	 	   regen_defconfig
	 	   menu
	 	   ;;
	 	6) toggle_prefs
	 	   ;;
	 	7) echo -e "$red Exiting"
	 	   clear
	 	   ;;
	 	1010) debug_menu
	 	   ;; 
	 	   
	 esac
	
}
# Super Secret Debug Menu
function debug_menu()  {
	clear
	echo -e "$red Super Secret Debug Menu"
	echo -e ""
	echo -e "1: artifact_check"
	echo -e "2: update_repo"
	echo -e "3: make_cleanup"
	echo -e "4: clear_ccache"
	echo -e "5: make_defconfig"
	echo -e "6: regen_defconfig"
	echo -e "7: toggle_prefs"
	echo -e "8: make_package"
	echo -e "9: make_cleanup"
	echo -e "10: make_kernel"
	echo -e "11: release"
	echo -e "12: menu"
	echo -e "13: make_releasenotes"
	echo -e ""
	echo -e "Awaiting User Input: $yellow"
	read dchoice
	
	case $dchoice in
		1) artifact_check 
	 	   ;;
	 	2) update_repo
	 	   ;;
	 	3) make_cleanup
	 	   ;;
	 	4) clear_ccache
	 	   ;;
	 	5) make_defconfig
	 	   ;;
	 	6) make_menuconfig
	 	   ;;
	 	7) regen_defconfig
	 	   ;;
	 	8) make_package
	 	   ;; 
	 	9) make_cleanup
	 	   ;;
	       10) make_kernel
	 	   ;;
	       11) release
	       	   ;;
	       12) menu
	       	   ;;
	       13) make_releasenotes
	 esac
	
}
printf "\n" | tee -a "$LOG_DIR"/"$LOG"
printf "Script started on "$DATE"\n" | tee -a "$LOG_DIR"/"$LOG"
printf "\n" | tee -a "$LOG_DIR"/"$LOG"
load_prefs
check_hash
menu
sed -i 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$LOG_DIR"/"$LOG"
BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))
echo -e "Script execution completed after $((DIFF/60)) minute(s) and $((DIFF % 60)) seconds"

