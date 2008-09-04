package Bio::EnsEMBL::GlyphSet::assemblyexception;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub squish {1;}

sub features {
  my ($self) = @_;
  warn "THIS IS AN ASSEMBLY EXCEPTION CALL...";
  warn @{ $self->{'container'}->get_all_AssemblyExceptionFeatures()||[] };
  return $self->{'container'}->get_all_AssemblyExceptionFeatures();
}

sub colour {
  my( $self, $f ) = @_;
  return $self->my_colour( $f->type );
}

sub feature_label {
  my ($self, $f) = @_;
  return undef if $self->my_config( 'label' ) eq 'off';
  if( $self->{'config'}->get_parameter( 'simplehap') ) {
    return $self->{'strand'} > 0 ? undef : ( $f->{'alternate_slice'}->seq_region_name, 'under' ) ;
  }
  my $c2 = $f->{'alternate_slice'}->seq_region_name;
  my $s2 = $f->{'alternate_slice'}->start;
  my $e2 = $f->{'alternate_slice'}->end;
  my $o2 = $f->{'alternate_slice'}->strand;
  my $name2 = $f->type.": $c2:$s2-$e2 ($o2)";
  return( $name2,'under' );
}

sub title {
  my ($self, $f ) = @_;

  my $c1 = $f->{'slice'}->seq_region_name;
  my $s1 = $f->{'slice'}->start+$f->{'start'}-1;
  my $e1 = $f->{'slice'}->start+$f->{'end'}-1;
  my $o1 = $f->{'slice'}->strand;

  my $c2 = $f->{'alternate_slice'}->seq_region_name;
  my $s2 = $f->{'alternate_slice'}->start;
  my $e2 = $f->{'alternate_slice'}->end;
  my $o2 = $f->{'alternate_slice'}->strand;
  my $name1 = "$c1: $s1-$e1 ($o1)";
  my $name2 = "$c2: $s2-$e2 ($o2)";
  my $HREF2 = $ENV{'ENSEMBL_SCRIPT'} eq 'multicontigview' ? "/@{[$self->{container}{web_species}]}/contigview?l=$c1:$s1-$e1": '';
  return $self->my_colour($f->type,'text')."; $c1:$s1-$e1 ($o1); $c2:$s2-$e2 ($o2)";
}


sub href {
  my ($self, $f ) = @_;
  my $c2 = $f->{'alternate_slice'}->seq_region_name;
  my $s2 = $f->{'alternate_slice'}->start;
  my $e2 = $f->{'alternate_slice'}->end;
  my $o2 = $f->{'alternate_slice'}->strand;
  my $script = $ENV{'ENSEMBL_SCRIPT'} eq 'multicontigview' ? 'contigview' : $ENV{'ENSEMBL_SCRIPT'};
  return $self->_url({
    'action' => 'View',
    'r'      => "$c2:$s2-$e2"
  });
}

sub tag {
  my ($self, $f) = @_;
  return { 'style' => 'join', 'tag' => $f->{'start'}.'-'.$f->{'end'}, 'colour' => $f->type eq 'PAR' ? 'aliceblue' : 'bisque', 'zindex' => -20 };
}

1;
