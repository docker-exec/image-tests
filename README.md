# Tests for docker-exec images

These tests checkout each of the docker-exec image sources, build the images tagged with "testing" and then executes several simple programs in the language provided by the image, and verifies the output is as expected.

Because the images are built from scratch, the tests take a long time to run. After the tests for an image have been executed, the image is removed and the source folder deleted.

The programs are:

### Hello World

This tests that the Docker image is capable of output.

Its output is:

```
hello world
```

### Echo Chamber

This tests that the Docker image is capable of input via Docker entrypoint. Several arguments are passed to the image and the program is expected to receive and print these out on a new line preserving spaces.

Its output is:

```
a
a b
a b c
x y
z
```

### Shebang Removal

This tests that a source file containing a shebang line that invokes ```dexec``` will have this stripped out. It is simply 'hello world' but the source file also contains the shebang line that instructs the shell to call ```dexec```.

### Unicode

This tests that the image is capable of parsing source files containing unicode and passing this to stdout.

Its output is:

```
hello unicode 👾
```

## Requirements

* Docker
* curl
* git
* bash + gnu core utils
* internet access

## Running the tests

### Run all tests

```sh
git clone https://github.com/docker-exec/image-tests.git
cd image-tests
./runtests.sh
```

### Run specific tests

```sh
git clone https://github.com/docker-exec/image-tests.git
cd image-tests
./runtests.sh scala racket rust
```
