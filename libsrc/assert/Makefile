
include ../Make.config

TARGET ?= test
GENOBJECTS = assert.o
ASMFILES = $(wildcard *.asm)

OBJECTS = $(GENOBJECTS) $(ASMFILES:.asm=.o)

all: dirs $(addprefix obj/z80/, $(OBJECTS)) $(addprefix obj/r2k/,$(OBJECTS)) $(addprefix obj/ixiy/,$(OBJECTS))  $(addprefix obj/8080/,$(OBJECTS)) $(addprefix obj/gbz80/,$(OBJECTS))


dirs:
	@mkdir -p obj/z80 obj/r2k obj/ixiy obj/$(TARGET) obj/8080 obj/gbz80

clean:
	$(RM) -fr obj
	$(RM) zcc_opt.def
