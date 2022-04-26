#!/bin/bash


# Clone the repositories
git clone --depth 1 https://gitlab.com/Panchajanya1999/azure-clang.git azure
git clone --depth 1 -b surya https://github.com/taalojarvi/AnyKernel3
git clone --depth 1 https://github.com/Stratosphere-Kernel/Stratosphere-Canaries

# Workaround for safe.directory permission fix
git config --global safe.directory "$GITHUB_WORKSPACE"
git config --global safe.directory /github/workspace
git config --global --add safe.directory /__w/android_kernel_xiaomi_surya/android_kernel_xiaomi_surya

# Export Environment Variables. 
export DATE=$(date +"%d-%m-%Y-%I-%M")
export PATH="$(pwd)/azure/bin:$PATH"
# export PATH="$TC_DIR/bin:$HOME/gcc-arm/bin${PATH}"
export CLANG_TRIPLE=aarch64-linux-gnu-
export ARCH=arm64
# export CROSS_COMPILE=~/gcc-arm64/bin/aarch64-elf-
# export CROSS_COMPILE_ARM32=~/gcc-arm/bin/arm-eabi-
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
export LD_LIBRARY_PATH=$TC_DIR/lib
export KBUILD_BUILD_USER="taalojarvi"
export KBUILD_BUILD_HOST="Github Actions CI"
export USE_HOST_LEX=yes
export KERNEL_IMG=output/arch/arm64/boot/Image
export KERNEL_DTBO=output/arch/arm64/boot/dtbo.img
export KERNEL_DTB=output/arch/arm64/boot/dts/qcom/sdmmagpie.dtb
export DEFCONFIG=vendor/surya-perf_defconfig
export ANYKERNEL_DIR=$(pwd)/AnyKernel3/
export TC_DIR=$(pwd)/azure/

# Telegram API Stuff
BUILD_START=$(date +"%s")
export GITHUB_TOKEN=$TOKEN
export token=$TGKEN
KBUILD_COMPILER_STRING=$("$TC_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
BOT_MSG_URL="https://api.telegram.org/bot$token/sendMessage"
BOT_BUILD_URL="https://api.telegram.org/bot$token/sendDocument"
CHATID=-1001719821334
COMMIT_HEAD=$(git log --oneline -1)
TERM=xterm
if [ "$(cat /sys/devices/system/cpu/smt/active)" = "1" ]; then
		export THREADS=$(expr $(nproc --all) \* 2)
	else
		export THREADS=$(nproc --all)
	fi
##---------------------------------------------------------##

tg_post_msg() {
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$CHATID" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"

}

##----------------------------------------------------------------##

tg_post_build() {
	#Post MD5Checksum alongwith for easeness
	MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)

	#Show the Checksum alongwith caption
	curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
	-F chat_id="$CHATID"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=Markdown" \
	-F caption="$2 | *MD5 Checksum : *\`$MD5CHECK\`"
}

##----------------------------------------------------------##

# Create Release Notes
touch releasenotes.md
echo -e "This is an Automated Build of Stratosphere Kernel. Flash at your own risk!" > releasenotes.md
echo -e >> releasenotes.md
echo -e "Build Information" >> releasenotes.md
echo -e >> releasenotes.md
echo -e "Build Server Name: "$RUNNER_NAME >> releasenotes.md
echo -e "Build ID: "$GITHUB_RUN_ID >> releasenotes.md
echo -e "Build URL: "$GITHUB_SERVER_URL >> releasenotes.md
echo -e >> releasenotes.md
echo -e "Last 5 Commits before Build:-" >> releasenotes.md
git log --decorate=auto --pretty=reference --graph -n 10 >> releasenotes.md
cp releasenotes.md $(pwd)/Stratosphere-Canaries/

# Make defconfig
make $DEFCONFIG -j$THREADS CC=clang LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip O=output/

# Make Kernel
tg_post_msg "<b> Build Started on Github Actions</b>%0A<b>Build Number: </b><code>"$GITHUB_RUN_NUMBER"</code>%0A<b>Date : </b><code>$(TZ=Etc/UTC date)</code>%0A<b>Top Commit : </b><code>$COMMIT_HEAD</code>%0A"
make -j$THREADS CC=clang LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip O=output/

# Check if Image.gz-dtb exists. If not, stop executing.
if ! [ -a $KERNEL_IMG ];
  then
    echo "An error has occured during compilation. Please check your code."
    tg_post_msg "<b>An error has occured during compilation. Build has failed</b>%0A"
    exit 1
  fi 

# Make Flashable Zip
cp "$KERNEL_IMG" "$ANYKERNEL_DIR"
cp "$KERNEL_DTB" "$ANYKERNEL_DIR"/dtb
cp "$KERNEL_DTBO" "$ANYKERNEL_DIR"
cd AnyKernel3
zip -r9 UPDATE-AnyKernel2.zip * -x README.md LICENSE UPDATE-AnyKernel2.zip zipsigner.jar
cp UPDATE-AnyKernel2.zip package.zip
cp UPDATE-AnyKernel2.zip Stratosphere-$GITHUB_RUN_ID-$GITHUB_RUN_NUMBER.zip
BUILD_END=$(date +"%s")
DIFF=$((BUILD_END - BUILD_START))
tg_post_build "Stratosphere-$GITHUB_RUN_ID-$GITHUB_RUN_NUMBER.zip" "Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"


# Upload Flashable zip to tmp.ninja and uguu.se
# curl -i -F files[]=@Stratosphere-"$GITHUB_RUN_ID"-"$GITHUB_RUN_NUMBER".zip https://uguu.se/upload.php
# curl -i -F files[]=@Stratosphere-"$GITHUB_RUN_ID"-"$GITHUB_RUN_NUMBER".zip https://tmp.ninja/upload.php?output=text

cp Stratosphere-$GITHUB_RUN_ID-$GITHUB_RUN_NUMBER.zip ../Stratosphere-Canaries/
cd ../Stratosphere-Canaries/

# Upload Flashable Zip to GitHub Releases <3
gh release create earlyaccess-$DATE "Stratosphere-"$GITHUB_RUN_ID"-"$GITHUB_RUN_NUMBER.zip"" -F releasenotes.md -p -t "Stratosphere Kernel: Automated Build" || echo "gh-cli encountered an unexpected error"
