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

package Bio::EnsEMBL::ExternalData::DAS::CoordSystem;

use Bio::EnsEMBL::Utils::Argument  qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);

# This object does NOT inherit from Bio::EnsEMBL::CoordSystem, because DAS
# coordinate systems are not storable.

=head2 new

  Arg [..]   : List of named arguments:
               -NAME      - The name of the coordinate system
               -VERSION   - (optional) The version of the coordinate system.
                            Note that if the version passed in is undefined,
                            it will be set to the empty string in the
                            resulting CoordSystem object.
               -SPECIES   - (optional) For species-specific systems
               -LABEL     - (optional) A human-readable label
  Example    : $cs = Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new(
                 -NAME    => 'chromosome',
                 -VERSION => 'NCBI33',
                 -SPECIES => 'Homo_sapiens',
               );
  Description: Creates a new CoordSystem object representing a coordinate
               system.
  Returntype : Bio::EnsEMBL::ExternalData::DAS::CoordSystem
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub new {
  my $caller = shift;
  my $class = ref($caller) || $caller;
  my ($name, $version, $species, $label) = rearrange(['NAME','VERSION','SPECIES','LABEL'], @_);

  $name    || throw('The NAME argument is required');
  $version ||= '';
  $species ||= '';
  
  if (!$label) {
    $label = join ' ', map { ucfirst $_ } grep { $_ } (split /_/, $name), $version;
  }
  
  my $self = {
              'name'    => $name,
              'version' => $version,
              'species' => $species,
              'label'   => $label,
             };
  bless $self, $class;

  return $self;
}


=head2 new_from_hashref

  Arg [1]    : Hash reference containing:
               name     - The name of the coordinate system
               version  - (optional) The version of the coordinate system.
                            Note that if the version passed in is undefined,
                            it will be set to the empty string in the
                            resulting CoordSystem object.
               species  - (optional) For species-specific systems
               label    - (optional) A human-readable label
  Example    : $cs = Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( {
                 name    => 'chromosome',
                 version => 'NCBI33',
                 species => 'Homo_sapiens',
               } );
  Description: Creates a new CoordSystem object representing a coordinate
               system.
  Returntype : Bio::EnsEMBL::ExternalData::DAS::CoordSystem
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub new_from_hashref {
  my $caller = shift;
  my $hash   = shift;
  my $class  = ref($caller) || $caller;
  
  return $class->new( -name    => $hash->{'name'},
                      -version => $hash->{'version'},
                      -species => $hash->{'species'},
                      -label   => $hash->{'label'});
}


=head2 new_from_string

  Arg [1]    : String containing the following fields, joined by a ":"
               name     - The name of the coordinate system
               version  - (optional) The version of the coordinate system.
                            Note that if the version passed in is undefined,
                            it will be set to the empty string in the
                            resulting CoordSystem object.
               species  - (optional) For species-specific systems
               label    - (optional) A human-readable label
  Example    : $cs = Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new(
                 'chromosome:NCBI33:Homo_sapiens'
               );
               $cs = Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new(
                 'ensembl_gene'
               );
  Description: Creates a new CoordSystem object representing a coordinate
               system.
  Returntype : Bio::EnsEMBL::ExternalData::DAS::CoordSystem
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub new_from_string {
  my $caller = shift;
  my $string = shift;
  my $class  = ref($caller) || $caller;

  my ($name, $version, $species, $label) = split /:/, $string, 4;
  return $class->new( -name    => $name,
                      -version => $version,
                      -species => $species,
                      -label   => $label);
}


=head2 name

  Arg [1]    : (optional) string $name
  Example    : print $coord_system->name();
  Description: Getter for the name of this coordinate system
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub name {
  my $self = shift;
  return $self->{'name'};
}

=head2 version

  Arg [1]    : none
  Example    : print $coord->version();
  Description: Getter for the version of this coordinate system.  This
               will return an empty string if no version is defined for this
               coordinate system.
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub version {
  my $self = shift;
  return $self->{'version'};
}


=head2 species

  Arg [1]    : none
  Example    : print $coord->species();
  Description: Getter for the species of this coordinate system.  This
               will return an empty string if no species is defined for this
               coordinate system (i.e. it is not species-specific).
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub species {
  my $self = shift;
  return $self->{'species'};
}


=head2 label

  Arg [1]    : none
  Example    : print $coord->label();
  Description: Getter for the display label of this coordinate system.
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub label {
  my $self = shift;
  return $self->{'label'};
}


=head to_string

  Args       : none
  Example    : print $coord->to_string();
  Description: Converts the source into a string form, suitable for the
               new_from_string constructor.
  Returntype : string
  Exceptions : none
  Caller     : web code
  Status     : At risk

=cut

sub to_string {
  my $self = shift;
  return join ':', $self->name, $self->version, $self->species, $self->label;
}


=head2 equals

  Arg [1]    : Bio::EnsEMBL::ExternalData::DAS::CoordSystem
               The coord system to compare to for equality.
  Example    : if($coord_sys->equals($other_coord_sys)) { ... }
  Description: Compares 2 coordinate systems and returns true if they are
               equivalent.  The definition of equivalent is sharing the same
               name and version, and being species compatible (see the
               matches_species method.
  Returntype : 0 or 1
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub equals {
  my $self = shift;
  my $cs = shift;

  unless ( $cs && ref($cs) &&
          ( $cs->isa('Bio::EnsEMBL::ExternalData::DAS::CoordSystem') ||
            $cs->isa('Bio::EnsEMBL::CoordSystem') ) ) {
    throw('Argument must be a CoordSystem');
  }
  
  return ( $self->{'version'} eq $cs->version() &&
           $self->{'name'}    eq $cs->name()    &&
           $self->matches_species( $cs->species ) ) ? 1 : 0;
}


=head2 matches_species

  Arg [1]    : Species string
  Example    : if ( $coord_sys->matches_species( 'Homo_sapiens' ) ) { ... }
  Description: Determines whether the CoordSystem supports a given species. Will
               return if the coordinate system is not species-specific, or is
               specific to the given species.
  Returntype : 1 or 0
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub matches_species {
  my ($self, $species) = @_;
  if ( !$species || !$self->species || $self->species eq $species ) {
    return 1;
  }
  return 0;
}

1;