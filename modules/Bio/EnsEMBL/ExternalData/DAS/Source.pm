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

=head1 NAME

Bio::EnsEMBL::ExternalData::DAS::Source

=head1 SYNOPSIS

  $src = Bio::EnsEMBL::ExternalData::DAS::Source->new(
    -DSN         => 'astd_exon_human_36',
    -URL         => 'http://www.ebi.ac.uk/das-srv/genomicdas/das',
    -COORDS      => [ 'chromosome:NCBI36, 'uniprot_peptide' ],
    #...etc
  );

=head1 DESCRIPTION

An object representation of a DAS source.

=head1 AUTHOR

Andy Jenkinson <aj@ebi.ac.uk>

=cut
package Bio::EnsEMBL::ExternalData::DAS::Source;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument  qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);

=head1 METHODS

=head2 new

  Arg [..]   : List of named arguments:
               -URL           - The URL (excluding source name) for the source.
               -DSN           - The source name.
               -COORDS        - (optional) The coordinate systems supported by
                                the source. This is an arrayref of
                                Bio::EnsEMBL::ExternalData::DAS::CoordSystem
                                objects.
               -LOGIC_NAME    - (optional) The logic name of the source.
               -LABEL         - (optional) The display name of the source.
               -DESCRIPTION   - (optional) The description of the source.
               -HOMEPAGE      - (optional) A URL link to a page with more
                                           information about the source.
               -MAINTAINER    - (optional) A contact email address for the source.
  Example    : $src = Bio::EnsEMBL::ExternalData::DAS::Source->new(
                  -DSN           => 'astd_exon_human_36',
                  -URL           => 'http://www.ebi.ac.uk/das-srv/genomicdas/das',
                  -COORDS        => [ $cs1, $cs2 ],
                  -LABEL         => 'ASTD transcripts',
                  -DESCRIPTION   => 'Transcripts from the ASTD database...',
                  -HOMEPAGE      => 'http://www.ebi.ac.uk/astd',
                  -MAINTAINER    => 'andy.jenkinson@ebi.ac.uk',
                );
  Description: Creates a new Source object representing a DAS source.
  Returntype : Bio::EnsEMBL::ExternalData::DAS::Source
  Exceptions : If the URL or DSN are missing or incorrect
  Caller     : general
  Status     : Stable

=cut
sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
  
  my ($name, $label, $url, $dsn, $coords, $desc, $homepage, $maintainer) =
    rearrange(['LOGIC_NAME', 'LABEL', 'URL', 'DSN', 'COORDS', 'DESCRIPTION', 'HOMEPAGE', 'MAINTAINER'], @_);
  
  $self->url           ( $url ); # Checks and applies some formatting
  $self->dsn           ( $dsn ); # Checks
  $self->logic_name    ( $name );
  $self->label         ( $label );
  $self->description   ( $desc );
  $self->maintainer    ( $maintainer );
  $self->homepage      ( $homepage );
  $self->coord_systems ( $coords );
  
  return $self;
}

=head2 full_url

  Args       : none
  Description: Getter for the source URL (including DSN)
  Returntype : scalar
  Status     : Stable

=cut
sub full_url {
  my $self = shift;
  return $self->url . q(/). $self->dsn;
}

=head2 url

  Arg [1]    : Optional value to set
  Description: Get/Setter for the server URL (excluding DSN)
  Returntype : scalar
  Exceptions : If the URL is missing or of an incorrect format
  Status     : Stable

