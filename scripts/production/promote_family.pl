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

use strict;
use Bio::SeqIO;
use Getopt::Long;
use Data::Dumper;


#first we need to duplicate the directory 2015-12-18/
my $promoting_file;

GetOptions( 'promoting_file=s' => \$promoting_file );

unless ($promoting_file) {
    print "\nERROR : must provide a file with the list of families to promote.\n\n";
    usage();
}

my $new_library_time_stamp = "2018-08-20";
my $promote_from_path      = "/hps/nobackup2/production/ensembl/compara_ensembl/treefam_hmms/2015-12-18";
my $promote_to_path        = "/hps/nobackup2/production/ensembl/compara_ensembl/treefam_hmms/$new_library_time_stamp";

my %promoting_list;

open my $fh, "<", $promoting_file;
while (<$fh>) {
    chomp($_);
    $promoting_list{$_} = 1;
}
close($fh);

unlink "$promote_to_path/globals/con.Fasta*";

my $in_file = Bio::SeqIO->new( -file => "$promote_from_path/globals/con.Fasta", -format => 'fasta' );
my $in_file_panther_9 = Bio::SeqIO->new( -file => "promote/con_PANTHER_9.Fasta", -format => 'fasta' );

open my $out_fh, '>', "$promote_to_path/globals/con.Fasta";

#Fetch all the sequences from PANTHER 9
my %panther_9;
while ( my $seq = $in_file_panther_9->next_seq() ) {
    $panther_9{$seq->id} = $seq->seq;
}

while ( my $seq = $in_file->next_seq() ) {

    my $seq_id = $seq->id;
    if ( $promoting_list{ $seq->id } ) {
        #print "Promoting $seq_id:\n";
        foreach my $fam (keys %panther_9){
            if ($fam =~ /$seq_id:/){
                my $new_name = $fam;
                $new_name =~ s/:/_/;

                #print to $promote_to_path/globals/con.Fasta
                print ">$new_name\n";
                print $out_fh ">$new_name\n";
                print $out_fh $panther_9{$fam}."\n";
            }
        }
        
        rmdir("$promote_to_path/books/$seq_id");

        my @sub_families = get_sub_families( $seq->id );
        foreach my $sub_family (@sub_families){
            #copy sub-families directories from $promote_from_path/books/$seq->id/$sub_family/ to $promote_to_path/books
            system( "cp -r $promote_from_path/books/$seq_id/$sub_family $promote_to_path/books/$seq_id\_$sub_family");
        }
    }
    else{
        #print to $promote_to_path/globals/con.Fasta
        print $out_fh ">".$seq->id."\n";
        print $out_fh $seq->seq."\n";
    }
}

system ("makeblastdb -in $promote_to_path/globals/con.Fasta -dbtype prot"); 

sub get_sub_families {
    my $family = shift;
    my @dirs   = glob("$promote_from_path/books/$family/SF*");
    my @sub_families;
    foreach my $dir (@dirs) {
        my @tok = split( /\//, $dir );
        push( @sub_families, $tok[-1] );
    }
    return @sub_families;
}

sub usage {
    print "\npromote_family.pl [options]\n";
    print " --promoting_file                  : file with the list of families to promote\n";
    print "\n";

    exit(1);
}

