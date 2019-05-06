#Name of the program or library.
NAME := 

#Type of output. If making a static or shared library, set that here.
#Options: STATIC_LIB, SHARED_LIB (doesn't actually check EXECUTABLE)
TYPE := EXECUTABLE

#What file extension you're compiling.
COMPILE_EXT := .cpp

#The directory we're working from.
#Use this if your main project is in a directory other than the makefile.
TOPDIR := .
#Directory to put build files.
BUILDDIR := $(TOPDIR)/build
#Build output directory (the program or library).
OUTDIR := $(TOPDIR)

#Where your project files are located, relative to TOPDIR.
#Can include multiple locations separated by a space.
#A useful rule to use may be:
# $(sort $(dir $(wildcard $(TOPDIR)/*/)))
#This will get a list of sub directories in your top directory, though not recursively.
#The dir function gets the path part of each file, and use sort as it removes duplicates.
#If you want recursion, probably best to use a shell command:
# $(sort $(dir $(shell find . -name "$(TOPDIR)/*$(COMPILE_EXT)")))
#Watch out for grabbing build folders when grabbing sub directories.
SRCDIRS := $(TOPDIR)

CC = g++
#Set language level or extra warnings here.
COMP_FLAGS = -std=c++17 -Wall -Wextra -pedantic
#Set libraries for linking here.
#Useful to use either package config for an instaled dependency or a direct path to a library (e.g. a submodule):
#`pkg-config --libs sdl2`
#-Lpath/to/my/lib/ -lmylib
LINK_FLAGS = 
#Set include directories for compilation here, similar to LINK_FLAGS.
#`pkg-config --cflags sdl2`
#-Ipath/to/my/include/dir
INCL_DIRS = 

#Debug mode flags.
DEBUG_FLAGS = -DDEBUG -g
#Release mode flags.
RELEASE_FLAGS = -DNDEBUG -O2

#This makes output files have _d or _r suffixes depending on debug/release build.
APPEND_TYPE = YES

#------------------------------------------------------------------
#Submodules
#------------------------------------------------------------------
#If there are submodules, specify the paths here.
#The given directories should include makefiles to call.
#Note that if this is a static library, we don't do anything fancy with the submodules other than build them.
SUBMODS := 

#Set commands to call on submodles. By default just pass down the same commands called for this file.
SUBMODCMD := $(MAKECMDGOALS)
#If you have a variable you want to pass down to all submodules, you can do so with export.
#EG: VAR := 1
#export VAR

#------------------------------------------------------------------
#Build
#------------------------------------------------------------------
#These next steps are automatic and hopefully shouldn't need modification for simple projects.

#Flags for handling dependencies. MMD generates dependencies on non-system header files.
#MP makes a phoney target for each dependency, to avoid errors if you delete a header file and recompile
DEPS_FLAGS = -MMD -MP

#Get the sources to compile from source directories.
SRCS = $(foreach dir, $(SRCDIRS), $(wildcard $(dir)*$(COMPILE_EXT)))
#Make names for objects. Object files let us reuse a built file if it hasn't changed between compilations.
OBJS = $(patsubst $(TOPDIR)/%$(COMPILE_EXT),$(BUILDDIR)/%.o,$(SRCS))
#Make names for dependencies. Dependencies allow us to rebuild a file when included headers change.
DEPS = $(patsubst $(TOPDIR)/%$(COMPILE_EXT),$(BUILDDIR)/%.d,$(SRCS))

#Directories we'll have to create.
MKDIRS = $(BUILDDIR) $(patsubst $(TOPDIR)/%,$(BUILDDIR)/%,$(SRCDIRS)) $(OUTDIR)

#Final file to output.
COMPILED := $(OUTDIR)/$(NAME)
ifeq ($(APPEND_TYPE), YES)
 debug:   COMPILED := $(COMPILED)_d
 release: COMPILED := $(COMPILED)_r
endif

#Determine what type of build we're making.
ifeq ($(TYPE), STATIC_LIB)
 OUTPUT_CMD := static_lib
else ifeq($(TYPE), SHARED_LIB)
 OUTPUT_CMD := shared_lib
 #Use fPIC for "Position Independent Code" while compiling.
 COMP_FLAGS += -fPIC
else
 OUTPUT_CMD := program
endif

.PHONY: all
#The main build step. Make directories, build any submodules, then build the program/library.
#This is run by default "make" command, without debug or release flags.
#If you want debug or release to run by default, move one of them above this.
all:            ## Build the examples.
all: $(MKDIRS) $(SUBMODS) $(OUTPUT_CMD)

#Make any needed directories.
$(MKDIRS):
	@mkdir -p $@

#Build sub modules, passing down the build command(s).
.PHONY: $(SUBMODS)
$(SUBMODS):
	$(MAKE) -C $@ $(SUBMODCMD)

#If build order of submodules is important, declare dependencies here. EG:
#subdir2: subdir1 #Build subdir2 after subdir1 has completed building.

#Archive step for static library.
.PHONY: static_lib
static_lib: $(OBJS)
	ar -rcs $^ -o $(COMPILED)

#Link step for shared library.
.PHONY: shared_lib
shared_lib: $(OBJS)
	$(CC) $^ -shared $(LINK_FLAGS) -o $(COMPILED).so

#Link step for program. Make sure any submodules are built first.
.PHONY: program
program: $(OBJS) | $(SUBMODS)
	$(CC) $^ $(LINK_FLAGS) -o $(COMPILED)

#Build step.
#Build each object with the prerequisite that either there isn't a matching object in the build dir,
#or its last modified date is older than the source file in the source dir.
$(OBJS): $(BUILDDIR)/%.o : $(TOPDIR)/%$(COMPILE_EXT)
	$(CC) $(INCL_DIRS) $(COMP_FLAGS) $(DEPS_FLAGS) -c $< -o $@

.PHONY: debug
debug:          ## Make debug build.
debug: COMP_FLAGS += $(DEBUG_FLAGS)
debug: BUILDDIR := $(BUILDDIR)/debug
debug: all

.PHONY: release
release:        ## Make release build.
release: COMP_FLAGS += $(RELEASE_FLAGS)
release: all

.PHONY: clean
clean:          ## Clean this project and all submodules.
clean: clean_local clean_submods

.PHONY: clean_local
clean_local:    ## Clean only this project, ignoring submodules.
	rm -rf $(BUILDDIR) $(COMPILED) $(COMPILED)_d $(COMPILED)_r

.PHONY: clean_submods
clean_submods:  ## Clean only submodules.
clean_submods: SUBMODCMD := clean
clean_submods: $(SUBMODS)

.PHONY: help
#This rule grabs all the ## comments for each rule and writes them to the console.
help:           ## Display this help.
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

# Include all dependency files. Use "-" flavour because they might not exist yet (e.g. new file being compiled).
-include $(DEPS)