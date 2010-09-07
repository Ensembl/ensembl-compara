
=pod 

=head1 NAME

Bio::EnsEMBL::Hive::RunnableDB::DumpMultiAlign::Compress.pm

=head1 SYNOPSIS

This RunnableDB module is part of the DumpMultiAlign pipeline.

=head1 DESCRIPTION

This RunnableDB module runs gzip -9

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk

=cut


package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::Compress;

use strict;
use Bio::EnsEMBL::Hive::DBSQL::AnalysisDataAdaptor;
use base ('Bio::EnsEMBL::Hive::ProcessWithParams');

=head2 strict_hash_format

    Description : Implements strict_hash_format() interface method of Bio::EnsEMBL::Hive::ProcessWithParams that is used to set the strictness level of the parameters' parser.
                  Here we return 0 in order to indicate that neither input_id() nor parameters() is required to contain a hash.

=cut

sub strict_hash_format {
    return 0;
}

sub fetch_input {
    my $self = shift;

}

sub run {
    my $self = shift;

    #
    #Run gzip -9 command (with force option)
    #
    my $cmd = "gzip -f -9 " . $self->param('output_file');
    if(my $return_value = system($cmd)) {
        $return_value >>= 8;
        die "system( $cmd ) failed: $return_value";
    }

    #
    #If maf_output_dir defined, move maf file from emf directory to maf
    #directory
    #
    if ($self->param('maf_output_dir')) {
	my $mv_cmd = "mv " . $self->param('output_file') . ".gz " . $self->param('maf_output_dir');
	if(my $return_value = system($mv_cmd)) {
	    $return_value >>= 8;
	    die "system( $cmd ) failed: $return_value";
	}
    }

}

sub write_output {
    my $self = shift @_;

}

1;
