package EnsEMBL::Web::Component::Gene::GeneSeq;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub caption {
  return undef;
}

sub content {
  my $self   = shift;
  my $object = $self->object;
  my $slice  = $object->get_slice_object->Obj; # Object for this section is the slice

  my $colours = $object->species_defs->colour('sequence_markup');
  my %c = map { $_ => $colours->{$_}->{'default'} } keys %$colours;

  my $config = {
    display_width => $object->param('display_width') || 60,
    colours => \%c,
    site_type => ucfirst(lc($object->species_defs->ENSEMBL_SITETYPE)) || 'Ensembl',
    gene_name => $object->Obj->stable_id,
    species => $object->species,
    key_template => qq{<p><code><span style="%s">THIS STYLE:</span></code> %s</p>},
    key => ''
  };

  for ('exon_display', 'exon_ori', 'snp_display', 'line_numbering') {
    $config->{$_} = $object->param($_) unless $object->param($_) eq "off";
  }

  $config->{'exon_features'} = $object->get_slice_object->highlight_display($object->Obj->get_all_Exons);
  $config->{'slices'} = [{ slice => $slice, name => $config->{'species'} }];

  if ($config->{'line_numbering'}) {
    $config->{'end_number'} = 1;
    $config->{'number'} = 1;
  }

  my ($sequence, $markup) = $self->get_sequence_data($config->{'slices'}, $config);
  
  $self->markup_exons($sequence, $markup, $config) if $config->{'exon_display'};
  $self->markup_variation($sequence, $markup, $config) if $config->{'snp_display'};
  $self->markup_line_numbers($sequence, $config) if $config->{'line_numbering'};
  
  $config->{'html_template'} = qq{<p>$config->{'key'}</p><pre>&gt;} . $slice->name . qq{\n%s</pre>};
  
  return $self->build_sequence($sequence, $config);
}

1;
