# mathbin
This repository contains some shell scripts
for e.g.

* Fetching bibliography entries from mathscinet (`msc`), zentralblatt (`zentralblatt`), arXiv (`arxiv2bibtex`)
* Fetching pdf from DOI (`doi2pdf`, `bibtex2pdf`, also `arxiv2pdf`)
* Preparing LaTeX files for submission (`used_...`)

## Usage with Mac OS

Most of the scripts and tools provided here work directly with Mac OS. This is tested with Mac OS 11 Big Sur, but should work with Mac OS 10.15 Catalina as well, maybe even earlier; just note that with Catalina zsh got the default shell. The issue is, that two tools are missing/wrong

* `grep` is different from the GNU grep used here (especially the option `-P` is not available on Mac OS)
* `curl` is missing

You can install these using your favourite package manager, here's how to solve both points with [homebrew](https://brew.sh).

### switch from `grep` to GNU `grep`

Install [GNU grep](https://formulae.brew.sh/formula/grep#default) using

```shell
brew install grep
```

which makes the GNU grep available as `ggrep`. To then exchange both, i.e. make GNU grep the default, add the line `PATH="$(brew --prefix)/opt/grep/libexec/gnubin:$PATH"` to your `.zshrc` for example using

```shell
echo '\nexport PATH="$(brew --prefix)/opt/grep/libexec/gnubin:$PATH"' >> ~/.zshrc
```

### Install `curl`

[`curl`](https://formulae.brew.sh/formula/curl#default) is available as a brew formula, so it can be installed using

```shell
brew install curl
```

# use docker to run the scripts

first build the container by running
```
docker build -t mathbin .
```
from this folder. That creates an image with the name mathbin. Afterwards you can use that image like
```
docker run --rm -v $(pwd):/data mathbin doi2pdf 10.1007/978-1-4612-2972-8
```
The option *--rm* removes the container after downloading the pdf (not the image!), whereas *-v* binds your working directory on the host to the folder /data on the container.
