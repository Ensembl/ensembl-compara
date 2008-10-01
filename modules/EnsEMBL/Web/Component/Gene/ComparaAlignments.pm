package EnsEMBL::Web::Component::Gene::ComparaAlignments;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  my $gene   = $self->object;
  my $html = qq{<p><strong>This gene can be viewed in genomic alignment with other species</strong></p>} ;

  my %alignments = $gene->species_defs->multiX('ALIGNMENTS');
  my $species = $gene->species;

  my $FLAG = 0;
  foreach my $id (
    sort { 10 *($alignments{$b}->{'type'} cmp $alignments{$a}->{'type'}) + ($a <=> $b) }
    grep { $alignments{$_}->{'species'}->{$species} }
    keys (%alignments)
  ) {
    my $label = $alignments{$id}->{'name'};
    my $KEY = "opt_align_${id}";
    my @species = grep {$_ ne $species} sort keys %{$alignments{$id}->{'species'}};
    if ( scalar(@species) == 1) {
     ($label = $species[0]) =~ s/_/ /g;
    }
    $html .= sprintf( qq(&nbsp;&nbsp;&nbsp;<a href="/%s/alignsliceview?l=%s:%s-%s;align=%s">view genomic alignment with <strong>%s</strong></a> <br/>),
       $gene->species,
       $gene->seq_region_name,
       $gene->seq_region_start,
       $gene->seq_region_end,
       $KEY,
       $label
    );
    $FLAG = 1;
  }

  return $FLAG ? $html : '';
}

1;

