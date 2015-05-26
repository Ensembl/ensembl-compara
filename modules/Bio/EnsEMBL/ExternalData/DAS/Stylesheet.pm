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

Bio::EnsEMBL::ExternalData::DAS::Stylesheet

############################################################################
#
# DEPRECATED MODULE - DAS SUPPORT WILL BE REMOVED FROM ENSEMBL IN RELEASE 83
#
#############################################################################


=head1 SYNOPSIS

  # Build a stylesheet object from the DAS response
  $das = Bio::Das::Lite->new($das_source_url);
  
  while ( ($url, $raw) = each %{ $das->stylesheet() } ) {
    $ss = Bio::EnsEMBL::ExternalData::DAS::Stylesheet->new( $raw );
  }
  
  # Find the glyph type for a feature
  $glyphtype = $ss->find_feature_glyph( $feature->type_category,
                                        $feature->type_id        );
  
  # Find the glyph type for a feature group
  $groups = $feature->groups();
  $glyphtype = $ss->find_group_glyph( $groups->[0]->{type_id} );
  
  # Use with ensembl-webcode:
  $symboltype = $glyphtype->{'symbol'};
  $symbol = Bio::EnsEMBL::Glyph::Symbol::$symboltype->new( $feature,
                                                           $glyphtype );

=head1 DESCRIPTION

An object representation of a DAS stylesheet, with methods for assigning glyph
types to features.

=cut
package Bio::EnsEMBL::ExternalData::DAS::Stylesheet;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(Exporter);
use vars qw(@EXPORT @EXPORT_OK);

@EXPORT = @EXPORT_OK = qw($DEFAULT_GRADIENT $DEFAULT_HISTOGRAM $DEFAULT_TILING
                          $BOX_GLYPH $LINE_GLYPH $HIDDEN_GLYPH);

our $DEFAULT_GRADIENT = bless {
  'default' => { 'default' => { 'default' => { 'symbol' => 'gradient',
                                               'color1' => 'yellow',
                                               'color2' => 'green',
                                               'color3' => 'blue'      } } }
}, 'Bio::EnsEMBL::ExternalData::DAS::Stylesheet';

our $DEFAULT_HISTOGRAM = bless {
  'default' => { 'default' => { 'default' => { 'symbol' => 'histogram',
                                               'color1' => 'black'      } } }
}, 'Bio::EnsEMBL::ExternalData::DAS::Stylesheet';

our $DEFAULT_TILING = bless {
  'default' => { 'default' => { 'default' => { 'symbol' => 'tiling',
                                               'color1' => 'orange'  } } }
}, 'Bio::EnsEMBL::ExternalData::DAS::Stylesheet';

# Default glyph, returned by find_feature_glyph when there is no matching style data
our $BOX_GLYPH = {
  'symbol'  => 'box',
  'fgcolor' => 'blue',
  'bgcolor' => 'blue'
};

# Default glyph, returned by find_group_glyph when there is no matching style data
our $LINE_GLYPH = {
  'symbol'  => 'line',
  'fgcolor' => 'blue',
  'bgcolor' => 'blue'
};

our $HIDDEN_GLYPH = {
  'symbol'  => 'hidden',
};

=head1 METHODS

=head2 new

  Arg [1]    : raw Bio::Das::Lite data (hashref or single-element arrayref)
  Example    : for $raw ( values %{ $das->stylesheet() } ) {
                 $ss = Bio::EnsEMBL::ExternalData::DAS::Stylesheet->new( $raw );
               }
  Description: Constructs a Stylesheet object from parsed DAS XML
  Returntype : Bio::EnsEMBL::ExternalData::DAS::Stylesheet
  Exceptions : If raw data is not in the correct format
  Caller     : Bio::EnsEMBL::ExternalData::DAS::Coordinator
  
=cut

