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

=head1 NAME

Bio::EnsEMBL::Compara::Production::EPOanchors::AnchorAlign

=head1 CONTACT

Ensembl-dev mailing list <http://lists.ensembl.org/mailman/listinfo/dev>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::EPOanchors::AnchorAlign;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Compara::DnaFrag;

use base qw(Bio::EnsEMBL::Compara::Locus Bio::EnsEMBL::Storable);


sub new {
    my($class, @args) = @_;

    my $self = $class->SUPER::new(@args);       # deal with Storable stuff

    ## First line is for backward compatibility with an old schema
    ## last is are for the new schema
    my ($method_link_species_set, $method_link_species_set_id, $anchor_id,
        $score, $num_of_organisms, $num_of_sequences, $evalue, $anchor_status) =
      rearrange([qw(
          METHOD_LINK_SPECIES_SET METHOD_LINK_SPECIES_SET_ID ANCHOR_ID
          SCORE NUM_OF_ORGANISMS NUM_OF_SEQUENCES EVALUE ANCHOR_STATUS)], @args);

    $self->method_link_species_set($method_link_species_set) if (defined($method_link_species_set));
    $self->method_link_species_set_id($method_link_species_set_id) if (defined($method_link_species_set_id));
    $self->anchor_id($anchor_id) if (defined($anchor_id));
    $self->score($score) if (defined($score));
    $self->num_of_organisms($num_of_organisms) if (defined($num_of_organisms));
    $self->num_of_sequences($num_of_sequences) if (defined($num_of_sequences));
    $self->evalue($evalue) if (defined($evalue));
    $self->anchor_status($anchor_status) if (defined($anchor_status));
    return $self;
}

sub method_link_species_set {
  my $self = shift;
  if (@_) {
    $self->{_method_link_species_set} = shift;
  }
  return $self->{_method_link_species_set};
}

sub method_link_species_set_id {
  my $self = shift;
  if (@_) {
    $self->{_method_link_species_set_id} = shift;
  }
  if (!defined($self->{_method_link_species_set_id}) and defined($self->{_method_link_species_set})) {
    $self->{_method_link_species_set_id} = $self->{_method_link_species_set}->dbID;
  }
  return $self->{_method_link_species_set_id};
}

sub anchor_id {
  my $self = shift;
  if (@_) {
    $self->{_anchor_id} = shift;
  }
  return $self->{_anchor_id};
}

sub evalue {
  my $self = shift;
  if (@_) {
    $self->{_evalue} = shift;
  }
  return $self->{_evalue};
}

sub score {
  my $self = shift;
  if (@_) {
    $self->{_score} = shift;
  }
  return $self->{_score};
}

sub num_of_organisms {
  my $self = shift;
  if (@_) {
    $self->{_num_of_organisms} = shift;
  }
  return $self->{_num_of_organisms};
}

sub num_of_sequences {
  my $self = shift;
  if (@_) {
    $self->{_num_of_sequences} = shift;
  }
  return $self->{_num_of_sequences};
}

sub anchor_status {
  my $self = shift;
  if (@_) {
	$self->{_anchor_status} = shift;
  }
  return $self->{_anchor_status};
}

sub seq {
  my $self = shift;
  return $self->{'_seq'} if ($self->{'_seq'});

  my $seq = $self->get_Slice()->seq;
  $self->{'_seq'} = $seq;

  return $self->{'_seq'};
}

1;
