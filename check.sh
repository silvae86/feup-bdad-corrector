#!/usr/bin/env bash

# BDAD automatic database creator and runner script
# Author: João Rocha da Silva (@silvae86 at Github)
# Homepage: https://silvae86.github.io/
# Repository: https://github.com/silvae86/feup-bdad-corrector

ORIGINAL_DIR=$(pwd)
PREAMBLE=".output stdout\n.mode columns\n.headers on\n"
CHECK_CONSISTENCY_COMMAND="PRAGMA foreign_keys=ON; pragma integrity_check; pragma foreign_key_check;"

# defaults
GENERATE_DIAGRAM="true"
BATCH_CORRECTION="false"
SHOW_SCRIPTS_AT_END="false"
TEST_TRIGGERS_AND_QUERIES="false"

programname=$0

function usage {
    echo "usage: $programname [-t] [-b] [-s] [-d] [-h]"
    echo "  -t      test triggers and queries (3rd delivery only)"
    echo "  -b      enable batch correction (scan subfolders of current one), useful for professors"
    echo "  -q      force sequential processing instead of parallel (useful for batch mode only, use on slower machines)."
    echo "  -s      (show/copy-paste scripts of students to the output.txt file after running checks."
    echo "  -d      do not generate diagram using schemacrawler"
    echo "  -h      print this help"
}

while getopts 'tbsdhq' arg; do
    case ${arg} in
				# test triggers and queries (3rd delivery)
        t) TEST_TRIGGERS_AND_QUERIES="true"
				;;
				# enable batch correction (scan subfolders of current one)
        b) BATCH_CORRECTION="true"
				;;
				# (show/copy-paste scripts of students to the output.txt file after running checks
				s) SHOW_SCRIPTS_AT_END="true"
				;;
				# do not generate diagram using schemacrawler
				d) GENERATE_DIAGRAM="false"
				;;
        # force sequential generation instead of parallelizing on batch mode
				q) FORCE_SEQUENTIAL="true"
				;;
        h) usage && exit 0
				;;
        # illegal option
        *) usage && exit 1
    esac
done

SECONDS=0

function print_message()
{
  local message="$1"
  local ELAPSED="$(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec"
  printf "[ $ELAPSED ] $message\n"
}

if [[ "$TEST_TRIGGERS_AND_QUERIES" == "true" ]]; then
	print_message "Testing DB Creation, Populating, Queries and Triggers (Third delivery)..."
else
	print_message "Testing DB Creation and Populating only (Second delivery)..."
fi

if [[ "$BATCH_CORRECTION" == "true" ]]; then
	print_message "Batch Correction Mode engaged! The program will scan all subdirectories and perform correction on all of them. Check output.txt inside each for the results."
fi

if [[ "$GENERATE_DIAGRAM" == "false" ]]; then
	print_message "Diagram will not be created."
fi

if [[ "$SHOW_SCRIPTS_AT_END" == "true" ]]; then
	print_message "Appending a copy of the scripts to the end of the output.txt file."
fi

if [[ "$FORCE_SEQUENTIAL" == "true" ]]; then
	print_message "Disabling parallel processing (slower machine setting active)."
fi

function exists()
{
	local file=$1
	[ -f "$file" ] || ( printf "File $file does not exist!\n" && return 1 )
	return 0
}

function diagram
{
  local database_path="$1/database.db"
  local diagram_path="$1/diagram.png"
  local diagram_title="$2"

	/opt/schemacrawler/schemacrawler.sh --server="sqlite" --database="$database_path" --user="" --password="" --loglevel="INFO" --sort-columns --info-level="maximum" --command="details" --outputformat="png" --output-file="$diagram_path" --title="$diagram_title" #--config-file="/feup-bdad-corrector/schemacrawler.config.properties"
}

function run_queries
{
	for (( i = 1; i <= 10; i++ )); do
		printf "\n---------Running query ./int${i}.sql---------\n\n"
    if exists "./int${i}.sql" ; then
      printf "OK: ./int${i}.sql file is in the folder\n"
      printf "\n---------int${i}.sql---------\n\n"
      cat  int${i}.sql >> output.txt
      printf "\n-----------------------------\n\n"
      printf "$PREAMBLE" | cat - int${i}.sql | sqlite3 database.db\
        || (printf "Error running query ${i}.\n" && return 1)
    else
        printf "ERROR: ./int${i}.sql file is missing inside the folder\n"
        return 1
    fi
	done
}

