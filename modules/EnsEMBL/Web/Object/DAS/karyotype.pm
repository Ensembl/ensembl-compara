package EnsEMBL::Web::Object::DAS::karyotype;

use strict;
use warnings;

use EnsEMBL::Web::Object::DAS;
our @ISA = qw(EnsEMBL::Web::Object::DAS);

sub Types {
  my $self = shift;

  my @segments = $self->Locations;
  my @features;
  my $dba = $self->database('core', $self->real_species); #->get_SliceAdaptor
  my $filter = 0;
  my %fts = map { $_?($_=>1):() } @{$self->FeatureTypes || []};
  $filter = 1 if keys %fts; 

  my $features =[];
  if(@segments) {
    foreach my $s (@segments) {
      if (ref($s) eq 'HASH' && ( $s->{'TYPE'} eq 'ERROR' || $s->{'TYPE'} eq 'UNKNOWN' ) ) {
        push @features, $s;
        next;
      }
      my $slice = $s->slice;
      my %types; 
      foreach my $ft (@{$slice->get_all_KaryotypeBands() || [] }){
        $types{$ft->{'stain'}}++;
      }
      my @segment_features = ();
      foreach (sort keys %types) {
        next if $filter && !$fts{"band:$_"};
        push @segment_features, { 'id' => "band:$_", 'text' => $types{$_}, 'category' => 'structural', 'method' => 'ensembl'  };
      }
      push @$features, {
        'REGION'   => $s->seq_region_name,
        'START'    => $s->seq_region_start,
        'STOP'     => $s->seq_region_end,
        'TYPE'     => $s->slice->coord_system_name,
        'FEATURES' => \@segment_features
      };
    }
    return $features;
  } else {
    my $sth = $dba->prepare("SELECT stain, count(*) FROM karyotype GROUP BY stain");
    $sth->execute();
    my @segment_features = ();
    foreach ( @{$sth->fetchall_arrayref} ) {
      next if $filter && !$fts{'band:'.$_->[0]};
      push @segment_features, { 'id' => "band:$_->[0]", 'text' => $_->[1], 'category' => 'structural', 'method' => 'ensembl'  };
    }
    return [{'FEATURES' => \@segment_features}];
  }
}

sub Features {
  my $self = shift;

  my @segments = $self->Locations;
  my @features;

  my $filter = 0;
  my %fts = map { $_?($_=>1):() } @{$self->FeatureTypes || []};
  $filter = 1 if keys %fts;

  my @fts = grep { $_ } @{$self->FeatureTypes || []};

  foreach my $s (@segments) {
    if (ref($s) eq 'HASH' && ( $s->{'TYPE'} eq 'ERROR' ||  $s->{'TYPE'} eq 'UNKNOWN' ) ) {
      push @features, $s;
      next;
    }
    my $slice = $s->slice;
    my @segment_features;
    my $group = {
      'ID'    => $s->seq_region_name,
      'TYPE'  => 'chromosome:'.$s->seq_region_name,
      'LABEL' => 'Chromosome '.$s->seq_region_name,
    };

    foreach my $ft (@{$slice->get_all_KaryotypeBands() || [] }){
      next if $filter && !$fts{'band:'.$ft->stain};
      my $f = {
        'ID'          => $ft->name,
        'TYPE'        => 'band:'.$ft->stain || '',
        'METHOD'      => 'ensembl',
        'CATEGORY'    => 'structural',
        'START'       => $ft->seq_region_start,
        'END'         => $ft->seq_region_end,
        'ORIENTATION' => 0,
        'GROUP'       => [$group]
      };
      push @segment_features, $f;
    }

    push @features, {
      'REGION'   => $s->seq_region_name, 
      'START'    => $s->seq_region_start, 
      'STOP'     => $s->seq_region_end,
      'FEATURES' => \@segment_features
    };
  }
  return \@features;
}

sub Stylesheet {
  my $self = shift;

  my $COL = $self->species_defs->colour('ideogram');
  my @default = ( 'FGCOLOR'=>'black','HEIGHT'=> 10, 'LABEL' => 'yes', 'BUMP' => 'no' );
  my $stylesheet_structure = {'structural' => {}};
  foreach ( keys %$COL ) {
    $stylesheet_structure->{'structural'}{'band:'.$_} = [{
      'type'=>'box',
      'attrs' => { @default,'BGCOLOR'=>$self->species_defs->colour('ideogram',lc($_)) }
    }];
  }
  $stylesheet_structure->{'structural'}{'default'} = [{'type'=>'box','attrs' => {@default, 'BGCOLOR'=>'grey50'}}];
  $stylesheet_structure->{'default'}{'default'} = [{'type'=>'box','attrs' => { @default,'BGCOLOR'=>'grey50'}}];
  return $self->_Stylesheet( $stylesheet_structure );
}

1;
