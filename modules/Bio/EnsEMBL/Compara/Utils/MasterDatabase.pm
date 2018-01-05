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


1;
