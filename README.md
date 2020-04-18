# feup-bdad-corrector

[![](https://images.microbadger.com/badges/image/joaorosilva/feup-bdad-corrector.svg)](https://microbadger.com/images/joaorosilva/feup-bdad-corrector "Get your own image badge on microbadger.com")
[![](https://images.microbadger.com/badges/version/joaorosilva/feup-bdad-corrector.svg)](https://microbadger.com/images/joaorosilva/feup-bdad-corrector "Get your own version badge on microbadger.com")

An auto corrector for FEUP's Databases Course of the 2nd year of the Masters in Informatics Engineering.

It tries to automate the checking of the more code-oriented deliveries (2nd and 3rd), and is packaged as a Docker image for zero-configuration usage.

The best part is, you can set it up in any computer and run it locally!

## What does it do?

- For the 2nd delivery
  1. Verifies the presence of the required files (`criar.sql` and `povoar.sql`)
  2. Runs them both and output any errors found
  3. Checks database consistency for wrong foreign keys, etc.
  4. Generates a diagram of the database using [schemacrawler 15](https://www.schemacrawler.com/). This is a completely UNOFFICIAL diagram type and only allows you to validate graphically if you are missing FKs or PKs, for example. It should not be replicated in practical or theoretical classes. Stick to the types of diagrams taught in class!
  5. If you use the `-s` argument, it will also copy your scripts to the `output.txt` file, with line numbers added, so you can pinpoint your mistakes

- For the 3rd delivery  (`-t` CLI argument must be present to activate this mode)
  1. Everything in the 2nd delivery
  2. runs the 10 query files expected (verifies the presence of all files with correct names: `int{1 to 10}.sql`)
  2. Runs the 3 trigger files (x3, as you need 3 files for each: `gatilho{1 to 3}_adiciona.sql`, `atilho{1 to 3}_verifica.sql`, and `atilho{1 to 3}_remove.sql`

- It produces two outputs
  1. `output.txt` - The result of the execution of the scripts
  2. `diagram.png` - The reverse-engineered database diagram of your database

## How to use

1. Install [Docker](https://docs.docker.com/get-docker/).
2. Place your .sql files in a folder X
  - Professors: place the works of each group in separate subdirectories inside X
3. Run the commands below in folder X (don't forget to `cd` to X)
4. Check the `output.txt` and `diagram.png` files that it produces. The final database will also be created with the name `database.db`.
  - Professors: each group's outputs will be inside corresponding subdirectories of X

### In Linux / Mac

```bash
docker pull joaorosilva/feup-bdad-corrector:latest
docker run -v "$(pwd)":/bdad -w /bdad joaorosilva/feup-bdad-corrector:latest -t -s
# add or remove arguments at the end of this command line
# to change the behaviour of the script accordingly.
# IMPORTANT: the `-t` argument checks queries and triggers, besides database creation and seeding
```

### In Windows CMD:

```shell
docker pull joaorosilva/feup-bdad-corrector:latest
docker run -v %cd%:/bdad -w /bdad joaorosilva/feup-bdad-corrector:latest -t -s
```

### In Windows PowerShell :

```PowerShell
docker pull joaorosilva/feup-bdad-corrector:latest
docker run -v ${PWD}:/bdad -w /bdad joaorosilva/feup-bdad-corrector:latest -t -s
```

## Possible arguments:
```txt
  -t      test triggers and queries (3rd delivery only)
  -b      enable batch correction (scan subfolders of current one), useful for professors
  -s      (show/copy-paste scripts of students to the output.txt file after running checks
  -d      do not generate diagram using schemacrawler
  -h      print this help
```

### For professors

By default, the script will run in the current folder where you execute the commands below. It also includes a batch mode for professors to run the script on all subdirectories of the current directory. The code executed is the same, it just iterates over all subdirs if the `-b` parameter is specified. If the batch mode is specified, operations are executed in parallel to take advantage of a multicore processor, if you have one.

#### For the curious

This command mounts the current folder in a Docker container, more specifically at its `/bdad` location; this way, it has bidirectional access to all files placed in the current directory (sql scripts...). Then it runs the script, placing outputs also in the current folder.

## Important disclaimer

Consider this an indication of correctness of your code. It only checks if stuff runs, not if it is logically correct. A full pass in these checks in no way indicates a maximum grade!!
