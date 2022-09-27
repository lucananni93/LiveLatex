# LiveLatex

Very simple bash script that re-compiles a `.tex` project automatically each time the file is modified.
The script takes as input the path of the Latex file, it checks if the file gets updated and automatically triggers the compilation of the PDF document (thorugh `pdflatex`).

## Example
```
livelatex.sh path/to/latex.tex
```

## Installation
Clone this repository
```
git clone https://github.com/lucananni93/LiveLatex.git
```

Make the script an executable
```
cd LiveLatex
chmod +x livelatex.sh
```

Add the script to the `PATH` variable, to call it everywhere in your system
```
export PATH="$(pwd):${PATH}"
```

## Usage

```
Live re-compilation of Latex files
Usage: livelatex.sh [-w|--wait <arg>] [-h|--help] <texfile>
        <texfile>: Path to the .tex file to compile
        -w, --wait: Time to wait before attempting refresh (in seconds) (default: '1')
        -h, --help: Prints help
```