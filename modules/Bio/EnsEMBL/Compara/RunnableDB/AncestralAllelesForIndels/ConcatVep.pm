=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::ConcatVep.pm

=head1 SYNOPSIS

This RunnableDB module is part of the AncestralAllelesForIndels pipeline.

=head1 DESCRIPTION

This RunnableDB module concatenates the sub-chunked jobs to produce files covering the slice of the chunked jobs (vep_size). This is to optimise the reading of these files by the Variant Effect Predictor plugin. These files are compressed with bgzip and indexed using tabix.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::ConcatVep;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');
use Bio::EnsEMBL::Variation::DBSQL::DBAdaptor;
use File::Basename;
use Bio::EnsEMBL::Utils::Exception qw(throw);

sub fetch_input {
    my $self = shift;
}

sub run {
    my $self = shift;
}

sub write_output {
    my $self = shift @_;

    my $sub_dir = $self->param('seq_region') . "/" . $self->param('seq_region_start') . "_" . $self->param('seq_region_end');

    #Change to the directory to keep the file path small
    chdir($self->param('work_dir') . "/" . $sub_dir) or die "Unable to change directory $!";
    my $all_files = "vep_" . $self->param('seq_region') . "_*";

    my @files = < $all_files >;
    
    my $vep_files;
    foreach my $file (@files) {
        my ($name, $path, $suffix) = fileparse($file);
        my ($vep, $seq_region, $start, $end) = split "_", $name;
        if ($start >= $self->param('seq_region_start') && $end <= $self->param('seq_region_end')) {
            $vep_files->{$start} = $file;
        }
    }

    #Concatenate files together
    my $concat_file = $self->param('work_dir') . "/" . $self->param('seq_region') . "/anc_indel_" . $self->param('seq_region') . "_" . $self->param('seq_region_start') . "_" . $self->param('seq_region_end');

    my @ordered_files;
    foreach my $start (sort {$a <=> $b} keys %$vep_files) {
        push @ordered_files, $vep_files->{$start};
    }
    my $file_list = join " ", @ordered_files;

    my $cat_cmd = "cat $file_list > $concat_file";
    $self->run_command($cat_cmd, { die_on_failure => 1 });
    
    #First check concat_file is not empty
    if (-s $concat_file) {
        
        #bgzip
        my $bgzip_cmd = [$self->param('bgzip'), '-f', $concat_file];
        $self->run_command($bgzip_cmd, { die_on_failure => 1 });
        
        #create tabix
        my $tabix_cmd = [$self->param('tabix'), qw(-s 1 -b 2 -e 2), $concat_file.'.gz'];
        $self->run_command($tabix_cmd, { die_on_failure => 1 });
    } else {
        #empty concat_file
        unlink $concat_file;
    }
    
    #Should be able to delete the original files now
    unlink @ordered_files;
}

1;