function test_triggers
{
	for (( i = 1; i <= 3; i++ )); do
		printf "\n---------Running trigger ./gatilho${i}_XXXXXX.sql---------\n\n"
		if exists "./gatilho${i}_adiciona.sql" &&  exists "./gatilho${i}_verifica.sql" && exists "./gatilho${i}_remove.sql" ;
    then
      printf "OK: ./gatilho${i}_adiciona.sql, ./gatilho${i}_verifica.sql and ./gatilho${i}_remove.sql files are in the folder\n"

      printf "\n---------gatilho${i}_adiciona.sql---------\n\n"
      cat  gatilho${i}_adiciona.sql >> output.txt
      printf "\n---------gatilho${i}_verifica.sql---------\n\n"
      cat  gatilho${i}_verifica.sql >> output.txt
      printf "\n---------gatilho${i}_remove.sql---------\n\n"
      cat  gatilho${i}_remove.sql >> output.txt
      printf "\n-----------------------------\n\n"

      printf "$PREAMBLE" | cat - gatilho${i}_adiciona.sql | sqlite3 database.db && \
			printf "$PREAMBLE" | cat - gatilho${i}_verifica.sql | sqlite3 database.db && \
			printf "$PREAMBLE" | cat - gatilho${i}_remove.sql | sqlite3 database.db \
		    || (
          printf "Error running trigger ${i}." &&
          printf "Check for the appropriate error message and validate" &&
          printf "if it is really supposed to be like this.\n"
          printf "If it is a BEFORE INSERT trigger and you intend to block" &&
          printf "invalid operations, for example, you may safely ignore" &&
          printf "this error message.\n\n" && return 1)
    else
        printf "ERROR: Either ./gatilho${i}_adiciona.sql, ./gatilho${i}_verifica.sql or ./gatilho${i}_remove.sql file is missing inside the folder\n"
        return 1
    fi
	done
}

function clean_dir()
{
  local dir_to_clean="$1"
  rm -f "$dir_to_clean/database.db"
  rm -f "$dir_to_clean/output.txt"
  rm -f "$dir_to_clean/diagram.png"
}

function copy_results()
{
  source="$1"
  target="$2"

  # echo "Copying $source/database.db to $target..."
  cp "$source/database.db" "$target"
  cp "$source/output.txt" "$target"
  cp "$source/diagram.png" "$target"
}

function run_everything() {
	local d="$1"
  local dirname
  local temp_dir
  dirname=`basename "$d"`
  temp_dir="/tmp/$(uuidgen)"

  mkdir -p "$temp_dir"
  cp -R "$d/." "$temp_dir"
	clean_dir "$d"
  clean_dir "$temp_dir"

	cd "$temp_dir" || (printf "ERROR: $temp_dir does not exist." && exit 1)
	touch output.txt
	{
    print_message "Running script over $dirname..."

		print_message "Creating database"

		printf "$PREAMBLE" | cat - criar.sql | sqlite3 database.db >> output.txt 2>&1 && \
		print_message "Creates BD without errors.\n" || \
		print_message "Errors creating DB!\n"

		print_message "Populating database..."

		printf "$PREAMBLE" | cat - povoar.sql | sqlite3 database.db >> output.txt 2>&1 && \
		print_message "Populates BD without errors.\n" || \
		print_message "Errors populating DB!\n"

		print_message "Now checking database consistency..."

		printf "${PREAMBLE}${CHECK_CONSISTENCY_COMMAND}" | sqlite3 database.db >> output.txt 2>&1 && \
		print_message  "Database is consistent\n \
    Attention: An empty database is also consistent.\n \
    Check for errors in creation and seeding.\n" ||
		print_message "Inconsistencies detected in DB!\n"

		if [[ "$TEST_TRIGGERS_AND_QUERIES" == "true" ]]; then
			print_message "Running queries..."

			run_queries && \
			print_message "Queries ran successfully.\n" || \
			print_message "Errors occurred while running queries against DB!\n"

			print_message "Running triggers..."

			test_triggers && \
			print_message "Triggers tested successfully.\n\n" || \
			print_message "Errors occurred while testing triggers!\n\n"
		fi

		if [[ "$SHOW_SCRIPTS_AT_END" == "true" ]]; then
			print_message "Create script follows."

			printf "$PREAMBLE" | cat - criar.sql | cat -n

			print_message "Populate script follows."

			printf "$PREAMBLE" | cat - povoar.sql | cat -n
		fi

		if [[ "$GENERATE_DIAGRAM" == "true" ]]; then
			# generate diagram
      print_message "Generating database diagram"
			diagram "$(pwd)" "$d" "$dirname" && print_message "Diagram Generated" || print_message "Errors printing diagram"
		fi

		print_message "Done for $dirname"
	}	>> output.txt 2>&1

  copy_results "$temp_dir" "$d" >> /dev/null 2>&1
  cd "$ORIGINAL_DIR" || (printf "ERROR: $ORIGINAL_DIR does not exist." && exit 1)
}

if [[ "$BATCH_CORRECTION" != "true" ]]; then
	run_everything "$(pwd)"
  cat output.txt
else
  # run all generation in parallel
	for d in ./*; do
	  if [ -d "$d" ]; then
      if [[ "$FORCE_SEQUENTIAL" == "true" ]]; then
        run_everything "$(pwd)/${d#.}"
        cat output.txt
      else
        run_everything "$(pwd)/${d#.}" &
      fi
	  fi
	done

  if [[ "$FORCE_SEQUENTIAL" != "true" ]]; then
  	wait
    # print results sequentially
    for d in ./*; do
      if [ -d "$d" ]; then
        cd "$d" || (printf "ERROR: $d does not exist." && exit 1)
        cat output.txt
      fi
    done
  fi

  print_message "All generation done!"
fi
