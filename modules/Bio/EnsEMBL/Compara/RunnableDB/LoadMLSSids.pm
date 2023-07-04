=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::LoadMLSSids

=head1 DESCRIPTION

Fetches for the MLSS id that matches the given method type, species set name and
release number, as well as its previous MLSS id (--add_prev_mlss) and its sister
MLSS ids (--add_sister_mlss). If a branch code is provided, the MLSS id(s) are
flowed into that branch. If not, they are added as pipeline-wide parameters
(default behaviour). The main MLSS id is saved under "mlss_id" key, except for
EPO Extended, where the main MLSS id is saved under "ext_mlss_id" instead. See
'--add_prev_mlss' and '--add_sister_mlsss' flags for more information.

=over

=item master_db

Mandatory. URL or alias of the Compara master database. If an alias is given,
'--reg_conf' parameter will be required as well.

=item method_type

Mandatory. Method type.

=item species_set_name

Mandatory. Species set name.

=item release

Mandatory. Release to use as current.

=item add_prev_mlss

Optional. Also fetch the previous MLSS id of the same method type and species
set name and return it under "prev_mlss_id" key. By default, do not fetch it.

=item add_sister_mlsss

Optional. Also fetch the sister MLSS ids of the main MLSS:
 - If method_type is EPO, fetch the EPO Extended MLSS id and its related GERP
   MLSS ids and return them under "ext_mlss_id", "ce_mlss_id" and "cs_mlss_id"
   keys, respectively
 - If method_type is EPO_EXTENDED, fetch its related GERP MLSS ids and the EPO
   MLSS id and return them under "ce_mlss_id", "cs_mlss_id" and "mlss_id" keys,
   respectively
 - If method_type is PECAN, fetch the GERP MLSS ids and return them under
   "ce_mlss_id" and "cs_mlss_id" keys
By default, do not fetch them.

=item use_prev_epo_ext

Optional. If method_type is EPO_EXTENDED and add_sister_mlsss is requested,
return the previous EPO Extended MLSS id as "mlss_id" instead of its related EPO
MLSS id.

=item branch_code

Optional. Flow the MLSS id(s) into the given branch instead of saving them as
pipeline-wide parameters. By default, save the MLSS id(s) as pipeline-wide
parameters.

=back

=head1 EXAMPLES

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::LoadMLSSids \
        --reg_conf $COMPARA_REG_PATH --master_db compara_master \
        --method_type EPO --species_set_name mammals --release $CURR_ENSEMBL_RELEASE

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::LoadMLSSids \
        --master_db $(cp1 details url ensembl_compara_master) \
        --method_type EPO --species_set_name sauropsids --release 101 \
        --add_prev_mlss 1 --add_sister_mlsss 1 --branch_code 2

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::LoadMLSSids \
        --master_db $(cp1 details url ensembl_compara_master) \
        --method_type EPO_EXTENDED --species_set_name sauropsids --release 101 \
        --add_sister_mlsss 1 --use_prev_epo_ext 1 --branch_code 2

=cut

package Bio::EnsEMBL::Compara::RunnableDB::LoadMLSSids;

use warnings;
use strict;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    my $self = shift;

    return {
        %{$self->SUPER::param_defaults},

        'add_prev_mlss'     => 0,
        'add_sister_mlsss'  => 0,
        'use_prev_epo_ext'  => 0,
        'branch_code'       => undef,
    }
}


