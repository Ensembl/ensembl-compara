package EnsEMBL::Web::Object::DAS;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Object);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( @_ );
  $self->real_species = $ENV{ENSEMBL_SPECIES};
  $self->{'_slice_hack'} = {};
  $self->{'_features'}   = {};
  return $self; 
}

sub real_species       :lvalue {
  my $self = shift;
  $self->{'real_species'};
};

sub ori {
  my($self,$strand) =@_;
  return $strand>0 ? '+' :
         $strand<0 ? '-' :
                     '.' ;
}
sub slice_cache {
  my( $self, $slice ) = @_;
  my $slice_name = $slice->seq_region_name.':'.$slice->start.','.$slice->end.':'.$slice->strand;
  unless( exists $self->{'_features'}{$slice_name} ) {
    $self->{'_features'}{$slice_name} = {
      'REGION' => $slice->seq_region_name,
      'START'  => $slice->start,
      'STOP'   => $slice->end,
      'FEATURES' => [],
    };
    if( $slice->strand > 0 ) {
      $self->{'_slice_hack'}{$slice_name} = [  1, $self->{'_features'}{$slice_name}{'START'}-1 ];
    } else {
      $self->{'_slice_hack'}{$slice_name} = [ -1, $self->{'_features'}{$slice_name}{'STOP'} +1 ];
    }
  }
  return $slice_name;
}

sub base_features {
  my( $self, $feature_type, $feature_label ) = @_;

  $self->{_feature_label} = $feature_label;
  my @segments      = $self->Locations;
  my %feature_types = map { $_ ? ($_=>1) : () } @{$self->FeatureTypes  || []};
  my @group_ids     = grep { $_ }               @{$self->GroupIDs      || []};
  my @feature_ids   = grep { $_ }               @{$self->FeatureIDs    || []};

  my $dba_hashref;
  my( $db, @logic_names ) = split /-/, $ENV{'ENSEMBL_DAS_SUBTYPE'};
  $db = 'core' unless $db;
  my @features;
  foreach ($db) {
    my $T = $self->{data}->{_databases}->get_DBAdaptor($_,$self->real_species);
    $dba_hashref->{$_}=$T if $T;
  }
  @logic_names = (undef) unless @logic_names;
  if(0){
    warn "Databases:   ",join ' ', sort keys %$dba_hashref;
    warn "Logic names: @logic_names";
    warn "Segments:    ",join ' ', map { $_->slice->seq_region_name } @segments;
    warn "Group ids:   @group_ids";
    warn "Feature ids: @feature_ids";
  }
  my $call         = "get_all_$feature_type".'s';
  my $adapter_call = "get_$feature_type".'Adaptor';

  foreach my $segment (@segments) {
    if( ref($segment) eq 'HASH' && $segment->{'TYPE'} eq 'ERROR' ) {
      push @features, $segment;
      next;
    }
    foreach my $db_key ( keys %$dba_hashref ) {
      foreach my $logic_name (@logic_names) {
        foreach my $feature ( @{$segment->slice->$call($logic_name,undef,$db_key) } ) {
          $self->_feature( $feature );
        }
      }
    }
  }
  my $dafa_hashref = {};
  foreach my $id ( @group_ids, @feature_ids ) {
    foreach my $db ( keys %$dba_hashref ) {
      $dafa_hashref->{$db} ||= $dba_hashref->{$db}->$adapter_call;
      foreach my $logic_name (@logic_names) {
        foreach my $align ( @{$dafa_hashref->{$db}->fetch_all_by_hit_name( $id, $logic_name )} ) {
          $self->_feature( $align );
        }
      }
    }
  }
  push @features, values %{ $self->{'_features'} };
  return \@features;
}

sub loc {
  my( $self, $slice_name, $start, $end, $strand ) = @_;
  return (
    'START'       => $self->{_slice_hack}{$slice_name}[0] * $start + $self->{_slice_hack}{$slice_name}[1],
    'END'         => $self->{_slice_hack}{$slice_name}[0] * $end   + $self->{_slice_hack}{$slice_name}[1],
    'ORIENTATION' => $self->{_slice_hack}{$slice_name}[0] * $strand > 0 ? '+' : '-'
  );
}

#sub Obj { 
#  return $_[0]{'data'}{'_object'}[0]->Obj; 
#}

sub Locations { return @{$_[0]{data}{_object}}; }

sub FeatureTypes { 
  my $self = shift;
  push @{$self->{'_feature_types'}}, @_ if @_;
  return $self->{'_feature_types'};
}

sub FeatureIDs { 
  my $self = shift;
  push @{$self->{'_feature_ids'}}, @_ if @_;
  return $self->{'_feature_ids'};
}

sub GroupIDs { 
  my $self = shift;
  push @{$self->{'_group_ids'}}, @_ if @_;
  return $self->{'_group_ids'};
}

sub Stylesheet { 
  my $self = shift;
  $self->_Stylesheet({});
}

sub _Stylesheet {
  my( $self, $category_hashref ) = @_;
  $category_hashref ||= {};
  my $stylesheet = qq(<STYLESHEET version="1.0">\n);
  foreach my $category_id ( keys %$category_hashref ) {
    $stylesheet .= qq(  <CATEGORY id="$category_id">\n);
    my $type_hashref = $category_hashref->{$category_id};
    foreach my $type_id ( keys %$type_hashref ) {
      $stylesheet .= qq(    <TYPE id="$type_id">\n);
      my $glyph_arrayref = $type_hashref->{$type_id};
      foreach my $glyph_hashref (@$glyph_arrayref ) {
        $stylesheet .= sprintf qq(      <GLYPH%s>\n        <%s>),
          $glyph_hashref->{'zoom'} ? qq( zoom="$glyph_hashref->{'zoom'}") : '',
          uc($glyph_hashref->{'type'});
        foreach my $key (keys %{$glyph_hashref->{'attrs'}||{}} ) {
          $stylesheet .= sprintf qq(          <%s>%s</%s>\n),
            uc($key),
            $glyph_hashref->{'attrs'}{$key},
            uc($key);
        }
        $stylesheet .= sprintf qq(        </%s>\n      </GLYPH>),  uc($glyph_hashref->{'type'});
      }
      $stylesheet .= qq(    </TYPE>\n);
    }
    $stylesheet .= qq(  </CATEGORY>\n);
  }
  $stylesheet .= qq(</STYLESHEET>\n);
  return $stylesheet;
}

sub EntryPoints {
  my ($self) = @_;
  my $collection;
  return $collection;
}

sub Types {
  my ($self) = @_;
  my $collection;
  return $collection;
}
1;
