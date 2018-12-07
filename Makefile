-include config.mk
-include installdeps.mk

CC       = gcc
CXX      = g++
CFLAGS   += -g -rdynamic -Wall -O2 -std=c++11 
LDFLAGS += $(LIBS) -lpthread -lz
BUILD_DIR = build

# SRC = src/main.c src/meth_main.c src/f5c.c src/events.c src/nanopolish_read_db.c \
#       src/nanopolish_index.c src/model.c src/align.c src/meth.c src/hmm.c
BINARY = f5c
OBJ = $(BUILD_DIR)/main.o \
      $(BUILD_DIR)/meth_main.o \
      $(BUILD_DIR)/f5c.o \
      $(BUILD_DIR)/events.o \
      $(BUILD_DIR)/nanopolish_read_db.o \
      $(BUILD_DIR)/nanopolish_index.o \
      $(BUILD_DIR)/model.o \
      $(BUILD_DIR)/align.o \
      $(BUILD_DIR)/meth.o \
      $(BUILD_DIR)/hmm.o
DEPS = src/config.h \
       src/error.h \
       src/f5c.h \
       src/f5cmisc.h \
       src/fast5lite.h \
       src/logsum.h \
       src/matrix.h \
       src/model.h \
       src/nanopolish_read_db.h \
       src/ksort.h

PREFIX = /usr/local
VERSION = 1.0

ifdef cuda
    DEPS_CUDA = src/f5c.h src/fast5lite.h src/error.h src/f5cmisc.cuh
    #SRC_CUDA = f5c.cu align.cu 
    OBJ_CUDA = $(BUILD_DIR)/f5c_cuda.o $(BUILD_DIR)/align_cuda.o
    CC_CUDA = nvcc
    CFLAGS_CUDA += -g  -O2 -std=c++11 -lineinfo $(CUDA_ARCH)
	CUDALIB += -L/usr/local/cuda/lib64/ -lcudart -lcudadevrt
    #CUDALIB_STATIC += -L/usr/local/cuda/lib64/ -lcudart_static -lcudadevrt -lrt
    OBJ += $(BUILD_DIR)/gpucode.o $(OBJ_CUDA)
    CPPFLAGS += -DHAVE_CUDA=1
endif

.PHONY: clean distclean format test

$(BINARY): src/config.h $(HTS_LIB) $(HDF5_LIB) $(OBJ)
	$(CXX) $(CFLAGS) $(OBJ) $(LDFLAGS) $(CUDALIB) -o $@

$(BUILD_DIR)/main.o: src/main.c src/f5cmisc.h src/error.h
	$(CXX) $(CFLAGS) $(CPPFLAGS) $< -c -o $@

$(BUILD_DIR)/meth_main.o: src/meth_main.c src/f5c.h src/f5cmisc.h src/logsum.h
	$(CXX) $(CFLAGS) $(CPPFLAGS) $< -c -o $@

$(BUILD_DIR)/f5c.o: src/f5c.c src/f5c.h src/f5cmisc.h
	$(CXX) $(CFLAGS) $(CPPFLAGS) $< -c -o $@

$(BUILD_DIR)/events.o: src/events.c src/f5c.h src/f5cmisc.h src/fast5lite.h src/nanopolish_read_db.h src/ksort.h
	$(CXX) $(CFLAGS) $(CPPFLAGS) $< -c -o $@

$(BUILD_DIR)/nanopolish_read_db.o: src/nanopolish_read_db.c src/nanopolish_read_db.h
	$(CXX) $(CFLAGS) $(CPPFLAGS) $< -c -o $@

$(BUILD_DIR)/nanopolish_index.o: src/nanopolish_index.c src/nanopolish_read_db.h src/fast5lite.h
	$(CXX) $(CFLAGS) $(CPPFLAGS) $< -c -o $@

$(BUILD_DIR)/model.o: src/model.c src/model.h src/f5c.h src/f5cmisc.h
	$(CXX) $(CFLAGS) $(CPPFLAGS) $< -c -o $@

$(BUILD_DIR)/align.o: src/align.c src/f5c.h
	$(CXX) $(CFLAGS) $(CPPFLAGS) $< -c -o $@

$(BUILD_DIR)/meth.o: src/meth.c src/f5c.h src/f5cmisc.h
	$(CXX) $(CFLAGS)$(CPPFLAGS) $< -c -o $@

