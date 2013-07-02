
=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::PrepareSpeciesSetsMLSS

=head1 DESCRIPTION

Used to create all the species set / MLSS objects needed for a gene-tree pipeline

 - the main MLSS of the pipeline
 - all the single-species paralogues MLSS
 - all the pairwise orthologues + paralogues MLSS
 - two empty species sets for reuse / nonreuse lists

If the master_db and mlss_id parameters, the Runnable will copy over the MLSS
from the master database. Otherwise, it will create new ones from the list of
all the species.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::PrepareSpeciesSetsMLSS;

use strict;

use Bio::EnsEMBL::Compara::SpeciesSet;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'tree_method_link'  => 'PROTEIN_TREES',
    };
}

sub fetch_input {
    my $self = shift @_;

    if(my $reference_db = $self->param('master_db')) {
        my $reference_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $reference_db );
        $self->param('reference_dba', $reference_dba);
        warn "Storing with a reference_db ($reference_db)\n" if($self->debug());
    } else {
        $self->param('reference_dba', undef);
        warn "Storing without a reference_db\n" if($self->debug());
    }

    if ($self->param('mlss_id')) {
        my $mlss_id = $self->param('mlss_id');
        my $mlss = $self->param('reference_dba')->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
        $self->param('genome_dbs', $mlss->species_set_obj->genome_dbs);
    } else {
        $self->param('genome_dbs', $self->compara_dba->get_GenomeDBAdaptor->fetch_all());
    }

    my $method_adaptor = $self->compara_dba->get_MethodAdaptor;
    $self->param('ml_ortho', $method_adaptor->fetch_by_type('ENSEMBL_ORTHOLOGUES'));
    $self->param('ml_para', $method_adaptor->fetch_by_type('ENSEMBL_PARALOGUES'));
    $self->param('ml_genetree', $method_adaptor->fetch_by_type($self->param('tree_method_link')));

}


sub write_output {
    my $self = shift;

    my $ss = $self->_write_ss($ self->param('genome_dbs') );
    my $mlss = $self->_write_mlss( $ss, $self->param('ml_genetree') );
    # Should be a pipeline-wide parameter
    $self->compara_dba->get_MetaContainer->store_key_value('mlss_id', $mlss->dbID);

    foreach my $genome_db1 (@{$self->param('genome_dbs')}) {
        my $ss1 = $self->_write_ss( [$genome_db1] );
        my $mlss_p1 = $self->_write_mlss( $ss1, $self->param('ml_para') );
        foreach my $genome_db2 (@{$self->param('genome_dbs')}) {
            next if $genome_db1->dbID >= $genome_db2->dbID;

            my $ss12 = $self->_write_ss( [$genome_db1, $genome_db2] );
            my $mlss_p12 = $self->_write_mlss( $ss12, $self->param('ml_para') );
            my $mlss_o12 = $self->_write_mlss( $ss12, $self->param('ml_ortho') );
        }
    }

    foreach my $ss_id (qw(reuse_ss_id nonreuse_ss_id)) {
        my $ss = Bio::EnsEMBL::Compara::SpeciesSet->new;
        $self->compara_dba->get_SpeciesSetAdaptor->store($ss);
        # Should be a pipeline-wide parameter
        $self->compara_dba->get_MetaContainer->store_key_value($ss_id, $ss->dbID);
    }
}

sub _write_ss {
    my ($self, $genome_dbs) = @_;

    my $ss;
    if ($self->param('reference_dba')) {
        $ss = $self->param('reference_dba')->get_SpeciesSetAdaptor->fetch_by_GenomeDBs($genome_dbs);
    }
    unless ($ss) {
        $ss = Bio::EnsEMBL::Compara::SpeciesSet->new( -genome_dbs => $genome_dbs );
    }
    $self->compara_dba->get_SpeciesSetAdaptor->store($ss);
    return $ss;
}


sub _write_mlss {
    my ($self, $ss, $method) = @_;

    my $mlss;
    if ($self->param('reference_dba')) {
        $mlss = $self->param('reference_dba')->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_id_species_set_id($method->dbID, $ss->dbID);
    }
    unless ($mlss) {
        $mlss = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new( -method => $method, -species_set_obj => $ss);
    }
    $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->store($mlss);
    return $mlss;
}


1;

