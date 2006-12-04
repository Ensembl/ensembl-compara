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
  my $translation = $self->{'container'};
  return  if (! $translation->dbID );

  # Get features.
  my $feat_container = $translation->get_all_DAS_Features();
  $self->{'order'} = 9999;

  my @das_adaptors = map{$_->adaptor} @{$translation->get_all_DASFactories};
  my %authorities = map{$_->name => $_->authority} @das_adaptors;
  my %stypes = map{$_->name => $_->type} @das_adaptors;

  my $user_confkey;
  foreach my $source ( keys( %$feat_container ) ){
    $user_confkey = "genedas_$source";
    next if ($Config->get($user_confkey, "on") ne 'on');
    my @features = @{$feat_container->{$source}};

# To distiguish between tracks that really don't have features and those that don't have features that we display
    my $skipped_features = 0; 

    my %feats_by_glyphset;
    foreach my $feat( @features ){
      my $type = $feat->das_type || $feat->das_type_id || 'UNKNOWN';

      if ( ($feat->das_type_id =~ /^(contig|component|karyotype)$/i) || ($feat->das_type_id =~ /^(contig|component|karyotype):/i) || (! $feat->das_end )) {
        $skipped_features = 1;
        next;
      }
      my $fend = $feat->das_end();
      $feats_by_glyphset{$type} ||= [];
      push @{$feats_by_glyphset{$type}}, $feat
    }
    if (! scalar keys %feats_by_glyphset) {
      next if ($skipped_features);
      $feats_by_glyphset{'No annotation'} = [] 
    };
   # Add a separator (top)
    my $label = $Config->get($user_confkey, "label") || $source;
    $self->add_glyphset_separator ({ 
      'name'      => $label,
      'confkey'   => $user_confkey,
      'authority' => $authorities{$source},
      'order'     => sprintf("%05d", $self->{order} -- )
    });
    foreach my $das_track( keys %feats_by_glyphset ) {
      my $extra_config = {};
      $extra_config->{'name'}         = $das_track;
      $extra_config->{'source_type'}  = $stypes{$source},
      $extra_config->{'confkey'}      = $user_confkey;
      $extra_config->{'features'}     = $feats_by_glyphset{$das_track};
      $extra_config->{'order'}        = sprintf( "%05d", $self->{order} -- );
      $self->add_glyphset( $extra_config );
    }
  }

  return 1;
}


sub add_glyphset {
  my ($self,$config) = @_;	
  my $glyphset;
  eval {
    $glyphset = new Bio::EnsEMBL::GlyphSet::Pprotdas(
      $self->{'container'},  $self->{'config'},
      $self->{'highlights'}, $self->{'strand'}, $config
    );
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
    $glyphset = new Bio::EnsEMBL::GlyphSet::Pseparator(
      $self->{'container'},   $self->{'config'},
      $self->{'highlights'}, $self->{'strand'},  $config
    );
  };
  if($@) {
    print STDERR "DAS GLYPHSET $config->{'name'} failed: $@\n";
    return undef();
  }
  push @{$self->{'glyphsets'}}, $glyphset;
  return 1;
}

1;
