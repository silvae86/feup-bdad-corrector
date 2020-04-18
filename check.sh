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

if [[ "$TEST_TRIGGERS_AND_QUERIES" == "true" ]]; then
	printf "Testing DB Creation, Populating, Queries and Triggers (Third delivery)...\n"
else
	printf "Testing DB Creation and Populating only (Second delivery)...\n"
fi

if [[ "$BATCH_CORRECTION" == "true" ]]; then
	printf "Batch Correction Mode engaged! The program will scan all subdirectories and perform correction on all of them. Check output.txt inside each for the results.\n"
fi

if [[ "$GENERATE_DIAGRAM" == "false" ]]; then
	printf "Diagram will not be created.\n"
fi

if [[ "$SHOW_SCRIPTS_AT_END" == "true" ]]; then
	printf "Appending a copy of the scripts to the end of the output.txt file.\n"
fi

function exists()
{
	local file=$1
	[ -f "$file" ] || printf "File $file does not exist!\n" && return 1
	return 0
}

function diagram
{
  local database_path="$1"
  local database_tmp_copy_path="/tmp/$(uuidgen).db"

	#echo "database is at $database_path"
  cp "$database_path" "$database_tmp_copy_path"

  local diagram_path="$2"
  local diagram_tmp_copy_path="/tmp/$(uuidgen).png"
	#echo "diagram will be at $diagram_path"

	/opt/schemacrawler/schemacrawler.sh -server sqlite -database "$database_tmp_copy_path" -user -password -loglevel SEVERE -sort-columns -infolevel maximum -command details -outputformat png -outputfile "$diagram_tmp_copy_path" -g "/feup-bdad-corrector/schemacrawler.config.properties"

  mv -f "$diagram_tmp_copy_path" "$diagram_path"
  rm -f "$diagram_tmp_copy_path"
  rm -f "$database_tmp_copy_path"
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

function run_everything() {
	local d="$1"
	printf "Entering $d...\n\n"
	cd "$d"
	rm -f database.db
	rm -f output.txt
  rm -f diagram.png
	touch output.txt
	{
		printf "##############################################\n"
		printf "###         Creating database...          ### \n"
		printf "##############################################\n"

		printf "$PREAMBLE" | cat - criar.sql | sqlite3 database.db >> output.txt 2>&1 && \
		printf "Creates BD without errors.\n" || \
		printf "Errors creating DB!\n"

		printf "##############################################\n"
		printf "###          Populating database...        ###\n"
		printf "##############################################\n\n"
		printf "$PREAMBLE" | cat - povoar.sql | sqlite3 database.db >> output.txt 2>&1 && \
		printf "Populates BD without errors.\n" || \
		printf "Errors populating DB!\n"

		printf "##############################################\n"
		printf "###  Now checking database consistency...  ###\n"
		printf "##############################################\n\n"

		printf "${PREAMBLE}${CHECK_CONSISTENCY_COMMAND}" | sqlite3 database.db >> output.txt 2>&1 && \
		printf "Database is consistent\n" && \
    printf "Attention: An empty database is also consistent.\n" && \
    printf "Check for errors in creation and seeding.\n" ||
		printf "Inconsistencies detected in DB!\n"

		if [[ "$TEST_TRIGGERS_AND_QUERIES" == "true" ]]; then
			printf "##############################################\n"
			printf "###           Running queries...           ###\n"
			printf "##############################################\n\n"

			run_queries && \
			printf "Queries ran successfully.\n" || \
			printf "Errors occurred while running queries against DB!\n"

			printf "##############################################\n"
			printf "###           Running triggers...          ###\n"
			printf "##############################################\n\n"

			test_triggers && \
			printf "Triggers tested successfully.\n\n" || \
			printf "Errors occurred while testing triggers!\n\n"
		fi

		if [[ "$SHOW_SCRIPTS_AT_END" == "true" ]]; then
			printf "##############################################\n"
			printf "###         Create script follows.         ###\n"
			printf "##############################################\n\n"

			printf "$PREAMBLE" | cat - criar.sql | cat -n

			printf "##############################################\n"
			printf "###         Populate script follows.       ###\n"
			printf "##############################################\n\n"
			printf "$PREAMBLE" | cat - povoar.sql | cat -n
		fi

		if [[ "$GENERATE_DIAGRAM" == "true" ]]; then
			# generate diagram
      printf "##############################################\n"
      printf "###       Generating database diagram.     ###\n"
      printf "##############################################\n\n"
			diagram "$(pwd)/database.db" "$(pwd)/diagram.png"
      printf "##############################################\n"
      printf "###           Diagram generated.           ###\n"
      printf "##############################################\n\n"
		fi

		printf "##############################################\n"
		printf "###                 All Done               ###\n"
		printf "##############################################\n\n"
	}	>> output.txt 2>&1
}

if [[ "$BATCH_CORRECTION" != "true" ]]; then
	run_everything "$(pwd)"
	cat output.txt
else
	for d in ./*; do
	  if [ -d "$d" ]; then
			run_everything "$d"
			cat output.txt
			cd "$ORIGINAL_DIR"
	  fi
	done
	wait
fi
