.PHONY: coq extract clean

CODE := $(shell git ls-files "*.v")

all: _CoqProject coq extract

coq: Makefile.coq
	$(MAKE) -f Makefile.coq

# TODO: fold this into the _CoqProject and Makefile.coq, find some other way to
# add the post-processing on the generated Haskell
ExtractReplicatedDisk.vo: coq replicate-nbd/fiximports.py
	@echo "COQC ExtractReplicatedDisk.v"
	@coqc -R src Pocs -noglob ExtractReplicatedDisk.v
	./scripts/add-preprocess.sh replicate-nbd/src/Bytes.hs
	./scripts/add-preprocess.sh replicate-nbd/src/Interface.hs
	./scripts/add-preprocess.sh replicate-nbd/src/ReplicatedDisk.hs
	./scripts/add-preprocess.sh replicate-nbd/src/DiskSize.hs
	./scripts/add-preprocess.sh replicate-nbd/src/ReadWrite.hs
	./scripts/add-preprocess.sh replicate-nbd/src/Recovery.hs
	./scripts/add-preprocess.sh replicate-nbd/src/TwoDiskImpl.hs

extract: ExtractReplicatedDisk.vo

Makefile.coq: Makefile $(CODE) _CoqProject
	coq_makefile -f _CoqProject > Makefile.coq

clean: Makefile.coq
	$(MAKE) -f Makefile.coq clean
	rm -f Makefile.coq _CoqProject
	rm -f replicate-nbd/src/*.hs
	rm -f *.vo *.glob

_CoqProject: $(CODE) _CoqProject.in
	{ cat _CoqProject.in; git ls-files "src/*.v"; } > $@
