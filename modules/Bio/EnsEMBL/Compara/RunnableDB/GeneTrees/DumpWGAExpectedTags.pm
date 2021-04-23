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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpWGAExpectedTags

=head1 DESCRIPTION

Dumps 'wga_expected' tags to the specified TSV file and deletes them from the database.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpWGAExpectedTags;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;
   
    $self->dump_wga_expected();

    $self->delete_wga_expected();
}


sub dump_wga_expected {
    my $self = shift;

    my $dump_file = $self->param_required('wga_expected_file');
    open( my $fh_out, '>', $dump_file ) || die "Could not open output file $dump_file";
    print $fh_out "method_link_species_set_id\twga_expected\n";

    my $sql = "SELECT method_link_species_set_id, value FROM method_link_species_set_tag WHERE tag = 'wga_expected'";
    my $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute();
    while (my @row = $sth->fetchrow_array()) {
        print "Dumping mlss_id " . $row[0] . " wga_expected tag into $dump_file\n" if $self->debug;
        print $fh_out join("\t", @row) . "\n";
    }
    $sth->finish;
    close($fh_out);
}

sub delete_wga_expected {
	my $self = shift;

	print "Deleting wga_expected tag\n" if $self->debug;
	my $sql = "DELETE FROM method_link_species_set_tag WHERE tag = 'wga_expected'";
	$self->compara_dba->dbc->do($sql);
}

1;