sub fetch_input {
    my $self = shift;
    my $master_dba = $self->get_cached_compara_dba('master_db');
    my $release = $self->param_required('release');
    my $method_type = $self->param_required('method_type');
    my $species_set_name = $self->param_required('species_set_name');
    my $use_prev_epo_ext = $self->param('use_prev_epo_ext') && ($method_type =~ /^EPO_EXTENDED$/i) && $self->param('add_sister_mlsss');

    my %mlss_ids;
    my $mlss_adaptor = $master_dba->get_MethodLinkSpeciesSetAdaptor;
    # First, fetch all the MLSSs that match the given method type and species set name (allowing the
    # "collection-" prefix for the species set name)
    my @mlsss = grep { $_->species_set->name =~ /^(collection-)?$species_set_name$/ }
        @{ $mlss_adaptor->fetch_all_by_method_link_type($method_type) };
    $self->throw("No MLSSs found for method '$method_type' and species set '$species_set_name'") unless @mlsss;

    # Fetch the "current" MLSS id (for the given release number)
    my @curr_mlss = grep { $_->is_in_release($release) } @mlsss;
    $self->throw("No MLSS found for method '$method_type' and species set '$species_set_name' in release $release") unless @curr_mlss;
    my $mlss = $curr_mlss[0];
    $mlss_ids{mlss_id} = $mlss->dbID;
    $mlss_ids{ext_mlss_id} = $mlss->dbID if $method_type =~ /^EPO_EXTENDED$/i;

    my @prev_mlss;
    if ( $self->param('add_prev_mlss') || $use_prev_epo_ext ) {
        # Fetch the previous MLSS id
        my $prev_release = $mlss->first_release - 1;
        @prev_mlss = grep { (defined $_->last_release) && ($_->last_release == $prev_release) } @mlsss;
        $self->throw(sprintf("No previous MLSS found for MLSS '%s' (%s)", $mlss->name, $mlss->dbID)) unless @prev_mlss;
        $mlss_ids{prev_mlss_id} = $prev_mlss[0]->dbID if $self->param('add_prev_mlss');
    }

    if ( $self->param('add_sister_mlsss') ) {
        if ( $method_type =~ /^EPO/i ) {
            my $is_epo = $method_type =~ /^EPO$/i;
            my @linked_mlss;
            if ($use_prev_epo_ext) {
                @linked_mlss = @prev_mlss;
            } else {
                # Fetch the linked MLSS id
                my $linked_method_type = $is_epo ? 'EPO_EXTENDED' : 'EPO';
                @linked_mlss = grep { ($_->species_set->name =~ /^(collection-)?$species_set_name$/ ) && $_->is_in_release($release) }
                    @{ $mlss_adaptor->fetch_all_by_method_link_type($linked_method_type) };
                $self->throw(sprintf("No %s MLSS found for MLSS '%s' (%s)", $linked_method_type, $mlss->name, $mlss->dbID)) unless @linked_mlss;
            }
            # Assign the EPO MLSS id to mlss_id and EPO Extended MLSS id to ext_mlss_id
            if ($is_epo) {
                $mlss_ids{ext_mlss_id} = $linked_mlss[0]->dbID;
                # The GERP MLSSs are linked to the EPO Extended MLSS, not the EPO MLSS
                $mlss = $linked_mlss[0];
            } else {
                $mlss_ids{ext_mlss_id} = $mlss_ids{mlss_id};
                $mlss_ids{mlss_id}     = $linked_mlss[0]->dbID;
            }
        }

        if ( $method_type =~ /^(EPO|EPO_EXTENDED|PECAN)$/i ) {
            # Fetch the GERP MLSS ids (constrained element and conservation score)
            my $ce_mlss = $mlss->get_all_sister_mlss_by_class('ConstrainedElement.constrained_element');
            if (@$ce_mlss) {
                $mlss_ids{ce_mlss_id} = $ce_mlss->[0]->dbID;
            } else {
                $self->warning(sprintf("No Constrained Element MLSS found for MLSS '%s' (%s)\n", $mlss->name, $mlss->dbID));
            }
            my $cs_mlss = $mlss->get_all_sister_mlss_by_class('ConservationScore.conservation_score');
            if (@$cs_mlss) {
                $mlss_ids{cs_mlss_id} = $cs_mlss->[0]->dbID;
            } else {
                $self->warning(sprintf("No Conservation Score MLSS found for MLSS '%s' (%s)\n", $mlss->name, $mlss->dbID));
            }
        }
    }

    $self->param('mlss_ids', \%mlss_ids);
}


sub write_output {
    my $self = shift;
    my $mlss_ids = $self->param('mlss_ids');

    if ( defined $self->param('branch_code') ) {
        $self->dataflow_output_id($mlss_ids, $self->param('branch_code'));
    } else {
        foreach my $param_name ( keys %$mlss_ids ) {
            $self->add_or_update_pipeline_wide_parameter($param_name, $mlss_ids->{$param_name});
        }
    }
}


1;
