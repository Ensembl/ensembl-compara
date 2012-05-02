=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
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

Bio::EnsEMBL::Hive::RunnableDB::DumpMultiAlign::MD5SUM

=head1 SYNOPSIS

This RunnableDB module is part of the DumpMultiAlign pipeline.

=head1 DESCRIPTION

The RunnableDB module runs the md5sum command

=cut


package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MD5SUM;

use strict;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift;

}

sub run {
    my $self = shift;

    #
    #Run md5sum comamnd
    #
    chdir $self->param('output_dir');
    my $cmd = "md5sum *.gz > MD5SUM";

    if(my $return_value = system($cmd)) {
        $return_value >>= 8;
        die "system( $cmd ) failed: $return_value";
    }

}

sub write_output {
    my $self = shift @_;

}

1;
