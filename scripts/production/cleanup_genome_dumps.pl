#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use warnings;
use strict;

use File::Basename;
use Getopt::Long;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my ( $help, $reg_conf, $master_db, $genome_dumps_dir, $before_release, $force, $dry_run );
GetOptions(
    "help"               => \$help,
    "reg_conf=s"         => \$reg_conf,
    "master_db=s"        => \$master_db,
    "genome_dumps_dir=s" => \$genome_dumps_dir,
    "before_release=s"   => \$before_release,
    "force"              => \$force,
    "dry_run"            => \$dry_run,
);

$master_db ||= 'compara_master';
die &helptext if ( $help || !($reg_conf && $master_db && $genome_dumps_dir && $before_release) );

my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing") if $reg_conf;

my $master_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $master_db );
my @all_genome_dbs = @{ $master_dba->get_GenomeDBAdaptor->fetch_all() };

my ($total_deleted_species, $total_deleted_files, $total_deleted_size_gb) = (0, 0, 0);
foreach my $genome_db ( @all_genome_dbs ) {
    if ( defined $genome_db->last_release && $genome_db->last_release < $before_release ) {
        my $this_genome_dump_path = $genome_db->_get_genome_dump_path($genome_dumps_dir);
        if ( -e $this_genome_dump_path ) {
            $total_deleted_species++;
            my ($this_filename, $this_dir, $this_suffix) = fileparse($this_genome_dump_path, ".fa");
            my ($gdb_name, $gdb_ass, $gdb_lr) = ($genome_db->name, $genome_db->assembly, $genome_db->last_release);
            print "Removing $gdb_name ($gdb_ass) - retired in $gdb_lr\t$this_dir/$this_filename.*\n";
            my $f = $force ? '-f ':'';
            my @files_to_rm = glob "$this_dir/$this_filename.*";
            foreach my $file_to_rm ( @files_to_rm ) {
                $total_deleted_files++;
                $total_deleted_size_gb += (-s $file_to_rm) / (1024 * 1024 * 1024); # size in gb
                system("rm $f $file_to_rm") unless $dry_run;
            }
            
        }
    }
}
my $del_status = $dry_run ? "marked for deletion" : "deleted";
my $rounded_size = sprintf("%.2f", $total_deleted_size_gb);
print "\n$total_deleted_files files $del_status from $total_deleted_species species, totalling ${rounded_size}G\n\n";


sub helptext {
	my $msg = <<HELPEND;

Usage: cleanup_genome_dumps.pl --master_db <master> --genome_dumps_dir <dir> --before_release <XX>

Options:
    --reg_conf          (optional) registry configuration file
    --master_db         URL or alias for master database
    --genome_dumps_dir  directory containing genome dumps
    --before_release    remove dumps of species retired before this release version
    --force             (optional) force remove files (rm -f)
    --dry_run           (optional) don't remove files - just report intentions to remove

HELPEND
	return $msg;
}
