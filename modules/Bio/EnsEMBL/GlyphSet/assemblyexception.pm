package Bio::EnsEMBL::GlyphSet::assemblyexception;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);
use Data::Dumper;

$Data::Dumper::Indent=3;
sub squish {1;}

my %MAP = (
 'HAP' => 'Haplotype block',
 'PAR' => 'Pseudo-autosomal region' 
);

sub my_label { 
    my $self = shift;
    if ($self->{'config'}->get('lab') eq 'off') {
	return;
    }
    return $self->{'config'}->get('_settings','simplehap') ? '' : "HAP/PAR.";
}

sub features {
  my ($self) = @_;
  my $r = $self->{'container'}->get_all_AssemblyExceptionFeatures();
#  warn scalar @$r;
#  warn Data::Dumper::Dumper($r);
  return $r;

}

sub tag {
  my ($self, $f) = @_;
  return { 'style' => 'join', 'tag' => $f->{'start'}.'-'.$f->{'end'}, 'colour' => $f->type eq 'PAR' ? 'aliceblue' : 'bisque' };
}

sub href {
 my ($self, $f ) = @_;
  my $c2 = $f->{'alternate_slice'}->seq_region_name;
  my $s2 = $f->{'alternate_slice'}->start;
  my $e2 = $f->{'alternate_slice'}->end;
  my $o2 = $f->{'alternate_slice'}->strand;
  return "/@{[$self->{container}{_config_file_name_}]}/$ENV{'ENSEMBL_SCRIPT'}?l=$c2:$s2-$e2";
}

sub zmenu {
  my ($self, $f ) = @_;

  my $c1 = $f->{'slice'}->seq_region_name;
  my $s1 = $f->{'slice'}->start+$f->{'start'}-1;
  my $e1 = $f->{'slice'}->start+$f->{'end'}-1;
  my $o1 = $f->{'slice'}->strand;

  my $c2 = $f->{'alternate_slice'}->seq_region_name;
  my $s2 = $f->{'alternate_slice'}->start;
  my $e2 = $f->{'alternate_slice'}->end;
  my $o2 = $f->{'alternate_slice'}->strand;
  my $name1 = "$c1:$s1-$e1 ($o1)";
  my $name2 = "$c2:$s2-$e2 ($o2)";
  return { 
    'caption' => $MAP{$f->type},
    $name1    => '',
    $name2    => $self->href($f)
  };
}

sub image_label {
  my ($self, $f) = @_;
  return undef if $self->my_config( 'label' ) eq 'off';
  if( $self->{'config'}->get('_settings','simplehap') ) {
    return $self->{'strand'} > 0 ? undef : ( $f->{'alternate_slice'}->seq_region_name, 'under' ) ;
  }
  my $c2 =  $f->{'alternate_slice'}->seq_region_name;
  my $s2 = $f->{'alternate_slice'}->start;
  my $e2 = $f->{'alternate_slice'}->end;
  my $o2 = $f->{'alternate_slice'}->strand;
  my $name2 = "@{[$f->type]} $c2:$s2-$e2 ($o2)";
  return( $name2,'under' );
}

sub colour {
  my ($self, $f) = @_;
  return $f->type eq 'PAR' ? 'blue3' : 'red3';
}

sub no_features { }
1;
