=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Compara::Production::DBSQL::AnchorSeqAdaptor;

use strict;
use warnings;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


sub store {
  my ($self, @args) = @_;
  my ($anchor_id, $dnafrag_id, $start, $end, $strand, $mlssid, $sequence) = 
	rearrange([qw(ANCHOR_ID DNAFRAG_ID START END STRAND MLSSID SEQUENCE LENGTH)], @args);

  my $length = length($sequence);

print join(":", $anchor_id, $dnafrag_id, $start, $end, $strand, $mlssid, $sequence,$length), "\n";
  my $sth = $self->prepare("INSERT INTO anchor_sequence (sequence, 
	length, dnafrag_id, start, end, strand, anchor_id, method_link_species_set_id) VALUES (?,?,?,?,?,?,?,?)");	  
  $sth->execute($sequence, $length, $dnafrag_id, $start, $end, $strand, $anchor_id, $mlssid);
  $sth->finish;
}

1;

