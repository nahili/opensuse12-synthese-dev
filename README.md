<h1>Synthese Dev environment on OpenSuse 12.3</h1>

This docker reposity is able to compile and run Synthese from source.

<h2>Content</h2>
* A build script that uses CMake and make
* All the basic compilation tools (gcc, make, etc)
* An updated version of CMake
* An updated version of subversion
* MariaDB binaries and headers
* Boost 1.42 (required for Synthese)

<h2>Usage</h2>

The code itself is not and should not be within the Docker instance.

The build script is exptecting the source code to be placed on /src/synthese.

To build Synthese, on can simply invoke the Docker images on its source code :
<pre>
docker run -i -t -v /path/to/src:/src/synthese nahili/opensuse12-synthese-dev build
</pre>

For a full usage of the Docker image or the build system, see :
<pre>
docker run -i -t nahili/opensuse12-synthese-dev help
</pre>
and
<pre>
docker run -i -t nahili/opensuse12-synthese-dev run /opt/bin/build.sh --help
</pre>
