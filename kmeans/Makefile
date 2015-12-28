## ------------------------------------------------------- ##
## MAC CHECK                                               ##
## kextstat | grep -i cuda
## if empty: 
## sudo kextload /System/Library/Extensions/CUDA.kext 
## ------------------------------------------------------- ##

EXECUTABLE      := kmeans

# Cuda source files (compiled with cudacc)
CUFILES_sm_11   := kmeans.cu
CUDEPS		:= 
# C/C++ source files (compiled with gcc / c++)
CCFILES         := \

# Additional compiler flags and LIBs to include
USEGLLIB         := 1
USEGLUT          := 1
USERENDERCHECKGL := 1

# all the standard cuda rules
ROOTBINDIR = ./bin
include ../../common/common.mk


LIB += -lcuda
