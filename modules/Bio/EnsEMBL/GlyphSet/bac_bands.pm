package Bio::EnsEMBL::GlyphSet::bac_bands;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);
sub my_label { return "Band BACs"; }

sub features {
    my ($self) = @_;
    my $container_length = $self->{'container'}->length();	
	return $self->{'container'}->get_all_MiscFeatures( 'bacs_bands' );
}

sub href {
  my $self = shift;
  my $f = shift;
  my $chr = $f->seq_region_name;
  my $chr_start = $f->seq_region_start;
  my $chr_end = $f->seq_region_end;

  my $page = ($ENV{'ENSEMBL_SCRIPT'} eq 'cytoview') ? 'contigview' : 'cytoview';

  return qq(/@{[$self->{container}{_config_file_name_}]}/$page?chr=$chr&chr_start=$chr_start&chr_end=$chr_end) ;
}

sub zmenu {
  my ($self, $f ) = @_;
  return if $self->{'container'}->length() > ( $self->{'config'}->get( 'bac_bands', 'threshold_navigation' ) || 2e7) * 1000;
	
  my $page = ($ENV{'ENSEMBL_SCRIPT'} eq 'cytoview') ? 'contigview' : 'cytoview';

  my $zmenu = {
    'caption'   => "BAC: @{[$f->get_scalar_attribute('name')]}",
    "01:Jump to $page" => $self->href($f),
    "02:Status: @{[$f->get_scalar_attribute('status')]}"   => '',
  };
  foreach( @{$f->get_all_attribute_values('synonyms')} ) {
    $zmenu->{"04:BAC band: $_"} = '';
  }
  foreach(@{$f->get_all_attribute_values('embl_accs')}) {
    $zmenu->{"06:BAC end: $_"} = $self->ID_URL( 'EMBL', $_);
  }
  return $zmenu;
}

sub colour {
    my ($self, $f) = @_;
    my $state = $f->get_scalar_attribute('status');
    return $self->{'colours'}{"col_$state"},
           $self->{'colours'}{"lab_$state"},
           $f->length > $self->{'config'}->get( "bac_bands", 'outline_threshold' ) ? 'border' : '';
}

sub image_label {
    my ($self, $f ) = @_;
    return ($f->get_scalar_attribute('name'),'overlaid');
}

1;

