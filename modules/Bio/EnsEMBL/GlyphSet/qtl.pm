package Bio::EnsEMBL::GlyphSet::qtl;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub squish {1;}

sub my_label { return "QTLs"; }

sub features {
  my ($self) = @_;
  return $self->{'container'}->get_all_QtlFeatures();
}

sub href {
  my($self,$f) = @_;
  ( my $SRC = uc( $f->qtl->source_database ) ) =~s/ /_/g;
  return  return $self->{'config'}->{'ext_url'}->get_url( $SRC, $f->qtl->source_primary_id );
}

sub zmenu {
    my ($self, $f ) = @_;

    return { 
     'caption'     => $f->qtl->trait,
     $f->qtl->source_database.':'.$f->qtl->source_primary_id => $self->href($f),
    };
}

sub image_label {
  my ($self, $f) = @_;
  return $f->qtl->trait,'overlaid';
}

1;
