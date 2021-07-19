=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ExtIndex::ENSEMBL_RETRIEVE;

### Class to retrieve sequences for given Ensembl ids

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use EnsEMBL::Web::Exceptions;

use parent qw(EnsEMBL::Web::ExtIndex);

sub get_sequence {
  ## @param Hashref with following keys:
  ##  - id          Id of the object
  ##  - translation Flag if on, will only return the linked translation sequences
  ##  - multi       Flag if on, will return all possible sequences (defaults to returning the longest sequence only)
  ## @exception If id is invalid or sequence could not be found.
  my ($self, $params) = @_;

  my $hub         = $self->hub;
  my $sd          = $hub->species_defs;
  my $sitetype    = $sd->ENSEMBL_SITETYPE;

  # invalid id
  throw exception('WebException', "No valid $sitetype ID provided.")              unless $params->{'id'};
  throw exception('WebException', "$params->{'id'} is not a valid $sitetype ID.") unless $params->{'id'} =~ /^[a-z0-9_\.\-]+$/i;

  my $registry    = 'Bio::EnsEMBL::Registry';
  my $stable_id   = sprintf '%s%011d', split(/(?=[0-9])/, $params->{'id'}, 2); # prefix '0's before the number part if it's less than 11 digits
  my $trans_only  = $params->{'translation'};

  # get species name etc from stable id
  my ($species, $object_type, $db_type) = $registry->get_species_and_object_type($stable_id);

  my @seqs;

  if ($species) { # current release stable id

    if (my $object = $registry->get_adaptor($species, $db_type, $object_type)->fetch_by_stable_id($stable_id)) {

      my @trans;

      if ($object->isa('Bio::EnsEMBL::Gene')) {

        if ($trans_only) {
          @trans = map { $_->translation || () } @{$object->get_all_Transcripts};
        } else {
          @seqs = {
            'id'          => $object->stable_id,
            'sequence'    => $object->seq,
            'description' => sprintf('%s %s Gene %s', $object->display_id, $sitetype, $object->seqname),
            'length'      => $object->length
          };
        }

      } elsif ($object->isa('Bio::EnsEMBL::Transcript')) {

        if ($trans_only) {
          @trans = $object->translation || ();
        } else {
          @seqs = {
            'id'          => $object->stable_id,
            'sequence'    => $object->seq->seq,
            'description' => sprintf('%s %s Transcript %s', $object->version ? $object->display_id . "." . $object->version : $object->display_id, $sitetype, $object->seqname),
            'length'      => $object->length
          };
        }

      } elsif ($object->isa('Bio::EnsEMBL::Translation')) {
        @trans = $object;
      }

      @seqs = map {
        'id'          => $_->stable_id,
        'sequence'    => $_->seq,
        'description' => sprintf('%s %s Translation', $_->display_id, $sitetype),
        'length'      => $_->length
      }, @trans if @trans;

    }

    # throw error if no sequence found for the given stable id
    throw exception('WebException', sprintf 'No sequence found for %s with stable id %s', lc $object_type, $stable_id) unless @seqs;

  } else { # not a current release stable id? try for archive stable id for each species

    my %checked_species;

    for ($hub->species, @{$hub->get_favourite_species}, $sd->ENSEMBL_PRIMARY_SPECIES || (), $sd->ENSEMBL_SECONDARY_SPECIES || (), $sd->valid_species) { # try important species first

      if (!$checked_species{$_} && (my $object = $registry->get_adaptor($_, 'Core', 'ArchiveStableId')->fetch_by_stable_id($stable_id))) {

        # get translations from recent release
        my $recent_release = 0;
        for (@{$object->get_all_translation_archive_ids}) {
          my $release = $_->release;
          if ($release >= $recent_release) {
            if ($release > $recent_release) {
              $recent_release = $release;
              @seqs = ();
            }
            my $seq = $_->get_peptide;
            my $id  = $_->stable_id;
            push @seqs, {
              'id'          => $id,
              'sequence'    => $seq,
              'length'      => length($seq),
              'description' => sprintf('%s %s Archive Translation', $id, $sitetype),
            };
          }
        }

        # if no seq found for this valid archive stable id
        throw exception('WebException', sprintf 'No sequence found for %s with archive stable id %s', lc $object->type, $stable_id) unless @seqs;

        last;
      }
      $checked_species{$_} = 1;
    }
  }

  # throw error if no sequence retrieved
  throw exception('WebException', sprintf 'Could not find any sequence corresponding to id %s', $params->{'id'}) unless @seqs;

  @seqs = sort { $b->{'length'} <=> $a->{'length'} } @seqs;
  @seqs = ($seqs[0]) unless $params->{'mutli'};

  # create fasta format sequence
  for (@seqs) {
    my $fasta = [ sprintf '>%s', delete $_->{'description'} ];
    push @$fasta, $1 while $_->{'sequence'} =~ m/(.{1,60})/g;
    $_->{'sequence'} = join "\n", @$fasta;
  }

  return wantarray ? @seqs : $seqs[0];
}

1;