$(BUILD_DIR)/hmm.o: src/hmm.c src/f5c.h src/f5cmisc.h src/matrix.h src/logsum.h
	$(CXX) $(CFLAGS) $(CPPFLAGS) $< -c -o $@

# cuda stuff
$(BUILD_DIR)/gpucode.o: $(OBJ_CUDA)
	$(CC_CUDA) $(CFLAGS_CUDA) -dlink $^ -o $@ 

$(BUILD_DIR)/f5c_cuda.o: src/f5c.cu src/error.h src/f5c.h src/f5cmisc.cuh src/f5cmisc.h
	$(CC_CUDA) -x cu $(CFLAGS_CUDA) $(CPPFLAGS) -rdc=true -c $< -o $@

$(BUILD_DIR)/align_cuda.o: src/align.cu src/f5c.h src/f5cmisc.cuh
	$(CC_CUDA) -x cu $(CFLAGS_CUDA) $(CPPFLAGS) -rdc=true -c $< -o $@

src/config.h:
	echo "/* Default config.h generated by Makefile */" >> $@
	echo "#define HAVE_HDF5_H 1" >> $@

$(BUILD_DIR)/lib/libhts.a:
	@if command -v curl; then \
		curl -o $(BUILD_DIR)/htslib.tar.bz2 -L https://github.com/samtools/htslib/releases/download/$(HTS_VERSION)/htslib-$(HTS_VERSION).tar.bz2; \
	else \
		wget -O $(BUILD_DIR)/htslib.tar.bz2 https://github.com/samtools/htslib/releases/download/$(HTS_VERSION)/htslib-$(HTS_VERSION).tar.bz2; \
	fi
	tar -xf $(BUILD_DIR)/htslib.tar.bz2 -C $(BUILD_DIR)
	mv $(BUILD_DIR)/htslib-$(HTS_VERSION) $(BUILD_DIR)/htslib
	rm -f $(BUILD_DIR)/htslib.tar.bz2
	cd $(BUILD_DIR)/htslib && \
	./configure --prefix=`pwd`/../ --enable-bz2=no --enable-lzma=no --with-libdeflate=no --enable-libcurl=no  --enable-gcs=no --enable-s3=no && \
	make -j8 && \
	make install

$(BUILD_DIR)/lib/libhdf5.a:
	@if command -v curl; then \
		curl -o $(BUILD_DIR)/hdf5.tar.bz2 https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-`echo $(HDF5_VERSION) | awk -F. '{print $$1"."$$2}'`/hdf5-$(HDF5_VERSION)/src/hdf5-$(HDF5_VERSION).tar.bz2; \
	else \
		wget -O $(BUILD_DIR)/hdf5.tar.bz2 https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-`echo $(HDF5_VERSION) | awk -F. '{print $$1"."$$2}'`/hdf5-$(HDF5_VERSION)/src/hdf5-$(HDF5_VERSION).tar.bz2; \
	fi
	tar -xf $(BUILD_DIR)/hdf5.tar.bz2 -C $(BUILD_DIR)
	mv $(BUILD_DIR)/hdf5-$(HDF5_VERSION) $(BUILD_DIR)/hdf5
	rm -f $(BUILD_DIR)/hdf5.tar.bz2
	cd $(BUILD_DIR)/hdf5 && \
	./configure --prefix=`pwd`/../ && \
	make -j8 && \
	make install

clean: 
	rm -rf $(BINARY) $(BUILD_DIR)/*.o

# Delete all gitignored files (but not directories)
distclean: clean
	git clean -f -X 
	rm -rf $(BUILD_DIR)/*

dist: distclean
	mkdir -p f5c-$(VERSION)
	autoreconf
	cp -r README.md LICENSE Dockerfile Makefile configure.ac config.mk.in \
		installdeps.mk src docs build scripts/install-hdf5.sh \
		scripts/install-hts.sh .dockerignore configure f5c-$(VERSION)
	tar -cf f5c-$(VERSION).tar f5c-$(VERSION)
	gzip f5c-$(VERSION).tar
	rm -rf f5c-$(VERSION)

install: $(BINARY)
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	mkdir -p $(DESTDIR)$(PREFIX)/share/man/man1
	cp -f $(BINARY) $(DESTDIR)$(PREFIX)/bin
	gzip < docs/f5c.1 > $(DESTDIR)$(PREFIX)/share/man/man1/f5c.1.gz

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/$(BINARY) \
		$(DESTDIR)$(PREFIX)/share/man/man1/f5c.1.gz

test: $(BINARY)
	./scripts/test.sh
