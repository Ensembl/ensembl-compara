package Bio::EnsEMBL::GlyphSetManager::Pprotdas;

use strict;
use Sanger::Graphics::GlyphSetManager;
use Bio::EnsEMBL::GlyphSet::Pprotdas;
use Bio::EnsEMBL::GlyphSet::Pseparator;
use vars qw(@ISA);
@ISA = qw(Sanger::Graphics::GlyphSetManager);

sub init {
  my ($self) = @_;

  my $Config = $self->{'config'};
  my $protein = $self->{'container'};

  # Get features. The data structure returned is YUK!
  my $feat_container = $protein->get_all_DASFeatures();
  ref( $feat_container ) ne 'HASH' and return; # Sanity check

  # Set the order flag. This ensures glyphsets are drawn in the order 
  # they are pushed onto the list.
  $self->{'order'} = 9999;

  # Examine the data structure, and create glyphs accordingly
  my $user_confkey;
  foreach my $das_confkey( keys( %$feat_container ) ){

    $user_confkey = 'genedas_'.$das_confkey;

    # Add a separator (top)
    $self->add_glyphset_separator
      ({ 
        name=>"DAS $das_confkey",
        confkey=>$user_confkey,
        order  => sprintf("%05d", $self->{order} -- )
       });

    my $sub_feat_container = $feat_container->{$das_confkey};
    ref( $sub_feat_container ) ne 'ARRAY' and next; # Another sanity check
    my $feat_ref = $sub_feat_container->[1];

    # OK - we now have a list of DASSeqFeature objs. Sort them per-glyph
    my %feats_by_glyphset;
    foreach my $feat( @$feat_ref ){

      # Skip protein-wide features (GeneDAS - tabulated elsewhere )
      # GeneDAS Identified by DAS segment id eq DAS feature id
      if( $feat->das_segment->ref() eq $feat->das_id() ) { next; }	

      my $type = $feat->das_type_id() || 'UNKNOWN';
      $feats_by_glyphset{$type} ||= [];
      push @{$feats_by_glyphset{$type}}, $feat
    }
    if( ! scalar keys %feats_by_glyphset ){ 
      $feats_by_glyphset{'No annotation'} = [] 
    };

    foreach my $das_track( keys %feats_by_glyphset ) {
      my $extra_config = {};
      $extra_config->{'name'}     = $das_track;
      $extra_config->{'confkey'}  = $user_confkey;
      $extra_config->{'features'} = $feats_by_glyphset{$das_track};
      $extra_config->{'order'}    = sprintf( "%05d", $self->{order} -- );
      $self->add_glyphset( $extra_config );
    }
  }

    # Add a separator (bottom)
  #$self->add_glyphset_separator({ name=>'', 
  #                                  confkey=> $user_confkey,
  #                                  order  => sprintf( "%05d", 
  #                                                     $self->{order} -- ) });

  return 1;

}

sub add_glyphset {
    my ($self,$config) = @_;	
    my $glyphset;
    eval {
	$glyphset = new Bio::EnsEMBL::GlyphSet::Pprotdas
	  ( $self->{'container'},
	    $self->{'config'},
	    $self->{'highlights'},
	    $self->{'strand'},
	    $config );
    };
    if($@) {
	print STDERR "DAS GLYPHSET $config->{'name'} failed: $@\n";
	return undef();
    }

    push @{$self->{'glyphsets'}}, $glyphset;
    return 1;
}

sub add_glyphset_separator{
  my ($self,$config) = @_;	
  my $glyphset;
  eval {
    $glyphset = new Bio::EnsEMBL::GlyphSet::Pseparator
      ( $self->{'container'},
	$self->{'config'},
	$self->{'highlights'},
	$self->{'strand'},
	$config );
  };
  if($@) {
    print STDERR "DAS GLYPHSET $config->{'name'} failed: $@\n";
    return undef();
  }

  push @{$self->{'glyphsets'}}, $glyphset;
  return 1;
}

1;
