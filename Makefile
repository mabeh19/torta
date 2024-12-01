LINUX_C_SOURCES=serial/serial_linux_backend.c
WINDOWS_C_SOURCES=serial/serial_windows_backend.c
C_SOURCES=
ODIN_FLAGS=-debug
CC=gcc
COMPILER_FLAGS=-c
MAKE_LIB=ar 
MAKE_LIB_FLAGS=-rc 
RM=rm
OBJECT_EXT=o
LIB_EXT=a



ifeq ($(OS),Windows_NT)
	C_SOURCES += $(WINDOWS_C_SOURCES)
	CC=cl
	MAKE_LIB=lib
	MAKE_LIB_FLAGS=/out:
	RM=del
	OBJECT_EXT=obj
	LIB_EXT=lib
else
	UNAME_S=$(shell uname -s)
	C_SOURCES += $(LINUX_C_SOURCES)
endif


C_OBJECTS=$(C_SOURCES:%.c=%.$(OBJECT_EXT))
C_LIBS=$(C_OBJECTS:%.o=%.$(LIB_EXT))

%.$(OBJECT_EXT): %.c
	$(CC) $(COMPILER_FLAGS) $< -o $@

%.$(LIB_EXT): %.$(OBJECT_EXT)
	$(MAKE_LIB) $(MAKE_LIB_FLAGS)$@ $<
	$(RM) $<

all: $(C_LIBS)
	odin build . $(ODIN_FLAGS)

run: $(C_LIBS)
	odin run . $(ODIN_FLAGS)

debug: all
	gdb torta

dll:
	odin build . -build-mode:dll
	mv app.so ..


phony: all
