#!/bin/bash
set -e

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
pushd $dir > /dev/null

if [ ! "$#" -eq 1 ]; then
	echo "Usage: ./build.sh <target>"
	echo
	echo "e.g.:"
	echo "       ./build.sh release_debug"
	echo "       ./build.sh debug"
	echo	
	exit 1
fi

if [ ! -d ../godot ]; then
	echo "No Godot clone found. Run ./setup.sh <Godot branch or tag> <dev> first."
	exit 1
fi

target="target=${1%/}"
mono=${2%/}
executable=${3%/}
dev="false"
if [ -f "../godot/custom.py" ]; then
	dev="true"
fi

cpus=2
if [ "$OSTYPE" = "msys" ]; then
	cpus=$NUMBER_OF_PROCESSORS
elif [[ "$OSTYPE" = "darwin"* ]]; then
	cpus=$(sysctl -n hw.logicalcpu)
else
	cpus=$(grep -c ^processor /proc/cpuinfo)
fi

echo "CPUS: $cpus"

pushd ../godot
if [ `uname` == 'Darwin' ] && [ $dev = "false" ]; then	
	scons $target arch=x86_64 compiledb=yes custom_modules="../spine_godot" --jobs=$cpus
	scons $target arch=arm64 compiledb=yes custom_modules="../spine_godot" --jobs=$cpus

	pushd bin
	cp -r ../misc/dist/osx_tools.app .
	mv osx_tools.app Godot.app
	mkdir -p Godot.app/Contents/MacOS
	if [ "$target" = "debug" ]; then
		lipo -create godot.osx.tools.x86_64 godot.osx.tools.arm64 -output godot.osx.tools.universal
		strip -S -x godot.osx.tools.universal
		cp godot.osx.tools.universal Godot.app/Contents/MacOS/Godot
	else
		lipo -create godot.osx.opt.tools.x86_64 godot.osx.opt.tools.arm64 -output godot.osx.opt.tools.universal
		strip -S -x godot.osx.opt.tools.universal
		cp godot.osx.opt.tools.universal Godot.app/Contents/MacOS/Godot
	fi	
	chmod +x Godot.app/Contents/MacOS/Godot	
	popd
else
	if [ "$OSTYPE" = "msys" ]; then
		target="$target vsproj=yes livepp=$LIVEPP"
	fi
	
	if [ $mono = "true" ]; then
		echo "BUILD: mono build is enabled"
	
		# build temporary binary
		scons $target tools=yes custom_modules="../spine_godot" module_mono_enabled=yes mono_glue=no
		
		# generate glue sources
		cmd='bin/$executable --generate-mono-glue modules/mono/glue'
		eval "$cmd";
		
		# build binaries normally
		scons $target compiledb=yes use_asan=yes custom_modules="../spine_godot" module_mono_enabled=yes tools=yes --jobs=$cpus	
	else
		scons $target compiledb=yes use_asan=yes custom_modules="../spine_godot" --jobs=$cpus	
		if [ -f "bin/godot.x11.opt.tools.64" ]; then
			strip bin/godot.x11.opt.tools.64
			chmod a+x bin/godot.x11.opt.tools.64
		fi
	fi
fi
popd

popd > /dev/null
