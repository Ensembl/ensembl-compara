# AUTHOR:
# Kathryn Beal (kbeal@ebi.ac.uk)
# COPYRIGHT:
# This script is part of the Ensembl project http://www.ensembl.org
# DESCRIPTION:
# This file is called from view_alignment.pl. Please see this file for
# documentation and usage
#\
exec stash "$0" ${@+"$@"} || exit 1

#open gap4 database 
proc open_database {name} {
    if {[set dot [string last . $name]] == -1} {
        puts "ERROR: Invalid database name '$name'"
        return ""
    }
    set db_name [string range $name 0 [expr $dot-1]]
    set version_num [string range $name [expr $dot+1] end]

    #if name exists, don't create a new database
    if {[file exists $name]} {
        set c 0
    } else {
        set c 1
    }

    return [open_db -name $db_name -version $version_num -access rw -create $c]
}

#close gap4 database only when the last contig editor has been closed
proc close_database {io} {
    global WinCnt

    incr WinCnt -1
    if {$WinCnt ==0} {
	close_db -io $io
	exit
    }
}

tkinit
wm withdraw .

load_package gap

error_bell 0

InitTagArray
InitLists
set WinCnt 0

#2 arguments 
if {$argc > 0} {
    set db_name [lindex $argv 0]
    if {$argc >= 2} {
	set fofn [lindex $argv 1]
	set template_display [lindex $argv 2]
    }
} else {
    puts "ERROR: No database or file of filenames found"
    exit 1
}

if {![file exists $db_name]} {
    set create_new_db 1
} else {
    set create_new_db 0
}

# Open the database
if {[set io [open_database $db_name]] == ""} {
    puts "ERROR: Couldn't open database '[lindex $argv 0]'"
    exit 1
}

#if database name doesn't exist, create a new database.
if {$create_new_db} {
    assemble_direct -io $io -files [ListLoad $fofn files] -align 0
}

set allcontigs [ListGet allcontigs]

set WinCnt [llength $allcontigs]

for {set j 0} {$j < [llength $allcontigs]} {incr j} {
    set winList($j) [edit_contig -io $io -contig [lindex $allcontigs $j]]
    bind $winList($j) <Destroy> {+close_database $io}
}

if {$template_display} {
    set contig_list [CreateAllContigList $io]
    CreateTemplateDisplay $io $contig_list
}