sub new {
  my $proto = shift;
  my $class = ref $proto || $proto;
  my $self  = bless {}, $class;
  my $raw   = shift;
  if ( !$raw || !ref $raw ) {
    return $self;
  }
  if ( ref $raw eq 'ARRAY' ) {
    $raw = $raw->[0];
  }
  if ( ref $raw ne 'HASH' ) {
    throw('Raw data not in correct format');
  }
  
  # Raw hash is like:
  # {
  #  'category' => [
  #                 'category_id' => 'transcription',
  #                 'type'        => [
  #                                   {
  #                                    'type_id' => 'exon',
  #                                    'glyph'   => [
  #                                                  {
  #                                                   'glyph_zoom' => 'high',
  #                                                   'box' => [
  #                                                             {
  #                                                              'fgcolor' => 'red',
  #                                                              'bgcolor' => 'black'
  #                                                             }
  #                                                            ]
  #                                                  }
  #                                                 ]
  #                                   }
  #                                  ]
  #                ]
  # }
  
  # We simplify hash into:
  # {
  #  'transcription' => {
  #                      'exon' => {
  #                                 'high' => {
  #                                            'symbol'  => 'box',
  #                                            'fgcolor' => 'red',
  #                                            'bgcolor' => 'black'
  #                                           }
  #                                }
  #                     }
  # }
  for my $category ( @{ $raw->{'category'} || [] } ) {
    
    for my $type ( @{ $category->{'type'} || [] } ) {
      
      for my $glyph_hash ( @{ $type->{'glyph'} } ) {
        
        my $zoom = delete $glyph_hash->{'glyph_zoom'} || 'default';
        my $glyph_type = ( keys %{ $glyph_hash } )[0];
        my $glyph_attr = $glyph_hash->{$glyph_type}->[0] || next;
        $glyph_attr->{'symbol'} = $glyph_type;
        
        # Store the glyph
        $self->{ $category->{'category_id'} }{ $type->{'type_id'} }{ $zoom } = $glyph_attr;
      }
    }
  }
  
  return $self;
}

=head2 find_feature_glyph

  Arg [1]    : string category
  Arg [2]    : string type
  Arg [3]    : (optional) string zoom [high|medium|low]
  Examples   : $glyph = $stylesheet->find_glyph_type( 'transcription', 'exon' );
  Description: Assigns a glyph type given a feature category and type. If a
               match is not found, will return a default box glyph. The result
               is cached for faster subsequent lookups.
  Returntype : A hashref suitable for use with Bio::EnsEMBL::Glyph::Symbol
  Exceptions : none
  Caller     : ensembl-webcode drawning modules

=cut

sub find_feature_glyph {
  my ( $self, $category, $type, $zoom ) = @_;
  $zoom ||= 'default';
  # If not found in the tree, expand the tree to include it so that next
  # feature with same type is found faster
  $self->{$category}{$type}{$zoom} ||= $self->{$category}{$type    }{'default'} ||
                                       $self->{$category}{'default'}{$zoom    } ||
                                       $self->{$category}{'default'}{'default'} ||
                                       $self->{'default'}{$type    }{$zoom    } ||
                                       $self->{'default'}{$type    }{'default'} ||
                                       $self->{'default'}{'default'}{$zoom    } ||
                                       $self->{'default'}{'default'}{'default'} ||
                                       $BOX_GLYPH;
}

=head2 find_group_glyph

  Arg [1]    : string type
  Arg [2]    : (optional) string zoom [high|medium|low]
  Examples   : $glyph = $stylesheet->find_glyph_type( 'transcription', 'exon' );
  Description: Assigns a glyph type given a group type. If a match is not found,
               will return a default line glyph. The result is cached for faster
               subsequent lookups.
  Returntype : A hashref suitable for use with Bio::EnsEMBL::Glyph::Symbol
  Exceptions : none
  Caller     : ensembl-webcode drawing modules

=cut

sub find_group_glyph {
  my ( $self, $type, $zoom ) = @_;
  $zoom ||= 'default';
  # If not found in the tree, expand the tree to include it so that next
  # feature with same type is found faster
  $self->{'group'}{$type}{$zoom} ||= $self->{'group'}{$type    }{'default'} ||
                                     $self->{'group'}{'default'}{$zoom    } ||
                                     $self->{'group'}{'default'}{'default'} ||
                                     $LINE_GLYPH;
}


1;
