=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::FindMLSS

=head1 DESCRIPTION

This Runnable finds the MLSSs associated with the queried species-set. It is used
to match a pipeline with its mates when we need to combine data from all of them.

Parameters:
 - master_db: location of the master database.

 # Here are multiple ways of defining a species-set 
 - species_set_id:
 - mlss_id:
 - species_set_name:

 - method_links: hash that maps method_link types to variable names. The Runnable
                 will find the MLSSs that match each method_link and the species-set
                 and store their "content" in the variables
 - content: string. either "url" (default) or "mlss_id"

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FindMLSS;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::DBSQL::DBConnection;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'content'   => 'url',
    }
}


sub fetch_input {
    my $self = shift @_;

    my $master_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $self->param_required('master_db') );
    $self->param('master_dba', $master_dba);

    my $species_set_id = $self->param('species_set_id');

    if ($species_set_id) {
        my $species_set = $master_dba->get_SpeciesSetAdaptor->fetch_by_dbID($species_set_id)
            or die "Could not find the species-set dbID=$species_set_id in the master database\n";
    }

    # FIXME: there can be multiple species sets with the same name !
    if (not $species_set_id and (my $species_set_name = $self->param('species_set_name'))) {
        my $ss = (grep {$_->is_current} @{$master_dba->get_SpeciesSetAdaptor->fetch_all_by_name($species_set_name)})[0]
            or die "Could not find the collection named '$species_set_name' in the master database\n";
        $species_set_id = $ss->dbID;
    }

    if (not $species_set_id and (my $mlss_id = $self->param('mlss_id'))) {
        my $mlss = $master_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id)
            or die "Could not find the MLSS dbID=$mlss_id in the master database\n";
        $species_set_id = $mlss->species_set_obj->dbID;
    }

    if ($species_set_id) {
        warn "Found the species-set dbID=$species_set_id\n" if $self->debug;
    } else {
        die "It was not possible to identify a species-set. Tried 'species_set_id', 'mlss_id', and 'species_set_name'\n";
    }

    $self->param('species_set_id', $species_set_id);
}

sub run {
    my $self = shift @_;

    my $method_links = $self->param('method_links');
    my $species_set_id = $self->param('species_set_id');
    my $master_dba = $self->param('master_dba');
    my $content_method = { 'url' => 'url', 'mlss_id' => 'dbID', 'dbid' => 'dbID' }->{lc $self->param_required('content')};

    my @pwp = ();
    foreach my $ml_type (keys %$method_links) {

        my $ml = $master_dba->get_MethodAdaptor->fetch_by_type($ml_type)
            or die "Could not find the method '$ml_type' in the master database\n";
        my $mlss = $master_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_id_species_set_id($ml->dbID, $species_set_id)
            or die "Could not find a MLSS with the method '$ml_type' and the species_set dbID=$species_set_id\n";

        my $variable = $method_links->{$ml_type};
        my $content = $mlss->$content_method();
        warn "Found MLSS dbID=".$mlss->dbID." for the method '$ml_type' -> Going to store '$content' in '$variable'\n" if $self->debug;
        push @pwp, {'param_name' => $variable, 'param_value' => $content};
    }
    $self->param('pwp', \@pwp);

}

sub write_output {
    my $self = shift @_;

    $self->db->get_PipelineWideParametersAdaptor->store( $self->param('pwp') );
}

1;

