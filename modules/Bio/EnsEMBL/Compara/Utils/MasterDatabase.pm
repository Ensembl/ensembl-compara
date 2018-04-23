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

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This modules contains common methods used when dealing with the
Compara master database. They can in fact be called on other
databases too.

- update_dnafrags: updates the DnaFrags of a species

=head1 METHODS

=cut

package Bio::EnsEMBL::Compara::Utils::MasterDatabase;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Method;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;


=head2 update_dnafrags

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Arg[3]      : Bio::EnsEMBL::DBSQL::DBAdaptor $species_dba
  Description : This method fetches all the dnafrag in the compara DB
                corresponding to the $genome_db. It also gets the list
                of top_level seq_regions from the species core DB and
                updates the list of dnafrags in the compara DB.
  Returns     : -none-
  Exceptions  :

=cut

sub update_dnafrags {
    my ($compara_dba, $genome_db, $species_dba) = @_;

    $species_dba //= $genome_db->db_adaptor;
    my $dnafrag_adaptor = $compara_dba->get_adaptor('DnaFrag');
    my $old_dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB_region($genome_db);
    my $old_dnafrags_by_name;
    foreach my $old_dnafrag (@$old_dnafrags) {
        $old_dnafrags_by_name->{$old_dnafrag->name} = $old_dnafrag;
    }

    my $gdb_slices = $genome_db->genome_component
        ? $species_dba->get_SliceAdaptor->fetch_all_by_genome_component($genome_db->genome_component)
        : $species_dba->get_SliceAdaptor->fetch_all('toplevel', undef, 1, 1, 1);
    die 'Could not fetch any toplevel slices from '.$genome_db->name() unless(scalar(@$gdb_slices));

    my $new_dnafrags_ids = 0;
    my $existing_dnafrags_ids = 0;
    foreach my $slice (@$gdb_slices) {

        my $new_dnafrag = Bio::EnsEMBL::Compara::DnaFrag->new_from_Slice($slice, $genome_db);


        if (my $old_df = delete $old_dnafrags_by_name->{$slice->seq_region_name}) {
            $new_dnafrag->dbID($old_df->dbID);
            $dnafrag_adaptor->update($new_dnafrag);
            $existing_dnafrags_ids++;

        } else {
            $dnafrag_adaptor->store($new_dnafrag);
            $new_dnafrags_ids++;
        }
    }
    print "$existing_dnafrags_ids DnaFrags already in the database. Inserted $new_dnafrags_ids new DnaFrags.\n";

    if (keys %$old_dnafrags_by_name) {
        print 'Now deleting ', scalar(keys %$old_dnafrags_by_name), ' former DnaFrags...';
        my $sth = $compara_dba->dbc->prepare('DELETE FROM dnafrag WHERE dnafrag_id = ?');
        foreach my $deprecated_dnafrag (values %$old_dnafrags_by_name) {
            $sth->execute($deprecated_dnafrag->dbID);
        }
        print "  ok!\n\n";
    }
}


sub create_species_set {
    my ($genome_dbs, $species_set_name) = @_;
    $species_set_name ||= join('-', sort map {$_->get_short_name} @{$genome_dbs});
    return Bio::EnsEMBL::Compara::SpeciesSet->new(
        -GENOME_DBS => $genome_dbs,
        -NAME => $species_set_name,
    );
}

sub _get_species_set_display_name {
    my ($species_set) = @_;
    my $ss_name = $species_set->name;
    $ss_name =~ s/collection-//;
    return $ss_name;
}

sub create_mlss {
    my ($method, $species_set, $mlss_name, $ss_display_name, $source, $url) = @_;
    if (ref($species_set) eq 'ARRAY') {
        $species_set = create_species_set($species_set);
    }
    $ss_display_name ||= _get_species_set_display_name($species_set);
    $mlss_name ||= sprintf('%s %s', $ss_display_name, lc $Bio::EnsEMBL::Compara::Method::PLAIN_TEXT_DESCRIPTIONS{$method->type} || die "No description for ".$method->type);
    return Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
        -SPECIES_SET => $species_set,
        -METHOD => $method,
        -NAME => $mlss_name,
        -SOURCE => $source,
        -URL => $url,
    );
}

sub create_mlsss_on_singletons {
    my ($method, $genome_dbs) = @_;
    return [map {create_mlss($method, [$_])} @$genome_dbs];
}

sub create_mlsss_on_pairs {
    my ($method, $genome_dbs, $source, $url) = @_;
    my @mlsss;
    my @input_genome_dbs = @$genome_dbs;
    while (my $gdb1 = shift @input_genome_dbs) {
        foreach my $gdb2 (@input_genome_dbs) {
            push @mlsss, create_mlss($method, [$gdb1, $gdb2], undef, undef, $source, $url);
        }
    }
    return \@mlsss;
}

