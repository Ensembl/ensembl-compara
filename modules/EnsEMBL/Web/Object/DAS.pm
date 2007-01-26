package EnsEMBL::Web::Object::DAS;

use strict;
use warnings;

use EnsEMBL::Web::Object;
our @ISA = qw(EnsEMBL::Web::Object);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( @_ );
  $self->real_species = $ENV{ENSEMBL_SPECIES};
  return $self; 
}

sub real_species       :lvalue { $_[0]->{'data'}{'real_species'}};

#sub Obj { 
#  return $_[0]{'data'}{'_object'}[0]->Obj; 
#}

sub Locations { return @{$_[0]{data}{_object}}; }

sub FeatureTypes { 
  my $self = shift;
  push @{$self->{'data'}{'_feature_types'}}, @_ if @_;
  return $self->{'data'}{'_feature_types'};
}

sub FeatureIDs { 
  my $self = shift;
  push @{$self->{'data'}{'_feature_ids'}}, @_ if @_;
  return $self->{'data'}{'_feature_ids'};
}

sub GroupIDs { 
  my $self = shift;
  push @{$self->{'data'}{'_group_ids'}}, @_ if @_;
  return $self->{'data'}{'_group_ids'};
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
    $stylesheet .= sprintf qq(  <CATEGORY id="%s">\n), $category_id;
    my $type_hashref = $category_hashref->{$category_id};
    foreach my $type_id ( keys %$type_hashref ) {
      $stylesheet .= sprintf qq(    <TYPE id="%s">\n), $type_id;
      my $glyph_arrayref = $type_hashref->{$type_id};
      foreach my $glyph_hashref (@$glyph_arrayref ) {
        $stylesheet .= sprintf qq(      <GLYPH%s>\n        <%s>), $glyph_hashref->{'zoom'}? qq( zoom="$glyph_hashref->{'zoom'}") : '', uc($glyph_hashref->{'type'});
        foreach my $key (keys %{$glyph_hashref->{'attrs'}||{}} ) {
          $stylesheet .= sprintf qq(          <%s>%s</%s>\n),  uc($key), $glyph_hashref->{'attrs'}{$key}, uc($key);
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
