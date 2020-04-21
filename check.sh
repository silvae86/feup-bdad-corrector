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
    echo "  -s      (show/copy-paste scripts of students to the output.txt file after running checks "
    echo "  -d      do not generate diagram using schemacrawler"
    echo "  -h      print this help"
}

while getopts 'tbsdh' arg; do
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

function exists()
{
	local file=$1
	[ -f "$file" ] || printf "File $file does not exist!\n" && return 1
	return 0
}

function diagram
{
  local database_path="$1/database.db"
  local diagram_path="$1/diagram.png"
  local target_dir="$2"

	/opt/schemacrawler/schemacrawler.sh -server sqlite -database "$database_path" -user -password -loglevel SEVERE -sort-columns -infolevel maximum -command details -outputformat png -outputfile "$diagram_path" -g "/feup-bdad-corrector/schemacrawler.config.properties"
}

function run_queries
{
	for (( i = 1; i <= 10; i++ )); do
		printf "\n---------Running query ./int${i}.sql---------\n\n"
		exists "./int${i}.sql" || printf "OK: ./int${i}.sql file is in the folder\n" && \
			printf "$PREAMBLE" | cat - int${i}.sql | sqlite3 database.db \
		|| (printf "Error running query ${i}.\n" && return 1)
	done
}

function test_triggers
{
	for (( i = 1; i <= 3; i++ )); do
		printf "\n---------Running trigger ./gatilho${i}_XXXXXX.sql---------\n\n"
		( exists "./gatilho${i}_adiciona.sql" && exists "./gatilho${i}_verifica.sql" && exists "./gatilho${i}_remove.sql" ) && printf "OK: ./gatilho${i}_adiciona.sql, ./gatilho${i}_verifica.sql and ./gatilho${i}_remove.sql files are in the folder\n" && \
			printf "$PREAMBLE" | cat - gatilho${i}_adiciona.sql | sqlite3 database.db >> output.txt 2>&1 && \
			printf "$PREAMBLE" | cat - gatilho${i}_verifica.sql | sqlite3 database.db >> output.txt 2>&1 && \
			printf "$PREAMBLE" | cat - gatilho${i}_remove.sql | sqlite3 database.db >> output.txt 2>&1 \
		|| (printf "Error running trigger ${i}.?\n" && return 1)
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
  local dirname=`basename "$d"`
  local temp_dir="/tmp/$(uuidgen)"
  mkdir -p "$temp_dir"
  cp -R "$d/." "$temp_dir"
	clean_dir "$d"

  print_message "Running script over $dirname..."

	cd "$temp_dir"
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
			diagram "$(pwd)" "$d" && print_message "Diagram Generated" || print_message "Errors printing diagram"
		fi

		print_message "Done for $dirname"
	}	>> output.txt 2>&1

  copy_results "$temp_dir" "$d" >> /dev/null 2>&1
  cd "$ORIGINAL_DIR"
}

if [[ "$BATCH_CORRECTION" != "true" ]]; then
	run_everything "$(pwd)"
  cat output.txt
else
  # run all generation in parallel
	for d in ./*; do
	  if [ -d "$d" ]; then
			run_everything "$(pwd)/${d#.}" &
	  fi
	done
	wait

  print_message "All generation done!"

  # print results sequentially
  for d in ./*; do
    if [ -d "$d" ]; then
      cd "$d"
      cat output.txt
    fi
  done
fi
