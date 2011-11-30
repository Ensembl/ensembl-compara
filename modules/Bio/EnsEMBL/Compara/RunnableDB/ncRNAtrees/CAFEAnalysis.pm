=head1 LICENSE

  Copyright (c) 1999-2010 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=cut

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::CAFEDynamics

=head1 SYNOPSIS

=head1 DESCRIPTION

This RunnableDB calculates the dynamics of a ncRNA family (based on the tree obtained and the CAFE software) in terms of gains losses per branch tree. It needs a CAFE-compliant species tree.

=head1 INHERITANCE TREE

Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::CAFEAnalysis;

use strict;
use Data::Dumper;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

    Title     : fetch_input
    Usage     : $self->fetch_input
    Function  : Fetches input data from database
    Returns   : none
    Args      : none

=cut

sub fetch_input {
    my ($self) = @_;

    unless ( $self->param('cafe_tree_string') ) {
        die ('cafe_species_tree can not be found');
    }

    unless ( $self->param('cafe_table_file') ) {
        die ('cafe_table_file must be set');
    }

    my $nctree_Adaptor = $self->compara_dba->get_NCTreeAdaptor;
    $self->param('nctree_Adaptor', $nctree_Adaptor);

    # cafe_shell, mlss_id, cafe_lambdas and cafe_struct_tree_str are also defined parameters

    return;
}

sub run {
    my ($self) = @_;
    $self->run_cafe_script;
    $self->store_expansion_contraction;
}

sub write_output {
    my ($self) = @_;
    my $lambda = $self->param('lambda');
    $self->dataflow_output_id ( {
                                 'cafe_lambda' => $self->param('lambda'),
                                 'cafe_table_file' => $self->param('cafe_table_file'),
                                 'cafe_tree_string' => $self->param('cafe_tree_string'),
                                }, 3);

}

###########################################
## Internal methods #######################
###########################################

sub run_cafe_script {
    my ($self) = @_;

    my $mlss_id = $self->param('mlss_id');
    my $cafe_out_file = $self->worker_temp_directory() . "cafe_${mlss_id}.out";
    my $script_file = $self->worker_temp_directory() . "cafe_${mlss_id}.sh";
    open my $sf, ">", $script_file or die $!;
    print STDERR "Script file is [$script_file]\n" if ($self->debug());

    my $cafe_shell = $self->param('cafe_shell');
    my $cafe_tree_str = $self->param('cafe_tree_string');
    chop($cafe_tree_str); #remove final semicolon
    $cafe_tree_str =~ s/:\d+$//; # remove last branch length

    my $cafe_table_file = $self->param('cafe_table_file');
    my $cafe_lambdas = $self->param('cafe_lambdas');
    my $cafe_struct_tree = $self->param('cafe_struct_tree_str');

    print $sf '#!' . $cafe_shell . "\n\n";
    print $sf "tree $cafe_tree_str\n\n";
    print $sf "load -i $cafe_table_file\n\n";
    print $sf "lambda ";
    print $sf $cafe_lambdas ? "-l $cafe_lambdas -t $cafe_struct_tree\n\n" : " -s\n\n";
    print $sf "report $cafe_out_file\n\n";
    close ($sf);

    print STDERR "CAFE output in [$cafe_out_file]\n" if ($self->debug());

    $self->param('cafe_out_file', $cafe_out_file);

    chmod 0755, $script_file;

    $self->compara_dba->dbc->disconnect_when_inactive(0);
    unless ((my $err = system($script_file)) == 0) {
        print STDERR "CAFE returning error 4096\n";
#         for my $f (glob "$cafe_out_file*") {
#             system(`head $f >> /lustre/scratch101/ensembl/mp12/kkkk`);
#         }
        # It seems that CAFE doesn't exit with error code 0 never (usually 4096?)
#        $self->throw("problem running script $cafe_out_file: $err\n");
    }
    $self->compara_dba->dbc->disconnect_when_inactive(1);
    return;
}

sub store_expansion_contraction {
    my ($self) = @_;
    my $cafe_out_file = $self->param('cafe_out_file');
    my $nctree_Adaptor = $self->param('nctree_Adaptor');

    open my $fh, "<", $cafe_out_file.".cafe" or die $!;
#     my $tree_line = <$fh>;
#     my $lambda_line = <$fh>;
#     my $ids_line = <$fh>;

## WARNING: if the lambda tree is provided, 1 more line in the output file will be present.

    while (my $fam_line = <$fh>) {
        if ($fam_line =~ /^Lambda:\s(\d+\.\d+)/) {
            $self->param('lambda', $1);
            next;
        }
        next unless $fam_line =~ /^\d+/;
        chomp $fam_line;
        my @flds = split /\s+/, $fam_line;
        my ($node_id, $avg_expansion) = @flds[0,2];
        my $nc_tree = $nctree_Adaptor->fetch_node_by_node_id($node_id);
        $nc_tree->store_tag('average_expansion', $avg_expansion);
    }

    return;
}

1;
