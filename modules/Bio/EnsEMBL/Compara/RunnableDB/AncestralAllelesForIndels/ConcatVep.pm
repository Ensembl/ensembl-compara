=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::ConcatVep.pm

=head1 SYNOPSIS

This RunnableDB module is part of the AncestralAllelesForIndels pipeline.

=head1 DESCRIPTION

This RunnableDB module concatenates the sub-chunked jobs to produce files covering the slice of the chunked jobs (vep_size). This is to optimise the reading of these files by the Variant Effect Predictor plugin. These files are compressed with bgzip and indexed using tabix.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::ConcatVep;

use strict;
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

    unless (system("cat $file_list > $concat_file") == 0) {
        throw("Failed cat $file_list $?\n");
    }
    
    #First check concat_file is not empty
    if (-s $concat_file) {
        
        #bgzip
        my $bgzip = $self->param('bgzip');
        unless (system("$bgzip -f $concat_file") == 0) {
            throw("bgzip execution failed $?");
        }
        
        #create tabix
        my $tabix = $self->param('tabix');
        unless (system("$tabix -s 1 -b 2 -e 2 $concat_file.gz") == 0) {
            throw("tabix execution failed $?");
        }
    } else {
        #empty concat_file
        unlink $concat_file;
    }
    
    #Should be able to delete the original files now
    unlink @ordered_files;
}

1;