=cut
sub url {
  my $self = shift;
  if ( @_ ) {
    $_[0] || throw("No URL specified");
    my ($url) = $_[0] =~ m{(.+/das)1?/*$};
    $url || throw("URL is not of correct format: $_[0]");
    $self->{url} = $url;
  }
  return $self->{url};
}

=head2 dsn

  Arg [1]    : Optional value to set
  Description: Get/Setter for the DSN
  Returntype : scalar
  Exceptions : If the DSN is missing
  Status     : Stable

=cut
sub dsn {
  my $self = shift;
  if ( @_ ) {
    my $dsn = shift || throw("No DSN specified");
    $self->{dsn} = $dsn;
  }
  return $self->{dsn};
}

=head2 coord_systems

  Arg [1]    : Optional value to set (arrayref)
  Description: Get/Setter for the Ensembl coordinate systems supported by the source
  Returntype : arrayref of Bio::EnsEMBL::ExternalData::DAS::CoordSystem objects
  Status     : Stable

=cut
sub coord_systems {
  my $self = shift;
  if ( @_ ) {
    $self->{coords} = shift;
  }
  return $self->{coords} || [];
}

=head2 description

  Arg [1]    : Optional value to set
  Description: Get/Setter for the source description
  Returntype : scalar
  Status     : Stable

=cut
sub description {
  my $self = shift;
  if ( @_ ) {
    $self->{description} = shift;
  }
  return $self->{description} || $self->label;
}

=head2 maintainer

  Arg [1]    : Optional value to set
  Description: Get/Setter for the source maintainer email address
  Returntype : scalar
  Status     : Stable

=cut
sub maintainer {
  my $self = shift;
  if ( @_ ) {
    $self->{maintainer} = shift;
  }
  return $self->{maintainer};
}

=head2 homepage

  Arg [1]    : Optional value to set
  Description: Get/Setter for the source homepage URL
  Returntype : scalar
  Status     : Stable

=cut
sub homepage {
  my $self = shift;
  if ( @_ ) {
    $self->{homepage} = shift;
  }
  return $self->{homepage};
}

=head2 logic_name

  Arg [1]    : Optional value to set
  Description: Get/Setter for the logic name
  Returntype : scalar
  Status     : Stable

=cut
sub logic_name {
  my $self = shift;
  if ( @_ ) {
    $self->{logic_name} = shift;
  }
  return $self->{logic_name} || $self->dsn;
}

=head2 label

  Arg [1]    : Optional value to set
  Description: Get/Setter for the source label
  Returntype : scalar
  Status     : Stable

=cut
sub label {
  my $self = shift;
  if ( @_ ) {
    $self->{label} = shift;
  }
  return $self->{label} || $self->dsn;
}

=head2 matches_species

  Arg [1]    : Species string
  Description: Determines whether the Source supports a species with at least
               one of its coordinate systems.
  Returntype : 1 or 0
  Status     : Stable

=cut
sub matches_species {
  my ($self, $species) = @_;
  if (grep { $_->matches_species( $species ) } @{ $self->coord_systems || [] }) {
    return 1;
  }
  return 0;
}

=head2 matches_name

  Arg [1]    : Whole or part name string
  Description: Determines whether the Source name matches a name filter. Matches
               the dsn and label against a regex.
  Returntype : 1 or 0
  Status     : Stable

=cut
sub matches_name {
  my ($self, $name) = @_;
  return (join '', $self->dsn, $self->label) =~ m/$name/ ? 1 : 0;
}


=head2 equals

  Arg [1]    : Bio::EnsEMBL::ExternalData::DAS::Source
               The source to compare to for equality.
  Example    : if($source1->equals($source2)) { ... }
  Description: Compares 2 DAS sources and returns true if they are
               equivalent.  The definition of equivalent is sharing the same
               full URL and coordinate systems.
  Returntype : 0 or 1
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut
sub equals {
  my ( $this, $that ) = @_;
  
  if ($this->full_url eq $that->full_url) {
    
    my @this_cs = sort { $a->to_string cmp $b->to_string } @{ $this->coord_systems };
    my @that_cs = sort { $a->to_string cmp $b->to_string } @{ $that->coord_systems };
    
    if ( scalar @this_cs != scalar @that_cs ) {
      return 0;
    }
    
    while (my $this_cs = shift @this_cs ) {
      my $that_cs = shift @that_cs;
      ( $this_cs && $that_cs && $this_cs->equals( $that_cs ) ) || return 0;
    }
    
    return 1;
  }
  
  return 0;
}

1;