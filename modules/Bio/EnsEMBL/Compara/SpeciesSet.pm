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

=head1 NAME

Bio::EnsEMBL::Compara::SpeciesSet

=head1 DESCRIPTION

Class to represent a set of GenomeDBs

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::SpeciesSet
  +- Bio::EnsEMBL::Compara::Taggable
  `- Bio::EnsEMBL::Storable

=head1 SYNOPSIS

Content of the set:
 - genome_dbs()

Others:
 - toString()

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=head1 METHODS


=cut

package Bio::EnsEMBL::Compara::SpeciesSet;

use strict;
use warnings;

use Scalar::Util qw(looks_like_number);

use Bio::EnsEMBL::Utils::Exception qw(warning deprecate throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Compara::GenomeDB;

use base (  'Bio::EnsEMBL::Compara::StorableWithReleaseHistory',           # inherit dbID(), adaptor() and new() methods, and first_release() and last_release()
            'Bio::EnsEMBL::Compara::Taggable'   # inherit everything related to tagability
         );


=head2 new

  Arg [..]   : Takes a set of named arguments
  Example    : my $my_species_set = Bio::EnsEMBL::Compara::SpeciesSet->new(
                                -dbID            => $species_set_id,
                                -genome_dbs      => [$gdb1, $gdb2, $gdb3 ],
                                -adaptor         => $species_set_adaptor );
  Description: Creates a new SpeciesSet object
  Returntype : Bio::EnsEMBL::Compara::SpeciesSet

=cut

sub new {
    my $caller = shift @_;
    my $class = ref($caller) || $caller;

    my $self = $class->SUPER::new(@_);  # deal with Storable stuff

    my ($genome_dbs, $name) = rearrange([qw(GENOME_DBS NAME)], @_);

    $self->genome_dbs($genome_dbs || []);
    $self->name($name) if (defined $name);

    return $self;
}


=head2 name

  Example     : my $name = $species_set->name();
  Example     : $species_set->name($name);
  Description : Getter/Setter for the name of the species set.
  Returntype  : String
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub name {
    my $self = shift;
    $self->{'_name'} = shift if @_;
    return $self->{'_name'} || '';
}


=head2 genome_dbs

  Arg [1]    : (opt.) list of genome_db objects
  Example    : my $genome_dbs = $species_set->genome_dbs();
  Example    : $species_set->genome_dbs( [$gdb1, $gdb2, $gdb3] );
  Description: Getter/Setter for the genome_dbs of this object in the database
  Returntype : arrayref genome_dbs
  Exceptions : none
  Caller     : general

=cut

sub genome_dbs {
    my ($self, $args) = @_;

    if ($args) {
        my $hashed_genome_dbs = {};
        foreach my $gdb (@$args) {
            throw("undefined value used as a Bio::EnsEMBL::Compara::GenomeDB\n") if (!defined($gdb));

            if(ref($gdb) eq 'HASH') {
                $gdb = Bio::EnsEMBL::Compara::GenomeDB->new( %$gdb ) or die "Could not automagically create a GenomeDB\n";

            } elsif (looks_like_number($gdb)) {
                # probably a genome_db_id
                $gdb = $self->adaptor->get_GenomeDBAdaptor->fetch_by_dbID($gdb) or die "Could not automagicallycreate a GenomeDB from '$gdb'\n";
            }

            my $hash_key = join('--', $gdb->name, $gdb->assembly, $gdb->genome_component || '' );
        
            if($hashed_genome_dbs->{ $hash_key }) {
                warn("GenomeDB with hash key '$hash_key' appears twice in this Bio::EnsEMBL::Compara::SpeciesSet(".($self->dbID ? 'dbID='.$self->dbID : 'no dbID').")\n");
            } else {
                $hashed_genome_dbs->{ $hash_key } = $gdb;
            }
        }

        $self->{'genome_dbs'} = [ values %{$hashed_genome_dbs} ] ;
    }
    return $self->{'genome_dbs'};
}


=head2 size

  Example     : my $size = $species_set->size();
  Description : Getter for the size of the species set.
  Returntype  : Integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub size {
    my $self = shift;
    return scalar(@{$self->genome_dbs});
}


=head2 toString

  Args       : (none)
  Example    : print $species_set->toString()."\n";
  Description: returns a stringified representation of the species_set
  Returntype : string

=cut

sub toString {
    my $self = shift;

    my $txt = sprintf('SpeciesSet dbID=%s', $self->dbID || '?');
    $txt .= ' ' . ($self->name ? sprintf('"%s"', $self->name) : '(unnamed)');
    if ($self->size <= 5) {
        $txt .= "', genome_dbs=[".join(', ', map { $_->name.'('.($_->dbID || '?').')'} sort {$a->dbID <=> $b->dbID} @{ $self->genome_dbs })."]";
    } else {
        $txt .= sprintf("', %d genome_dbs", $self->size);
    }
    $txt .= ' ' . $self->SUPER::toString();
    return $txt;
}


=head2 get_common_classification

  Example    : my $common_classification = $species_set->get_common_classification();
  Description: This method fetches the taxonomic classifications for all the species
               included in this species-set and returns the common part of them.
  Returntype : array-ref of strings
  Caller     : general

=cut

sub get_common_classification {
  my ($self) = @_;
  my $common_classification;

  foreach my $this_genome_db (@{$self->genome_dbs}) {
    my @classification = split(" ", $this_genome_db->taxon->classification);
    if (!defined($common_classification)) {
      @$common_classification = @classification;
    } else {
      my $new_common_classification = [];
      for (my $i = 0; $i <@classification; $i++) {
        for (my $j = 0; $j<@$common_classification; $j++) {
          if ($classification[$i] eq $common_classification->[$j]) {
            push(@$new_common_classification, splice(@$common_classification, $j, 1));
            last;
          }
        }
      }
      $common_classification = $new_common_classification;
    }
  }

  return $common_classification;
}



1;