sub create_self_wga_mlss {
    my ($method, $gdb) = @_;
    my $method_display_name = lc $method->type;
    $method_display_name =~ tr/_/-/;
    my $species_set = create_species_set([$gdb]);
    my $mlss_name = sprintf('%s self-%s', $gdb->get_short_name, $method_display_name);
    return create_mlss($method, $species_set, $mlss_name);
}

sub create_pairwise_wga_mlss {
    my ($compara_dba, $method, $ref_gdb, $nonref_gdb) = @_;
    my @mlsss;
    my $method_display_name = lc $method->type;
    $method_display_name =~ tr/_/-/;
    my $species_set = create_species_set([$ref_gdb, $nonref_gdb]);
    my $mlss_name = sprintf('%s %s (on %s)', $species_set->name, $method_display_name, $ref_gdb->get_short_name);
    push @mlsss, create_mlss($method, $species_set, $mlss_name);
    if ($ref_gdb->has_karyotype and $nonref_gdb->has_karyotype) {
        my $synt_method = $compara_dba->get_MethodAdaptor->fetch_by_type('SYNTENY');
        push @mlsss, create_mlss($synt_method, $species_set);
    }
    return \@mlsss;
}

sub create_multiple_wga_mlss {
    my ($compara_dba, $method, $species_set, $ss_display_name, $with_gerp, $source, $url) = @_;
    my @mlsss;
    my $ss_size = scalar(@{$species_set->genome_dbs});
    $ss_display_name ||= _get_species_set_display_name($species_set);
    my $mlss_name = sprintf('%d %s %s', $ss_size, $ss_display_name, $Bio::EnsEMBL::Compara::Method::PLAIN_TEXT_DESCRIPTIONS{$method->type});
    push @mlsss, create_mlss($method, $species_set, $mlss_name);
    if ($with_gerp) {
        my $ce_method = $compara_dba->get_MethodAdaptor->fetch_by_type('GERP_CONSTRAINED_ELEMENT');
        $mlss_name = sprintf('Gerp Constrained Elements (%d %s)', $ss_size, $ss_display_name);
        push @mlsss, create_mlss($ce_method, $species_set, $mlss_name);
        my $cs_method = $compara_dba->get_MethodAdaptor->fetch_by_type('GERP_CONSERVATION_SCORE');
        $mlss_name = sprintf('Gerp Conservation Scores (%d %s)', $ss_size, $ss_display_name);
        push @mlsss, create_mlss($cs_method, $species_set, $mlss_name);
    }
    if ($method->type eq 'CACTUS_HAL') {
        my $pw_method = $compara_dba->get_MethodAdaptor->fetch_by_type('CACTUS_HAL_PW');
        push @mlsss, @{ create_mlsss_on_pairs($pw_method, $species_set->genome_dbs, $source, $url) };
    }
    return \@mlsss;
}

sub create_assembly_patch_mlsss {
    my ($compara_dba, $genome_db) = @_;
    my $species_set = create_species_set([$genome_db]);
    my @mlsss;
    {
        my $method = $compara_dba->get_MethodAdaptor->fetch_by_type('LASTZ_PATCH');
        my $mlss_name = sprintf('%s lastz-patch', $species_set->name);
        push @mlsss, create_mlss($method, $species_set, $mlss_name);
    }
    {
        my $method = $compara_dba->get_MethodAdaptor->fetch_by_type('ENSEMBL_PROJECTIONS');
        my $mlss_name = sprintf('%s patch projections', $species_set->name);
        push @mlsss, create_mlss($method, $species_set, $mlss_name);
    }
    return \@mlsss,
}

sub create_homology_mlsss {
    my ($compara_dba, $method, $species_set, $ss_display_name) = @_;
    my @mlsss;
    push @mlsss, create_mlss($method, $species_set, undef, $ss_display_name);
    if (($method->type eq 'PROTEIN_TREES') or ($method->type eq 'NC_TREES')) {
        my $orth_method = $compara_dba->get_MethodAdaptor->fetch_by_type('ENSEMBL_ORTHOLOGUES');
        push @mlsss, @{ create_mlsss_on_pairs($orth_method, $species_set->genome_dbs) };
        my $para_method = $compara_dba->get_MethodAdaptor->fetch_by_type('ENSEMBL_PARALOGUES');
        push @mlsss, @{ create_mlsss_on_singletons($para_method, $species_set->genome_dbs) };
    }
    return \@mlsss;
}


1;
