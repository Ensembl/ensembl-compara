package Bio::EnsEMBL::GlyphSet::_qtl;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub squish {1;}

sub my_label { return "QTLs"; }

sub features {
  my ($self) = @_;
  return $self->{'container'}->get_all_QtlFeatures();
}

sub href {
  my($self,$f, $src) = @_;

  my $syns = $f->qtl->get_synonyms;

  #if no source specified use first src
  ($src) = keys %$syns if(!$src);

  my $id = $syns->{$src};

  ( my $SRC = uc( $src ) ) =~s/ /_/g;
  return $self->ID_URL( $SRC, $id);
}

sub zmenu {
    my ($self, $f ) = @_;

    my $syns = $f->qtl->get_synonyms;

    #create links of form SOURCE:ID => URL
    my @links = map {$_.':'.$syns->{$_} => $self->href($f,$_)} keys %$syns;

    return { 
     'caption'     => $f->qtl->trait,
     @links
    };
}

sub image_label {
  my ($self, $f) = @_;
  return $f->qtl->trait,'overlaid';
}

1;
