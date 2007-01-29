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

  $self->{'order'} = 9999;
  my $species_defs = $Config->{species_defs};

  my ($feat_container, $styles) = $translation->get_all_DAS_Features();
  my $source_container;

# Temp bit to get internal das sources. Later they should come from the session just like external sources
  my @das_source_names =  ref( $species_defs->ENSEMBL_INTERNAL_DAS_SOURCES ) eq 'HASH' ?  keys %{$species_defs->ENSEMBL_INTERNAL_DAS_SOURCES} : ();

  foreach my $isrc (@das_source_names) {
    my $confkey = "genedas_$isrc";
    next unless( $Config->get($confkey,'on') eq 'on' );
    $source_container->{$isrc} = $species_defs->ENSEMBL_INTERNAL_DAS_SOURCES->{$isrc};
  }

  my $object = $Config->{_object};
  foreach my $source (@{ $Config->{_object}->get_session->get_das_filtered_and_sorted($ENV{'ENSEMBL_SPECIES'}) }) {
    my $confkey = "genedas_".$source->get_key;
    next unless $Config->get($confkey,'on') eq 'on';
    $source_container->{ $source->get_key } = $source->get_data;
  }

  foreach my $src (sort keys %{$source_container || {}}) {
    my $source_config = $source_container->{$src};
    my $confkey = "genedas_$src";

    my %feats_by_glyphset;
    foreach my $feat( @{$feat_container->{$src} || []}){
      my $type = $feat->das_type || $feat->das_type_id || ' ';
      next if ( ($feat->das_type_id =~ /^(contig|component|karyotype)$/i) || ($feat->das_type_id =~ /^(contig|component|karyotype):/i) || (! $feat->das_end ));
      $feats_by_glyphset{$type} ||= [];
      push @{$feats_by_glyphset{$type}}, $feat
    }
    my $zmenu; 
    if ( my $chart = $source_config->{'score'}) {
      if ($chart ne 'n') {
        my ($min_score, $max_score) = (sort {$a <=> $b} (map { $_->score } @{$feat_container->{$src} || []}))[0,-1] ;
        $zmenu = {
	  "10: Min Score: $min_score" => '',
	  "20: Max Score: $max_score" => ''
	};
      }
    }
   # Add a separator (top)
    my $label = $source_config->{'label'} || $source_config->{'name'} || $source_config->{'dsn'};
    $self->add_glyphset_separator ({ 
      'name'      => $label,
      'confkey'   => $confkey,
      'authority' => $source_config->{'authority'},
      'order'     => sprintf("%05d", $self->{order} -- ),
      'zmenu' => $zmenu
    });

    foreach my $ftype ( keys %feats_by_glyphset ) {
      my $extra_config = {};
      %$extra_config = %$source_config;
      $extra_config->{'source_type'}  = $source_config->{'type'},
      $extra_config->{'label'}        = $ftype;
      $extra_config->{'confkey'}      = $confkey;
      $extra_config->{'features'}     = $feats_by_glyphset{$ftype};
      $extra_config->{'order'}        = sprintf( "%05d", $self->{order} -- );
      $extra_config->{'styles'}       = $styles->{$src};
      $extra_config->{'use_style'} = uc($extra_config->{'stylesheet'}) eq 'Y' ? 1 : 0;
      $extra_config->{'colour'} ||= $extra_config->{'col'};
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
