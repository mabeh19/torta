LINUX_C_SOURCES=serial/serial_linux_backend.c
WINDOWS_C_SOURCES=serial\\serial_windows_backend.c
C_SOURCES=
ODIN_DEBUG_FLAGS=-debug -sanitize:address
ODIN_RELEASE_FLAGS=-o:speed
ODIN_LIBS=
CC=gcc
COMPILER_FLAGS=-O3 -c
COMPILER_END_FLAGS=
COMPILER_OUTPUT_SPECIFIER=-o 
MAKE_LIB=ar 
MAKE_LIB_FLAGS=rcs 
RM=rm
OBJECT_EXT=o
LIB_EXT=a


ifeq ($(OS),Windows_NT)
	C_SOURCES += $(WINDOWS_C_SOURCES)
	CC=cl
	COMPILER_FLAGS=-TC -c
	COMPILER_OUTPUT_SPECIFIER=/Fo:
	COMPILER_END_FLAGS=/link setupapi.lib 
	MAKE_LIB=lib
	MAKE_LIB_FLAGS=-nologo -out:
	RM=del
	OBJECT_EXT=obj
	LIB_EXT=lib
else
	UNAME_S=$(shell uname -s)
	C_SOURCES += $(LINUX_C_SOURCES)
	ODIN_LIBS += -ludev
	ODIN_DEBUG_FLAGS += -extra-linker-flags:"$(ODIN_LIBS)"
	ODIN_RELEASE_FLAGS += -extra-linker-flags:"$(ODIN_LIBS)"
endif


C_OBJECTS=$(C_SOURCES:%.c=%.$(OBJECT_EXT))
C_LIBS=$(C_SOURCES:%.c=%.$(LIB_EXT))

%.$(OBJECT_EXT): %.c
	$(CC) $(COMPILER_FLAGS) $< $(COMPILER_OUTPUT_SPECIFIER)$@ $(COMPILER_END_FLAGS)

%.$(LIB_EXT): %.$(OBJECT_EXT)
	$(MAKE_LIB) $(MAKE_LIB_FLAGS)$@ $< 

local: $(C_LIBs)
	odin run . $(ODIN_DEBUG_FLAGS) -define:LOCAL_TEST=true


all: $(C_LIBS)
	odin build . $(ODIN_DEBUG_FLAGS)

run: $(C_LIBS)
	odin run . $(ODIN_DEBUG_FLAGS)

release: $(C_LIBS)
	odin build . $(ODIN_RELEASE_FLAGS)

debug: all
	gdb torta

dll:
	odin build . -build-mode:dll
	mv app.so ..

test: all
	odin test .

phony: all
