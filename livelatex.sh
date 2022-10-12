#!/bin/bash


# # When called, the process ends.
# Args:
# 	$1: The exit message (print to stderr)
# 	$2: The exit code (default is 1)
# if env var _PRINT_HELP is set to 'yes', the usage is print to stderr (prior to $1)
# Example:
# 	test -f "$_arg_infile" || _PRINT_HELP=yes die "Can't continue, have to supply file as an argument, got '$_arg_infile'" 4
die()
{
	local _ret="${2:-1}"
	test "${_PRINT_HELP:-no}" = yes && print_help >&2
	echo "$1" >&2
	exit "${_ret}"
}


# Function that evaluates whether a value passed to it begins by a character
# that is a short option of an argument the script knows about.
# This is required in order to support getopts-like short options grouping.
begins_with_short_option()
{
	local first_option all_short_options='wh'
	first_option="${1:0:1}"
	test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}

# THE DEFAULTS INITIALIZATION - POSITIONALS
# The positional args array has to be reset before the parsing, because it may already be defined
# - for example if this script is sourced by an argbash-powered script.
_positionals=()
# THE DEFAULTS INITIALIZATION - OPTIONALS
_arg_wait="1"



# Function that prints general usage of the script.
# This is useful if users asks for it, or if there is an argument parsing error (unexpected / spurious arguments)
# and it makes sense to remind the user how the script is supposed to be called.
print_help()
{
	printf '%s\n' "Live re-compilation of Latex files"
	printf 'Usage: %s [-w|--wait <arg>] [-h|--help] <texfile>\n' "$0"
	printf '\t%s\n' "<texfile>: Path to the .tex file to compile"
	printf '\t%s\n' "-w, --wait: Time to wait before attempting refresh (in seconds) (default: '1')"
	printf '\t%s\n' "-h, --help: Prints help"
}

# The parsing of the command-line
parse_commandline()
{
	_positionals_count=0
	while test $# -gt 0
	do
		_key="$1"
		case "$_key" in
			# We support whitespace as a delimiter between option argument and its value.
			# Therefore, we expect the --wait or -w value.
			# so we watch for --wait and -w.
			# Since we know that we got the long or short option,
			# we just reach out for the next argument to get the value.
			-w|--wait)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_wait="$2"
				shift
				;;
			# We support the = as a delimiter between option argument and its value.
			# Therefore, we expect --wait=value, so we watch for --wait=*
			# For whatever we get, we strip '--wait=' using the ${var##--wait=} notation
			# to get the argument value
			--wait=*)
				_arg_wait="${_key##--wait=}"
				;;
			# We support getopts-style short arguments grouping,
			# so as -w accepts value, we allow it to be appended to it, so we watch for -w*
			# and we strip the leading -w from the argument string using the ${var##-w} notation.
			-w*)
				_arg_wait="${_key##-w}"
				;;
			# The help argurment doesn't accept a value,
			# we expect the --help or -h, so we watch for them.
			-h|--help)
				print_help
				exit 0
				;;
			# We support getopts-style short arguments clustering,
			# so as -h doesn't accept value, other short options may be appended to it, so we watch for -h*.
			# After stripping the leading -h from the argument, we have to make sure
			# that the first character that follows coresponds to a short option.
			-h*)
				print_help
				exit 0
				;;
			*)
				_last_positional="$1"
				_positionals+=("$_last_positional")
				_positionals_count=$((_positionals_count + 1))
				;;
		esac
		shift
	done
}


# Check that we receive expected amount positional arguments.
# Return 0 if everything is OK, 1 if we have too little arguments
# and 2 if we have too much arguments
handle_passed_args_count()
{
	local _required_args_string="'texfile'"
	test "${_positionals_count}" -ge 1 || _PRINT_HELP=yes die "FATAL ERROR: Not enough positional arguments - we require exactly 1 (namely: $_required_args_string), but got only ${_positionals_count}." 1
	test "${_positionals_count}" -le 1 || _PRINT_HELP=yes die "FATAL ERROR: There were spurious positional arguments --- we expect exactly 1 (namely: $_required_args_string), but got ${_positionals_count} (the last one was: '${_last_positional}')." 1
}


# Take arguments that we have received, and save them in variables of given names.
# The 'eval' command is needed as the name of target variable is saved into another variable.
assign_positional_args()
{
	local _positional_name _shift_for=$1
	# We have an array of variables to which we want to save positional args values.
	# This array is able to hold array elements as targets.
	# As variables don't contain spaces, they may be held in space-separated string.
	_positional_names="_arg_texfile "

	shift "$_shift_for"
	for _positional_name in ${_positional_names}
	do
		test $# -gt 0 || break
		eval "$_positional_name=\${1}" || die "Error during argument parsing, possibly an Argbash bug." 1
		shift
	done
}

# Compile the latex document
latex_compile() {
	tex_path=$1

	xelatex -halt-on-error  ${tex_path}
	bibtex "$(echo ${tex_path} | rev | cut -d'.' -f 2- | rev)"
	xelatex -halt-on-error ${tex_path}
	xelatex -halt-on-error ${tex_path}
}



# Now call all the functions defined above that are needed to get the job done
parse_commandline "$@"
handle_passed_args_count
assign_positional_args 1 "${_positionals[@]}"


TEX_PATH=${_arg_texfile}
SLEEP_SECONDS=${_arg_wait}

dir_path="$(dirname ${TEX_PATH})"
cd ${dir_path}

TEX_PATH=$(basename ${TEX_PATH})
pdf_path="$(echo ${TEX_PATH} | rev | cut -d'.' -f2- | rev).pdf"
previous_tex_edit_time=-1
while true
do
	if [[ ! -f ${pdf_path} ]]
	then
		latex_compile ${TEX_PATH}
	else
		# Get the time of last edit of PDF
		pdf_last_edit_time=$(stat -c %Y ${pdf_path})

		# Get the time of last edit of TEX
		tex_last_edit_time=$(stat -c %Y ${TEX_PATH})

		# If TEX last update is after the one of PDF, it means we have to update PDF
		if (( ${tex_last_edit_time} > ${pdf_last_edit_time} )) && \
			(( ${tex_last_edit_time} > ${previous_tex_edit_time} ))
		then
			latex_compile ${TEX_PATH}
		fi
		previous_tex_edit_time=${tex_last_edit_time}
	fi
	sleep ${SLEEP_SECONDS}
done