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

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Getopt::Long;

my ( $help, $reg_conf, $compara_db, $ftp_root, $release, $division );
GetOptions(
    "help"         => \$help,
    "reg_conf=s"   => \$reg_conf,
    "compara_db=s" => \$compara_db,
    "ftp_root=s"   => \$ftp_root,
    "release=i"    => \$release,
    "division=s"   => \$division,
);

$release  = $ENV{CURR_ENSEMBL_RELEASE} unless $release;
$ftp_root = $ENV{ENSEMBL_FTP} . "/release-$release/" unless $ftp_root;

die "FTP root '$ftp_root' does not exist\n" unless -e $ftp_root;
die &helptext if ( $help || !($reg_conf && $compara_db && $division) );

my %ftp_file_per_mlss = (
	LASTZ_NET                => 'maf/ensembl-compara/pairwise_alignments/#mlss_filename#*.tar*',
	EPO                      => 'maf/ensembl-compara/multiple_alignments/#mlss_filename#/*',
	EPO_LOW_COVERAGE         => 'maf/ensembl-compara/multiple_alignments/#mlss_filename#/*',
	PECAN                    => 'maf/ensembl-compara/multiple_alignments/#mlss_filename#/*',
	GERP_CONSTRAINED_ELEMENT => 'bed/ensembl-compara/#mlss_filename#/*',
	GERP_CONSERVATION_SCORE  => 'compara/conservation_scores/#mlss_filename#/*',
    PROTEIN_TREES            => "xml/ensembl-compara/homologies/Compara.$release.protein_#clusterset_id#.alltrees.orthoxml.xml.gz",
    NC_TREES                 => "xml/ensembl-compara/homologies/Compara.$release.ncrna_#clusterset_id#.alltrees.orthoxml.xml.gz",
    ENSEMBL_ORTHOLOGUES      => 'tsv/ensembl-compara/homologies/#species_name#/*',
    ENSEMBL_PARALOGUES       => 'tsv/ensembl-compara/homologies/#species_name#/*',
    SPECIES_TREE             => 'compara/species_trees/*.nh',
);

my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing") if $reg_conf;
my $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $compara_db );
my $mlsses = $dba->get_MethodLinkSpeciesSetAdaptor->fetch_all_current;

foreach my $mlss ( @$mlsses ) {
    my $file_for_type = $ftp_file_per_mlss{$mlss->method->type};
    next unless defined $file_for_type;
    
    if ( $file_for_type =~ /#mlss_filename#/ ) {
        my $mlss_filename = $mlss->filename;
        $file_for_type =~ s/#mlss_filename#/$mlss_filename/ig;
        $file_for_type = "$ftp_root/$file_for_type";
        my @files = glob $file_for_type;
        if ( (!defined $files[0] || !-e $files[0]) && $mlss->method->type eq 'LASTZ_NET' ) {
            # try different order of species
            my $orig_mlss_filename = $mlss_filename;
            $mlss_filename =~ /(.+)\.v\.(.+)\.lastz_net/;
            $mlss_filename = "$2.v.$1.lastz_net";
            $file_for_type =~ s/$orig_mlss_filename/$mlss_filename/;
            @files = glob $file_for_type;
        }
        die "Could not find file for MethodLinkSpeciesSet dbID " . $mlss->dbID . " (" . $mlss->name . "): $file_for_type" unless scalar(@files) && -e $files[0];
    } elsif ( $file_for_type =~ /#collection_name#/ ) {
        my $collection_name = $mlss->species_set->name;
        $collection_name =~ s/collection-//;
        $file_for_type =~ s/#collection_name#/$collection_name/;
        $file_for_type = "$ftp_root/$file_for_type";
        my @files = glob $file_for_type;
        die "Could not find file for MethodLinkSpeciesSet dbID " . $mlss->dbID . " (" . $mlss->name . "): $file_for_type" unless scalar(@files) && -e $files[0];
    } elsif ( $file_for_type =~ /#clusterset_id#/ ) {
        my $clusterset_id = 'default';
        if ( $division eq 'vertebrates' ) {
            my $collection_name = $mlss->species_set->name;
            $collection_name =~ s/collection-//;
            $clusterset_id = $collection_name;
        }
        $file_for_type =~ s/#clusterset_id#/$clusterset_id/;
        $file_for_type = "$ftp_root/$file_for_type";
        my @files = glob $file_for_type;
        die "Could not find file for MethodLinkSpeciesSet dbID " . $mlss->dbID . " (" . $mlss->name . "): $file_for_type" unless scalar(@files) && -e $files[0];
    } elsif ( $file_for_type =~ /#species_name#/ ) {
        $file_for_type = "$ftp_root/$file_for_type";
        foreach my $gdb ( @{ $mlss->species_set->genome_dbs } ) {
            my $this_species_file_for_type = $file_for_type;
            my $this_species_name = $gdb->name;
            $this_species_file_for_type =~ s/#species_name#/$this_species_name/;
            my @files = glob $this_species_file_for_type;
            unless (scalar(@files) && -e $files[0]) {
                # Try with a collection
                my $this_collection_species_file_for_type = $file_for_type;
                $this_collection_species_file_for_type =~ s/#species_name#/*_collection\/$this_species_name/;
                @files = glob $this_collection_species_file_for_type;
                die "Could not find file for MethodLinkSpeciesSet dbID " . $mlss->dbID . " (" . $mlss->name . "): $this_species_file_for_type" unless scalar(@files) && -e $files[0];
            }
        }
    } else {
        $file_for_type = "$ftp_root/$file_for_type";
        my @files = glob $file_for_type;
        die "Could not find file for MethodLinkSpeciesSet dbID " . $mlss->dbID . " (" . $mlss->name . "): $file_for_type" unless scalar(@files) && -e $files[0];
    }
}
print "All MethodLinkSpeciesSets found in FTP\n\n";

sub helptext {
	my $msg = <<HELPEND;

Usage: perl verify_ftp_dumps.pl --reg_conf <registry config> --compara_db <alias or url> -division <division> [--release <release number> --ftp_root <path to FTP root>]

HELPEND
	return $msg;
}
