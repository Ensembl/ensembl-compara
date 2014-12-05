=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::PrepareSpeciesSetsMLSS

=head1 DESCRIPTION

Used to create all the species set / MLSS objects needed for a gene-tree pipeline

 - the main MLSS of the pipeline
 - all the single-species paralogues MLSS
 - all the pairwise orthologues MLSS
 - two empty species sets for reuse / nonreuse lists

If the master_db and mlss_id parameters, the Runnable will copy over the MLSS
from the master database. Otherwise, it will create new ones from the list of
all the species.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::PrepareSpeciesSetsMLSS;

use strict;
use Scalar::Util qw(looks_like_number);

use Bio::EnsEMBL::Compara::SpeciesSet;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'tree_method_link'  => 'PROTEIN_TREES',
        'reused_gdb_ids'    => [],
        'nonreused_gdb_ids' => [],
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
    $self->param('ml_homoeo', $method_adaptor->fetch_by_type('ENSEMBL_HOMOEOLOGUES'));
    $self->param('ml_genetree', $method_adaptor->fetch_by_type($self->param('tree_method_link')));

    my %homoeologous_groups = ();
    foreach my $i (1..(scalar(@{$self->param('homoeologous_genome_dbs')}))) {
        my $group = $self->param('homoeologous_genome_dbs')->[$i-1];
        foreach my $gdb (@{$group}) {
            if (looks_like_number($gdb)) {
                $homoeologous_groups{$gdb} = $i;
            } elsif (ref $gdb) {
                $homoeologous_groups{$gdb->dbID} = $i;
            } else {
                $gdb = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_name_assembly($gdb);
                $homoeologous_groups{$gdb->dbID} = $i;
            }
        }
    }
    $self->param('homoeologous_groups', \%homoeologous_groups);

}


sub write_output {
    my $self = shift;

    my $ss = $self->_write_ss($self->param('genome_dbs') );
    my $mlss = $self->_write_mlss( $ss, $self->param('ml_genetree') );
    my $homoeologous_genome_dbs_groups_aref = $self->param('homoeologous_genome_dbs');
    my $hive_pwp_adaptor = $self->db->get_PipelineWideParametersAdaptor;

    # Should be a pipeline-wide parameter
    $hive_pwp_adaptor->store( {'param_name' => 'mlss_id', 'param_value' => $mlss->dbID} );
    $hive_pwp_adaptor->store( {'param_name' => 'species_count', 'param_value' => scalar(@{$self->param('genome_dbs')})} );

    foreach my $genome_db1 (@{$self->param('genome_dbs')}) {
        my $ss1 = $self->_write_ss( [$genome_db1] );
        my $mlss_p1 = $self->_write_mlss( $ss1, $self->param('ml_para') );
        foreach my $genome_db2 (@{$self->param('genome_dbs')}) {
            next if $genome_db1->dbID >= $genome_db2->dbID;

            my $ss12 = $self->_write_ss( [$genome_db1, $genome_db2] );
            #my $mlss_p12 = $self->_write_mlss( $ss12, $self->param('ml_para') );
            my $mlss_o12 = $self->_write_mlss( $ss12, $self->param('ml_ortho') );
            if (($self->param('homoeologous_groups')->{$genome_db1->dbID} || -1) == ($self->param('homoeologous_groups')->{$genome_db2->dbID} || -2)) {
               my $mlss_h12 = $self->_write_mlss( $ss12, $self->param('ml_homoeo') );
           }
        }
    }

    my $gdb_a = $self->compara_dba->get_GenomeDBAdaptor;

    my @reuse_gdbs = map {$gdb_a->fetch_by_dbID($_)} @{$self->param('reused_gdb_ids')};
    my $reuse_ss = $self->_write_ss( \@reuse_gdbs );
    $hive_pwp_adaptor->store( {'param_name' => 'reuse_ss_id', 'param_value' => $reuse_ss->dbID} );
    $hive_pwp_adaptor->store( {'param_name' => 'reuse_ss_csv', 'param_value' => join(',', -1, @{$self->param('reused_gdb_ids')}) } );

    my @nonreuse_gdbs = map {$gdb_a->fetch_by_dbID($_)} @{$self->param('nonreused_gdb_ids')};
    my $nonreuse_ss = $self->_write_ss( \@nonreuse_gdbs );
    $hive_pwp_adaptor->store( {'param_name' => 'nonreuse_ss_id', 'param_value' => $nonreuse_ss->dbID} );
    $hive_pwp_adaptor->store( {'param_name' => 'nonreuse_ss_csv', 'param_value' => join(',', -1, @{$self->param('nonreused_gdb_ids')})} );
    # Whether all the species are reused
    $hive_pwp_adaptor->store( {'param_name' => 'are_all_species_reused', 'param_value' => (scalar(@nonreuse_gdbs) ? 0 : 1)} );
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

